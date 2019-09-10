`timescale 1ns / 1ps
`default_nettype none


module decap_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Packed input signals size
    localparam DECAP_TUSER_IN_WIDTH = 1,
    localparam DECAP_TUSER_OUT_WIDTH = 2,
    localparam DECAP_CONFIG1_SEL_WIDTH = EFF_ID_WIDTH,
    localparam DECAP_CONFIG1_REG_WIDTH = 3+1,
    localparam DECAP_CONFIG2_SEL_WIDTH = EFF_ID_WIDTH,
    localparam DECAP_CONFIG2_REG_WIDTH = 3,

    //Features to Implement
    parameter USE_DYNAMIC_FSM = 0,
    parameter ALLOW_NO_ENCAP = 1,
    parameter ALLOW_MAC_ENCAP = 1,
    parameter ALLOW_IP4_ENCAP = 1,
    parameter ALLOW_UDP_ENCAP = 1,
    parameter ALLOW_NVGRE_ENCAP = 1,
    parameter ALLOW_VXLAN_ENCAP = 1,
    parameter ALLOW_ENCAP_W_TAG  = 0,

    //Retiming register stages for checksum calc (to be modified until timing met)
    parameter RETIMING_STAGES_PSEUDO = 0,
    parameter RETIMING_STAGES_ENCAP = 0,
    parameter RETIMING_STAGES_CHECKSUM = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [(1)-1:0]                  axis_in_tuser, // [DECAP_TUSER_IN_WIDTH-1:0]
    input wire [AXIS_ID_WIDTH:0]          axis_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [(2)-1:0]                 axis_out_tuser,
    output wire [AXIS_ID_WIDTH:0]         axis_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (1)
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]  
                                          decap_config1_sel,
    input wire [(3+1)-1:0]                decap_config1_regs,

    //Configuration register inputs (1)
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]  
                                          decap_config2_sel,
    input wire [(3)-1:0]                  decap_config2_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//   

    //Input signal declarations
    wire has_udp_checksum = axis_in_tuser;

    //Output signal declarations
    wire    poisoned;
    wire    parsing_done;

    assign axis_out_tuser = {parsing_done,poisoned};

    //Configuration select signals (1)
    wire [EFF_ID_WIDTH-1:0]    decap_sel_id_1;
    assign decap_config1_sel = decap_sel_id_1;

    //Configuration signal declarations (1)
    wire [2:0]      encap_mode_1;
    wire            has_vlan_tag;

    assign {has_vlan_tag,encap_mode_1} = decap_config1_regs;

    //Configuration select signals (2)
    wire [EFF_ID_WIDTH-1:0]    decap_sel_id_2;
    assign decap_config2_sel = decap_sel_id_2;

    //Configuration signal declarations (1)
    wire [2:0]      encap_mode_2 = decap_config2_regs;
    


    //--------------------------------------------------------//
    //   Decap Instantiation                                  //
    //--------------------------------------------------------//

    decapsulator
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        
        .USE_DYNAMIC_FSM            (USE_DYNAMIC_FSM),
        .ALLOW_NO_ENCAP             (ALLOW_NO_ENCAP),
        .ALLOW_MAC_ENCAP            (ALLOW_MAC_ENCAP),
        .ALLOW_IP4_ENCAP            (ALLOW_IP4_ENCAP),
        .ALLOW_UDP_ENCAP            (ALLOW_UDP_ENCAP),
        .ALLOW_NVGRE_ENCAP          (ALLOW_NVGRE_ENCAP),
        .ALLOW_VXLAN_ENCAP          (ALLOW_VXLAN_ENCAP),
        .ALLOW_ENCAP_W_TAG          (ALLOW_ENCAP_W_TAG),

        .RETIMING_STAGES_PSEUDO     (RETIMING_STAGES_PSEUDO),
        .RETIMING_STAGES_ENCAP      (RETIMING_STAGES_ENCAP),
        .RETIMING_STAGES_CHECKSUM   (RETIMING_STAGES_CHECKSUM)
    )
    decap 
    (
       
	    .axis_in_tdata (axis_in_tdata),
	    .axis_in_tdest (axis_in_tdest),
	    .axis_in_tkeep (axis_in_tkeep),
	    .axis_in_tlast (axis_in_tlast),
	    .axis_in_tvalid (axis_in_tvalid),
	    .axis_in_tready (axis_in_tready),
	    
	    .axis_out_tdata (axis_out_tdata),
	    .axis_out_tdest (axis_out_tdest),
	    .axis_out_tkeep (axis_out_tkeep),
	    .axis_out_tlast (axis_out_tlast),
	    .axis_out_tvalid (axis_out_tvalid),
	    .axis_out_tready (axis_out_tready),

	    .has_udp_checksum (has_udp_checksum),

	    .poisoned (poisoned),
	    .parsing_done (parsing_done),

	    .decap_sel_id_1 (decap_sel_id_1),

	    .encap_mode_1 (encap_mode_1),
	    .has_vlan_tag (has_vlan_tag),

	    .decap_sel_id_2 (decap_sel_id_2),

	    .encap_mode_2 (encap_mode_2),
	    
	    .aclk (aclk),
    	.aresetn (aresetn)
    );



endmodule

`default_nettype wire