`timescale 1ns / 1ps
`default_nettype none




//ETYPE field constants
`define ET_SIZE 16




//The ETYPE Parser Module
module etype_parser
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
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    //Features to implement
    parameter bit INCLUDE_MAC_NEXT_ACL = 1,
    parameter bit INCLUDE_MAC_DEST_ACL = 1,
    parameter bit INCLUDE_CONFIG_ETYPE = 1,
    parameter bit INCLUDE_ETYPE_CAM = 1,
    parameter NUM_CONFIG_ETYPES = 2
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

    //Side channel signals from previous stage (vlan parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in,
    input wire                          is_tagged_in,
    input wire [`ET_SIZE-1:0]           parsed_etype,
    input wire                          parsed_etype_valid,
    input wire                          mac_dest_is_bc,
    input wire                          mac_dest_is_mc,
    input wire                          mac_dest_is_ip4_mc,
    input wire                          mac_dest_is_ip6_mc,

    //Side channel signals passed to next stage (arp parser)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire                         next_is_config,
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out,
    output wire                         is_tagged_out,
    output wire                         next_is_arp,
    output wire                         next_is_ip4,

    //Configuration register values (used for ACL)
    output wire [EFF_ID_WIDTH-1:0]      etype_sel_id,

    input wire                          etype_allow_all,
    input wire                          etype_allow_next_ip4,
    input wire                          etype_allow_next_ip6,
    input wire                          etype_allow_next_arp,
    input wire                          etype_allow_next_raw,

    input wire                          etype_allow_bc,
    input wire                          etype_allow_mc,
    input wire                          etype_allow_bc_arp_only,
    input wire                          etype_allow_mc_ip_only,

    input wire [`ET_SIZE-1:0]           etype_config [NUM_CONFIG_ETYPES-1:0],

    //CAM contents
    input wire                          etype_allow_all_cam [NUM_AXIS_ID-1:0],
    input wire                          etype_allow_next_ip4_cam [NUM_AXIS_ID-1:0],
    input wire                          etype_allow_next_ip6_cam [NUM_AXIS_ID-1:0],
    input wire                          etype_allow_next_arp_cam [NUM_AXIS_ID-1:0],
    input wire                          etype_allow_next_raw_cam [NUM_AXIS_ID-1:0],
    
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

    //Output select signals for configurations registers
    assign etype_sel_id = axis_in_tid;

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
    reg reg_next_is_ip6;
    reg reg_next_is_arp;
    reg reg_next_is_raw;

    //Current beat's values for outputs
    wire cur_next_is_ip4;
    wire cur_next_is_ip6;
    wire cur_next_is_arp;
    wire cur_next_is_raw;

    //Assign current beat's value
    assign cur_next_is_ip4 = (etype_lane == 16'h0008);
    assign cur_next_is_ip6 = (etype_lane == 16'hDD86);
    assign cur_next_is_arp = (etype_lane == 16'h0608);
    assign cur_next_is_raw = (etype_lane == 16'hB588);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_next_is_ip4 <= 0;
            reg_next_is_ip6 <= 0;
            reg_next_is_arp <= 0;
            reg_next_is_raw <= 0;
        end
        else if(etype_lane_valid) begin
            reg_next_is_ip4 <= cur_next_is_ip4;
            reg_next_is_ip6 <= cur_next_is_ip6;
            reg_next_is_arp <= cur_next_is_arp;
            reg_next_is_raw <= cur_next_is_raw;
        end
    end

    //Assign output values
    assign next_is_ip4 = (etype_lane_valid ? cur_next_is_ip4 : reg_next_is_ip4);
    //assign next_is_ip6 = (etype_lane_valid ? cur_next_is_ip6 : reg_next_is_ip6);
    assign next_is_arp = (etype_lane_valid ? cur_next_is_arp : reg_next_is_arp);
    //assign next_is_raw = (etype_lane_valid ? cur_next_is_raw : reg_next_is_raw);


    //Check for custom configuration etypes
    generate if(INCLUDE_CONFIG_ETYPE) begin : inc_config_etype 

        //Signals for intermediate values
        reg reg_next_is_config;
        wire [NUM_CONFIG_ETYPES-1:0] cur_next_is_config;

        //Assign current beat's value
        for(genvar j = 0; j < NUM_CONFIG_ETYPES; j = j + 1) begin : config_etype
            assign cur_next_is_config[j] = (etype_lane == etype_config[j]);
        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_next_is_config <= 0;
            else if(etype_lane_valid) reg_next_is_config <= (|cur_next_is_config);
        end

        assign next_is_config = (etype_lane_valid ? (|cur_next_is_config) : reg_next_is_config);

    end else begin

        assign next_is_config = 0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Next Header ACL                                      //
    //--------------------------------------------------------//

    //Signal final result of ACL
    wire out_next_head_poisoned;

    //Include conditionally
    generate if(INCLUDE_MAC_NEXT_ACL) begin : inc_next_acl 

        //Signals for acl
        reg reg_next_head_poisoned;
        wire cur_next_head_poisoned;

        //Assign current beat's value
        wire ip4_exemption = cur_next_is_ip4 && etype_allow_next_ip4;
        wire ip6_exemption = cur_next_is_ip6 && etype_allow_next_ip6;
        wire arp_exemption = cur_next_is_arp && etype_allow_next_arp;
        wire raw_exemption = cur_next_is_raw && etype_allow_next_raw;
        wire etype_violation = !(etype_allow_all || ip4_exemption || ip6_exemption || arp_exemption || raw_exemption);

        assign cur_next_head_poisoned = etype_violation;

        //Assign Resgistered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_next_head_poisoned <= 0;
            else if(etype_lane_valid) reg_next_head_poisoned <= cur_next_head_poisoned;
        end

        //Assign final value
        assign out_next_head_poisoned = (etype_lane_valid ? cur_next_head_poisoned : reg_next_head_poisoned);

    end else begin

        assign out_next_head_poisoned = 0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   MAC Dest ACL                                         //
    //--------------------------------------------------------//

    //Signal final result of ACL
    wire out_dest_poisoned;

    //Include conditionally
    generate if(INCLUDE_MAC_DEST_ACL) begin : inc_dest_acl 

        //Signals for acl
        reg reg_dest_poisoned;
        wire cur_dest_poisoned;

        //Assign current beat's value
        wire bc_exemption = cur_next_is_arp && etype_allow_bc_arp_only;
        wire bc_violation = mac_dest_is_bc && !(etype_allow_bc || bc_exemption);

        wire mc_exemption = ((cur_next_is_ip4 && mac_dest_is_ip4_mc) || (cur_next_is_ip6 && mac_dest_is_ip6_mc)) && etype_allow_mc_ip_only;
        wire mc_violation = mac_dest_is_mc && !(etype_allow_mc || mc_exemption);

        assign cur_dest_poisoned = bc_violation || mc_violation;

        //Assign Resgistered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_dest_poisoned <= 0;
            else if(etype_lane_valid) reg_dest_poisoned <= cur_dest_poisoned;
        end

        //Assign final value
        assign out_dest_poisoned = (etype_lane_valid ? cur_dest_poisoned : reg_dest_poisoned);

    end else begin

        assign out_dest_poisoned = 0;

    end 
    endgenerate


    //Assign output value
    assign poisoned_out = out_next_head_poisoned | out_dest_poisoned | poisoned_in;



    //--------------------------------------------------------//
    //   Routing based on eType                               //
    //--------------------------------------------------------//

    //Include Conditionally
    generate if(INCLUDE_ETYPE_CAM) begin : gen_cam

        //Routing mask based on allowed etypes
        wire [NUM_AXIS_ID-1:0] etype_allow_all_cam_packed = {>>{etype_allow_all_cam}};
        wire [NUM_AXIS_ID-1:0] etype_allow_next_ip4_cam = {>>{etype_allow_next_ip4_cam}};
        wire [NUM_AXIS_ID-1:0] etype_allow_next_ip6_cam = {>>{etype_allow_next_ip6_cam}};
        wire [NUM_AXIS_ID-1:0] etype_allow_next_arp_cam = {>>{etype_allow_next_arp_cam}};
        wire [NUM_AXIS_ID-1:0] etype_allow_next_raw_cam = {>>{etype_allow_next_raw_cam}};
        
        wire [NUM_AXIS_ID-1:0] cur_out_route_mask = 
            etype_allow_all_cam_packed |
            (cur_next_is_ip4 ? etype_allow_next_ip4_cam : '0) |
            (cur_next_is_ip6 ? etype_allow_next_ip6_cam : '0) |
            (cur_next_is_arp ? etype_allow_next_arp_cam : '0) |
            (cur_next_is_raw ? etype_allow_next_raw_cam : '0);

        //Register routing mask
        reg [NUM_AXIS_ID-1:0] reg_out_route_mask;

        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_out_route_mask <= '1;
            else if(etype_lane_valid) reg_out_route_mask <= cur_out_route_mask;
        end

        wire [NUM_AXIS_ID-1:0] out_route_mask = (etype_lane_valid ? cur_out_route_mask : reg_out_route_mask);
        
        //Assign final value
        assign route_mask_out = out_route_mask & route_mask_in;

    end else begin

        assign route_mask_out = route_mask_in;

    end 
    endgenerate



endmodule

`default_nettype wire