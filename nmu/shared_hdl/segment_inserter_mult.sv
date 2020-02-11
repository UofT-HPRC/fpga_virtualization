`timescale 1ns / 1ps
`default_nettype none


module segment_inserter_mult
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_USER_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_BUS_LANES_LOG2 = NUM_BUS_BYTES_LOG2 - 1,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    //Inserted segment parameters
    parameter bit USE_DYNAMIC_FSM = 0,
    parameter INSERT_OFFSET = 12,
    parameter NUM_INSERT_SIZES = 2,
    parameter integer INSERT_SIZES_BYTES [NUM_INSERT_SIZES] = '{0,4},	//sizes, smallest to largest
    
    //Derived parameters for inserted segment 
    localparam NUM_INSRT_SIZES_LOG2 = $clog2(NUM_INSERT_SIZES),

    localparam MAX_INSRT_SIZE = INSERT_SIZES_BYTES[NUM_INSERT_SIZES-1],
    localparam NUM_INSRT_BYTES_LOG2 = $clog2(MAX_INSRT_SIZE),
    localparam NUM_INSRT_BYTES_CBITS = $clog2(MAX_INSRT_SIZE + 1),
    localparam NUM_INSRT_LANES = (MAX_INSRT_SIZE/2),
    localparam NUM_INSRT_LANES_LOG2 = NUM_INSRT_BYTES_LOG2 - 1
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [AXIS_USER_WIDTH-1:0]        axis_in_tuser,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [AXIS_USER_WIDTH-1:0]       axis_out_tuser,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,
    
    //Parmeter values for inserting
    input wire [(MAX_INSRT_SIZE*8)-1:0]     seg_to_insert,
    input wire [NUM_INSRT_BYTES_CBITS-1:0]  segment_size,
    input wire [NUM_INSRT_SIZES_LOG2-1:0]	segment_sel,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Segment (and FIFO) encap and stream data             //
    //--------------------------------------------------------//
    
    //Aliases for the pop side of the buffer (2 byte segments, assume network traffic even-byte aligned upto L2)
    wire [15:0]  axis_in_pop_tdata [NUM_BUS_LANES-1:0];
    wire [1:0]   axis_in_pop_tkeep [NUM_BUS_LANES-1:0];
    wire [1:0]   axis_in_pop_next_tkeep [NUM_BUS_LANES-1:0];
    wire         axis_in_pop_tvalid [NUM_BUS_LANES-1:0];
    wire         axis_lane_rd_en [NUM_BUS_LANES-1:0];

    wire [AXIS_USER_WIDTH-1:0]  axis_in_pop_tuser;
    wire                        axis_in_pop_tlast;
    
    //The FIFO
    axis_segout_shift_fifo
    #(
        .AXIS_BUS_WIDTH (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH  (AXIS_USER_WIDTH),
        .NUM_SEGMENTS   (NUM_BUS_LANES),
        .BUFFER_DEPTH   (3)
    )
    buffer
    (
        //Input AXI stream
        .axis_in_tdata       (axis_in_tdata),
        .axis_in_tuser       (axis_in_tuser),
        .axis_in_tkeep       (axis_in_tkeep),
        .axis_in_tlast       (axis_in_tlast),
        .axis_in_tvalid      (axis_in_tvalid),
        .axis_in_tready      (axis_in_tready),
        
        //Output AXI stream
        .axis_out_tdata     (axis_in_pop_tdata),
        .axis_out_tuser     (axis_in_pop_tuser),
        .axis_out_tkeep     (axis_in_pop_tkeep),
        .axis_out_tlast     (axis_in_pop_tlast),
        .axis_out_tvalid    (axis_in_pop_tvalid),
        .axis_out_tready    (axis_lane_rd_en),
        
        //Output AXI Stream Peek (Next Output)
        .axis_out_next_tkeep    (axis_in_pop_next_tkeep), 
        
        //Clocking
        .aclk       (aclk),
        .aresetn    (aresetn)
    );

    //Divide the custom encap into 2-byte wide lanes
    wire [15:0] segment_lanes [NUM_INSRT_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_INSRT_LANES; j = j + 1) begin : seg_lanes
            assign segment_lanes[j] = seg_to_insert[(j*16)+:16];
        end
    endgenerate
    
    

    //--------------------------------------------------------//
    //   Output Driving Muxes                                 //
    //--------------------------------------------------------//
    
    //Signals to drive output Muxes
    wire drive_lane_from_input [NUM_BUS_LANES-1:0];
    wire drive_lane_to_zero [NUM_BUS_LANES-1:0];

    wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index [NUM_BUS_LANES-1:0];
    wire [NUM_INSRT_LANES_LOG2-1:0] seg_mux_index [NUM_BUS_LANES-1:0];    

    //Infer mux logic per output lane
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : output_lanes
        
            assign axis_out_tdata[(j*16)+:16] = 
                (drive_lane_from_input[j] ?
                    axis_in_pop_tdata[data_mux_index[j]] :
                    segment_lanes[seg_mux_index[j]]
                );
            
            assign axis_out_tkeep[(j*2)+:2] =
                (drive_lane_to_zero[j] ?
                    2'b00 :
                    (drive_lane_from_input[j] ?
                        axis_in_pop_tkeep[data_mux_index[j]] :
                        2'b11
                ));
        end
    endgenerate


    
    //--------------------------------------------------------//
    //   Signals For/From FSM                                 //
    //--------------------------------------------------------//
    
    //Signals needed inside FSM blocks
    wire [NUM_BUS_LANES-1:0] axis_in_pop_tvalid_packed = {>>{axis_in_pop_tvalid}};
    wire is_regular_valid =  &(axis_in_pop_tvalid_packed);
    wire is_last_valid = axis_in_pop_tlast && axis_in_pop_tvalid[NUM_BUS_LANES-1];
   
    wire input_last_tkeep [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin: tkeep_striping
            assign input_last_tkeep[j] = axis_in_pop_tkeep[j][1];
        end
    endgenerate

    //Signals to test if next beat would have tkeep == 0
    wire [NUM_BUS_LANES_LOG2-1:0]   tkeep_test_index;
    wire                            tkeep_test_valid;
    wire                            tkeep_test_from_next;

    //Other output values
    assign axis_out_tuser = axis_in_pop_tuser;
    assign axis_out_tvalid = (is_regular_valid || is_last_valid) && axis_out_tkeep[0]; //Handles corner case where current beat would have tkeep = 0
    assign axis_out_tlast = (axis_in_pop_tlast && axis_lane_rd_en[NUM_BUS_LANES-1]) //Assert tlast when last lane of last beat read
                            || (!axis_in_pop_tkeep[tkeep_test_index][0] && tkeep_test_valid && !tkeep_test_from_next) //Handles corner case where next beat would have tkeep = 0
                            || (!axis_in_pop_next_tkeep[tkeep_test_index][0] && tkeep_test_valid && tkeep_test_from_next);

    //Known Issue - can get stuck if axis_out_tready waits for axs_out_tvalid



    //--------------------------------------------------------//
    //   FSMs to read from FIFO and output values             //
    //--------------------------------------------------------//
     
        
generate
if(USE_DYNAMIC_FSM) begin

    //The dynamic FSM-like signal output generator
    inserter_FSM_dyn
    #(
        .AXIS_BUS_WIDTH       (AXIS_BUS_WIDTH),
        .MAX_INSERT_BYTES     (MAX_INSRT_SIZE),
        .INSERT_OFFSET        (INSERT_OFFSET),
        .MAX_PACKET_LENGTH    (MAX_PACKET_LENGTH)
    )
    fsm
    (
        //Inputs to FSM
        .input_is_regular_valid (is_regular_valid),
        .input_is_last_valid    (is_last_valid),
        .input_last_tkeep       (input_last_tkeep),
        .output_is_ready        (axis_out_tready),
        .seg_size               (segment_size),
        
        //Outputs driven from FSM
        .axis_lane_rd_en        (axis_lane_rd_en),

        .drive_lane_from_input  (drive_lane_from_input),
        .drive_lane_to_zero     (drive_lane_to_zero),
        .data_mux_index         (data_mux_index),
        .seg_mux_index          (seg_mux_index),

        .tkeep_test_index       (tkeep_test_index),
        .tkeep_test_valid       (tkeep_test_valid),
        .tkeep_test_from_next   (tkeep_test_from_next),
        
        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

end else begin
    
    //FSM output signals arrayed for multiple FSM versions
    wire drive_lane_from_input_mult [NUM_INSERT_SIZES-1:0][NUM_BUS_LANES-1:0];
    wire drive_lane_to_zero_mult [NUM_INSERT_SIZES-1:0][NUM_BUS_LANES-1:0];
    wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index_mult [NUM_INSERT_SIZES-1:0][NUM_BUS_LANES-1:0];
    wire [NUM_INSRT_LANES_LOG2-1:0] seg_mux_index_mult [NUM_INSERT_SIZES-1:0][NUM_BUS_LANES-1:0];

    wire [NUM_BUS_LANES_LOG2-1:0] tkeep_test_index_mult [NUM_INSERT_SIZES-1:0];
    wire tkeep_test_valid_mult [NUM_INSERT_SIZES-1:0];
    wire tkeep_test_from_next_mult [NUM_INSERT_SIZES-1:0];

    wire axis_lane_rd_en_mult [NUM_INSERT_SIZES-1:0][NUM_BUS_LANES-1:0];

    //Loop through fsm versions
    for(genvar k = 0; k < NUM_INSERT_SIZES; k = k + 1) begin : fsm_vers

    	if(INSERT_SIZES_BYTES[k] == 0) begin

    		//Default values for no encapsulation
    		for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin

		        assign drive_lane_from_input_mult[k][j] = 1;
		        assign drive_lane_to_zero_mult[k][j] = 0;
		        assign data_mux_index_mult[k][j] =  j;
		        assign seg_mux_index_mult[k][j] = 0;

		        assign axis_lane_rd_en_mult[k][j] = axis_out_tready;

		    end
		    
		    assign tkeep_test_index_mult[k] = 0;
		    assign tkeep_test_valid_mult[k] = 0;
		    assign tkeep_test_from_next_mult[k] = 0;

    	end else begin

		    //The static (one size) FSM-like signal output generator
		    inserter_FSM_static
		    #(
		        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
		        .INSERT_SIZE_BYTES  (INSERT_SIZES_BYTES[k]),
                .SEG_MUX_INDEX_BITS (NUM_INSRT_LANES_LOG2),
		        .INSERT_OFFSET      (INSERT_OFFSET)    
		    )
		    fsm
		    (
		        //Inputs to FSM
		        .input_is_regular_valid (is_regular_valid),
		        .input_is_last_valid    (is_last_valid),
		        .input_last_tkeep       (input_last_tkeep),
		        .output_is_ready        (axis_out_tready),
                .read_last_lane         (axis_lane_rd_en[NUM_BUS_LANES-1]),
		        
		        //Outputs driven from FSM
		        .axis_lane_rd_en        (axis_lane_rd_en_mult[k]),

		        .drive_lane_from_input  (drive_lane_from_input_mult[k]),
		        .drive_lane_to_zero     (drive_lane_to_zero_mult[k]),
		        .data_mux_index         (data_mux_index_mult[k]),
		        .seg_mux_index          (seg_mux_index_mult[k]),

		        .tkeep_test_index       (tkeep_test_index_mult[k]),
		        .tkeep_test_valid       (tkeep_test_valid_mult[k]),
		        .tkeep_test_from_next   (tkeep_test_from_next_mult[k]),
		        
		        //Clocking
		        .aclk                   (aclk),
		        .aresetn                (aresetn)
		    );

		end
    end
    
    //Assign proper FSM output
    for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin

        assign drive_lane_from_input[j] = drive_lane_from_input_mult [segment_sel][j];
        assign drive_lane_to_zero[j] = drive_lane_to_zero_mult [segment_sel][j];
        assign data_mux_index[j] =  data_mux_index_mult [segment_sel][j];
        assign seg_mux_index[j] = seg_mux_index_mult [segment_sel][j];

        assign axis_lane_rd_en[j] = axis_lane_rd_en_mult [segment_sel][j];

    end
    
    assign tkeep_test_index = tkeep_test_index_mult [segment_sel];
    assign tkeep_test_valid = tkeep_test_valid_mult [segment_sel];
    assign tkeep_test_from_next = tkeep_test_from_next_mult [segment_sel];    
    
end
endgenerate



endmodule

`default_nettype wire