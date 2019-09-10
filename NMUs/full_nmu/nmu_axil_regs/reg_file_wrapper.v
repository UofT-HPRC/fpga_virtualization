`timescale 1ns / 1ps
`default_nettype none




//Network parameter constants
`define DA_MAC_SIZE 48
`define SA_MAC_SIZE 48
`define ET_SIZE 16
`define VID_SIZE 16
`define SA_IP4_SIZE 32
`define DA_IP4_SIZE 32
`define SPORT_SIZE 16
`define DPORT_SIZE 16
`define VSID_SIZE 32




//AXIL Registers
module reg_file_wrapper
#(
    //AXIL Params
    parameter AXIL_ADDR_WIDTH = 17,

    //AXI Stream Params
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),
    localparam NUM_AXIS_DEST = (2**AXIS_DEST_WIDTH),

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Configuration Params
    parameter NUM_CONFIG_ETYPES = 2,
    parameter MIN_TAG_SIZE_BITS = 32,
    parameter MAX_TAG_SIZE_BITS = 64,

    localparam NUM_TAG_SIZES = ((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16) + 2,
    localparam NUM_TAG_SIZES_LOG2 = $clog2(NUM_TAG_SIZES),  

    //Config Register packed sizes
    localparam CONFIG_SEL_WIDTH = EFF_ID_WIDTH + EFF_DEST_WIDTH,
    localparam ID_ONLY_SEL_WIDTH = EFF_ID_WIDTH,

    localparam MAC_CONFIG_REG_WIDTH = `SA_MAC_SIZE + `DA_MAC_SIZE + 4,
    localparam MAC_CAM_WIDTH = (`SA_MAC_SIZE + 1) * NUM_AXIS_ID,

    localparam VLAN_CONFIG_REG_WIDTH = `VID_SIZE + 2,
    localparam VLAN_CAM_WIDTH = (`VID_SIZE + 1) * NUM_AXIS_ID,

    localparam ET_CONFIG_REG_WIDTH = 9 + (`ET_SIZE*NUM_CONFIG_ETYPES),
    localparam ET_CAM_WIDTH = (5) * NUM_AXIS_ID,

    localparam ARP_CONFIG_REG_WIDTH = `SA_MAC_SIZE + (2*`DA_IP4_SIZE) + `SA_IP4_SIZE + 2,
    localparam ARP_CAM_WIDTH = (`SA_IP4_SIZE + 1) * NUM_AXIS_ID,

    localparam IP4_CONFIG_REG_WIDTH = (2*`DA_IP4_SIZE) + `SA_IP4_SIZE + 5,
    localparam IP4_CAM_WIDTH = (`SA_IP4_SIZE + 1) * NUM_AXIS_ID,

    localparam PORT_CONFIG_REG_WIDTH = `SPORT_SIZE + `DPORT_SIZE + 2,
    localparam PORT_CAM_WIDTH = (`SPORT_SIZE + 1) * NUM_AXIS_ID,

    localparam EGR_CONFIG_REG_WIDTH = (AXIS_ID_WIDTH + 1) + 1 + (NUM_AXIS_ID*2),

    localparam ENCAP_CONFIG1_REG_WIDTH = 3,
    localparam ENCAP_CONFIG2_REG_WIDTH = 3+48+48+1+16+6+8+8+16+32+32+16+16+16+1+24, //291

    localparam TAGGER_CONFIG_REG_WIDTH = MAX_TAG_SIZE_BITS + NUM_TAG_SIZES_LOG2,

    localparam CUS_TAG_CONFIG_REG_WIDTH = `ET_SIZE,
    localparam CUS_TAG_CAM_WIDTH = ((MAX_TAG_SIZE_BITS*2) + 1) * NUM_AXIS_ID,

    localparam DETAG_CONFIG_REG_WIDTH = NUM_TAG_SIZES_LOG2,

    localparam VSID_CONFIG_REG_WIDTH = 1,
    localparam VSID_CAM_WIDTH = (`VSID_SIZE + `DA_MAC_SIZE + 2) * NUM_AXIS_ID,

    localparam ING_CONFIG_REG_WIDTH = (AXIS_ID_WIDTH + 1) + 1,

    localparam DECAP_CONFIG1_REG_WIDTH = 3+1,
    localparam DECAP_CONFIG2_REG_WIDTH = 3,

    //Features to Implement
    parameter INCLUDE_MAC = 1,
    parameter INCLUDE_MAC_SRC_ACL = 1,
    parameter INCLUDE_MAC_DEST_ACL = 1,
    parameter INCLUDE_MAC_NEXT_ACL = 1,

    parameter INCLUDE_VLAN = 1,
    parameter INCLUDE_VLAN_ACL = 1,

    parameter INCLUDE_CONFIG_ETYPE = 1,

    parameter INCLUDE_IP4 = 1,
    parameter INCLUDE_IP4_SRC_ACL = 1,
    parameter INCLUDE_IP4_DEST_ACL = 1,
    parameter INCLUDE_IP4_NEXT_ACL = 1,

    parameter INCLUDE_PORT = 1,
    parameter INCLUDE_SRC_PORT_ACL = 1,
    parameter INCLUDE_DEST_PORT_ACL = 1,

    parameter INCLUDE_VSID = 1,
    parameter VTEP_MODE = 0,

    parameter INCLUDE_ENCAP = 1,
    parameter INCLUDE_TAGGING = 1,

    parameter INCLUDE_EGR_ROUTE = 1
)
(
    //The AXI-Lite interface
    input wire  [AXIL_ADDR_WIDTH-1:0]  awaddr,
    input wire                         awvalid,
    output reg                         awready,
    
    input wire  [31:0]                 wdata,
    //input wire  [3:0]                  wstrb,
    input wire                         wvalid,
    output reg                         wready,

    output reg [1:0]                   bresp,
    output reg                         bvalid,
    input wire                         bready,
    
    input wire  [AXIL_ADDR_WIDTH-1:0]  araddr,
    input wire                         arvalid,
    output reg                         arready,

    output reg [31:0]                  rdata,
    output reg [1:0]                   rresp,
    output reg                         rvalid,
    input wire                         rready,
    
    //Config Select signlas
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                                            mac_config_sel,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]    vlan_config_sel,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]    etype_config_sel,
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                                            arp_config_sel,
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                                            ip4_config_sel,                                                                                                                                                           
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                                            port_config_sel,                                       
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]    egress_config_sel,                                       
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]    encap_config1_sel,
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                                            encap_config2_sel,                              
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]    tag_config_sel,
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH))-1:0]  decap_config1_sel,
    input wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH))-1:0]  decap_config2_sel,                                                                                                                

    //Config Register values
    output wire [(`SA_MAC_SIZE+`DA_MAC_SIZE+4)-1:0]         mac_config_regs,
    output wire [(`VID_SIZE+2)-1:0]                         vlan_config_regs,
    output wire [(9+(`ET_SIZE*NUM_CONFIG_ETYPES))-1:0]      etype_config_regs,
    output wire [(`SA_MAC_SIZE+(2*`DA_IP4_SIZE)+`SA_IP4_SIZE+2)-1:0]   
                                                            arp_config_regs,                                                        
    output wire [((2*`DA_IP4_SIZE)+`SA_IP4_SIZE+5)-1:0]     ip4_config_regs,
    output wire [(`SPORT_SIZE+`DPORT_SIZE+2)-1:0]           port_config_regs,
    output wire [(((2**AXIS_ID_WIDTH)*2)+(AXIS_ID_WIDTH+1)+1)-1:0]
                                                            egress_config_regs,
    output wire [(3)-1:0]                                   encap_config1_regs,
    output wire [(291)-1:0]                                 encap_config2_regs,
    output wire [(MAX_TAG_SIZE_BITS+$clog2(((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16)+2))-1:0]
                                                            tag_config_regs,
    output wire [(`ET_SIZE)-1:0]                            cus_tag_config_regs,                                                        
    output wire [($clog2(((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16)+2))-1:0]
                                                            detag_config_regs,
    output wire [(1)-1:0]                                   vsid_config_regs,
    output wire [((AXIS_ID_WIDTH+1)+1)-1:0]                 ingress_config_regs,
    output wire [(3+1)-1:0]                                 decap_config1_regs,
    output wire [(3)-1:0]                                   decap_config2_regs,

    //CAM contents output
    output wire [((`SA_MAC_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]  mac_cam_values,
    output wire [((`VID_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]     vlan_cam_values,
    output wire [((5)*(2**AXIS_ID_WIDTH))-1:0]               etype_cam_values,
    output wire [((`SA_IP4_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]  arp_cam_values,
    output wire [((`SA_IP4_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]  ip4_cam_values,
    output wire [((`SPORT_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]   port_cam_values,
    output wire [(((MAX_TAG_SIZE_BITS*2)+1)*(2**AXIS_ID_WIDTH))-1:0]   
                                                             cus_tag_cam_values,
    output wire [((`VSID_SIZE+`DA_MAC_SIZE+2)*(2**AXIS_ID_WIDTH))-1:0]   
                                                             vsid_cam_values,

    //Clocking
    input wire aclk,
    input wire aresetn
);

    //--------------------------------------------------------//
    //  Create register values                                //
    //--------------------------------------------------------//

    //Parameters
    localparam NUM_DEST = NUM_AXIS_ID * NUM_AXIS_DEST;
    localparam NUM_VSID = NUM_AXIS_ID;
    localparam NUM_ELSE = (VTEP_MODE) ? 1 : NUM_AXIS_ID;

    //Actual Registers Values
    reg                            reg_mac_skip_parsing [NUM_ELSE-1:0];
    reg                            reg_mac_allow_next_ctag [NUM_ELSE-1:0];
    reg [`SA_MAC_SIZE-1:0]         reg_mac_addresses [NUM_ELSE-1:0];
    reg                            reg_mac_match_src [NUM_ELSE-1:0];
    reg [`DA_MAC_SIZE-1:0]         reg_mac_dest_addresses [NUM_DEST-1:0];
    reg                            reg_mac_match_dest [NUM_ELSE-1:0];
    reg                            reg_mac_cam_must_match [NUM_ELSE-1:0];

    reg [`VID_SIZE-1:0]            reg_vlan_fields [NUM_ELSE-1:0];
    reg                            reg_vlan_match_tag [NUM_ELSE-1:0];
    reg                            reg_vlan_match_pri [NUM_ELSE-1:0];
    reg                            reg_vlan_cam_must_match[NUM_ELSE-1:0];

    reg                            reg_etype_allow_all [NUM_ELSE-1:0];
    reg                            reg_etype_allow_next_ip4 [NUM_ELSE-1:0];
    reg                            reg_etype_allow_next_ip6 [NUM_ELSE-1:0];
    reg                            reg_etype_allow_next_arp [NUM_ELSE-1:0];
    reg                            reg_etype_allow_next_raw [NUM_ELSE-1:0];
    reg                            reg_etype_allow_bc [NUM_ELSE-1:0];
    reg                            reg_etype_allow_mc [NUM_ELSE-1:0];
    reg                            reg_etype_allow_bc_arp_only [NUM_ELSE-1:0];
    reg                            reg_etype_allow_mc_ip_only [NUM_ELSE-1:0];
    reg [`ET_SIZE-1:0]             reg_etype_config [NUM_CONFIG_ETYPES-1:0];

    reg                            reg_ip4_restrict_to_only_ports [NUM_ELSE-1:0];
    reg [`SA_IP4_SIZE-1:0]         reg_ip4_addresses [NUM_ELSE-1:0];
    reg                            reg_ip4_match_src [NUM_ELSE-1:0];
    reg [`DA_IP4_SIZE-1:0]         reg_ip4_dest_addresses [NUM_DEST-1:0];
    reg [`SA_IP4_SIZE-1:0]         reg_ip4_subnet_masks [NUM_ELSE-1:0];
    reg                            reg_ip4_allow_public [NUM_ELSE-1:0];
    reg                            reg_ip4_allow_bc [NUM_ELSE-1:0];
    reg                            reg_ip4_allow_mc [NUM_ELSE-1:0];
    reg                            reg_ip4_cam_must_match [NUM_ELSE-1:0];

    reg [`SPORT_SIZE-1:0]          reg_egress_ports [NUM_ELSE-1:0];
    reg [`SPORT_SIZE-1:0]          reg_ingress_ports [NUM_ELSE-1:0];
    reg                            reg_match_src_port [NUM_ELSE-1:0];
    reg [`DPORT_SIZE-1:0]          reg_dest_ports [NUM_DEST-1:0];
    reg                            reg_match_dest_port [NUM_ELSE-1:0];
    reg                            reg_port_cam_must_match [NUM_ELSE-1:0];

    reg [NUM_AXIS_ID-1:0]          reg_must_route_mask [NUM_VSID-1:0];
    reg [NUM_AXIS_ID-1:0]          reg_cannot_route_mask [NUM_VSID-1:0];
    reg                            reg_reroute_if_config;
    reg [AXIS_ID_WIDTH:0]          reg_reroute_dest;

    reg [2:0]                      reg_encap_mode [NUM_ELSE-1:0];
    reg                            reg_insert_vlan_tag [NUM_ELSE-1:0];
    reg [5:0]                      reg_ip4_dhsp [NUM_ELSE-1:0];
    reg [7:0]                      reg_ip4_ttl [NUM_ELSE-1:0];
    reg [7:0]                      reg_ip4_protocol [NUM_ELSE-1:0];
    reg [15:0]                     reg_ip4_partial_checksum [NUM_DEST-1:0];
    reg [15:0]                     reg_udp_partial_checksum [NUM_DEST-1:0];
    reg                            reg_include_udp_checksum [NUM_ELSE-1:0];

    reg [NUM_TAG_SIZES_LOG2-1:0]   reg_tag_mode [NUM_ELSE-1:0];
    reg [NUM_TAG_SIZES_LOG2-1:0]   reg_detag_mode;

    reg                            reg_has_cus_tag [NUM_ELSE-1:0];
    reg [MAX_TAG_SIZE_BITS-1:0]    reg_custom_tags [NUM_ELSE-1:0];
    reg [MAX_TAG_SIZE_BITS-1:0]    reg_custom_tag_masks [NUM_ELSE-1:0];
    reg [`ET_SIZE-1:0]             reg_expected_etype;

    reg [`VSID_SIZE-1:0]           reg_vsids [NUM_VSID-1:0];
    reg                            reg_vsid_cam_must_match [NUM_VSID-1:0];
    reg [`DA_MAC_SIZE-1:0]         reg_mac_encap_addresses [NUM_VSID-1:0];
    reg                            reg_mac_encap_cam_must_match [NUM_VSID-1:0];
    reg                            reg_is_vxlan;



    //Whether or not to mask the register values to the output
    localparam      INCLUDE_SIG_mac_skip_parsing        = INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_allow_next_ctag     = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_addresses           = INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_match_src           = INCLUDE_MAC_SRC_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_dest_addresses      = (INCLUDE_MAC_DEST_ACL || INCLUDE_ENCAP) && INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_match_dest          = INCLUDE_MAC_DEST_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_mac_cam_must_match      = INCLUDE_MAC;

    localparam      INCLUDE_SIG_vlan_fields             = INCLUDE_VLAN;
    localparam      INCLUDE_SIG_vlan_match_tag          = INCLUDE_VLAN_ACL && INCLUDE_VLAN;
    localparam      INCLUDE_SIG_vlan_match_pri          = INCLUDE_VLAN_ACL && INCLUDE_VLAN;
    localparam      INCLUDE_SIG_vlan_cam_must_match     = INCLUDE_VLAN;

    localparam      INCLUDE_SIG_etype_allow_all         = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_next_ip4    = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_next_ip6    = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_next_arp    = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_next_raw    = INCLUDE_MAC_NEXT_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_bc          = INCLUDE_MAC_DEST_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_mc          = INCLUDE_MAC_DEST_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_bc_arp_only = INCLUDE_MAC_DEST_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_allow_mc_ip_only  = INCLUDE_MAC_DEST_ACL && INCLUDE_MAC;
    localparam      INCLUDE_SIG_etype_config            = INCLUDE_CONFIG_ETYPE && INCLUDE_MAC;
    
    localparam      INCLUDE_SIG_ip4_restrict_to_only_ports = INCLUDE_IP4_NEXT_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_addresses           = INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_match_src           = INCLUDE_IP4_SRC_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_dest_addresses      = (INCLUDE_IP4_DEST_ACL || INCLUDE_ENCAP) && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_subnet_masks        = INCLUDE_IP4_DEST_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_allow_public        = INCLUDE_IP4_DEST_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_allow_bc            = INCLUDE_IP4_DEST_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_allow_mc            = INCLUDE_IP4_DEST_ACL && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_cam_must_match      = INCLUDE_IP4;

    localparam      INCLUDE_SIG_egress_ports            = (INCLUDE_SRC_PORT_ACL || INCLUDE_ENCAP) && INCLUDE_PORT;
    localparam      INCLUDE_SIG_ingress_ports           = INCLUDE_PORT;
    localparam      INCLUDE_SIG_match_src_port          = INCLUDE_SRC_PORT_ACL && INCLUDE_PORT;
    localparam      INCLUDE_SIG_dest_ports              = (INCLUDE_DEST_PORT_ACL || INCLUDE_ENCAP) && INCLUDE_PORT;
    localparam      INCLUDE_SIG_match_dest_port         = INCLUDE_DEST_PORT_ACL && INCLUDE_PORT;
    localparam      INCLUDE_SIG_port_cam_must_match     = INCLUDE_PORT;

    localparam      INCLUDE_SIG_must_route_mask         = INCLUDE_EGR_ROUTE;
    localparam      INCLUDE_SIG_cannot_route_mask       = INCLUDE_EGR_ROUTE;
    localparam      INCLUDE_SIG_reroute_if_config       = INCLUDE_CONFIG_ETYPE;
    localparam      INCLUDE_SIG_reroute_dest            = INCLUDE_CONFIG_ETYPE;

    localparam      INCLUDE_SIG_encap_mode              = INCLUDE_ENCAP;
    localparam      INCLUDE_SIG_insert_vlan_tag         = INCLUDE_ENCAP && INCLUDE_VLAN;
    localparam      INCLUDE_SIG_ip4_dhsp                = INCLUDE_ENCAP && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_ttl                 = INCLUDE_ENCAP && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_protocol            = INCLUDE_ENCAP && INCLUDE_IP4;
    localparam      INCLUDE_SIG_ip4_partial_checksum    = INCLUDE_ENCAP && INCLUDE_IP4;
    localparam      INCLUDE_SIG_udp_partial_checksum    = INCLUDE_ENCAP && INCLUDE_PORT;
    localparam      INCLUDE_SIG_include_udp_checksum    = INCLUDE_ENCAP && INCLUDE_PORT;

    localparam      INCLUDE_SIG_tag_mode                = INCLUDE_TAGGING;
    localparam      INCLUDE_SIG_detag_mode              = INCLUDE_TAGGING;

    localparam      INCLUDE_SIG_has_cus_tag             = INCLUDE_TAGGING;
    localparam      INCLUDE_SIG_custom_tags             = INCLUDE_TAGGING;
    localparam      INCLUDE_SIG_custom_tag_masks        = INCLUDE_TAGGING;
    localparam      INCLUDE_SIG_expected_etype          = INCLUDE_TAGGING;

    localparam      INCLUDE_SIG_vsids                   = INCLUDE_VSID;
    localparam      INCLUDE_SIG_vsid_cam_must_match     = INCLUDE_VSID;
    localparam      INCLUDE_SIG_mac_encap_addresses     = INCLUDE_VSID;
    localparam      INCLUDE_SIG_mac_encap_cam_must_match = INCLUDE_VSID;
    localparam      INCLUDE_SIG_is_vxlan                = INCLUDE_VSID;


    //Effective values for registers (masked if not included, to optimize awway)
    /*wire                          out_mac_skip_parsing [NUM_ELSE-1:0];
    wire                            out_mac_allow_next_ctag [NUM_ELSE-1:0];*/
    wire [`SA_MAC_SIZE-1:0]         out_mac_addresses [NUM_ELSE-1:0];
    /*wire                          out_mac_match_src [NUM_ELSE-1:0];
    wire [`DA_MAC_SIZE-1:0]         out_mac_dest_addresses [NUM_DEST-1:0];
    wire                            out_mac_match_dest [NUM_ELSE-1:0];*/
    wire                            out_mac_cam_must_match [NUM_ELSE-1:0];

    wire [`VID_SIZE-1:0]            out_vlan_fields [NUM_ELSE-1:0];
    /*wire                          out_vlan_match_tag [NUM_ELSE-1:0];
    wire                            out_vlan_match_pri [NUM_ELSE-1:0];*/
    wire                            out_vlan_cam_must_match[NUM_ELSE-1:0];

    wire                            out_etype_allow_all [NUM_ELSE-1:0];
    wire                            out_etype_allow_next_ip4 [NUM_ELSE-1:0];
    wire                            out_etype_allow_next_ip6 [NUM_ELSE-1:0];
    wire                            out_etype_allow_next_arp [NUM_ELSE-1:0];
    wire                            out_etype_allow_next_raw [NUM_ELSE-1:0];
    /*wire                          out_etype_allow_bc [NUM_ELSE-1:0];
    wire                            out_etype_allow_mc [NUM_ELSE-1:0];
    wire                            out_etype_allow_bc_arp_only [NUM_ELSE-1:0];
    wire                            out_etype_allow_mc_ip_only [NUM_ELSE-1:0];*/
    wire [`ET_SIZE-1:0]             out_etype_config [NUM_CONFIG_ETYPES-1:0];

    /*wire                          out_ip4_restrict_to_only_ports [NUM_ELSE-1:0];*/
    wire [`SA_IP4_SIZE-1:0]         out_ip4_addresses [NUM_ELSE-1:0];
    /*wire                          out_ip4_match_src [NUM_ELSE-1:0];
    wire [`DA_IP4_SIZE-1:0]         out_ip4_dest_addresses [NUM_DEST-1:0];
    wire [`SA_IP4_SIZE-1:0]         out_ip4_subnet_masks [NUM_ELSE-1:0];
    wire                            out_ip4_allow_public [NUM_ELSE-1:0];
    wire                            out_ip4_allow_bc [NUM_ELSE-1:0];
    wire                            out_ip4_allow_mc [NUM_ELSE-1:0];*/
    wire                            out_ip4_cam_must_match [NUM_ELSE-1:0];

    /*wire [`SPORT_SIZE-1:0]        out_egress_ports [NUM_ELSE-1:0]*/
    wire [`SPORT_SIZE-1:0]          out_ingress_ports [NUM_ELSE-1:0];
    /*wire                          out_match_src_port [NUM_ELSE-1:0]
    wire [`DPORT_SIZE-1:0]          out_dest_ports [NUM_DEST-1:0]
    wire                            out_match_dest_port [NUM_ELSE-1:0];*/
    wire                            out_port_cam_must_match [NUM_ELSE-1:0];

    /*wire [NUM_AXIS_ID-1:0]        out_must_route_mask [NUM_VSID-1:0];
    wire [NUM_AXIS_ID-1:0]          out_cannot_route_mask [NUM_VSID-1:0];
    wire                            out_reroute_if_config;
    wire [AXIS_ID_WIDTH:0]          out_reroute_dest;

    wire [2:0]                      out_encap_mode [NUM_ELSE-1:0];
    wire                            out_insert_vlan_tag [NUM_ELSE-1:0];
    wire [5:0]                      out_ip4_dhsp [NUM_ELSE-1:0];
    wire [7:0]                      out_ip4_ttl [NUM_ELSE-1:0];
    wire [7:0]                      out_ip4_protocol [NUM_ELSE-1:0];
    wire [15:0]                     out_ip4_partial_checksum [NUM_DEST-1:0];
    wire [15:0]                     out_udp_partial_checksum [NUM_DEST-1:0];
    wire                            out_include_udp_checksum [NUM_ELSE-1:0];

    wire [NUM_TAG_SIZES_LOG2-1:0]   out_tag_mode [NUM_ELSE-1:0];
    wire [NUM_TAG_SIZES_LOG2-1:0]   out_detag_mode;*/

    wire                            out_has_cus_tag [NUM_ELSE-1:0];
    wire [MAX_TAG_SIZE_BITS-1:0]    out_custom_tags [NUM_ELSE-1:0];
    wire [MAX_TAG_SIZE_BITS-1:0]    out_custom_tag_masks [NUM_ELSE-1:0];
    /*wire [`ET_SIZE-1:0]           out_expected_etype;*/

    wire [`VSID_SIZE-1:0]           out_vsids [NUM_VSID-1:0];
    wire                            out_vsid_cam_must_match [NUM_VSID-1:0];
    wire [`DA_MAC_SIZE-1:0]         out_mac_encap_addresses [NUM_VSID-1:0];
    wire                            out_mac_encap_cam_must_match [NUM_VSID-1:0];
    /*wire                          out_is_vxlan;*/



    //Assign values to the effective signals depending on mask
    /*generate
        for(i = 0; i < NUM_DEST; i = i + 1) begin : dest_assign

            assign out_mac_dest_addresses[i] = 
                (INCLUDE_SIG_mac_dest_addresses) ? reg_mac_dest_addresses[i] : 0;

            assign out_ip4_dest_addresses[i] = 
                (INCLUDE_SIG_ip4_dest_addresses) ? reg_ip4_dest_addresses[i] : 0;

            assign out_dest_ports[i] = 
                (INCLUDE_SIG_dest_ports) ? reg_dest_ports[i] : 0;

            assign out_ip4_partial_checksum[i] =
                (INCLUDE_SIG_ip4_partial_checksum) ? reg_ip4_partial_checksum[i] : 0;

            assign out_udp_partial_checksum[i] =
                (INCLUDE_SIG_udp_partial_checksum) ? reg_udp_partial_checksum[i] : 0;

        end 
    endgenerate*/

    genvar i;
    genvar j;
    generate
        for(i = 0; i < NUM_VSID; i = i + 1) begin : vsid_assign

            assign out_vsids[i] = 
                (INCLUDE_SIG_vsids) ? reg_vsids[i] : 0;

            assign out_vsid_cam_must_match[i] = 
                (INCLUDE_SIG_vsid_cam_must_match) ? reg_vsid_cam_must_match[i] : 0;

            assign out_mac_encap_addresses[i] = 
                (INCLUDE_SIG_mac_encap_addresses) ? reg_mac_encap_addresses[i] : 0;

            assign out_mac_encap_cam_must_match[i] = 
                (INCLUDE_SIG_mac_encap_cam_must_match) ? reg_mac_encap_cam_must_match[i] : 0;

            /*assign out_must_route_mask[i] =
                (INCLUDE_SIG_must_route_mask) ? reg_must_route_mask[i] : 0;

            //Modify route mask to exclude routing to sender
            assign out_cannot_route_mask[i] =
                ( (INCLUDE_SIG_cannot_route_mask) ? reg_cannot_route_mask[i] : 0 )
                    | { {(NUM_VSID-i-1){1'b0}}, 1'b1, {i{1'b0}} };*/

        end 
    endgenerate

    generate
        for(i = 0; i < NUM_ELSE; i = i + 1) begin : else_assign

            /*assign out_mac_skip_parsing[i] =
                (INCLUDE_SIG_mac_skip_parsing) ? reg_mac_skip_parsing[i] : 0;

            assign out_mac_allow_next_ctag[i] =
                (INCLUDE_SIG_mac_allow_next_ctag) ? reg_mac_allow_next_ctag[i] : 0;*/

            assign out_mac_addresses[i] =
                (INCLUDE_SIG_mac_addresses) ? reg_mac_addresses[i] : 0;

            /*assign out_mac_match_src[i] =
                (INCLUDE_SIG_mac_match_src) ? reg_mac_match_src[i] : 0;

            assign out_mac_match_dest[i] = 
                (INCLUDE_SIG_mac_match_dest) ? reg_mac_match_dest[i] : 0;*/

            assign out_mac_cam_must_match[i] =
                (INCLUDE_SIG_mac_cam_must_match) ? reg_mac_cam_must_match[i] : 0;

            assign out_vlan_fields[i] =
                (INCLUDE_SIG_vlan_fields) ? reg_vlan_fields[i] : 0;

            /*assign out_vlan_match_tag[i] =
                (INCLUDE_SIG_vlan_match_tag) ? reg_vlan_match_tag[i] : 0;

            assign out_vlan_match_pri[i] =
                (INCLUDE_SIG_vlan_match_pri) ? reg_vlan_match_pri[i] : 0;*/

            assign out_vlan_cam_must_match[i] =
                (INCLUDE_SIG_vlan_cam_must_match) ? reg_vlan_cam_must_match[i] : 0;

            assign out_etype_allow_all[i] =
                (INCLUDE_SIG_etype_allow_all) ? reg_etype_allow_all[i] : 0;

            assign out_etype_allow_next_ip4[i] =
                (INCLUDE_SIG_etype_allow_next_ip4) ? reg_etype_allow_next_ip4[i] : 0;

            assign out_etype_allow_next_ip6[i] =
                (INCLUDE_SIG_etype_allow_next_ip6) ? reg_etype_allow_next_ip6[i] : 0;

            assign out_etype_allow_next_arp[i] =
                (INCLUDE_SIG_etype_allow_next_arp) ? reg_etype_allow_next_arp[i] : 0;

            assign out_etype_allow_next_raw[i] =
                (INCLUDE_SIG_etype_allow_next_raw) ? reg_etype_allow_next_raw[i] : 0;

            /*assign out_etype_allow_bc[i] = 
                (INCLUDE_SIG_etype_allow_bc) ? reg_etype_allow_bc[i] : 0;

            assign out_etype_allow_mc[i] = 
                (INCLUDE_SIG_etype_allow_mc) ? reg_etype_allow_mc[i] : 0;

            assign out_etype_allow_bc_arp_only[i] = 
                (INCLUDE_SIG_etype_allow_bc_arp_only) ? reg_etype_allow_bc_arp_only[i] : 0;

            assign out_etype_allow_mc_ip_only[i] = 
                (INCLUDE_SIG_etype_allow_mc_ip_only) ? reg_etype_allow_mc_ip_only[i] : 0;

            assign out_ip4_restrict_to_only_ports[i] =
                (INCLUDE_SIG_ip4_restrict_to_only_ports) ? reg_ip4_restrict_to_only_ports[i] : 0;*/

            assign out_ip4_addresses[i] =
                (INCLUDE_SIG_ip4_addresses) ? reg_ip4_addresses[i] : 0;

            /*assign out_ip4_match_src[i] =
                (INCLUDE_SIG_ip4_match_src) ? reg_ip4_match_src[i] : 0;

            assign out_ip4_subnet_masks[i] = 
                (INCLUDE_SIG_ip4_subnet_masks) ? reg_ip4_subnet_masks[i] : 0;

            assign out_ip4_allow_public[i] = 
                (INCLUDE_SIG_ip4_allow_public) ? reg_ip4_allow_public[i] : 0;

            assign out_ip4_allow_bc[i] = 
                (INCLUDE_SIG_ip4_allow_bc) ? reg_ip4_allow_bc[i] : 0;

            assign out_ip4_allow_mc[i] = 
                (INCLUDE_SIG_ip4_allow_mc) ? reg_ip4_allow_mc[i] : 0;*/

            assign out_ip4_cam_must_match[i] =
                (INCLUDE_SIG_ip4_cam_must_match) ? reg_ip4_cam_must_match[i] : 0;

            /*assign out_egress_ports[i] =
                (INCLUDE_SIG_egress_ports) ? reg_egress_ports[i] : 0;*/

            assign out_ingress_ports[i] =
                (INCLUDE_SIG_ingress_ports) ? reg_ingress_ports[i] : 0;

            /*assign out_match_src_port[i] =
                (INCLUDE_SIG_match_src_port) ? reg_match_src_port[i] : 0;

            assign out_match_dest_port[i] = 
                (INCLUDE_SIG_match_dest_port) ? reg_match_dest_port[i] : 0;*/

            assign out_port_cam_must_match[i] =
                (INCLUDE_SIG_port_cam_must_match) ? reg_port_cam_must_match[i] : 0;

            assign out_has_cus_tag[i] =
                (INCLUDE_SIG_has_cus_tag) ? reg_has_cus_tag[i] : 0;

            assign out_custom_tags[i] =
                (INCLUDE_SIG_custom_tags) ? reg_custom_tags[i] : 0;

            assign out_custom_tag_masks[i] =
                (INCLUDE_SIG_custom_tag_masks) ? reg_custom_tag_masks[i] : 0;

            /*assign out_encap_mode[i] =
                (INCLUDE_SIG_encap_mode) ? reg_encap_mode[i] : 0;

            assign out_insert_vlan_tag[i] =
                (INCLUDE_SIG_insert_vlan_tag) ? reg_insert_vlan_tag[i] : 0;

            assign out_ip4_dhsp[i] =
                (INCLUDE_SIG_ip4_dhsp) ? reg_ip4_dhsp[i] : 0;

            assign out_ip4_ttl[i] =
                (INCLUDE_SIG_ip4_ttl) ? reg_ip4_ttl[i] : 0;

            assign out_ip4_protocol[i] =
                (INCLUDE_SIG_ip4_protocol) ? reg_ip4_protocol[i] : 0;

            assign out_include_udp_checksum[i] =
                (INCLUDE_SIG_include_udp_checksum) ? reg_include_udp_checksum[i] : 0;

            assign out_tag_mode[i] =
                (INCLUDE_SIG_tag_mode) ? reg_tag_mode[i] : 0;*/

        end 
    endgenerate

    generate
        for(i = 0; i < NUM_CONFIG_ETYPES; i = i + 1)  begin : config_assign
            assign out_etype_config[i] = (INCLUDE_SIG_etype_config) ? reg_etype_config[i] : 0;
        end 
    endgenerate

    /*assign out_detag_mode = (INCLUDE_SIG_detag_mode) ? reg_detag_mode : 0;
    assign out_is_vxlan = (INCLUDE_SIG_is_vxlan) ? reg_is_vxlan : 0;
    assign out_expected_etype = (INCLUDE_SIG_expected_etype) ? reg_expected_etype : 0;
    assign out_reroute_if_config = (INCLUDE_SIG_reroute_if_config) ? reg_reroute_if_config : 0;
    assign out_reroute_dest = (INCLUDE_SIG_reroute_dest) ? reg_reroute_dest : 0;*/



    //--------------------------------------------------------//
    //  Assign MAC Output values                              //
    //--------------------------------------------------------//

    //MAC Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] mac_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) mac_src_sel = 0;
        else mac_src_sel = mac_config_sel[CONFIG_SEL_WIDTH-1:CONFIG_SEL_WIDTH-AXIS_ID_WIDTH];
    end 

    reg [CONFIG_SEL_WIDTH-1:0] mac_dest_sel;
    always@(*) begin
        if((AXIS_ID_WIDTH == 0 && AXIS_DEST_WIDTH == 0) || VTEP_MODE) mac_dest_sel = 0;
        else if(AXIS_ID_WIDTH == 0) mac_dest_sel = mac_config_sel[CONFIG_SEL_WIDTH-2:0];
        else if(AXIS_DEST_WIDTH == 0) mac_dest_sel = mac_config_sel[CONFIG_SEL_WIDTH-1:1];
        else mac_dest_sel = mac_config_sel;
    end

    //MAC Config register outputs (using select signals)
    wire                    mac_skip_parsing =      (INCLUDE_SIG_mac_skip_parsing) ?    reg_mac_skip_parsing[mac_src_sel] : 0;
    wire                    mac_allow_next_ctag =   (INCLUDE_SIG_mac_allow_next_ctag) ? reg_mac_allow_next_ctag[mac_src_sel] : 0;
    wire [`SA_MAC_SIZE-1:0] mac_src_address =       out_mac_addresses[mac_src_sel];
    wire                    mac_match_src =         (INCLUDE_SIG_mac_match_src) ?       reg_mac_match_src[mac_src_sel] : 0;
    wire [`DA_MAC_SIZE-1:0] mac_dest_address =      (INCLUDE_SIG_mac_dest_addresses) ?  reg_mac_dest_addresses[mac_dest_sel] : 0;
    wire                    mac_match_dest =        (INCLUDE_SIG_mac_match_dest) ?      reg_mac_match_dest[mac_src_sel] : 0;

    assign mac_config_regs = 
        {mac_match_dest,mac_dest_address,mac_match_src,
         mac_src_address,mac_allow_next_ctag,mac_skip_parsing};

    //MAC CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : mac_cam_assign

            localparam PER_ID = (`SA_MAC_SIZE + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign mac_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_mac_cam_must_match[FROM_INDEX],out_mac_addresses[FROM_INDEX]};

        end 
    endgenerate



    //--------------------------------------------------------//
    //  Assign VLAN Output values                             //
    //--------------------------------------------------------//

    //VLAN Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] vlan_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) vlan_src_sel = 0;
        else vlan_src_sel = vlan_config_sel;
    end

    //VLAN Config register outputs (using select signals)
    wire [`VID_SIZE-1:0]          vlan_field_expected = out_vlan_fields[vlan_src_sel];
    wire                          vlan_match_tag = (INCLUDE_SIG_vlan_match_tag) ? reg_vlan_match_tag[vlan_src_sel] : 0;
    wire                          vlan_match_pri = (INCLUDE_SIG_vlan_match_pri) ? reg_vlan_match_pri[vlan_src_sel] : 0;

    assign vlan_config_regs = {vlan_match_pri,vlan_match_tag,vlan_field_expected};

    //VLAN CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : vlan_cam_assign

            localparam PER_ID = (`VID_SIZE + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign vlan_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_vlan_cam_must_match[FROM_INDEX],out_vlan_fields[FROM_INDEX]};

        end 
    endgenerate



    //--------------------------------------------------------//
    //  Assign eType Output values                            //
    //--------------------------------------------------------//

    //ETYPE Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] etype_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) etype_src_sel = 0;
        else etype_src_sel = etype_config_sel;
    end 

    //ETYPE Config register outputs (using select signals)
    wire                 etype_allow_all =          out_etype_allow_all[etype_src_sel];
    wire                 etype_allow_next_ip4 =     out_etype_allow_next_ip4[etype_src_sel];
    wire                 etype_allow_next_ip6 =     out_etype_allow_next_ip6[etype_src_sel];
    wire                 etype_allow_next_arp =     out_etype_allow_next_arp[etype_src_sel];
    wire                 etype_allow_next_raw =     out_etype_allow_next_raw[etype_src_sel];
    
    wire                 etype_allow_bc =           (INCLUDE_SIG_etype_allow_bc) ? reg_etype_allow_bc[etype_src_sel] : 0;
    wire                 etype_allow_mc =           (INCLUDE_SIG_etype_allow_mc) ? reg_etype_allow_mc[etype_src_sel] : 0;
    wire                 etype_allow_bc_arp_only =  (INCLUDE_SIG_etype_allow_bc_arp_only) ? reg_etype_allow_bc_arp_only[etype_src_sel] : 0;
    wire                 etype_allow_mc_ip_only =   (INCLUDE_SIG_etype_allow_mc_ip_only) ? reg_etype_allow_mc_ip_only[etype_src_sel] : 0;

    localparam ET_CONFIG_WIDTH_STATIC = 9;

    assign etype_config_regs[ET_CONFIG_WIDTH_STATIC-1:0] = 
        {etype_allow_mc_ip_only,etype_allow_bc_arp_only,etype_allow_mc,
         etype_allow_bc,etype_allow_next_raw,etype_allow_next_arp,
         etype_allow_next_ip6,etype_allow_next_ip4,etype_allow_all};

    generate
        for(j = 0; j < NUM_CONFIG_ETYPES; j = j + 1) begin : config_etype 

            assign etype_config_regs[(ET_CONFIG_WIDTH_STATIC+(`ET_SIZE*j))+:`ET_SIZE] 
            = out_etype_config[j];

        end
    endgenerate

    //ETYPE CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : etype_cam_assign

            localparam PER_ID = (5);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign etype_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_etype_allow_next_raw[FROM_INDEX],out_etype_allow_next_arp[FROM_INDEX],
                 out_etype_allow_next_ip6[FROM_INDEX],out_etype_allow_next_ip4[FROM_INDEX],
                 out_etype_allow_all[FROM_INDEX]};

        end 
    endgenerate



    //--------------------------------------------------------//
    //  Assign ARP Output values                              //
    //--------------------------------------------------------//

    //ARP Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] arp_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) arp_src_sel = 0;
        else arp_src_sel = arp_config_sel[CONFIG_SEL_WIDTH-1:CONFIG_SEL_WIDTH-AXIS_ID_WIDTH];
    end 

    reg [CONFIG_SEL_WIDTH-1:0] arp_dest_sel;
    always@(*) begin
        if((AXIS_ID_WIDTH == 0 && AXIS_DEST_WIDTH == 0) || VTEP_MODE) arp_dest_sel = 0;
        else if(AXIS_ID_WIDTH == 0) arp_dest_sel = arp_config_sel[CONFIG_SEL_WIDTH-2:0];
        else if(AXIS_DEST_WIDTH == 0) arp_dest_sel = arp_config_sel[CONFIG_SEL_WIDTH-1:1];
        else arp_dest_sel = arp_config_sel;
    end

    //ARP Config register outputs (using select signals)
    wire [`SA_MAC_SIZE-1:0]       mac_src_address_arp =     out_mac_addresses[arp_src_sel];
    wire                          mac_match_src_arp =       (INCLUDE_SIG_mac_match_src) ? reg_mac_match_src[arp_src_sel] : 0;
    wire [`SA_IP4_SIZE-1:0]       ip4_src_address_arp =     out_ip4_addresses[arp_src_sel];
    wire                          ip4_match_src_arp =       (INCLUDE_SIG_ip4_match_src) ? reg_ip4_match_src[arp_src_sel] : 0;
    wire [`DA_IP4_SIZE-1:0]       ip4_dest_address_arp =    (INCLUDE_SIG_ip4_dest_addresses) ? reg_ip4_dest_addresses[arp_dest_sel] : 0;
    wire [`SA_IP4_SIZE-1:0]       ip4_subnet_mask_arp =     (INCLUDE_SIG_ip4_subnet_masks) ? reg_ip4_subnet_masks[arp_src_sel] : 0;

    assign arp_config_regs = 
        {ip4_subnet_mask_arp,ip4_dest_address_arp,ip4_match_src_arp,
         ip4_src_address_arp,mac_match_src_arp,mac_src_address_arp};

    //ARP CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : arp_cam_assign

            localparam PER_ID = (`SA_IP4_SIZE + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign arp_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_ip4_cam_must_match[FROM_INDEX],out_ip4_addresses[FROM_INDEX]};

        end 
    endgenerate



    //--------------------------------------------------------//
    //  Assign IP4 Output values                              //
    //--------------------------------------------------------//

    //IP4 Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] ip4_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) ip4_src_sel = 0;
        else ip4_src_sel = ip4_config_sel[CONFIG_SEL_WIDTH-1:CONFIG_SEL_WIDTH-AXIS_ID_WIDTH];
    end 

    reg [CONFIG_SEL_WIDTH-1:0] ip4_dest_sel;
    always@(*) begin
        if((AXIS_ID_WIDTH == 0 && AXIS_DEST_WIDTH == 0) || VTEP_MODE) ip4_dest_sel = 0;
        else if(AXIS_ID_WIDTH == 0) ip4_dest_sel = ip4_config_sel[CONFIG_SEL_WIDTH-2:0];
        else if(AXIS_DEST_WIDTH == 0) ip4_dest_sel = ip4_config_sel[CONFIG_SEL_WIDTH-1:1];
        else ip4_dest_sel = ip4_config_sel;
    end

    //IP4 Config register outputs (using select signals)
    wire                          ip4_restrict_to_only_ports = (INCLUDE_SIG_ip4_restrict_to_only_ports) ? reg_ip4_restrict_to_only_ports[ip4_src_sel] : 0;
    wire [`SA_IP4_SIZE-1:0]       ip4_src_address =          out_ip4_addresses[ip4_src_sel];
    wire                          ip4_match_src =            (INCLUDE_SIG_ip4_match_src) ? reg_ip4_match_src[ip4_src_sel] : 0;
    wire [`DA_IP4_SIZE-1:0]       ip4_dest_address =         (INCLUDE_SIG_ip4_dest_addresses) ? reg_ip4_dest_addresses[ip4_dest_sel] : 0;
    wire [`SA_IP4_SIZE-1:0]       ip4_subnet_mask =          (INCLUDE_SIG_ip4_subnet_masks) ? reg_ip4_subnet_masks[ip4_src_sel] : 0;
    wire                          ip4_allow_public =         (INCLUDE_SIG_ip4_allow_public) ? reg_ip4_allow_public[ip4_src_sel] : 0;
    wire                          ip4_allow_bc =             (INCLUDE_SIG_ip4_allow_bc) ? reg_ip4_allow_bc[ip4_src_sel] : 0;
    wire                          ip4_allow_mc =             (INCLUDE_SIG_ip4_allow_mc) ? reg_ip4_allow_mc[ip4_src_sel] : 0;

    assign ip4_config_regs = 
        {ip4_allow_mc,ip4_allow_bc,ip4_allow_public,
         ip4_subnet_mask,ip4_dest_address,ip4_match_src,
         ip4_src_address,ip4_restrict_to_only_ports};

    //IP4 CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : ip4_cam_assign

            localparam PER_ID = (`SA_IP4_SIZE + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign ip4_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_ip4_cam_must_match[FROM_INDEX],out_ip4_addresses[FROM_INDEX]};

        end 
    endgenerate



    //--------------------------------------------------------//
    //  Assign PORT Output values                             //
    //--------------------------------------------------------//

    //PORT Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] port_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) port_src_sel = 0;
        else port_src_sel = port_config_sel[CONFIG_SEL_WIDTH-1:CONFIG_SEL_WIDTH-AXIS_ID_WIDTH];
    end 

    reg [CONFIG_SEL_WIDTH-1:0] port_dest_sel;
    always@(*) begin
        if((AXIS_ID_WIDTH == 0 && AXIS_DEST_WIDTH == 0) || VTEP_MODE) port_dest_sel = 0;
        else if(AXIS_ID_WIDTH == 0) port_dest_sel = port_config_sel[CONFIG_SEL_WIDTH-2:0];
        else if(AXIS_DEST_WIDTH == 0) port_dest_sel = port_config_sel[CONFIG_SEL_WIDTH-1:1];
        else port_dest_sel = port_config_sel;
    end

    //PORT Config register outputs (using select signals)
    wire [`SPORT_SIZE-1:0]        src_port =         (INCLUDE_SIG_egress_ports) ? reg_egress_ports[port_src_sel] : 0;
    wire                          match_src_port =   (INCLUDE_SIG_match_src_port) ? reg_match_src_port[port_src_sel] : 0;
    wire [`DPORT_SIZE-1:0]        dest_port =        (INCLUDE_SIG_dest_ports) ? reg_dest_ports[port_dest_sel] : 0;
    wire                          match_dest_port =  (INCLUDE_SIG_match_dest_port) ? reg_match_dest_port[port_src_sel] : 0;

    assign port_config_regs = {match_dest_port,dest_port,match_src_port,src_port};

    //PORT CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : port_cam_assign

            localparam PER_ID = (`SPORT_SIZE + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign port_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_port_cam_must_match[FROM_INDEX],out_ingress_ports[FROM_INDEX]};

        end
    endgenerate



    //--------------------------------------------------------//
    //  Assign Egress Filter Output values                    //
    //--------------------------------------------------------//

    //Egress Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] egress_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) egress_src_sel = 0;
        else egress_src_sel = egress_config_sel;
    end 

    //Egress Config register outputs (using select signals)
    wire [NUM_AXIS_ID-1:0]        must_route_mask =     (INCLUDE_SIG_must_route_mask) ? reg_must_route_mask[egress_src_sel] : 0;
    wire [NUM_AXIS_ID-1:0]        cannot_route_mask =   (INCLUDE_SIG_cannot_route_mask) ? reg_cannot_route_mask[egress_src_sel] : 0;
    wire                          reroute_if_config =   (INCLUDE_SIG_reroute_if_config) ? reg_reroute_if_config : 0;
    wire [AXIS_ID_WIDTH:0]        reroute_dest =        (INCLUDE_SIG_reroute_dest) ? reg_reroute_dest : 0;

    assign egress_config_regs = {reroute_dest,reroute_if_config,cannot_route_mask,must_route_mask};



    //--------------------------------------------------------//
    //  Assign ENCAP Output values                            //
    //--------------------------------------------------------//

    //ENCAP Select signals (1)
    reg [ID_ONLY_SEL_WIDTH-1:0] encap_src_sel1;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) encap_src_sel1 = 0;
        else encap_src_sel1 = encap_config1_sel;
    end 

    //ENCAP Config register outputs (using select signals) (1)
    wire [2:0]      encap_mode_1 = (INCLUDE_SIG_encap_mode) ? reg_encap_mode[encap_src_sel1] : 0;

    assign encap_config1_regs = encap_mode_1;


    //ENCAP Select signals (2)
    reg [ID_ONLY_SEL_WIDTH-1:0] encap_src_sel2;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) encap_src_sel2 = 0;
        else encap_src_sel2 = encap_config2_sel[CONFIG_SEL_WIDTH-1:CONFIG_SEL_WIDTH-AXIS_ID_WIDTH];
    end 

    reg [CONFIG_SEL_WIDTH-1:0] encap_dest_sel2;
    always@(*) begin
        if((AXIS_ID_WIDTH == 0 && AXIS_DEST_WIDTH == 0) || VTEP_MODE) encap_dest_sel2 = 0;
        else if(AXIS_ID_WIDTH == 0) encap_dest_sel2 = encap_config2_sel[CONFIG_SEL_WIDTH-2:0];
        else if(AXIS_DEST_WIDTH == 0) encap_dest_sel2 = encap_config2_sel[CONFIG_SEL_WIDTH-1:1];
        else encap_dest_sel2 = encap_config2_sel;
    end

    //ENCAP Config register outputs (using select signals)(2)
    wire [2:0]      encap_mode_2 =            (INCLUDE_SIG_encap_mode) ? reg_encap_mode[encap_src_sel2] : 0;
    wire [47:0]     mac_src_address_encap =   out_mac_addresses[encap_src_sel2];
    wire [47:0]     mac_dest_address_encap =  (INCLUDE_SIG_mac_dest_addresses) ? reg_mac_dest_addresses[encap_dest_sel2] : 0;
    wire            insert_vlan_tag =         (INCLUDE_SIG_insert_vlan_tag) ? reg_insert_vlan_tag[encap_src_sel2] : 0;
    wire [15:0]     vlan_field_encap =        out_vlan_fields[encap_src_sel2];
    wire [5:0]      ip4_dhsp =                (INCLUDE_SIG_ip4_dhsp) ? reg_ip4_dhsp[encap_src_sel2] : 0;
    wire [7:0]      ip4_ttl =                 (INCLUDE_SIG_ip4_ttl) ? reg_ip4_ttl[encap_src_sel2] : 0;
    wire [7:0]      ip4_protocol =            (INCLUDE_SIG_ip4_protocol) ? reg_ip4_protocol[encap_src_sel2] : 0;
    wire [15:0]     ip4_partial_checksum =    (INCLUDE_SIG_ip4_partial_checksum) ? reg_ip4_partial_checksum[encap_dest_sel2] : 0;
    wire [31:0]     ip4_src_address_encap =   out_ip4_addresses[encap_src_sel2];
    wire [31:0]     ip4_dest_address_encap =  (INCLUDE_SIG_ip4_dest_addresses) ? reg_ip4_dest_addresses[encap_dest_sel2] : 0;
    wire [15:0]     udp_src_port_encap =      (INCLUDE_SIG_egress_ports) ? reg_egress_ports[encap_src_sel2] : 0;
    wire [15:0]     udp_dest_port_encap =     (INCLUDE_SIG_dest_ports) ? reg_dest_ports[encap_dest_sel2] : 0;
    wire [15:0]     udp_partial_checksum =    (INCLUDE_SIG_udp_partial_checksum) ? reg_udp_partial_checksum[encap_dest_sel2] : 0;
    wire            include_udp_checksum =    (INCLUDE_SIG_include_udp_checksum) ? reg_include_udp_checksum[encap_src_sel2] : 0;
    wire [23:0]     virt_vsid =               out_vsids[encap_src_sel2];

    assign encap_config2_regs =
        {virt_vsid,include_udp_checksum,udp_partial_checksum,
         udp_dest_port_encap,udp_src_port_encap,ip4_dest_address_encap,ip4_src_address_encap,
         ip4_partial_checksum,ip4_protocol,ip4_ttl,ip4_dhsp,vlan_field_encap,
         insert_vlan_tag,mac_dest_address_encap,mac_src_address_encap,encap_mode_2};



    //--------------------------------------------------------//
    //  Assign Tagger Output values                           //
    //--------------------------------------------------------//

    //Tagger Select signals
    reg [ID_ONLY_SEL_WIDTH-1:0] tag_src_sel;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) tag_src_sel = 0;
        else tag_src_sel = tag_config_sel;
    end 

    //Tagger Config register outputs (using select signals)
    wire [MAX_TAG_SIZE_BITS-1:0]  tag =         out_custom_tags[tag_src_sel];
    wire [NUM_TAG_SIZES_LOG2-1:0] tag_mode =    (INCLUDE_SIG_tag_mode) ? reg_tag_mode[tag_src_sel] : 0;

    assign tag_config_regs = {tag_mode,tag};



    //--------------------------------------------------------//
    //  Assign Custom Tag Output values                       //
    //--------------------------------------------------------//

    //Custom Tag Config register outputs (using select signals)
    wire [`ET_SIZE-1:0] expected_etype = (INCLUDE_SIG_expected_etype) ? reg_expected_etype : 0;

    assign cus_tag_config_regs = expected_etype;

    //Custom Tag CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : cus_tag_cam_assign

            localparam PER_ID = ((MAX_TAG_SIZE_BITS*2) + 1);
            localparam FROM_INDEX = (VTEP_MODE) ? 0 : i;

            assign cus_tag_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_has_cus_tag[FROM_INDEX],out_custom_tag_masks[FROM_INDEX],out_custom_tags[FROM_INDEX]};

        end
    endgenerate



    //--------------------------------------------------------//
    //  Assign Detag Output values                            //
    //--------------------------------------------------------//

    //Detag Config register outputs (using select signals)
    wire [NUM_TAG_SIZES_LOG2-1:0] tag_mode2 = (INCLUDE_SIG_detag_mode) ? reg_detag_mode : 0;

    assign detag_config_regs = tag_mode2;



    //--------------------------------------------------------//
    //  Assign VSID Output values                             //
    //--------------------------------------------------------//

    //VSID Config register outputs (using select signals)
    wire   is_vxlan = (INCLUDE_SIG_is_vxlan) ? reg_is_vxlan : 0;

    assign vsid_config_regs = is_vxlan;

    //VSID CAM contents
    generate
        for(i = 0; i < NUM_AXIS_ID; i = i + 1) begin : vsid_cam_assign

            localparam PER_ID = (`VSID_SIZE + `DA_MAC_SIZE + 2);

            assign vsid_cam_values[(PER_ID*i)+:PER_ID] = 
                {out_mac_encap_cam_must_match[i],out_mac_encap_addresses[i],out_vsid_cam_must_match[i],out_vsids[i]};

        end
    endgenerate 



    //--------------------------------------------------------//
    //  Assign Ingress Output values                          //
    //--------------------------------------------------------//

    //Ingress Config register outputs (using select signals)
    wire                          reroute_if_config2 =  (INCLUDE_SIG_reroute_if_config) ? reg_reroute_if_config : 0;
    wire [AXIS_ID_WIDTH:0]        reroute_dest2 =       (INCLUDE_SIG_reroute_dest) ? reg_reroute_dest : 0;

    assign ingress_config_regs = {reroute_dest2,reroute_if_config2};



    //--------------------------------------------------------//
    //  Assign DECAP Output values                            //
    //--------------------------------------------------------//

    //DECAP Select signals (1)
    reg [ID_ONLY_SEL_WIDTH-1:0] decap_src_sel1;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) decap_src_sel1 = 0;
        else decap_src_sel1 = decap_config1_sel;
    end 

    //DECAP Config register outputs (using select signals) (1)
    wire [2:0]      encap_mode_1_decap = (INCLUDE_SIG_encap_mode) ? reg_encap_mode[decap_src_sel1] : 0;
    wire            has_vlan_tag = (INCLUDE_SIG_insert_vlan_tag) ? reg_insert_vlan_tag[decap_src_sel1] : 0;

    assign decap_config1_regs = {has_vlan_tag,encap_mode_1_decap};


    //DECAP Select signals (2)
    reg [ID_ONLY_SEL_WIDTH-1:0] decap_src_sel2;
    always@(*) begin
        if(AXIS_ID_WIDTH == 0 || VTEP_MODE) decap_src_sel2 = 0;
        else decap_src_sel2 = decap_config2_sel;
    end 

    //DECAP Config register outputs (using select signals)(2)
    wire [2:0]      encap_mode_2_decap = (INCLUDE_SIG_encap_mode) ? reg_encap_mode[decap_src_sel2] : 0;

    assign decap_config2_regs = encap_mode_2_decap;



    //--------------------------------------------------------//
    //  Parameters for register addresses in AXIL space       //
    //--------------------------------------------------------//

    //VTEP Group 1, 64-bit (VSID params in VTEP mode)
    localparam VTEP_1_FIRST_WORD = 0;
    localparam VTEP_1_LAST_WORD = (VTEP_MODE) ? NUM_VSID*2 : 0;

    localparam VTEP_1_mac_encap_addressess_OFFSET = 0;
    localparam VTEP_1_vsid_cam_must_match_OFFSET = 48;
    localparam VTEP_1_mac_encap_cam_must_match_OFFSET = 49;

    //VTEP Group 2, 64-bit (Routing in VTEP Mode)
    localparam VTEP_2_FIRST_WORD = VTEP_1_LAST_WORD;
    localparam VTEP_2_LAST_WORD = VTEP_2_FIRST_WORD + ((VTEP_MODE) ? NUM_VSID*2 : 0);

    localparam VTEP_2_must_route_mask_OFFSET = 0;

    //VTEP Group 3, 64-bit (Routing)
    localparam VTEP_3_FIRST_WORD = VTEP_2_LAST_WORD;
    localparam VTEP_3_LAST_WORD = VTEP_3_FIRST_WORD + ((VTEP_MODE) ? NUM_VSID*2 : 0);

    localparam VTEP_3_cannot_route_mask_OFFSET = 0;

    //VTEP Group 4, 64-bit (VSIDs in VTEP mode)
    localparam VTEP_4_FIRST_WORD = VTEP_3_LAST_WORD;
    localparam VTEP_4_LAST_WORD = VTEP_4_FIRST_WORD + ((VTEP_MODE) ? + NUM_VSID : 0);

    localparam VTEP_4_vsids_OFFSET = 0;




    //Group 1, 64-bit (Dest params 1)
    localparam GROUP_1_FIRST_WORD = VTEP_4_LAST_WORD;
    localparam GROUP_1_LAST_WORD = GROUP_1_FIRST_WORD + NUM_DEST*2;

    localparam GROUP_1_mac_dest_addresses_OFFSET = 0;
    localparam GROUP_1_dest_ports_OFFSET = 48;

    //Group 2, 32-bit (Dest params 2)
    localparam GROUP_2_FIRST_WORD = GROUP_1_LAST_WORD;
    localparam GROUP_2_LAST_WORD = GROUP_2_FIRST_WORD + NUM_DEST;

    localparam GROUP_2_ip4_dest_addresses_OFFSET = 0;

    //Group 3, 32-bit (Dest params 3)
    localparam GROUP_3_FIRST_WORD = GROUP_2_LAST_WORD;
    localparam GROUP_3_LAST_WORD = GROUP_3_FIRST_WORD + NUM_DEST;

    localparam GROUP_3_ip4_partial_checksum_OFFSET = 0;
    localparam GROUP_3_udp_partial_checksum_OFFSET = 16;

    //Group 4, 64-bit (MAC)
    localparam GROUP_4_FIRST_WORD = GROUP_3_LAST_WORD;
    localparam GROUP_4_LAST_WORD = GROUP_4_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_4_mac_addresses_OFFSET = 0;
    localparam GROUP_4_mac_skip_parsing_OFFSET = 48;
    localparam GROUP_4_mac_cam_must_match_OFFSET = 49;
    localparam GROUP_4_vlan_cam_must_match_OFFSET = 50;
    localparam GROUP_4_ip4_cam_must_match_OFFSET = 51;
    localparam GROUP_4_port_cam_must_match_OFFSET = 52;
    localparam GROUP_4_mac_match_src_OFFSET = 53;
    localparam GROUP_4_mac_match_dest_OFFSET = 54;
    localparam GROUP_4_vlan_match_tag_OFFSET = 55;
    localparam GROUP_4_vlan_match_pri_OFFSET = 56;
    localparam GROUP_4_ip4_match_src_OFFSET = 57;
    localparam GROUP_4_match_src_port_OFFSET = 58;
    localparam GROUP_4_match_dest_port_OFFSET = 59;

    //Group 5, 32-bit (VLAN and eType)
    localparam GROUP_5_FIRST_WORD = GROUP_4_LAST_WORD;
    localparam GROUP_5_LAST_WORD = GROUP_5_FIRST_WORD + NUM_ELSE;

    localparam GROUP_5_vlan_fields_OFFSET = 0;
    localparam GROUP_5_mac_allow_next_ctag_OFFSET = 16;
    localparam GROUP_5_etype_allow_all_OFFSET = 17;
    localparam GROUP_5_etype_allow_next_ip4_OFFSET = 18;
    localparam GROUP_5_etype_allow_next_ip6_OFFSET = 19;
    localparam GROUP_5_etype_allow_next_arp_OFFSET = 20;
    localparam GROUP_5_etype_allow_next_raw_OFFSET = 21;
    localparam GROUP_5_etype_allow_bc_OFFSET = 22;
    localparam GROUP_5_etype_allow_mc_OFFSET = 23;
    localparam GROUP_5_etype_allow_bc_arp_only_OFFSET = 24;
    localparam GROUP_5_etype_allow_mc_ip_only_OFFSET = 25;
    localparam GROUP_5_ip4_restrict_to_only_ports_OFFSET = 26;
    localparam GROUP_5_ip4_allow_public_OFFSET = 27;
    localparam GROUP_5_ip4_allow_bc_OFFSET = 28;
    localparam GROUP_5_ip4_allow_mc_OFFSET = 29;

    //Group 6, 32-bit (VSIDs, non-VTEP mode)
    localparam GROUP_6_FIRST_WORD = GROUP_5_LAST_WORD;
    localparam GROUP_6_LAST_WORD = GROUP_6_FIRST_WORD + NUM_ELSE;

    localparam GROUP_6_vsids_OFFSET = 0;

    //Group 7, 64-bit (VSID misc, non-VTEP mode)
    localparam GROUP_7_FIRST_WORD = GROUP_6_LAST_WORD;
    localparam GROUP_7_LAST_WORD = GROUP_7_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_7_mac_encap_addresses_OFFSET = 0;
    localparam GROUP_7_vsid_cam_must_match_OFFSET = 48;
    localparam GROUP_7_mac_encap_cam_must_match_OFFSET = 49;
    localparam GROUP_7_is_vxlan_OFFSET = 50;

    //Group 8, 32-bit (IP4)
    localparam GROUP_8_FIRST_WORD = GROUP_7_LAST_WORD;
    localparam GROUP_8_LAST_WORD = GROUP_8_FIRST_WORD + NUM_ELSE;

    localparam GROUP_8_ip4_addresses_OFFSET = 0;

    //Group 9, 32-bit (IP4 subnet)
    localparam GROUP_9_FIRST_WORD = GROUP_8_LAST_WORD;
    localparam GROUP_9_LAST_WORD = GROUP_9_FIRST_WORD + NUM_ELSE;

    localparam GROUP_9_ip4_subnet_masks_OFFSET = 0;

    //Group 10, 32-bit (ENCAP and TAGGING)
    localparam GROUP_10_FIRST_WORD = GROUP_9_LAST_WORD;
    localparam GROUP_10_LAST_WORD = GROUP_10_FIRST_WORD + NUM_ELSE;

    localparam GROUP_10_ip4_ttl_OFFSET = 0;
    localparam GROUP_10_ip4_protocol_OFFSET = 8;
    localparam GROUP_10_ip4_dhsp_OFFSET = 16;
    localparam GROUP_10_insert_vlan_tag_OFFSET = 22;
    localparam GROUP_10_include_udp_checksum_OFFSET = 23;
    localparam GROUP_10_encap_mode_OFFSET = 24;
    localparam GROUP_10_has_cus_tag_OFFSET = 27;
    localparam GROUP_10_tag_mode_OFFSET = 28;
    localparam GROUP_10_detag_mode_OFFSET = 30;

    //Group 11, 32-bit (Ports)
    localparam GROUP_11_FIRST_WORD = GROUP_10_LAST_WORD;
    localparam GROUP_11_LAST_WORD = GROUP_11_FIRST_WORD + NUM_ELSE;

    localparam GROUP_11_egress_ports_OFFSET = 0;   
    localparam GROUP_11_ingress_ports_OFFSET = 16;

    //Group 12, 64-bit (TAGGING)
    localparam GROUP_12_FIRST_WORD = GROUP_11_LAST_WORD;
    localparam GROUP_12_LAST_WORD = GROUP_12_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_12_custom_tags_OFFSET = 0;

    //Group 13, 64-bit (TAGGING)
    localparam GROUP_13_FIRST_WORD = GROUP_12_LAST_WORD;
    localparam GROUP_13_LAST_WORD = GROUP_13_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_13_custom_tag_masks_OFFSET = 0;

    //Group 14, 64-bit (Routing)
    localparam GROUP_14_FIRST_WORD = GROUP_13_LAST_WORD;
    localparam GROUP_14_LAST_WORD = GROUP_14_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_14_must_route_mask_OFFSET = 0;

    //Group 15, 64-bit (Routing)
    localparam GROUP_15_FIRST_WORD = GROUP_14_LAST_WORD;
    localparam GROUP_15_LAST_WORD = GROUP_15_FIRST_WORD + NUM_ELSE*2;

    localparam GROUP_15_cannot_route_mask_OFFSET = 0;

    //Group 16, 32-bit (Config eTypes)
    localparam GROUP_16_FIRST_WORD = GROUP_15_LAST_WORD;
    localparam GROUP_16_LAST_WORD = GROUP_16_FIRST_WORD + (NUM_CONFIG_ETYPES);

    localparam GROUP_16_etype_config_OFFSET = 0;
    localparam GROUP_16_reroute_dest_OFFSET = 16;

    //Group 17, 32-bit (misc)
    localparam GROUP_17_ADDR = GROUP_16_LAST_WORD;

    localparam GROUP_17_expected_etype_OFFSET = 0;
    localparam GROUP_17_reroute_if_config_OFFSET = 16;


    
    
    //--------------------------------------------------------//
    //  AXI-Lite protocol implementation                      //
    //--------------------------------------------------------//
    
    //AXI-LITE registered signals
    reg [AXIL_ADDR_WIDTH-1:0]       awaddr_reg;
    reg [AXIL_ADDR_WIDTH-1:0]       araddr_reg;
    reg [31:0]                      reg_data_out;
    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) awready <= 1'b0;
        else if (~awready && awvalid && wvalid) awready <= 1'b1;
        else awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge aclk) begin
        if (~aresetn) awaddr_reg <= 0;
        else if (~awready && awvalid && wvalid) awaddr_reg <= awaddr; 
    end
    
    //wready asserted once valid write request and data availavle
    always @(posedge aclk) begin
        if (~aresetn) wready <= 1'b0;
        else if (~wready && wvalid && awvalid) wready <= 1'b1;
        else wready <= 1'b0;
    end

    //write response logic
    always @(posedge aclk) begin
        if (~aresetn) begin
            bvalid  <= 1'b0;
            bresp   <= 2'b0;
        end else if (awready && awvalid && ~bvalid && wready && wvalid) begin
            bvalid <= 1'b1;
            bresp  <= 2'b0; // 'OKAY' response 
        end else if (bready && bvalid)  begin
            bvalid <= 1'b0; 
            bresp  <= 2'b0;
        end  
    end
    
    //arready asserted once valid read request available
    always @(posedge aclk) begin
        if (~aresetn) arready <= 1'b0;
        else if (~arready && arvalid) arready <= 1'b1;
        else arready <= 1'b0;
    end

    //Register araddr value
    always @(posedge aclk) begin
        if (~aresetn) araddr_reg  <= 32'b0;
        else if (~arready && arvalid) araddr_reg  <= araddr;
    end
    
    //Read response logic  
    always @(posedge aclk) begin
        if (~aresetn) begin
            rvalid <= 1'b0;
            rresp  <= 1'b0;
        end else if (arready && arvalid && ~rvalid) begin
            rvalid <= 1'b1;
            rresp  <= 2'b0; // 'OKAY' response
        end else if (rvalid && rready) begin
            rvalid <= 1'b0;
            rresp  <= 2'b0;
        end                
    end

    //Read and write enables
    wire slv_reg_wren = wready && wvalid && awready && awvalid;
    wire slv_reg_rden = arready & arvalid & ~rvalid;

    //register the output rdata
    always @(posedge aclk) begin
        if (~aresetn) rdata  <= 0;
        else if (slv_reg_rden) rdata <= reg_data_out;
    end



    //--------------------------------------------------------//
    //  Write Functionality                                   //
    //--------------------------------------------------------//
    
    //Segment address signal
    localparam ADDR_LSB = 2;
    localparam ADDR_WIDTH_ALIGNED = AXIL_ADDR_WIDTH - ADDR_LSB;
    localparam VSID_SEL_WIDTH = (NUM_VSID > 1) ? $clog2(NUM_VSID) : 1;
    localparam DEST_SEL_WIDTH = (NUM_DEST > 1) ? $clog2(NUM_DEST) : 1;
    localparam ELSE_SEL_WIDTH = (NUM_ELSE > 1) ? $clog2(NUM_ELSE) : 1;
    localparam NCONFIG_SEL_WIDTH = (NUM_CONFIG_ETYPES > 1) ? $clog2(NUM_CONFIG_ETYPES) : 1;
    localparam MASK0_ASSIGN_BITS = (NUM_AXIS_ID > 32) ? 32 : NUM_AXIS_ID;

    wire [ADDR_WIDTH_ALIGNED-1:0]   wr_addr = awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    
    wire [VSID_SEL_WIDTH-1:0]       wr_vsid_sel_32 = (NUM_VSID > 1) ? awaddr_reg[2+:VSID_SEL_WIDTH] : 0;
    wire [VSID_SEL_WIDTH-1:0]       wr_vsid_sel_64 = (NUM_VSID > 1) ? awaddr_reg[3+:VSID_SEL_WIDTH] : 0;

    wire [DEST_SEL_WIDTH-1:0]       wr_dest_sel_32 = (NUM_DEST > 1) ? awaddr_reg[2+:DEST_SEL_WIDTH] : 0;
    wire [DEST_SEL_WIDTH-1:0]       wr_dest_sel_64 = (NUM_DEST > 1) ? awaddr_reg[3+:DEST_SEL_WIDTH] : 0;

    wire [ELSE_SEL_WIDTH-1:0]       wr_else_sel_32 = (NUM_ELSE > 1) ? awaddr_reg[2+:ELSE_SEL_WIDTH] : 0;
    wire [ELSE_SEL_WIDTH-1:0]       wr_else_sel_64 = (NUM_ELSE > 1) ? awaddr_reg[3+:ELSE_SEL_WIDTH] : 0;

    wire [NCONFIG_SEL_WIDTH-1:0]    wr_config_sel = (NUM_CONFIG_ETYPES > 1) ? awaddr_reg[2+:NCONFIG_SEL_WIDTH] : 0;

    //Write to the registers/RAMs
    //NOTE - ignores wstrb 
    integer k;
    always @(posedge aclk) begin

        if(~aresetn) begin

            //Reset all registers (not BRAMs)
            for(k = 0; k < NUM_ELSE; k = k + 1) begin
                reg_mac_cam_must_match[k] <= 0;
                reg_mac_addresses[k] <= 0;
                reg_vlan_cam_must_match[k] <= 0;
                reg_vlan_fields[k] <= 0;
                reg_etype_allow_next_raw[k] <= 0;
                reg_etype_allow_next_arp[k] <= 0;
                reg_etype_allow_next_ip6[k] <= 0;
                reg_etype_allow_next_ip4[k] <= 0;
                reg_etype_allow_all[k] <= 0;
                reg_ip4_cam_must_match[k] <= 0;
                reg_ip4_addresses[k] <= 0;
                reg_port_cam_must_match[k] <= 0;
                reg_ingress_ports[k] <= 0;
                reg_has_cus_tag[k] <= 0;
                reg_custom_tag_masks[k] <= 0;
                reg_custom_tags[k] <= 0;
            end 

            for(k = 0; k < NUM_VSID; k = k + 1) begin
                reg_mac_encap_cam_must_match[k] <= 0;
                reg_mac_encap_addresses[k] <= 0;
                reg_vsid_cam_must_match[k] <= 0;
                reg_vsids[k] <= 0;
            end

            for(k = 0; k < NUM_CONFIG_ETYPES; k = k + 1) begin
                reg_etype_config[k] <= 0;
            end 
        
        end else if(slv_reg_wren) begin

            //Check for group regions
            if(wr_addr >= VTEP_1_FIRST_WORD && wr_addr < VTEP_1_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_mac_encap_addresses) 
                        reg_mac_encap_addresses[wr_vsid_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_mac_encap_addresses) 
                        reg_mac_encap_addresses[wr_vsid_sel_64][47:32] <= wdata[15:0];

                    if(INCLUDE_SIG_vsid_cam_must_match)
                        reg_vsid_cam_must_match[wr_vsid_sel_64]
                            <= wdata[(VTEP_1_vsid_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_mac_encap_cam_must_match)
                        reg_mac_encap_cam_must_match[wr_vsid_sel_64]
                            <= wdata[(VTEP_1_mac_encap_cam_must_match_OFFSET-32)+:1];

                end

            end 
            else if(wr_addr >= VTEP_2_FIRST_WORD && wr_addr < VTEP_2_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_must_route_mask) 
                        reg_must_route_mask[wr_vsid_sel_64][MASK0_ASSIGN_BITS-1:0] <= wdata;

                end else if(NUM_AXIS_ID > 32) begin

                    if(INCLUDE_SIG_must_route_mask) 
                        reg_must_route_mask[wr_vsid_sel_64][NUM_AXIS_ID-1:32] <= wdata;

                end

            end
            else if(wr_addr >= VTEP_3_FIRST_WORD && wr_addr < VTEP_3_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_cannot_route_mask) 
                        reg_cannot_route_mask[wr_vsid_sel_64][MASK0_ASSIGN_BITS-1:0] <= wdata;

                end else if(NUM_AXIS_ID > 32) begin

                    if(INCLUDE_SIG_cannot_route_mask) 
                        reg_cannot_route_mask[wr_vsid_sel_64][NUM_AXIS_ID-1:32] <= wdata;

                end

            end
            else if(wr_addr >= VTEP_4_FIRST_WORD && wr_addr < VTEP_4_LAST_WORD) begin

                if(INCLUDE_SIG_vsids) 
                    reg_vsids[wr_vsid_sel_32][31:0] <= wdata;

            end
            else if(wr_addr >= GROUP_1_FIRST_WORD && wr_addr < GROUP_1_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_mac_dest_addresses) 
                        reg_mac_dest_addresses[wr_dest_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_mac_dest_addresses) 
                        reg_mac_dest_addresses[wr_dest_sel_64][47:32] <= wdata[15:0];

                    if(INCLUDE_SIG_dest_ports)
                        reg_dest_ports[wr_dest_sel_64]
                            <= wdata[(GROUP_1_dest_ports_OFFSET-32)+:`DPORT_SIZE];

                end

            end
            else if(wr_addr >= GROUP_2_FIRST_WORD && wr_addr < GROUP_2_LAST_WORD) begin

                if(INCLUDE_SIG_ip4_dest_addresses) 
                    reg_ip4_dest_addresses[wr_dest_sel_32] <= wdata;

            end
            else if(wr_addr >= GROUP_3_FIRST_WORD && wr_addr < GROUP_3_LAST_WORD) begin

                if(INCLUDE_SIG_ip4_partial_checksum) 
                    reg_ip4_partial_checksum[wr_dest_sel_32] 
                        <= wdata[GROUP_3_ip4_partial_checksum_OFFSET+:16];

                if(INCLUDE_SIG_udp_partial_checksum) 
                    reg_udp_partial_checksum[wr_dest_sel_32] 
                        <= wdata[GROUP_3_udp_partial_checksum_OFFSET+:16];

            end
            else if(wr_addr >= GROUP_4_FIRST_WORD && wr_addr < GROUP_4_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_mac_addresses) 
                        reg_mac_addresses[wr_else_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_mac_addresses) 
                        reg_mac_addresses[wr_else_sel_64][47:32] <= wdata[15:0];

                    if(INCLUDE_SIG_mac_skip_parsing)
                        reg_mac_skip_parsing[wr_else_sel_64]
                            <= wdata[(GROUP_4_mac_skip_parsing_OFFSET-32)+:1];

                    if(INCLUDE_SIG_mac_cam_must_match)
                        reg_mac_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_4_mac_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_vlan_cam_must_match)
                        reg_vlan_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_4_vlan_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_ip4_cam_must_match)
                        reg_ip4_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_4_ip4_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_port_cam_must_match)
                        reg_port_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_4_port_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_mac_match_src)
                        reg_mac_match_src[wr_else_sel_64]
                            <= wdata[(GROUP_4_mac_match_src_OFFSET-32)+:1];

                    if(INCLUDE_SIG_mac_match_dest)
                        reg_mac_match_dest[wr_else_sel_64]
                            <= wdata[(GROUP_4_mac_match_dest_OFFSET-32)+:1];

                    if(INCLUDE_SIG_vlan_match_tag)
                        reg_vlan_match_tag[wr_else_sel_64]
                            <= wdata[(GROUP_4_vlan_match_tag_OFFSET-32)+:1];

                    if(INCLUDE_SIG_vlan_match_pri)
                        reg_vlan_match_pri[wr_else_sel_64]
                            <= wdata[(GROUP_4_vlan_match_pri_OFFSET-32)+:1];

                    if(INCLUDE_SIG_ip4_match_src)
                        reg_ip4_match_src[wr_else_sel_64]
                            <= wdata[(GROUP_4_ip4_match_src_OFFSET-32)+:1];

                    if(INCLUDE_SIG_match_src_port)
                        reg_match_src_port[wr_else_sel_64]
                            <= wdata[(GROUP_4_match_src_port_OFFSET-32)+:1];

                    if(INCLUDE_SIG_match_dest_port)
                        reg_match_dest_port[wr_else_sel_64]
                            <= wdata[(GROUP_4_match_dest_port_OFFSET-32)+:1];

                end

            end
            else if(wr_addr >= GROUP_5_FIRST_WORD && wr_addr < GROUP_5_LAST_WORD) begin

                if(INCLUDE_SIG_vlan_fields)
                    reg_vlan_fields[wr_else_sel_32]
                        <= wdata[GROUP_5_vlan_fields_OFFSET+:`VID_SIZE];

                if(INCLUDE_SIG_mac_allow_next_ctag)
                    reg_mac_allow_next_ctag[wr_else_sel_32]
                        <= wdata[GROUP_5_mac_allow_next_ctag_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_all)
                    reg_etype_allow_all[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_all_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_next_ip4)
                    reg_etype_allow_next_ip4[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_next_ip4_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_next_ip6)
                    reg_etype_allow_next_ip6[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_next_ip6_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_next_arp)
                    reg_etype_allow_next_arp[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_next_arp_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_next_raw)
                    reg_etype_allow_next_raw[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_next_raw_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_bc)
                    reg_etype_allow_bc[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_bc_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_mc)
                    reg_etype_allow_mc[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_mc_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_bc_arp_only)
                    reg_etype_allow_bc_arp_only[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_bc_arp_only_OFFSET+:1];

                if(INCLUDE_SIG_etype_allow_mc_ip_only)
                    reg_etype_allow_mc_ip_only[wr_else_sel_32]
                        <= wdata[GROUP_5_etype_allow_mc_ip_only_OFFSET+:1];

                if(INCLUDE_SIG_ip4_restrict_to_only_ports)
                    reg_ip4_restrict_to_only_ports[wr_else_sel_32]
                        <= wdata[GROUP_5_ip4_restrict_to_only_ports_OFFSET+:1];

                if(INCLUDE_SIG_ip4_allow_public)
                    reg_ip4_allow_public[wr_else_sel_32]
                        <= wdata[GROUP_5_ip4_allow_public_OFFSET+:1];

                if(INCLUDE_SIG_ip4_allow_bc)
                    reg_ip4_allow_bc[wr_else_sel_32]
                        <= wdata[GROUP_5_ip4_allow_bc_OFFSET+:1];

                if(INCLUDE_SIG_ip4_allow_mc)
                    reg_ip4_allow_mc[wr_else_sel_32]
                        <= wdata[GROUP_5_ip4_allow_mc_OFFSET+:1];

            end
            else if(wr_addr >= GROUP_6_FIRST_WORD && wr_addr < GROUP_6_LAST_WORD) begin

                if(INCLUDE_SIG_vsids && !VTEP_MODE) 
                    reg_vsids[wr_else_sel_32][31:0] <= wdata;

            end
            else if(wr_addr >= GROUP_7_FIRST_WORD && wr_addr < GROUP_7_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_mac_encap_addresses && !VTEP_MODE) 
                        reg_mac_encap_addresses[wr_else_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_mac_encap_addresses && !VTEP_MODE) 
                        reg_mac_encap_addresses[wr_else_sel_64][47:32] <= wdata[15:0];

                    if(INCLUDE_SIG_vsid_cam_must_match && !VTEP_MODE)
                        reg_vsid_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_7_vsid_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_mac_encap_cam_must_match && !VTEP_MODE)
                        reg_mac_encap_cam_must_match[wr_else_sel_64]
                            <= wdata[(GROUP_7_mac_encap_cam_must_match_OFFSET-32)+:1];

                    if(INCLUDE_SIG_is_vxlan)
                        reg_is_vxlan <= wdata[(GROUP_7_is_vxlan_OFFSET-32)+:1];

                end

            end
            else if(wr_addr >= GROUP_8_FIRST_WORD && wr_addr < GROUP_8_LAST_WORD) begin

                if(INCLUDE_SIG_ip4_addresses) 
                    reg_ip4_addresses[wr_else_sel_32] <= wdata;

            end
            else if(wr_addr >= GROUP_9_FIRST_WORD && wr_addr < GROUP_9_LAST_WORD) begin

                if(INCLUDE_SIG_ip4_subnet_masks) 
                    reg_ip4_subnet_masks[wr_else_sel_32] <= wdata;

            end
            else if(wr_addr >= GROUP_10_FIRST_WORD && wr_addr < GROUP_10_LAST_WORD) begin

                if(INCLUDE_SIG_ip4_ttl)
                    reg_ip4_ttl[wr_else_sel_32]
                        <= wdata[GROUP_10_ip4_ttl_OFFSET+:8];

                if(INCLUDE_SIG_ip4_protocol)
                    reg_ip4_protocol[wr_else_sel_32]
                        <= wdata[GROUP_10_ip4_protocol_OFFSET+:8];

                if(INCLUDE_SIG_ip4_dhsp)
                    reg_ip4_dhsp[wr_else_sel_32]
                        <= wdata[GROUP_10_ip4_dhsp_OFFSET+:6];

                if(INCLUDE_SIG_insert_vlan_tag)
                    reg_insert_vlan_tag[wr_else_sel_32]
                        <= wdata[GROUP_10_insert_vlan_tag_OFFSET+:1];

                if(INCLUDE_SIG_include_udp_checksum)
                    reg_include_udp_checksum[wr_else_sel_32]
                        <= wdata[GROUP_10_include_udp_checksum_OFFSET+:1];

                if(INCLUDE_SIG_encap_mode)
                    reg_encap_mode[wr_else_sel_32]
                        <= wdata[GROUP_10_encap_mode_OFFSET+:3];

                if(INCLUDE_SIG_has_cus_tag)
                    reg_has_cus_tag[wr_else_sel_32]
                        <= wdata[GROUP_10_has_cus_tag_OFFSET+:1];

                if(INCLUDE_SIG_tag_mode)
                    reg_tag_mode[wr_else_sel_32]
                        <= wdata[GROUP_10_tag_mode_OFFSET+:NUM_TAG_SIZES_LOG2];

                if(INCLUDE_SIG_detag_mode)
                    reg_detag_mode <= wdata[GROUP_10_detag_mode_OFFSET+:NUM_TAG_SIZES_LOG2];

            end
            else if(wr_addr >= GROUP_11_FIRST_WORD && wr_addr < GROUP_11_LAST_WORD) begin

                if(INCLUDE_SIG_egress_ports)
                    reg_egress_ports[wr_else_sel_32]
                        <= wdata[GROUP_11_egress_ports_OFFSET+:`SPORT_SIZE];

                if(INCLUDE_SIG_ingress_ports)
                    reg_ingress_ports[wr_else_sel_32]
                        <= wdata[GROUP_11_ingress_ports_OFFSET+:`SPORT_SIZE];

            end
            else if(wr_addr >= GROUP_12_FIRST_WORD && wr_addr < GROUP_12_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_custom_tags) 
                        reg_custom_tags[wr_else_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_custom_tags && MAX_TAG_SIZE_BITS > 32) 
                        reg_custom_tags[wr_else_sel_64][MAX_TAG_SIZE_BITS-1:32] 
                            <= wdata[0+:(MAX_TAG_SIZE_BITS-32)];

                end

            end
            else if(wr_addr >= GROUP_13_FIRST_WORD && wr_addr < GROUP_13_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_custom_tag_masks) 
                        reg_custom_tag_masks[wr_else_sel_64][31:0] <= wdata;

                end else begin

                    if(INCLUDE_SIG_custom_tag_masks && MAX_TAG_SIZE_BITS > 32) 
                        reg_custom_tag_masks[wr_else_sel_64][MAX_TAG_SIZE_BITS-1:32] 
                            <= wdata[0+:(MAX_TAG_SIZE_BITS-32)];

                end

            end
            else if(wr_addr >= GROUP_14_FIRST_WORD && wr_addr < GROUP_14_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_must_route_mask && !VTEP_MODE) 
                        reg_must_route_mask[wr_else_sel_64][MASK0_ASSIGN_BITS-1:0] <= wdata;

                end else if(NUM_AXIS_ID > 32) begin

                    if(INCLUDE_SIG_must_route_mask && !VTEP_MODE) 
                        reg_must_route_mask[wr_else_sel_64][NUM_AXIS_ID-1:32] <= wdata;

                end

            end
            else if(wr_addr >= GROUP_15_FIRST_WORD && wr_addr < GROUP_15_LAST_WORD) begin

                if(wr_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                    if(INCLUDE_SIG_cannot_route_mask && !VTEP_MODE) 
                        reg_cannot_route_mask[wr_else_sel_64][MASK0_ASSIGN_BITS-1:0] <= wdata;

                end else if(NUM_AXIS_ID > 32) begin

                    if(INCLUDE_SIG_cannot_route_mask && !VTEP_MODE) 
                        reg_cannot_route_mask[wr_else_sel_64][NUM_AXIS_ID-1:32] <= wdata;

                end

            end
            else if(wr_addr >= GROUP_16_FIRST_WORD && wr_addr < GROUP_16_LAST_WORD) begin

                if(INCLUDE_SIG_etype_config)
                    reg_etype_config[wr_config_sel]
                        <= wdata[GROUP_16_etype_config_OFFSET+:`ET_SIZE];

                if(INCLUDE_SIG_reroute_dest)
                    reg_reroute_dest <= wdata[GROUP_16_reroute_dest_OFFSET+:(AXIS_ID_WIDTH+1)];

            end
            else if(wr_addr == GROUP_17_ADDR) begin

                if(INCLUDE_SIG_expected_etype)
                    reg_expected_etype <= wdata[GROUP_17_expected_etype_OFFSET+:`ET_SIZE];

                if(INCLUDE_SIG_reroute_if_config)
                    reg_reroute_if_config <= wdata[GROUP_17_reroute_if_config_OFFSET+:1];

            end

        end

    end 


    
    //--------------------------------------------------------//
    //  Read Functionality                                    //
    //--------------------------------------------------------//

    //Segment address signal
    wire [ADDR_WIDTH_ALIGNED-1:0]   rd_addr = araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    
    wire [VSID_SEL_WIDTH-1:0]       rd_vsid_sel_32 = (NUM_VSID > 1) ? araddr_reg[2+:VSID_SEL_WIDTH] : 0;
    wire [VSID_SEL_WIDTH-1:0]       rd_vsid_sel_64 = (NUM_VSID > 1) ? araddr_reg[3+:VSID_SEL_WIDTH] : 0;

    wire [DEST_SEL_WIDTH-1:0]       rd_dest_sel_32 = (NUM_DEST > 1) ? araddr_reg[2+:DEST_SEL_WIDTH] : 0;
    wire [DEST_SEL_WIDTH-1:0]       rd_dest_sel_64 = (NUM_DEST > 1) ? araddr_reg[3+:DEST_SEL_WIDTH] : 0;

    wire [ELSE_SEL_WIDTH-1:0]       rd_else_sel_32 = (NUM_ELSE > 1) ? araddr_reg[2+:ELSE_SEL_WIDTH] : 0;
    wire [ELSE_SEL_WIDTH-1:0]       rd_else_sel_64 = (NUM_ELSE > 1) ? araddr_reg[3+:ELSE_SEL_WIDTH] : 0;

    wire [NCONFIG_SEL_WIDTH-1:0]    rd_config_sel = (NUM_CONFIG_ETYPES > 1) ? araddr_reg[2+:NCONFIG_SEL_WIDTH] : 0;


    //Read from the registers/RAMs
    always @(*) begin

        //Defualt assignment
        reg_data_out = 0;

        //Check for group regions
        if(rd_addr >= VTEP_1_FIRST_WORD && rd_addr < VTEP_1_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_mac_encap_addresses) 
                    reg_data_out = reg_mac_encap_addresses[rd_vsid_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_mac_encap_addresses) 
                    reg_data_out[15:0] = reg_mac_encap_addresses[rd_vsid_sel_64][47:32];

                if(INCLUDE_SIG_vsid_cam_must_match)
                    reg_data_out[(VTEP_1_vsid_cam_must_match_OFFSET-32)+:1] 
                        = reg_vsid_cam_must_match[rd_vsid_sel_64];

                if(INCLUDE_SIG_mac_encap_cam_must_match)
                    reg_data_out[(VTEP_1_mac_encap_cam_must_match_OFFSET-32)+:1]
                        = reg_mac_encap_cam_must_match[rd_vsid_sel_64];

            end

        end
        else if(rd_addr >= GROUP_15_FIRST_WORD && rd_addr < GROUP_15_LAST_WORD) begin

            

        end
        else if(rd_addr >= VTEP_2_FIRST_WORD && rd_addr < VTEP_2_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_must_route_mask) 
                    reg_data_out = {   {(32-MASK0_ASSIGN_BITS){1'b0}},
                                        reg_must_route_mask[rd_vsid_sel_64][MASK0_ASSIGN_BITS-1:0]};

            end else if(NUM_AXIS_ID > 32) begin

                if(INCLUDE_SIG_must_route_mask) 
                    reg_data_out = {   {(64-NUM_AXIS_ID){1'b0}},
                                        reg_must_route_mask[rd_vsid_sel_64][NUM_AXIS_ID-1:32]};

            end

        end 
        else if(rd_addr >= VTEP_3_FIRST_WORD && rd_addr < VTEP_3_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_cannot_route_mask) 
                    reg_data_out = {   {(32-MASK0_ASSIGN_BITS){1'b0}},
                                        reg_cannot_route_mask[rd_vsid_sel_64][MASK0_ASSIGN_BITS-1:0]};
                    
            end else if(NUM_AXIS_ID > 32) begin

                if(INCLUDE_SIG_cannot_route_mask) 
                    reg_data_out = {   {(64-NUM_AXIS_ID){1'b0}},
                                        reg_cannot_route_mask[rd_vsid_sel_64][NUM_AXIS_ID-1:32]};

            end

        end
        else if(rd_addr >= VTEP_4_FIRST_WORD && rd_addr < VTEP_4_LAST_WORD) begin

            if(INCLUDE_SIG_vsids) 
                reg_data_out = reg_vsids[rd_vsid_sel_32][31:0];

        end
        else if(rd_addr >= GROUP_1_FIRST_WORD && rd_addr < GROUP_1_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_mac_dest_addresses) 
                    reg_data_out = reg_mac_dest_addresses[rd_dest_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_mac_dest_addresses) 
                    reg_data_out[15:0] = reg_mac_dest_addresses[rd_dest_sel_64][47:32];

                if(INCLUDE_SIG_dest_ports)
                    reg_data_out[(GROUP_1_dest_ports_OFFSET-32)+:`DPORT_SIZE] 
                        = reg_dest_ports[rd_dest_sel_64];

            end

        end
        else if(rd_addr >= GROUP_2_FIRST_WORD && rd_addr < GROUP_2_LAST_WORD) begin

            if(INCLUDE_SIG_ip4_dest_addresses) 
                reg_data_out = reg_ip4_dest_addresses[rd_dest_sel_32];

        end
        else if(rd_addr >= GROUP_3_FIRST_WORD && rd_addr < GROUP_3_LAST_WORD) begin

            if(INCLUDE_SIG_ip4_partial_checksum) 
                reg_data_out[GROUP_3_ip4_partial_checksum_OFFSET+:16] 
                    = reg_ip4_partial_checksum[rd_dest_sel_32];

            if(INCLUDE_SIG_udp_partial_checksum) 
                reg_data_out[GROUP_3_udp_partial_checksum_OFFSET+:16] 
                    = reg_udp_partial_checksum[rd_dest_sel_32];

        end
        else if(rd_addr >= GROUP_4_FIRST_WORD && rd_addr < GROUP_4_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_mac_addresses) 
                    reg_data_out = reg_mac_addresses[rd_else_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_mac_addresses) 
                    reg_data_out[15:0] = reg_mac_addresses[rd_else_sel_64][47:32];

                if(INCLUDE_SIG_mac_skip_parsing)
                    reg_data_out[(GROUP_4_mac_skip_parsing_OFFSET-32)+:1]
                        = reg_mac_skip_parsing[rd_else_sel_64];

                if(INCLUDE_SIG_mac_cam_must_match)
                    reg_data_out[(GROUP_4_mac_cam_must_match_OFFSET-32)+:1]
                        = reg_mac_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_vlan_cam_must_match)
                    reg_data_out[(GROUP_4_vlan_cam_must_match_OFFSET-32)+:1]
                        = reg_vlan_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_ip4_cam_must_match)
                    reg_data_out[(GROUP_4_ip4_cam_must_match_OFFSET-32)+:1]
                        = reg_ip4_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_port_cam_must_match)
                    reg_data_out[(GROUP_4_port_cam_must_match_OFFSET-32)+:1]
                        = reg_port_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_mac_match_src)
                    reg_data_out[(GROUP_4_mac_match_src_OFFSET-32)+:1]
                        = reg_mac_match_src[rd_else_sel_64];

                if(INCLUDE_SIG_mac_match_dest)
                    reg_data_out[(GROUP_4_mac_match_dest_OFFSET-32)+:1]
                        = reg_mac_match_dest[rd_else_sel_64];

                if(INCLUDE_SIG_vlan_match_tag)
                    reg_data_out[(GROUP_4_vlan_match_tag_OFFSET-32)+:1]
                        = reg_vlan_match_tag[rd_else_sel_64];

                if(INCLUDE_SIG_vlan_match_pri)
                    reg_data_out[(GROUP_4_vlan_match_pri_OFFSET-32)+:1]
                        = reg_vlan_match_pri[rd_else_sel_64];

                if(INCLUDE_SIG_ip4_match_src)
                    reg_data_out[(GROUP_4_ip4_match_src_OFFSET-32)+:1]
                        = reg_ip4_match_src[rd_else_sel_64];

                if(INCLUDE_SIG_match_src_port)
                    reg_data_out[(GROUP_4_match_src_port_OFFSET-32)+:1]
                        = reg_match_src_port[rd_else_sel_64];

                if(INCLUDE_SIG_match_dest_port)
                    reg_data_out[(GROUP_4_match_dest_port_OFFSET-32)+:1]
                        = reg_match_dest_port[rd_else_sel_64];

            end

        end
        else if(rd_addr >= GROUP_5_FIRST_WORD && rd_addr < GROUP_5_LAST_WORD) begin

            if(INCLUDE_SIG_vlan_fields)
                reg_data_out[GROUP_5_vlan_fields_OFFSET+:`VID_SIZE] 
                    = reg_vlan_fields[rd_else_sel_32];

            if(INCLUDE_SIG_mac_allow_next_ctag)
                reg_data_out[GROUP_5_mac_allow_next_ctag_OFFSET+:1] 
                    = reg_mac_allow_next_ctag[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_all)
                reg_data_out[GROUP_5_etype_allow_all_OFFSET+:1] 
                    = reg_etype_allow_all[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_next_ip4)
                reg_data_out[GROUP_5_etype_allow_next_ip4_OFFSET+:1] 
                    = reg_etype_allow_next_ip4[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_next_ip6)
                reg_data_out[GROUP_5_etype_allow_next_ip6_OFFSET+:1] 
                    = reg_etype_allow_next_ip6[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_next_arp)
                reg_data_out[GROUP_5_etype_allow_next_arp_OFFSET+:1] 
                    = reg_etype_allow_next_arp[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_next_raw)
                reg_data_out[GROUP_5_etype_allow_next_raw_OFFSET+:1] 
                    = reg_etype_allow_next_raw[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_bc)
                reg_data_out[GROUP_5_etype_allow_bc_OFFSET+:1] 
                    = reg_etype_allow_bc[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_mc)
                reg_data_out[GROUP_5_etype_allow_mc_OFFSET+:1] 
                    = reg_etype_allow_mc[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_bc_arp_only)
                reg_data_out[GROUP_5_etype_allow_bc_arp_only_OFFSET+:1] 
                    = reg_etype_allow_bc_arp_only[rd_else_sel_32];

            if(INCLUDE_SIG_etype_allow_mc_ip_only)
                reg_data_out[GROUP_5_etype_allow_mc_ip_only_OFFSET+:1] 
                    = reg_etype_allow_mc_ip_only[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_restrict_to_only_ports)
                reg_data_out[GROUP_5_ip4_restrict_to_only_ports_OFFSET+:1] 
                    = reg_ip4_restrict_to_only_ports[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_allow_public)
                reg_data_out[GROUP_5_ip4_allow_public_OFFSET+:1] 
                    = reg_ip4_allow_public[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_allow_bc)
                reg_data_out[GROUP_5_ip4_allow_bc_OFFSET+:1] 
                    = reg_ip4_allow_bc[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_allow_mc)
                reg_data_out[GROUP_5_ip4_allow_mc_OFFSET+:1] 
                    = reg_ip4_allow_mc[rd_else_sel_32];

        end
        else if(rd_addr >= GROUP_6_FIRST_WORD && rd_addr < GROUP_6_LAST_WORD) begin

            if(INCLUDE_SIG_vsids && !VTEP_MODE) 
                reg_data_out = reg_vsids[rd_else_sel_32][31:0];

        end
        else if(rd_addr >= GROUP_7_FIRST_WORD && rd_addr < GROUP_7_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_mac_encap_addresses && !VTEP_MODE) 
                    reg_data_out = reg_mac_encap_addresses[rd_else_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_mac_encap_addresses && !VTEP_MODE) 
                    reg_data_out[15:0] = reg_mac_encap_addresses[rd_else_sel_64][47:32];

                if(INCLUDE_SIG_vsid_cam_must_match && !VTEP_MODE)
                    reg_data_out[(GROUP_7_vsid_cam_must_match_OFFSET-32)+:1] 
                        = reg_vsid_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_mac_encap_cam_must_match && !VTEP_MODE)
                    reg_data_out[(GROUP_7_mac_encap_cam_must_match_OFFSET-32)+:1] 
                        = reg_mac_encap_cam_must_match[rd_else_sel_64];

                if(INCLUDE_SIG_is_vxlan)
                    reg_data_out[(GROUP_7_is_vxlan_OFFSET-32)+:1] = reg_is_vxlan;

            end

        end
        else if(rd_addr >= GROUP_8_FIRST_WORD && rd_addr < GROUP_8_LAST_WORD) begin

            if(INCLUDE_SIG_ip4_addresses) 
                reg_data_out = reg_ip4_addresses[rd_else_sel_32];

        end
        else if(rd_addr >= GROUP_9_FIRST_WORD && rd_addr < GROUP_9_LAST_WORD) begin

            if(INCLUDE_SIG_ip4_subnet_masks) 
                reg_data_out = reg_ip4_subnet_masks[rd_else_sel_32];

        end
        else if(rd_addr >= GROUP_10_FIRST_WORD && rd_addr < GROUP_10_LAST_WORD) begin

            if(INCLUDE_SIG_ip4_ttl)
                reg_data_out[GROUP_10_ip4_ttl_OFFSET+:8]
                    = reg_ip4_ttl[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_protocol)
                reg_data_out[GROUP_10_ip4_protocol_OFFSET+:8]
                    = reg_ip4_protocol[rd_else_sel_32];

            if(INCLUDE_SIG_ip4_dhsp)
                reg_data_out[GROUP_10_ip4_dhsp_OFFSET+:6]
                    = reg_ip4_dhsp[rd_else_sel_32];

            if(INCLUDE_SIG_insert_vlan_tag)
                reg_data_out[GROUP_10_insert_vlan_tag_OFFSET+:1]
                    = reg_insert_vlan_tag[rd_else_sel_32];

            if(INCLUDE_SIG_include_udp_checksum)
                reg_data_out[GROUP_10_include_udp_checksum_OFFSET+:1]
                    = reg_include_udp_checksum[rd_else_sel_32];

            if(INCLUDE_SIG_encap_mode)
                reg_data_out[GROUP_10_encap_mode_OFFSET+:3]
                    = reg_encap_mode[rd_else_sel_32];

            if(INCLUDE_SIG_has_cus_tag)
                reg_data_out[GROUP_10_has_cus_tag_OFFSET+:1]
                    = reg_has_cus_tag[rd_else_sel_32];

            if(INCLUDE_SIG_tag_mode)
                reg_data_out[GROUP_10_tag_mode_OFFSET+:NUM_TAG_SIZES_LOG2]
                    = reg_tag_mode[rd_else_sel_32];

            if(INCLUDE_SIG_detag_mode)
                reg_data_out[GROUP_10_detag_mode_OFFSET+:NUM_TAG_SIZES_LOG2] = reg_detag_mode;

        end
        else if(rd_addr >= GROUP_11_FIRST_WORD && rd_addr < GROUP_11_LAST_WORD) begin

            if(INCLUDE_SIG_egress_ports)
                reg_data_out[GROUP_11_egress_ports_OFFSET+:`SPORT_SIZE]
                    = reg_egress_ports[rd_else_sel_32];

            if(INCLUDE_SIG_ingress_ports)
                reg_data_out[GROUP_11_ingress_ports_OFFSET+:`SPORT_SIZE]
                    = reg_ingress_ports[rd_else_sel_32];

        end
        else if(rd_addr >= GROUP_12_FIRST_WORD && rd_addr < GROUP_12_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_custom_tags) 
                    reg_data_out = reg_custom_tags[rd_else_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_custom_tags && MAX_TAG_SIZE_BITS > 32) 
                    reg_data_out[0+:(MAX_TAG_SIZE_BITS-32)]
                        = reg_custom_tags[rd_else_sel_64][MAX_TAG_SIZE_BITS-1:32];

            end

        end
        else if(rd_addr >= GROUP_13_FIRST_WORD && rd_addr < GROUP_13_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_custom_tag_masks) 
                    reg_data_out = reg_custom_tag_masks[rd_else_sel_64][31:0];

            end else begin

                if(INCLUDE_SIG_custom_tag_masks && MAX_TAG_SIZE_BITS > 32) 
                    reg_data_out[0+:(MAX_TAG_SIZE_BITS-32)] 
                        = reg_custom_tag_masks[rd_else_sel_64][MAX_TAG_SIZE_BITS-1:32];

            end

        end
        else if(rd_addr >= GROUP_14_FIRST_WORD && rd_addr < GROUP_14_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_must_route_mask && !VTEP_MODE) 
                    reg_data_out = {   {(32-MASK0_ASSIGN_BITS){1'b0}},
                                        reg_must_route_mask[rd_else_sel_64][MASK0_ASSIGN_BITS-1:0]};

            end else if(NUM_AXIS_ID > 32) begin

                if(INCLUDE_SIG_must_route_mask && !VTEP_MODE) 
                    reg_data_out = {   {(64-NUM_AXIS_ID){1'b0}},
                                        reg_must_route_mask[rd_else_sel_64][NUM_AXIS_ID-1:32]};

            end

        end
        else if(rd_addr >= GROUP_15_FIRST_WORD && rd_addr < GROUP_15_LAST_WORD) begin

            if(rd_addr[0] == 1'b0) begin //group contents spread accross 64-bit, i.e. 2 words

                if(INCLUDE_SIG_cannot_route_mask && !VTEP_MODE) 
                    reg_data_out = {   {(32-MASK0_ASSIGN_BITS){1'b0}},
                                        reg_cannot_route_mask[rd_else_sel_64][MASK0_ASSIGN_BITS-1:0]};
                    
            end else if(NUM_AXIS_ID > 32) begin

                if(INCLUDE_SIG_cannot_route_mask && !VTEP_MODE) 
                    reg_data_out = {   {(64-NUM_AXIS_ID){1'b0}},
                                        reg_cannot_route_mask[rd_else_sel_64][NUM_AXIS_ID-1:32]};

            end

        end
        else if(rd_addr >= GROUP_16_FIRST_WORD && rd_addr < GROUP_16_LAST_WORD) begin

            if(INCLUDE_SIG_etype_config)
                reg_data_out[GROUP_16_etype_config_OFFSET+:`ET_SIZE] 
                    = reg_etype_config[rd_config_sel];

            if(INCLUDE_SIG_reroute_dest)
                reg_data_out[GROUP_16_reroute_dest_OFFSET+:(AXIS_ID_WIDTH+1)] = reg_reroute_dest;

        end
        else if(rd_addr == GROUP_17_ADDR) begin

            if(INCLUDE_SIG_expected_etype)
                reg_data_out[GROUP_17_expected_etype_OFFSET+:`ET_SIZE] 
                    = reg_expected_etype;

            if(INCLUDE_SIG_reroute_if_config)
                reg_data_out[GROUP_17_reroute_if_config_OFFSET+:1] 
                    = reg_reroute_if_config;

        end

    end 
    


endmodule

`default_nettype wire