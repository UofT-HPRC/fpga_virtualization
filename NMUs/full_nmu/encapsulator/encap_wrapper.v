`timescale 1ns / 1ps
`default_nettype none


module encap_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Packed input signals size
    localparam ENCAP_CONFIG1_SEL_WIDTH = EFF_ID_WIDTH,
    localparam ENCAP_CONFIG1_REG_WIDTH = 3,
    localparam ENCAP_CONFIG2_SEL_WIDTH = EFF_ID_WIDTH + EFF_DEST_WIDTH,
    localparam ENCAP_CONFIG2_REG_WIDTH = 3+48+48+1+16+6+8+8+16+32+32+16+16+16+1+24, //291

    //Features to Implement
    parameter USE_DYNAMIC_FSM = 1,
    parameter ALLOW_NO_ENCAP = 1,
    parameter ALLOW_MAC_ENCAP = 1,
    parameter ALLOW_IP4_ENCAP = 1,
    parameter ALLOW_UDP_ENCAP = 1,
    parameter ALLOW_NVGRE_ENCAP = 1,
    parameter ALLOW_VXLAN_ENCAP = 1,
    parameter ALLOW_ENCAP_W_TAG  = 1,

    //Retiming register stages for checksum calc (to be modified until timing met)
    parameter RETIMING_STAGES_CHECKSUM = 0,
    parameter RETIMING_STAGES_ENCAP = 0
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
                                          encap_config1_sel,
    input wire [(3)-1:0]                  encap_config1_regs,

    output wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                          encap_config2_sel,
    input wire [(291)-1:0]                encap_config2_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//   

    //Configuration select signals (1)
    wire [EFF_ID_WIDTH-1:0]        encap_sel_id_1;

    assign encap_config1_sel = encap_sel_id_1;

    //Configuration signal declarations (1)
    wire [2:0]      encap_mode_1 = encap_config1_regs;



    //Configuration select signals (2)
    wire [EFF_ID_WIDTH-1:0]        encap_sel_id_2;
    wire [EFF_DEST_WIDTH-1:0]      encap_sel_dest_2;

    assign encap_config2_sel = {encap_sel_id_2,encap_sel_dest_2};

    //Configuration signal declarations (2)
    wire [2:0]      encap_mode_2;
    wire [47:0]     mac_src_address;
    wire [47:0]     mac_dest_address;
    wire            insert_vlan_tag;
    wire [15:0]     vlan_field;
    wire [5:0]      ip4_dhsp;
    wire [7:0]      ip4_ttl;
    wire [7:0]      ip4_protocol;
    wire [15:0]     ip4_partial_checksum;
    wire [31:0]     ip4_src_address;
    wire [31:0]     ip4_dest_address;
    wire [15:0]     udp_src_port;
    wire [15:0]     udp_dest_port;
    wire [15:0]     udp_partial_checksum;
    wire            include_udp_checksum;
    wire [23:0]     virt_vsid;

    assign {virt_vsid,include_udp_checksum,udp_partial_checksum,
            udp_dest_port,udp_src_port,ip4_dest_address,ip4_src_address,
            ip4_partial_checksum,ip4_protocol,ip4_ttl,ip4_dhsp,vlan_field,
            insert_vlan_tag,mac_dest_address,mac_src_address,encap_mode_2}    
    = encap_config2_regs;



    //--------------------------------------------------------//
    //   Encap Instantiation                                  //
    //--------------------------------------------------------//

    encapsulator
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        
        .USE_DYNAMIC_FSM            (USE_DYNAMIC_FSM),
        .ALLOW_NO_ENCAP             (ALLOW_NO_ENCAP),
        .ALLOW_MAC_ENCAP            (ALLOW_MAC_ENCAP),
        .ALLOW_IP4_ENCAP            (ALLOW_IP4_ENCAP),
        .ALLOW_UDP_ENCAP            (ALLOW_UDP_ENCAP),
        .ALLOW_NVGRE_ENCAP          (ALLOW_NVGRE_ENCAP),
        .ALLOW_VXLAN_ENCAP          (ALLOW_VXLAN_ENCAP),
        .ALLOW_ENCAP_W_TAG          (ALLOW_ENCAP_W_TAG),

        .RETIMING_STAGES_CHECKSUM   (RETIMING_STAGES_CHECKSUM),
        .RETIMING_STAGES_ENCAP      (RETIMING_STAGES_ENCAP)
    )
    encap 
    (
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tid (axis_in_tid),
        .axis_in_tdest (axis_in_tdest),
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),
        
        .axis_out_tdata (axis_out_tdata),
        .axis_out_tid (axis_out_tid),
        .axis_out_tdest (axis_out_tdest),
        .axis_out_tkeep (axis_out_tkeep),
        .axis_out_tlast (axis_out_tlast),
        .axis_out_tvalid (axis_out_tvalid),
        .axis_out_tready (axis_out_tready),

        .encap_sel_id_1 (encap_sel_id_1),

        .encap_mode_1 (encap_mode_1),

        .encap_sel_id_2 (encap_sel_id_2),
        .encap_sel_dest_2 (encap_sel_dest_2),

        .encap_mode_2 (encap_mode_2),
        .mac_src_address (mac_src_address),
        .mac_dest_address (mac_dest_address),

        .insert_vlan_tag (insert_vlan_tag),
        .vlan_field (vlan_field),

        .ip4_dhsp (ip4_dhsp),
        .ip4_ttl (ip4_ttl),
        .ip4_protocol (ip4_protocol),
        .ip4_partial_checksum (ip4_partial_checksum),
        .ip4_src_address (ip4_src_address),
        .ip4_dest_address (ip4_dest_address),

        .udp_src_port (udp_src_port),
        .udp_dest_port (udp_dest_port),
        .udp_partial_checksum (udp_partial_checksum),
        .include_udp_checksum (include_udp_checksum),

        .virt_vsid (virt_vsid),
        
        .aclk (aclk),
        .aresetn (aresetn)
    );



endmodule

`default_nettype wire