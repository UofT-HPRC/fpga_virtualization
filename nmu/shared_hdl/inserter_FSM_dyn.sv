`timescale 1ns / 1ps
`default_nettype none


module inserter_FSM_dyn
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_BUS_LANES_LOG2 = NUM_BUS_BYTES_LOG2 - 1,

    //Inserted segment parameters
    parameter MAX_INSERT_BYTES = 4,
    parameter INSERT_OFFSET = 12,
        
    //Derived parameters for inserted segment
    localparam NUM_INSRT_BYTES = MAX_INSERT_BYTES,
    localparam NUM_INSRT_LANES = MAX_INSERT_BYTES/2,
    localparam NUM_INSRT_BYTES_LOG2 = $clog2(NUM_INSRT_BYTES),
    localparam NUM_INSRT_BYTES_CBITS = $clog2(NUM_INSRT_BYTES+1),
    localparam NUM_INSRT_LANES_LOG2 = NUM_INSRT_BYTES_LOG2 - 1,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Derived params for network packet        
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1)
)
(
    //Inputs from FIFO side
    input wire      input_is_regular_valid,
    input wire      input_is_last_valid,
    input wire      input_last_tkeep [NUM_BUS_LANES-1:0],
    
    //Inputs from output side
    input wire      output_is_ready,
    
    //Input for segment size (shouldn't change before end of packet)
    input wire [NUM_INSRT_BYTES_CBITS-1:0] seg_size,
    
    //Outputs driven to FIFO side
    output wire     axis_lane_rd_en [NUM_BUS_LANES-1:0],
    
    //Outputs driven to output side
    output wire                             drive_lane_from_input [NUM_BUS_LANES-1:0],
    output wire                             drive_lane_to_zero [NUM_BUS_LANES-1:0],
    output wire [NUM_BUS_LANES_LOG2-1:0]    data_mux_index [NUM_BUS_LANES-1:0],
    output wire [NUM_INSRT_LANES_LOG2-1:0]  seg_mux_index [NUM_BUS_LANES-1:0],
    
    //Outputs to determine tkeep value of next beat
    output wire [NUM_BUS_LANES_LOG2-1:0]    tkeep_test_index,
    output wire                             tkeep_test_valid,
    output wire                             tkeep_test_from_next,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);


    //Whether or not a beat is sent
    wire input_is_valid = input_is_regular_valid || input_is_last_valid;
    wire transition = input_is_valid && output_is_ready; 
    wire transition_last; //Indicates end of packet


   
    //--------------------------------------------------------//
    //   Calauclate Param-based Output Values                 //
    //--------------------------------------------------------// 
    
    //Values of outputs on not last beat
    wire                             axis_lane_rd_en_first [NUM_BUS_LANES-1:0];
    reg                              drive_lane_from_input_first [NUM_BUS_LANES-1:0];
    reg                              drive_lane_to_zero_first [NUM_BUS_LANES-1:0];
    reg [NUM_BUS_LANES_LOG2-1:0]     data_mux_index_first [NUM_BUS_LANES-1:0];
    wire [NUM_INSRT_LANES_LOG2-1:0]  seg_mux_index_first [NUM_BUS_LANES-1:0];
    reg [NUM_BUS_LANES_LOG2-1:0]     tkeep_test_index_first;
    reg                              tkeep_test_valid_first;
    wire                             tkeep_test_from_next_first;
    
    //Values of outputs for each state on last beat
    wire                             axis_lane_rd_en_last [NUM_BUS_LANES-1:0];
    reg                              drive_lane_to_zero_last [NUM_BUS_LANES-1:0];    
    
    //Calculate read offset and num bytes to read
    wire [NUM_BUS_LANES_LOG2-1:0] read_offset;
    reg [NUM_BUS_LANES_LOG2:0] num_read_lanes;
    reg [NUM_BUS_LANES_LOG2:0] num_insrt_lanes;
    
    reg [NUM_BUS_LANES_LOG2-1:0] acc_read_lanes; //Note, computes accumulated read lanes % num_lanes
    reg [NUM_INSRT_BYTES_CBITS-1:0] acc_insrt_lanes;
    reg [PACKET_LENGTH_CBITS-1:0] total_lanes;
    
    always@(posedge aclk) begin
        if(~aresetn || transition_last) begin
            acc_read_lanes <= 0;
            acc_insrt_lanes <= 0;
            total_lanes <= NUM_BUS_LANES;
        end
        else if(transition) begin
            acc_read_lanes <= acc_read_lanes + num_read_lanes;
            acc_insrt_lanes <= acc_insrt_lanes + num_insrt_lanes;
            total_lanes <= total_lanes + NUM_BUS_LANES;
        end
    end
    
    wire [NUM_INSRT_BYTES_CBITS-1:0] remaining_insrt = (seg_size/2) - acc_insrt_lanes;
    wire [NUM_BUS_LANES_LOG2:0] max_insrt_lanes = (remaining_insrt > NUM_BUS_LANES ? NUM_BUS_LANES : remaining_insrt);   

    always@(*) begin
        if(total_lanes <= (INSERT_OFFSET/2))
            num_read_lanes = NUM_BUS_LANES;
        else if(total_lanes <= (INSERT_OFFSET/2) + NUM_BUS_LANES)
            if(max_insrt_lanes < NUM_BUS_LANES -  ((INSERT_OFFSET/2) % NUM_BUS_LANES))
                num_read_lanes = NUM_BUS_LANES - max_insrt_lanes;
            else
                num_read_lanes = (INSERT_OFFSET/2) % NUM_BUS_LANES;
        else
            num_read_lanes = NUM_BUS_LANES - max_insrt_lanes;
    end
    
    assign num_insrt_lanes = NUM_BUS_LANES - num_read_lanes;
    assign read_offset = acc_read_lanes % NUM_BUS_LANES;
    
    
    //Calculate read emable signals
    generate
    for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : read_enables
        wire [NUM_BUS_LANES_LOG2+1:0] end_offset = read_offset + num_read_lanes;
        assign axis_lane_rd_en_first[k] = ( (k >= read_offset) && (k < end_offset) ) || ((k+NUM_BUS_LANES) < end_offset);
    end
    endgenerate
    
    //Calculate read enables for last beat
    wire insrt_starts_mid_beat = ((total_lanes > (INSERT_OFFSET/2)) && (total_lanes < (INSERT_OFFSET/2 + NUM_BUS_LANES)));
    localparam INDEX_BEFORE_INSRT = (INSERT_OFFSET != 0 ? (INSERT_OFFSET/2 - 1) % NUM_BUS_LANES : NUM_BUS_LANES-1);
    wire input_last_tkeep_before_insrt = (insrt_starts_mid_beat ? input_last_tkeep[INDEX_BEFORE_INSRT] : 1'b1);
    
    generate
    for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : read_enables_last
        assign axis_lane_rd_en_last[k] = axis_lane_rd_en_first[k] || !input_last_tkeep_before_insrt;;
    end
    endgenerate
    
    
    //Select signals for output muxing
    generate
    for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : lanes2
    
        wire [PACKET_LENGTH_CBITS-1:0] index = (total_lanes - NUM_BUS_LANES) + k;
        
        always@(*) begin
            //Check the index value range
            if(index < (INSERT_OFFSET/2)) begin
                //Non last values
                drive_lane_from_input_first[k] = 1'b1;
                drive_lane_to_zero_first[k] = 1'b0;
                data_mux_index_first[k] = k;
                
                //Last values
                drive_lane_to_zero_last[k] = 1'b0;
            end
            else if(index < ((INSERT_OFFSET + seg_size)/2)) begin
                //Non last values
                drive_lane_from_input_first[k] = 1'b0;
                drive_lane_to_zero_first[k] = 1'b0;
                data_mux_index_first[k] = k; //Don't care
                
                //Last values
                drive_lane_to_zero_last[k] = ~input_last_tkeep_before_insrt;
            end
            else begin
                //Non last values
                drive_lane_from_input_first[k] = 1'b1;
                drive_lane_to_zero_first[k] = 1'b0;
                data_mux_index_first[k] = (index - (seg_size/2)) % NUM_BUS_LANES;
                
                //Last values
                drive_lane_to_zero_last[k] = (k >= (NUM_BUS_LANES - read_offset) ? 1'b1 : 1'b0);
            end
        end

        assign seg_mux_index_first[k] = (index - (INSERT_OFFSET/2));
    end
    endgenerate
    
    
    //Signals for checking tkeep of next beat
    always@(*) begin
        //Check the index value range
        if(total_lanes < (INSERT_OFFSET/2)) begin
            //Non last values
            tkeep_test_valid_first = 1'b1;
            tkeep_test_index_first = 0;
        end
        else if(total_lanes < ((INSERT_OFFSET + seg_size)/2)) begin
            //Non last values
            tkeep_test_valid_first = 1'b0;
            tkeep_test_index_first = 0;
        end
        else begin
            //Non last values
            tkeep_test_valid_first = 1'b1;
            tkeep_test_index_first = (total_lanes - (seg_size/2)) % NUM_BUS_LANES;
        end
    end
    
    assign tkeep_test_from_next_first = (num_read_lanes == NUM_BUS_LANES);        
    
    
    //Determine if end of transmission on last beat (to reset register values)
    assign transition_last = input_is_last_valid & axis_lane_rd_en_last[NUM_BUS_LANES-1] && output_is_ready;

    
    
    //--------------------------------------------------------//
    //   Assign output values                                 //
    //--------------------------------------------------------// 
    
    //Output value logic for read enables
    generate
    for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : lanes3
        assign axis_lane_rd_en[j] =
            (~transition ?
                1'b0 :
                (input_is_last_valid ?
                    axis_lane_rd_en_last[j] :
                    axis_lane_rd_en_first[j]
            ));
    end
    endgenerate      
    
    //Output value logic for last beat
    assign drive_lane_to_zero =
        (input_is_last_valid ?
            drive_lane_to_zero_last :
            drive_lane_to_zero_first
        );
            
    
    //Output value logic for remaining outputs
    assign drive_lane_from_input = drive_lane_from_input_first;
    assign data_mux_index = data_mux_index_first;
    assign seg_mux_index = seg_mux_index_first;
    assign tkeep_test_index = tkeep_test_index_first;
    assign tkeep_test_valid = tkeep_test_valid_first;
    assign tkeep_test_from_next = tkeep_test_from_next_first;
    



endmodule

`default_nettype wire