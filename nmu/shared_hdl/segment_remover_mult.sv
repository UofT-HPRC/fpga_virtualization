`timescale 1ns / 1ps
`default_nettype none


module segment_remover_mult
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TUSER_WIDTH = 4,

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
    parameter REMOVE_OFFSET = 12,
    parameter NUM_REMOVE_SIZES = 2,
    parameter integer REMOVE_SIZES_BYTES [NUM_REMOVE_SIZES] = '{0,4},	//sizes, smallest to largest
    
    //Derived parameters for inserted segment 
    localparam NUM_RMV_SIZES_LOG2 = $clog2(NUM_REMOVE_SIZES),

    localparam MAX_RMV_SIZE = REMOVE_SIZES_BYTES[NUM_REMOVE_SIZES-1],
    localparam NUM_RMV_BYTES_CBITS = $clog2(MAX_RMV_SIZE + 1),
    localparam NUM_RMV_LANES = (MAX_RMV_SIZE/2),

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire [AXIS_TUSER_WIDTH-1:0]       axis_in_tuser,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_tuser,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,
    
    //Parmeter values for inserting
    input wire [NUM_RMV_BYTES_CBITS-1:0]    segment_size,
    input wire [NUM_RMV_SIZES_LOG2-1:0]	    segment_sel,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);
    
    //--------------------------------------------------------//
    //   Muxing for inputs into FIFO                          //
    //--------------------------------------------------------//

    //Divide the input data into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    wire [1:0] axis_in_tkeep_lanes [NUM_BUS_LANES-1:0];

    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : axis_in_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+:16];
            assign axis_in_tkeep_lanes[j] = axis_in_tkeep[(j*2)+:2];
        end
    endgenerate

    //Aliases for the input side of the buffer
    wire [15:0]  axis_in_push_tdata [NUM_BUS_LANES-1:0];
    wire [1:0]   axis_in_push_tkeep [NUM_BUS_LANES-1:0];

    //Signals to drive Muxes
    wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index [NUM_BUS_LANES-1:0];

    //Infer mux logic per output lane
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : mux_lanes
            assign axis_in_push_tdata[j] = axis_in_tdata_lanes[data_mux_index[j]];
            assign axis_in_push_tkeep[j] = axis_in_tkeep_lanes[data_mux_index[j]];
        end
    endgenerate



    //--------------------------------------------------------//
    //   Signals For/From FSM                                 //
    //--------------------------------------------------------//

    //Signal to indicate which lanes to write
    localparam   AXIS_WRITE_SIZE = (NUM_BUS_LANES*2) - 1;
    wire         axis_in_push_write [AXIS_WRITE_SIZE-1:0];

    //Mask write signal for invalid lanes
    wire    axis_in_write [AXIS_WRITE_SIZE-1:0];

    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : axis_write1
            assign axis_in_push_write[j] = axis_in_write[j] & axis_in_push_tkeep[j][0];
        end

        for(genvar j = NUM_BUS_LANES; j < AXIS_WRITE_SIZE; j = j + 1) begin : axis_write2
            assign axis_in_push_write[j] = axis_in_write[j] & axis_in_push_tkeep[j-NUM_BUS_LANES][0];
        end
    endgenerate



    //--------------------------------------------------------//
    //   FSMs to read from FIFO and output values             //
    //--------------------------------------------------------//
        
generate
if(USE_DYNAMIC_FSM) begin

    //The dynamic FSM-like signal output generator
    remover_FSM_dyn
    #(
        .AXIS_BUS_WIDTH       (AXIS_BUS_WIDTH),
        .MAX_REMOVE_BYTES     (MAX_RMV_SIZE),
        .REMOVE_OFFSET        (REMOVE_OFFSET),
        .MAX_PACKET_LENGTH    (MAX_PACKET_LENGTH)
    )
    fsm
    (
        //Inputs to FSM
        .input_is_valid         (axis_in_tvalid),
        .input_is_last          (axis_in_tlast),
        .output_is_ready        (axis_out_tready),
        .seg_size               (segment_size),
        
        //Outputs driven from FSM
        .axis_lane_write        (axis_in_write),
        .data_mux_index         (data_mux_index),
        
        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

end else begin
    
    //FSM output signals arrayed for multiple FSM versions
    wire axis_in_write_mult [NUM_REMOVE_SIZES-1:0][AXIS_WRITE_SIZE-1:0];
    wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index_mult [NUM_REMOVE_SIZES-1:0][NUM_BUS_LANES-1:0];

    //Loop through fsm versions
    for(genvar k = 0; k < NUM_REMOVE_SIZES; k = k + 1) begin : fsm_vers

        if(REMOVE_SIZES_BYTES[k] == 0) begin

            //Default values for no encapsulation
            for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : fsm_vers_idx
                assign axis_in_write_mult[k][j] = 1'b1;
                assign data_mux_index_mult[k][j] = j;
            end

            for(genvar j = NUM_BUS_LANES; j < AXIS_WRITE_SIZE; j = j + 1) begin :fsm_vers_idx2
                assign axis_in_write_mult[k][j] = 1'b0;
            end

        end else begin

            //The static (one size) FSM-like signal output generator
            remover_FSM_static
            #(
                .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
                .REMOVE_SIZE_BYTES  (REMOVE_SIZES_BYTES[k]),
                .REMOVE_OFFSET      (REMOVE_OFFSET)    
            )
            fsm
            (
                //Inputs to FSM
                .input_is_valid         (axis_in_tvalid),
                .input_is_last          (axis_in_tlast),
                .output_is_ready        (axis_in_tready),
                
                //Outputs driven from FSM
                .axis_lane_write        (axis_in_write_mult[k]),
                .data_mux_index         (data_mux_index_mult[k]),
                
                //Clocking
                .aclk                   (aclk),
                .aresetn                (aresetn)
            );

        end
    end
    
    //Assign proper FSM output
    for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : idx_asg
        assign data_mux_index[j] = data_mux_index_mult [segment_sel][j];
    end

    for(genvar j = 0; j < AXIS_WRITE_SIZE; j = j + 1) begin : write_asg
        assign axis_in_write[j] = axis_in_write_mult [segment_sel][j];
    end    
    
end
endgenerate



    //--------------------------------------------------------//
    //   Retiming registers                                   //
    //--------------------------------------------------------//

    //pack tuser signals for input
    wire [(AXIS_TUSER_WIDTH+AXIS_WRITE_SIZE)-1:0] axis_in_tuser2;
    assign axis_in_tuser2[0+:AXIS_TUSER_WIDTH] = axis_in_tuser;
    assign axis_in_tuser2[AXIS_TUSER_WIDTH+:AXIS_WRITE_SIZE] = {>>{axis_in_push_write}};


    //Pack tdata signals for output
    wire [15:0]                     axis_reg_in_push_tdata[NUM_BUS_LANES-1:0];
    wire [AXIS_BUS_WIDTH-1:0]       axis_reg_in_push_tdata_pack;

    generate for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : tdata_assign
        assign axis_reg_in_push_tdata[j] = axis_reg_in_push_tdata_pack[(j*16)+:16];
    end endgenerate


    //Pack tkeep signals for output
    wire [1:0]                      axis_reg_in_push_tkeep[NUM_BUS_LANES-1:0];
    wire [NUM_BUS_BYTES-1:0]        axis_reg_in_push_tkeep_pack;

    generate for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : tkeep_assign
        assign axis_reg_in_push_tkeep[j] = axis_reg_in_push_tkeep_pack[(j*2)+:2];
    end endgenerate


    //Pack tuser signals for output
    wire                                            axis_reg_in_push_write[AXIS_WRITE_SIZE-1:0];
    wire [AXIS_TUSER_WIDTH-1:0]                     axis_reg_in_tuser;
    wire [(AXIS_TUSER_WIDTH+AXIS_WRITE_SIZE)-1:0]   axis_reg_in_tuser2;

    assign axis_reg_in_tuser = axis_reg_in_tuser2[0+:AXIS_TUSER_WIDTH];
    generate for(genvar j = 0; j < AXIS_WRITE_SIZE; j = j + 1) begin : tuser_assign
        assign axis_reg_in_push_write[j] = axis_reg_in_tuser2[AXIS_TUSER_WIDTH+j];
    end endgenerate


    //Registered stream output signals
    wire        axis_reg_in_tlast;
    wire        axis_reg_in_tvalid;
    wire        axis_reg_in_tready;



    //Retiming registers instantiated
    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (AXIS_TUSER_WIDTH+AXIS_WRITE_SIZE),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      ({>>{axis_in_push_tdata}}),
        .axis_in_tuser      (axis_in_tuser2),                                         
        .axis_in_tkeep      ({>>{axis_in_push_tkeep}}),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .axis_out_tdata     (axis_reg_in_push_tdata_pack),
        .axis_out_tuser     (axis_reg_in_tuser2),                                          
        .axis_out_tkeep     (axis_reg_in_push_tkeep_pack),
        .axis_out_tlast     (axis_reg_in_tlast),
        .axis_out_tvalid    (axis_reg_in_tvalid),
        .axis_out_tready    (axis_reg_in_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );



    //--------------------------------------------------------//
    //   Insert Segmented Input Into FIFO                     //
    //--------------------------------------------------------//

    //The FIFO
    axis_segin_shift_fifo
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_TUSER_WIDTH   (AXIS_TUSER_WIDTH),
        .NUM_SEGMENTS       (NUM_BUS_LANES),
        .BUFFER_DEPTH       (3)
    )
    buffer
    (
        //Input AXI stream
        .axis_in_tdata      (axis_reg_in_push_tdata),
        .axis_in_tkeep      (axis_reg_in_push_tkeep),
        .axis_in_tuser      (axis_reg_in_tuser),
        .axis_in_tvalid     (axis_reg_in_tvalid),
        .axis_in_tlast      (axis_reg_in_tlast),
        .axis_in_tready     (axis_reg_in_tready),
        
        .axis_in_write      (axis_reg_in_push_write),

        //Output AXI stream
        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tuser     (axis_out_tuser),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),
        
        //Clocking
        .aclk       (aclk),
        .aresetn    (aresetn)
    );



endmodule

`default_nettype wire