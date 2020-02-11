`timescale 1ns / 1ps
`default_nettype none

/*
App Region Wrapper

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module wraps an isolated application, with access to a 
   a network port (tx and rx) and a control slave interface.

Parameters:
   NET_AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   NET_AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction
   NET_AXIS_DEST_WIDTH - the width of all network stream AXI DEST sigals
   NET_MAX_PACKET_LENGTH - the maximum network packet length to support (for forced tlast)

   CTRL_AXI_ADDR_WIDTH - the width of the address signal on the control interface

Ports:
   axis_tx_m_* - the output axi stream for the tx direction
   axis_rx_s_* - the input axi stream for the rx direction
   axis_aclk - clock to which all of the network signals are synchronous
   axis_aresetn - active-low reset corresponding to above clock

   axi_lite_s_ctrl_* - the AXI-Lite control interface to expose control registers
   ctrl_aclk - clock to which the control signal is synchronous
   ctrl_aresetn - active-low reset corresponding to above clock
*/


module app_region
#(
    //Network AXI Stream Params
    parameter NET_AXIS_BUS_WIDTH = 64,
    parameter NET_AXIS_ID_WIDTH = 3,
    parameter NET_AXIS_DEST_WIDTH = 1,

    //Network Packet Params
    parameter NET_MAX_PACKET_LENGTH = 1522
)
(
    //Egress Input AXI stream (application regions send packets to this interface)
    output wire [NET_AXIS_BUS_WIDTH-1:0]         axis_tx_m_tdata,
    output wire [NET_AXIS_ID_WIDTH-1:0]          axis_tx_m_tid,
    output wire [NET_AXIS_DEST_WIDTH-1:0]        axis_tx_m_tdest,                                          
    output wire [(NET_AXIS_BUS_WIDTH/8)-1:0]     axis_tx_m_tkeep,
    output wire                                  axis_tx_m_tlast,
    output wire                                  axis_tx_m_tvalid,
    input wire                                   axis_tx_m_tready,

    //Ingress Output AXI stream (application regions receive packets from this interface)
    input wire [NET_AXIS_BUS_WIDTH-1:0]          axis_rx_s_tdata,
    input wire [NET_AXIS_ID_WIDTH-1:0]           axis_rx_s_tdest,
    input wire [(NET_AXIS_BUS_WIDTH/8)-1:0]      axis_rx_s_tkeep,
    input wire                                   axis_rx_s_tlast,
    input wire                                   axis_rx_s_tvalid,
    output wire                                  axis_rx_s_tready,

    //Decoupled clock
    input wire axis_aclk,
    input wire axis_aresetn,



    //AXI-Lite interface (to expose registers to control)
    //Write Address Channel  
    input wire [31:0]                       axi_lite_s_ctrl_awaddr,
    input wire                              axi_lite_s_ctrl_awvalid,
    output wire                             axi_lite_s_ctrl_awready,
    //Write Data Channel
    input wire [31:0]                       axi_lite_s_ctrl_wdata,
    input wire [3:0]                        axi_lite_s_ctrl_wstrb,
    input wire                              axi_lite_s_ctrl_wvalid,
    output wire                             axi_lite_s_ctrl_wready,
    //Write Response Channel
    output wire [1:0]                       axi_lite_s_ctrl_bresp,
    output wire                             axi_lite_s_ctrl_bvalid,
    input wire                              axi_lite_s_ctrl_bready,
    //Read Address Channel 
    input wire [31:0]                       axi_lite_s_ctrl_araddr,
    input wire                              axi_lite_s_ctrl_arvalid,
    output wire                             axi_lite_s_ctrl_arready,
    //Read Data Response Channel
    output wire [31:0]                      axi_lite_s_ctrl_rdata,
    output wire [1:0]                       axi_lite_s_ctrl_rresp,
    output wire                             axi_lite_s_ctrl_rvalid,
    input wire                              axi_lite_s_ctrl_rready,

    //Ctrl Clocking
    input wire  ctrl_aclk,
    input wire  ctrl_aresetn
);

    //--------------------------------------------------------//
    //   Application Here                                     //
    //--------------------------------------------------------//

    //Control to Network connection (output of clock conversion)
    //Write Address Channel 
    wire [31:0]                       net_lite_access_awaddr;
    wire                              net_lite_access_awvalid;
    wire                              net_lite_access_awready;
    //Write Data Channel
    wire [31:0]                       net_lite_access_wdata;
    wire [3:0]                        net_lite_access_wstrb;
    wire                              net_lite_access_wvalid;
    wire                              net_lite_access_wready;
    //Write Response Channel
    wire [1:0]                        net_lite_access_bresp;
    wire                              net_lite_access_bvalid;
    wire                              net_lite_access_bready;
    //Read Address Channel 
    wire [31:0]                       net_lite_access_araddr;
    wire                              net_lite_access_arvalid;
    wire                              net_lite_access_arready;
    //Read Data Response Channel
    wire [31:0]                       net_lite_access_rdata;
    wire [1:0]                        net_lite_access_rresp;
    wire                              net_lite_access_rvalid;
    wire                              net_lite_access_rready;

    //Clock conversion
    axi_lite_clock_cross net_access_clock_conv
    (
      .s_axi_aclk(ctrl_aclk),        // input wire s_axi_aclk
      .s_axi_aresetn(ctrl_aresetn),  // input wire s_axi_aresetn
      
      .s_axi_awaddr(axi_lite_s_ctrl_awaddr),    // input wire [19 : 0] s_axi_awaddr
      .s_axi_awprot(0),    // input wire [2 : 0] s_axi_awprot
      .s_axi_awvalid(axi_lite_s_ctrl_awvalid),  // input wire s_axi_awvalid
      .s_axi_awready(axi_lite_s_ctrl_awready),  // output wire s_axi_awready
      .s_axi_wdata(axi_lite_s_ctrl_wdata),      // input wire [31 : 0] s_axi_wdata
      .s_axi_wstrb(axi_lite_s_ctrl_wstrb),      // input wire [3 : 0] s_axi_wstrb
      .s_axi_wvalid(axi_lite_s_ctrl_wvalid),    // input wire s_axi_wvalid
      .s_axi_wready(axi_lite_s_ctrl_wready),    // output wire s_axi_wready
      .s_axi_bresp(axi_lite_s_ctrl_bresp),      // output wire [1 : 0] s_axi_bresp
      .s_axi_bvalid(axi_lite_s_ctrl_bvalid),    // output wire s_axi_bvalid
      .s_axi_bready(axi_lite_s_ctrl_bready),    // input wire s_axi_bready
      .s_axi_araddr(axi_lite_s_ctrl_araddr),    // input wire [19 : 0] s_axi_araddr
      .s_axi_arprot(0),    // input wire [2 : 0] s_axi_arprot
      .s_axi_arvalid(axi_lite_s_ctrl_arvalid),  // input wire s_axi_arvalid
      .s_axi_arready(axi_lite_s_ctrl_arready),  // output wire s_axi_arready
      .s_axi_rdata(axi_lite_s_ctrl_rdata),      // output wire [31 : 0] s_axi_rdata
      .s_axi_rresp(axi_lite_s_ctrl_rresp),      // output wire [1 : 0] s_axi_rresp
      .s_axi_rvalid(axi_lite_s_ctrl_rvalid),    // output wire s_axi_rvalid
      .s_axi_rready(axi_lite_s_ctrl_rready),    // input wire s_axi_rready
      
      .m_axi_aclk(axis_aclk),        // input wire m_axi_aclk
      .m_axi_aresetn(axis_aresetn),  // input wire m_axi_aresetn
      
      .m_axi_awaddr(net_lite_access_awaddr),    // output wire [19 : 0] m_axi_awaddr
      .m_axi_awprot( ),    // output wire [2 : 0] m_axi_awprot
      .m_axi_awvalid(net_lite_access_awvalid),  // output wire m_axi_awvalid
      .m_axi_awready(net_lite_access_awready),  // input wire m_axi_awready
      .m_axi_wdata(net_lite_access_wdata),      // output wire [31 : 0] m_axi_wdata
      .m_axi_wstrb(net_lite_access_wstrb),      // output wire [3 : 0] m_axi_wstrb
      .m_axi_wvalid(net_lite_access_wvalid),    // output wire m_axi_wvalid
      .m_axi_wready(net_lite_access_wready),    // input wire m_axi_wready
      .m_axi_bresp(net_lite_access_bresp),      // input wire [1 : 0] m_axi_bresp
      .m_axi_bvalid(net_lite_access_bvalid),    // input wire m_axi_bvalid
      .m_axi_bready(net_lite_access_bready),    // output wire m_axi_bready
      .m_axi_araddr(net_lite_access_araddr),    // output wire [19 : 0] m_axi_araddr
      .m_axi_arprot( ),    // output wire [2 : 0] m_axi_arprot
      .m_axi_arvalid(net_lite_access_arvalid),  // output wire m_axi_arvalid
      .m_axi_arready(net_lite_access_arready),  // input wire m_axi_arready
      .m_axi_rdata(net_lite_access_rdata),      // input wire [31 : 0] m_axi_rdata
      .m_axi_rresp(net_lite_access_rresp),      // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(net_lite_access_rvalid),    // input wire m_axi_rvalid
      .m_axi_rready(net_lite_access_rready)    // output wire m_axi_rready
    );

    //network application access app
    packet_loopback_app
    #(
        .AXIS_BUS_WIDTH         (NET_AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH          (NET_AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH        (NET_AXIS_DEST_WIDTH),
        .MAX_FIFO_DEPTH         (256)
    )
    (
        //Egress Output AXI stream
        .axis_out_tdata     (axis_tx_m_tdata),
        .axis_out_tid       (axis_tx_m_tid),
        .axis_out_tdest     (axis_tx_m_tdest),
        .axis_out_tkeep     (axis_tx_m_tkeep),
        .axis_out_tlast     (axis_tx_m_tlast),
        .axis_out_tvalid    (axis_tx_m_tvalid),
        .axis_out_tready    (axis_tx_m_tready),

        //Ingress Input AXI stream
        .axis_in_tdata      (axis_rx_s_tdata),
        .axis_in_tdest      (axis_rx_s_tdest),
        .axis_in_tkeep      (axis_rx_s_tkeep),
        .axis_in_tlast      (axis_rx_s_tlast),
        .axis_in_tvalid     (axis_rx_s_tvalid),
        .axis_in_tready     (axis_rx_s_tready),

        //The AXI-Lite Control Interface
        .ctrl_awaddr        (net_lite_access_awaddr),
        .ctrl_awvalid       (net_lite_access_awvalid),
        .ctrl_awready       (net_lite_access_awready),
        .ctrl_wdata         (net_lite_access_wdata),
        .ctrl_wvalid        (net_lite_access_wvalid),
        .ctrl_wready        (net_lite_access_wready),
        .ctrl_bresp         (net_lite_access_bresp),
        .ctrl_bvalid        (net_lite_access_bvalid),
        .ctrl_bready        (net_lite_access_bready),
        .ctrl_araddr        (net_lite_access_araddr),
        .ctrl_arvalid       (net_lite_access_arvalid),
        .ctrl_arready       (net_lite_access_arready),
        .ctrl_rdata         (net_lite_access_rdata),
        .ctrl_rresp         (net_lite_access_rresp),
        .ctrl_rvalid        (net_lite_access_rvalid),
        .ctrl_rready        (net_lite_access_rready),

        //Clocking
        .aclk               (axis_aclk),
        .aresetn            (axis_aresetn)
    );


endmodule

`default_nettype wire