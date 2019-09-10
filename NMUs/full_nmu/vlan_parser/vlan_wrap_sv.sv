`timescale 1ns / 1ps
`default_nettype none




//VLAN field constants
`define VID_SIZE 16
`define ET_SIZE 16




//The VLAN Parser Module
module vlan_wrap_sv
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

    //Packed input signals size
    localparam VLAN_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + `ET_SIZE + 8,
    localparam VLAN_TUSER_OUT_WDITH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + `ET_SIZE + 8,
    localparam VLAN_CONFIG_SEL_WIDTH = EFF_ID_WIDTH,
    localparam VLAN_CONFIG_REG_WIDTH = `VID_SIZE + 2,
    localparam VLAN_CAM_WIDTH = (`VID_SIZE + 1) * NUM_AXIS_ID,

    //Features to implement
    parameter INCLUDE_VLAN_ACL = 1,
    parameter INCLUDE_VLAN_CAM = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+`ET_SIZE+8)-1:0] // [VLAN_TUSER_IN_WIDTH-1:0]
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
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+`ET_SIZE+8)-1:0] // [VLAN_TUSER_OUT_WDITH-1:0] 
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
                                          vlan_config_sel,
    input wire [(`VID_SIZE+2)-1:0]        vlan_config_regs,
    input wire [((`VID_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]          
                                          vlan_cam_values,

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
    wire                          next_is_ctag_vlan;
    wire [`ET_SIZE-1:0]           parsed_etype_in;
    wire                          parsed_etype_valid_in;
    wire                          mac_dest_is_bc_in;
    wire                          mac_dest_is_mc_in;
    wire                          mac_dest_is_ip4_mc_in;
    wire                          mac_dest_is_ip6_mc_in;

    assign {mac_dest_is_ip6_mc_in,mac_dest_is_ip4_mc_in,mac_dest_is_mc_in,
            mac_dest_is_bc_in,parsed_etype_valid_in,parsed_etype_in,next_is_ctag_vlan,
            cur_pos_in,parsing_done_in,poisoned_in,route_mask_in}
    = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask_out;
    wire                         poisoned_out;
    wire                         parsing_done_out;
    wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out;
    wire                         is_tagged;
    wire [`ET_SIZE-1:0]          parsed_etype_out;
    wire                         parsed_etype_valid_out;
    wire                         mac_dest_is_bc_out;
    wire                         mac_dest_is_mc_out;
    wire                         mac_dest_is_ip4_mc_out;
    wire                         mac_dest_is_ip6_mc_out;

    wire [VLAN_TUSER_OUT_WDITH-1:0] axis_pack_out_tuser = 
        {mac_dest_is_ip6_mc_out,mac_dest_is_ip4_mc_out,mac_dest_is_mc_out,
         mac_dest_is_bc_out,parsed_etype_valid_out,parsed_etype_out,is_tagged,
         cur_pos_out,parsing_done_out,poisoned_out,route_mask_out};

    //Configuration select signals
    wire [EFF_ID_WIDTH-1:0]  vlan_sel_id;
    assign vlan_config_sel = vlan_sel_id;

    //Configuration signal declarations
    wire [`VID_SIZE-1:0]   vlan_field_expected;
    wire                   vlan_match_tag;
    wire                   vlan_match_pri;

    assign {vlan_match_pri,vlan_match_tag,vlan_field_expected} = vlan_config_regs;

    //CAM values unpacking
    wire [`VID_SIZE-1:0]    vlan_fields [NUM_AXIS_ID-1:0];
    wire                    vlan_cam_must_match[NUM_AXIS_ID-1:0];

    localparam PER_ID = (`VID_SIZE + 1);

    genvar j;
    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : cam_config_loop 

            assign {vlan_cam_must_match[j],vlan_fields[j]}    
            = vlan_cam_values[(PER_ID*j)+:PER_ID];

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
    vlan_parser
    #(
        .AXIS_BUS_WIDTH          (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH           (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH         (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH       (MAX_PACKET_LENGTH),
        .INCLUDE_VLAN_ACL        (INCLUDE_VLAN_ACL),
        .INCLUDE_VLAN_CAM        (INCLUDE_VLAN_CAM)  
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
        .AXIS_USER_WIDTH    (VLAN_TUSER_OUT_WDITH+EFF_ID_WIDTH+EFF_DEST_WIDTH),
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