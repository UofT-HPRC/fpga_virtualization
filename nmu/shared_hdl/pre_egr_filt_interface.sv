`timescale 1ns / 1ps
`default_nettype none


//The MAC Parser Module
module pre_egr_filt_interface
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),  

    //Params for unused inputs (for sizing the bus width)
    parameter MAX_PACKET_LENGTH = 1522,
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),
    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET),

    //Packed input signals size
    localparam TUSER_OUT_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 5
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        
                                          axis_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_in_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+5)-1:0] 
                                          axis_out_tuser,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       
                                          axis_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_out_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Clocking (unused)
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Connect signals, swap tuser and tdest                //
    //--------------------------------------------------------//

    assign axis_out_tdata = axis_in_tdata;
    assign axis_out_tid = axis_in_tid;
    assign axis_out_tdest = axis_in_tdest;
    assign axis_out_tkeep = axis_in_tkeep;
    assign axis_out_tlast = axis_in_tlast;
    assign axis_out_tvalid = axis_in_tvalid;
    assign axis_in_tready = axis_out_tready;

    wire [NUM_AXIS_ID-1:0]            route_mask = 0;
    wire                              poisoned = 0;
    wire                              parsing_done = 1'b1;
    wire                              next_is_config = 0;
    wire [PACKET_LENGTH_CBITS-1:0]    cur_pos = 0;
    wire [MAX_ADDED_OFFSET_CBITS-1:0] added_offset = 0;
    wire                              next_can_have_vsid = 0;
    wire                              has_udp_checksum = 0;

    assign axis_out_tuser = 
        {has_udp_checksum,next_can_have_vsid,added_offset,cur_pos,
         next_is_config,parsing_done,poisoned,route_mask};



endmodule

`default_nettype wire