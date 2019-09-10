`timescale 1ns / 1ps
`default_nettype none




//IP4 field constants
`define SA_IP4_SIZE 32
`define DA_IP4_SIZE 32




//The IP4 Parser Module
module ip4_wrap_sv
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
    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1),

    //Packed input signals size
    localparam IP4_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + 5,
    localparam IP4_TUSER_OUT_WDITH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 6,
    localparam IP4_CONFIG_SEL_WIDTH = EFF_ID_WIDTH + EFF_DEST_WIDTH,
    localparam IP4_CONFIG_REG_WIDTH = (2*`DA_IP4_SIZE) + `SA_IP4_SIZE + 5,
    localparam IP4_CAM_WIDTH = (`SA_IP4_SIZE + 1) * NUM_AXIS_ID,

    //Features to implement
    parameter INCLUDE_IP4_NEXT_ACL = 1,
    parameter ALLOW_IP4_OPTIONS = 0,
    parameter INCLUDE_IP4_SRC_ACL = 1,
    parameter INCLUDE_IP4_DEST_ACL = 1,
    parameter INCLUDE_IP4_DEST_CAM = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+5)-1:0] // [IP4_TUSER_IN_WIDTH-1:0]
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
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+6)-1:0] // [IP4_TUSER_OUT_WDITH-1:0] 
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
    output wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                          ip4_config_sel,
    input wire [((2*`DA_IP4_SIZE)+`SA_IP4_SIZE+5)-1:0]
                                          ip4_config_regs,
    input wire [((`SA_IP4_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]          
                                          ip4_cam_values,

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
    wire                          next_is_config_in;
    wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in;
    wire                          is_tagged;
    wire                          next_is_ip4;

    assign {next_is_ip4,is_tagged,cur_pos_in,next_is_config_in,
            parsing_done_in,poisoned_in,route_mask_in}
    = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask_out;
    wire                         poisoned_out;
    wire                         parsing_done_out;
    wire                         next_is_config_out;
    wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out;
    wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset;
    wire                         next_has_ports;
    wire                         next_can_have_vsid;
    wire                         next_can_have_udp_check;

    wire [IP4_TUSER_OUT_WDITH-1:0] axis_pack_out_tuser = 
        {next_can_have_udp_check,next_can_have_vsid,next_has_ports,added_offset,
         cur_pos_out,next_is_config_out,parsing_done_out,poisoned_out,route_mask_out};

    //Configuration select signals
    wire [EFF_ID_WIDTH-1:0]        ip4_sel_id;
    wire [EFF_DEST_WIDTH-1:0]      ip4_sel_dest;

    assign ip4_config_sel = {ip4_sel_id,ip4_sel_dest};

    //Configuration signal declarations
    wire                          ip4_restrict_to_only_ports;
    wire [`SA_IP4_SIZE-1:0]       ip4_src_address;
    wire                          ip4_match_src;
    wire [`DA_IP4_SIZE-1:0]       ip4_dest_address;
    wire [`SA_IP4_SIZE-1:0]       ip4_subnet_mask;
    wire                          ip4_allow_public;
    wire                          ip4_allow_bc;
    wire                          ip4_allow_mc;

    assign {ip4_allow_mc,ip4_allow_bc,ip4_allow_public,
            ip4_subnet_mask,ip4_dest_address,ip4_match_src,
            ip4_src_address,ip4_restrict_to_only_ports}
    = ip4_config_regs;

    //CAM contents
    wire [`SA_IP4_SIZE-1:0]       ip4_addresses [NUM_AXIS_ID-1:0];
    wire                          ip4_cam_must_match [NUM_AXIS_ID-1:0];

    localparam PER_ID = (`SA_IP4_SIZE + 1);

    genvar j;
    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : cam_config_loop 

            assign {ip4_cam_must_match[j],ip4_addresses[j]}    
            = ip4_cam_values[(PER_ID*j)+:PER_ID];

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
    ip4_parser
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        .INCLUDE_IP4_NEXT_ACL       (INCLUDE_IP4_NEXT_ACL),
        .ALLOW_IP4_OPTIONS          (ALLOW_IP4_OPTIONS),
        .INCLUDE_IP4_SRC_ACL        (INCLUDE_IP4_SRC_ACL),
        .INCLUDE_IP4_DEST_ACL       (INCLUDE_IP4_DEST_ACL),
        .INCLUDE_IP4_DEST_CAM       (INCLUDE_IP4_DEST_CAM)
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
        .AXIS_USER_WIDTH    (IP4_TUSER_OUT_WDITH+EFF_ID_WIDTH+EFF_DEST_WIDTH),
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