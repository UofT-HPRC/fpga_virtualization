`timescale 1ns / 1ps
`default_nettype none




//ETYPE field constants
`define ET_SIZE 16




//The ETYPE Parser Module
module etype_cam_only
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = 2 ** AXIS_ID_WIDTH,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Bits required for internal counters
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1)
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]           axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]         axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]          axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]        axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Side channel signals from previous stage (vlan parser)
    input wire [NUM_AXIS_ID-1:0]            route_mask_mac_in,
    input wire [NUM_AXIS_ID-1:0]            route_mask_vlan_in,
    input wire                              parsing_done_in,
    input wire [PACKET_LENGTH_CBITS-1:0]    cur_pos_in,
    input wire                              is_tagged_in,
    input wire [`ET_SIZE-1:0]               parsed_etype,
    input wire                              parsed_etype_valid,

    //Side channel signals passed to next stage (arp parser)
    output wire [NUM_AXIS_ID-1:0]           route_mask_out,
    output wire                             parsing_done_out,
    output wire [PACKET_LENGTH_CBITS-1:0]   cur_pos_out,
    output wire                             is_tagged_out,
    output wire                             next_is_arp,
    output wire                             next_is_ip4,

    //CAM contents
    input wire                              etype_allow_all_cam [NUM_AXIS_ID-1:0],
    input wire                              etype_allow_next_ip4_cam [NUM_AXIS_ID-1:0],
    input wire                              etype_allow_next_arp_cam [NUM_AXIS_ID-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Signals Used Throughout                              //
    //--------------------------------------------------------//

    //Stream passthrough
    assign axis_out_tdata = axis_in_tdata;
    assign axis_out_tid = axis_in_tid;
    assign axis_out_tdest = axis_in_tdest;
    assign axis_out_tkeep = axis_in_tkeep;
    assign axis_out_tlast = axis_in_tlast;
    assign axis_out_tvalid = axis_in_tvalid;
    assign axis_in_tready = axis_out_tready;

    //Other passthrough
    assign cur_pos_out = cur_pos_in;
    assign parsing_done_out = parsing_done_in;
    assign is_tagged_out = is_tagged_in;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;



    //--------------------------------------------------------//
    //   Ethertype Parsing                                    //
    //--------------------------------------------------------//

    //ethertype from mac and vlan parsing
    wire [15:0]  etype_lane = parsed_etype;
    wire         etype_lane_valid = parsed_etype_valid;



    //--------------------------------------------------------//
    //   Next Header Determination                            //
    //--------------------------------------------------------//

    //Registers to hold stored values of outputs
    reg reg_next_is_ip4;
    reg reg_next_is_arp;

    //Current beat's values for outputs
    wire cur_next_is_ip4;
    wire cur_next_is_arp;

    //Assign current beat's value
    assign cur_next_is_ip4 = (etype_lane == 16'h0008);
    assign cur_next_is_arp = (etype_lane == 16'h0608);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_next_is_ip4 <= 0;
            reg_next_is_arp <= 0;
        end
        else if(etype_lane_valid) begin
            reg_next_is_ip4 <= cur_next_is_ip4;
            reg_next_is_arp <= cur_next_is_arp;
        end
    end

    //Assign output values
    assign next_is_ip4 = (etype_lane_valid ? cur_next_is_ip4 : reg_next_is_ip4);
    assign next_is_arp = (etype_lane_valid ? cur_next_is_arp : reg_next_is_arp);



    //--------------------------------------------------------//
    //   Routing based on eType                               //
    //--------------------------------------------------------//

    //Routing mask based on allowed etypes
    wire [NUM_AXIS_ID-1:0] etype_allow_all_cam_packed = {>>{etype_allow_all_cam}};
    wire [NUM_AXIS_ID-1:0] etype_allow_next_ip4_cam = {>>{etype_allow_next_ip4_cam}};
    wire [NUM_AXIS_ID-1:0] etype_allow_next_arp_cam = {>>{etype_allow_next_arp_cam}};
    
    wire [NUM_AXIS_ID-1:0] cur_out_route_mask = 
        etype_allow_all_cam_packed |
        (cur_next_is_ip4 ? etype_allow_next_ip4_cam : '0) |
        (cur_next_is_arp ? etype_allow_next_arp_cam : '0);

    //Register routing mask
    reg [NUM_AXIS_ID-1:0] reg_out_route_mask;

    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_out_route_mask <= '1;
        else if(etype_lane_valid) reg_out_route_mask <= cur_out_route_mask;
    end

    wire [NUM_AXIS_ID-1:0] out_route_mask = (etype_lane_valid ? cur_out_route_mask : reg_out_route_mask);
    
    //Assign final value
    assign route_mask_out = out_route_mask & route_mask_vlan_in & (next_is_arp ? '1 : route_mask_mac_in);



endmodule

`default_nettype wire