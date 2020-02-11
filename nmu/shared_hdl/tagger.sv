`timescale 1ns / 1ps
`default_nettype none




//Tag offset
`define TAG_OFFSET 12




//The Tagger
module tagger
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

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
    localparam NUM_TAG_SIZES_LOG2 = $clog2(NUM_TAG_SIZES)
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]       axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]     axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]      axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]    axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Configuration register inputs
    output wire [EFF_ID_WIDTH-1:0]      tag_sel_id,

    input wire [MAX_TAG_SIZE_BITS-1:0]  tag,
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
    //   Actual Packet Tagging                                //
    //--------------------------------------------------------//

    //Tag configuartion
    assign tag_sel_id = axis_out_tid;
    wire [MAX_TAG_BYTES_CBITS-1:0] tag_size = TAG_SIZES_BYTES[tag_mode];

    //Insert the tag
    segment_inserter_mult
    #(
        .AXIS_BUS_WIDTH      (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH     (EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .MAX_PACKET_LENGTH   (MAX_PACKET_LENGTH),
        .USE_DYNAMIC_FSM     (USE_DYNAMIC_FSM),
        .INSERT_OFFSET       (`TAG_OFFSET),
        .NUM_INSERT_SIZES    (NUM_TAG_SIZES),
        .INSERT_SIZES_BYTES  (TAG_SIZES_BYTES)
    )
    insert
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tuser      ({axis_in_tid,axis_in_tdest}),
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tid,axis_out_tdest}),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .seg_to_insert      (tag),
        .segment_size       (tag_size),
        .segment_sel        (tag_mode),
        
        .aclk       (aclk),
        .aresetn    (aresetn)
    );



endmodule

`default_nettype wire