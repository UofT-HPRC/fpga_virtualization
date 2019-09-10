`timescale 1ns / 1ps
`default_nettype none




//ETYPE field constants
`define ET_SIZE 16




//The ETYPE Parser Module
module etype_wrap_sv
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    //Features to implement
    parameter INCLUDE_MAC_NEXT_ACL = 1,
    parameter INCLUDE_MAC_DEST_ACL = 1,
    parameter INCLUDE_CONFIG_ETYPE = 1,
    parameter INCLUDE_ETYPE_CAM = 1,
    parameter NUM_CONFIG_ETYPES = 2,

    //Packed input signals size
    localparam ET_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + `ET_SIZE + 8,
    localparam ET_TUSER_OUT_WDITH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + 6,
    localparam ET_CONFIG_SEL_WIDTH = EFF_ID_WIDTH,
    localparam ET_CONFIG_REG_WIDTH = 9 + (NUM_CONFIG_ETYPES*`ET_SIZE),
    localparam ET_CAM_WIDTH = (5) * NUM_AXIS_ID,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+(16)+8)-1:0] // [TUSER_IN_WIDTH-1:0]
                                          axis_in_tuser,
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
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+6)-1:0] // [TUSER_OUT_WDITH-1:0] 
                                          axis_out_tuser,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       
                                          axis_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_out_tdest, 
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]  
                                          etype_config_sel,
    input wire [(9+(NUM_CONFIG_ETYPES*`ET_SIZE))-1:0]
                                          etype_config_regs,
    input wire [((5)*(2**AXIS_ID_WIDTH))-1:0]
                                          etype_cam_values,                                          

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//

    //Input signal declarations
    wire [NUM_AXIS_ID-1:0]        route_mask_in;
    wire                          poisoned_in;
    wire                          parsing_done_in;
    wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in;
    wire                          is_tagged_in;
    wire [`ET_SIZE-1:0]           parsed_etype;
    wire                          parsed_etype_valid;
    wire                          mac_dest_is_bc;
    wire                          mac_dest_is_mc;
    wire                          mac_dest_is_ip4_mc;
    wire                          mac_dest_is_ip6_mc;

    assign {mac_dest_is_ip6_mc,mac_dest_is_ip4_mc,mac_dest_is_mc,
            mac_dest_is_bc,parsed_etype_valid,parsed_etype,is_tagged_in,
            cur_pos_in,parsing_done_in,poisoned_in,route_mask_in}
    = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask_out;
    wire                         poisoned_out;
    wire                         parsing_done_out;
    wire                         next_is_config;
    wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out;
    wire                         is_tagged_out;
    wire                         next_is_arp;
    wire                         next_is_ip4;

    wire [ET_TUSER_OUT_WDITH-1:0] axis_pack_out_tuser = 
        {next_is_ip4,next_is_arp,is_tagged_out,cur_pos_out,next_is_config,
         parsing_done_out,poisoned_out,route_mask_out};

    //Configuration select signals
    wire [EFF_ID_WIDTH-1:0]        etype_sel_id;

    assign etype_config_sel = etype_sel_id;

    //Configuration signal declarations
    wire                 etype_allow_all;
    wire                 etype_allow_next_ip4;
    wire                 etype_allow_next_ip6;
    wire                 etype_allow_next_arp;
    wire                 etype_allow_next_raw;

    wire                 etype_allow_bc;
    wire                 etype_allow_mc;
    wire                 etype_allow_bc_arp_only;
    wire                 etype_allow_mc_ip_only;

    localparam ET_CONFIG_WIDTH_STATIC = 9;

    assign {etype_allow_mc_ip_only,etype_allow_bc_arp_only,etype_allow_mc,
            etype_allow_bc,etype_allow_next_raw,etype_allow_next_arp,
            etype_allow_next_ip6,etype_allow_next_ip4,etype_allow_all}
    = etype_config_regs[ET_CONFIG_WIDTH_STATIC-1:0];

    wire [`ET_SIZE-1:0]  etype_config [NUM_CONFIG_ETYPES-1:0];

    genvar j;
    generate
        for(j = 0; j < NUM_CONFIG_ETYPES; j = j + 1) begin : config_etype 

            assign etype_config[j] 
            = etype_config_regs[(ET_CONFIG_WIDTH_STATIC+(`ET_SIZE*j))+:`ET_SIZE];

        end
    endgenerate

    //CAM values unpacking
    wire                 etype_allow_all_cam [NUM_AXIS_ID-1:0];
    wire                 etype_allow_next_ip4_cam [NUM_AXIS_ID-1:0];
    wire                 etype_allow_next_ip6_cam [NUM_AXIS_ID-1:0];
    wire                 etype_allow_next_arp_cam [NUM_AXIS_ID-1:0];
    wire                 etype_allow_next_raw_cam [NUM_AXIS_ID-1:0];

    localparam PER_ID = (5);

    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : cam_config_loop 

            assign {etype_allow_next_raw_cam[j],etype_allow_next_arp_cam[j],
                    etype_allow_next_ip6_cam[j],etype_allow_next_ip4_cam[j],
                    etype_allow_all_cam[j]}    
            = etype_cam_values[(PER_ID*j)+:PER_ID];

        end
    endgenerate



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_buff_tid;
    wire [EFF_DEST_WIDTH-1:0]      axis_buff_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    etype_parser
    #(
        .AXIS_BUS_WIDTH          (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH           (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH         (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH       (MAX_PACKET_LENGTH),
        .INCLUDE_MAC_NEXT_ACL    (INCLUDE_MAC_NEXT_ACL),
        .INCLUDE_MAC_DEST_ACL    (INCLUDE_MAC_DEST_ACL),
        .INCLUDE_CONFIG_ETYPE    (INCLUDE_CONFIG_ETYPE),
        .INCLUDE_ETYPE_CAM       (INCLUDE_ETYPE_CAM),
        .NUM_CONFIG_ETYPES       (NUM_CONFIG_ETYPES)
    )
    parse
    (
        .axis_out_tdata     (axis_buff_tdata),
        .axis_out_tid       (axis_buff_tid),
        .axis_out_tdest     (axis_buff_tdest),
        .axis_out_tkeep     (axis_buff_tkeep),
        .axis_out_tlast     (axis_buff_tlast),
        .axis_out_tvalid    (axis_buff_tvalid),
        .axis_out_tready    (axis_buff_tready),
        .*
    );



    //--------------------------------------------------------//
    //   Retiming registers                                   //
    //--------------------------------------------------------//

    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (ET_TUSER_OUT_WDITH+EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      ({axis_pack_out_tuser,axis_buff_tid,axis_buff_tdest}),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tuser,axis_out_tid,axis_out_tdest}),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );
    
    


endmodule

`default_nettype wire