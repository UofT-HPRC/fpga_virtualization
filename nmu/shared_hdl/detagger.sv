`timescale 1ns / 1ps
`default_nettype none




//Tag field constants
`define TAG_OFFSET 12




//The detagger
module detagger
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = 2 ** AXIS_ID_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Inserted Tag Params
    parameter bit USE_DYNAMIC_FSM = 0,
    parameter MIN_TAG_SIZE_BITS = 32,
    parameter MAX_TAG_SIZE_BITS = 64,

    //Derived params for tag
    localparam MAX_TAG_SIZE_BYTES = MAX_TAG_SIZE_BITS/8,
    localparam MAX_TAG_BYTES_CBITS = $clog2(MAX_TAG_SIZE_BYTES + 1),
    localparam NUM_TAG_SIZES = ((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16) + 2,
    localparam NUM_TAG_SIZES_LOG2 = $clog2(NUM_TAG_SIZES),

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals passed from previous stage (custom tag parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          cus_tag_present,

    //Side channel signals passed to next stage (mac parser)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,

    //Configuration register inputs
    input wire [NUM_TAG_SIZES_LOG2-1:0] tag_mode,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Tagging types and sizes params                       //
    //--------------------------------------------------------//

    typedef integer ret_array [NUM_TAG_SIZES];
    function ret_array sizes_allowed 
    (
        input integer min_size_bytes,
        input integer max_size_bytes
    ); 
    begin
        automatic integer i = 1;

        sizes_allowed[0] = 0;
        for(integer j = min_size_bytes; j <= max_size_bytes; j = j + 2) begin 
            sizes_allowed[i] = j;
            i = i + 1;
        end
    end
    endfunction

    localparam integer TAG_SIZES_BYTES[NUM_TAG_SIZES] = 
        sizes_allowed((MIN_TAG_SIZE_BITS/8),(MAX_TAG_SIZE_BITS/8));



    //--------------------------------------------------------//
    //   Actual Packet De0Tagging                             //
    //--------------------------------------------------------//

    //Tag configuartion
    wire [NUM_TAG_SIZES_LOG2-1:0] tag_sel = (cus_tag_present ? tag_mode : 0);
    wire [MAX_TAG_BYTES_CBITS-1:0] tag_size = TAG_SIZES_BYTES[tag_sel];

    //Remove the tag
    segment_remover_mult
    #(
        .AXIS_BUS_WIDTH      (AXIS_BUS_WIDTH),
        .AXIS_TUSER_WIDTH    (NUM_AXIS_ID),
        .MAX_PACKET_LENGTH   (MAX_PACKET_LENGTH),
        .USE_DYNAMIC_FSM     (USE_DYNAMIC_FSM),
        .REMOVE_OFFSET       (`TAG_OFFSET),
        .NUM_REMOVE_SIZES    (NUM_TAG_SIZES),
        .REMOVE_SIZES_BYTES  (TAG_SIZES_BYTES),
        .RETIMING_STAGES     (RETIMING_STAGES)
    )
    remove
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tuser      (route_mask_in),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tuser     (route_mask_out),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .segment_size       (tag_size),
        .segment_sel        (tag_sel),
        
        .aclk       (aclk),
        .aresetn    (aresetn)
    );



endmodule

`default_nettype wire