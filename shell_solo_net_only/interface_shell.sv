`timescale 1ns / 1ps
`default_nettype none

/*
Shell Wrapper needed per Application Region (for network, and control)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module wraps all of the isolation cores needed for a single 
   application region (i.e. PR region). Note, zero widths for any of 
   the signals is not supported.

Parameters:
   NET_AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   NET_AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction
   NET_AXIS_DEST_WIDTH - the width of all network stream AXI DEST sigals
   NET_MAX_PACKET_LENGTH - the maximum network packet length to support (for forced tlast)
   NET_INCLUDE_BW_SHAPER - binary, whether or not to include a bandwidth shaper for tx packets, for network interface
   NET_DISALLOW_INGR_BACKPRESSURE - binary, whether the rx port is allowed to assert backpressure, for network interface (the rx_tready overrided if enabled)
   NET_DISALLOW_INVALID_MID_PACKET_EGR - binary, whether to expect (and enforce) a continuous stream of flits for tx, for network interface
   NET_INCLUDE_TIMEOUT_ERROR_INGR - binary, whether to check for timeouts on rx, for network interface (useless if rx channel cannot assert backpressure)
   NET_INGR_TIMEOUT_CYCLES - total numner of cycles to wait after tvalid is asserted before indicating an rx timeout, for network interface
   NET_TOKEN_COUNT_INT_WIDTH - the token count integer component width, for network interface (fixed point representation)
   NET_TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width, for network interface (fixed point representation)

   CTRL_AWTIMEOUT_CYCLES - total number of cycles to wait after awvalid is asserted before indicating an AW-channel timeout, control interface
   CTRL_WTIMEOUT_CYCLES - total number of cycles to wait after wvalid is asserted before indicating a W-channel timeout, control interface
   CTRL_BTIMEOUT_CYCLES - total numner of cycles to wait after valid AW and W data have been received for a response before indicating a B-channel timeout, control interface
   CTRL_ARTIMEOUT_CYCLES - total number of cycles to wait after arvalid is asserted before indicating an AR-channel timeout, control interface
   CTRL_RTIMEOUT_CYCLES - total numner of cycles to wait after a valid AR request has been received for a response before indicating a B-channel timeout, control interface
   CTRL_OUTSTANDING_WREQ - the maximum allowed oustanding write requests, control interface
   CTRL_OUTSTANDING_RREQ - the maximum allowed outstanding read requests, control interface
   CTRL_INCLUDE_BACKPRESSURE - binary, whether or not to assert backpressure when OUTSTANDING limits reached, control interface (recommended)
   CTRL_W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted, control interface

AXI-Lite Control Interface Register Space
   Based on currently implemented AXI lite crossbar:
       0x0000000000000000 - Base address of the application region's axi lite space
       0x0000000000100000 - Base address of the network isolation/decoupler core
       0x0000000000200000 - Base address of the control isolation/decoupler core
       0x0000000000300000 - Base address of the clocking and reset controller

Ports:
   axis_tx_s_* - the input axi stream for the tx direction
   axis_tx_m_* - the output axi stream for the tx direction
   axis_rx_s_* - the input axi stream for the rx direction
   axis_rx_m_* - the output axi stream for the rx direction
   axis_aclk - clock to which all of the network signals are synchronous
   axis_aresetn - active-low reset corresponding to above clock
   axis_pr_aclk - clock for network to be used by the application region
   axis_pr_aresetn - reset for network to be used by the application region

   axi_lite_m_ctrl_* - the AXI-Lite control interface into the application region
   ctrl_* - the AXI-Lite control interface (top-level)
   ctrl_aclk - clock to which the control signal is synchronous
   ctrl_aresetn - active-low reset corresponding to above clock
   ctrl_pr_aclk - clock for control to be used by the application region
   ctrl_pr_aresetn - reset for control to be used by the application region

Notes:
   - Various portions of the hdl below require the manual addition of vendor
   specific cores for clock crossing and AXI switching/crossbar. Search for 
   [VENDOR SPECIFIC] for all places where such cores are required
*/


module interface_shell
#(
    //Network AXI Stream Params
    parameter NET_AXIS_BUS_WIDTH = 64,
    parameter NET_AXIS_ID_WIDTH = 5,
    parameter NET_AXIS_DEST_WIDTH = 1,

    //Network Packet Params
    parameter NET_MAX_PACKET_LENGTH = 1522,

    //Network Isolation Options
    parameter NET_INCLUDE_BW_SHAPER = 1,
    parameter NET_DISALLOW_INGR_BACKPRESSURE = 1,
    parameter NET_DISALLOW_INVALID_MID_PACKET_EGR = 1,
    parameter NET_INCLUDE_TIMEOUT_ERROR_INGR = 0,

    //Network Core Params
    parameter NET_INGR_TIMEOUT_CYCLES = 15,

    //Network token counter params
    parameter NET_TOKEN_COUNT_INT_WIDTH = 16,
    parameter NET_TOKEN_COUNT_FRAC_WIDTH = 8,



    //AXI-Lite Interface Params
    //parameter CTRL_AXI_DATA_WIDTH = 32, //Fixed to 32 for now, 64-bit not supported by some cores
    
    //Timeout limits
    parameter CTRL_AWTIMEOUT_CYCLES = 15,
    parameter CTRL_WTIMEOUT_CYCLES = 15,
    parameter CTRL_BTIMEOUT_CYCLES = 127,
    parameter CTRL_ARTIMEOUT_CYCLES = 15,
    parameter CTRL_RTIMEOUT_CYCLES = 127,
    
    //Additional Params to determine particular capabilities
    parameter CTRL_OUTSTANDING_WREQ = 8,
    parameter CTRL_OUTSTANDING_RREQ = 8,
    parameter CTRL_INCLUDE_BACKPRESSURE = 1,
    parameter CTRL_W_BEFORE_AW_CAPABLE = 1
)
(
    //Egress Input AXI stream (application region sends packets to this interface)
    input wire [NET_AXIS_BUS_WIDTH-1:0]         axis_tx_s_tdata,
    input wire [NET_AXIS_ID_WIDTH-1:0]          axis_tx_s_tid,
    input wire [NET_AXIS_DEST_WIDTH-1:0]        axis_tx_s_tdest,                                          
    input wire [(NET_AXIS_BUS_WIDTH/8)-1:0]     axis_tx_s_tkeep,
    input wire                                  axis_tx_s_tlast,
    input wire                                  axis_tx_s_tvalid,
    output wire                                 axis_tx_s_tready,

    //Egress Output AXI stream (TX packets go to Phy from this interface)
    output wire [NET_AXIS_BUS_WIDTH-1:0]        axis_tx_m_tdata,
    output wire [NET_AXIS_ID_WIDTH-1:0]         axis_tx_m_tid,
    output wire [NET_AXIS_DEST_WIDTH-1:0]       axis_tx_m_tdest,                                           
    output wire [(NET_AXIS_BUS_WIDTH/8)-1:0]    axis_tx_m_tkeep,
    output wire                                 axis_tx_m_tlast,
    output wire                                 axis_tx_m_tvalid,
    input wire                                  axis_tx_m_tready,

    //Ingress Input AXI stream (RX packets from Phy connect to this interafce)
    input wire [NET_AXIS_BUS_WIDTH-1:0]         axis_rx_s_tdata,
    input wire [NET_AXIS_ID_WIDTH-1:0]          axis_rx_s_tdest,
    input wire [(NET_AXIS_BUS_WIDTH/8)-1:0]     axis_rx_s_tkeep,
    input wire                                  axis_rx_s_tlast,
    input wire                                  axis_rx_s_tvalid,
    output wire                                 axis_rx_s_tready,

    //Ingress Output AXI stream (application region receives packets from this interface)
    output wire [NET_AXIS_BUS_WIDTH-1:0]        axis_rx_m_tdata,
    output wire [NET_AXIS_ID_WIDTH-1:0]         axis_rx_m_tdest,
    output wire [(NET_AXIS_BUS_WIDTH/8)-1:0]    axis_rx_m_tkeep,
    output wire                                 axis_rx_m_tlast,
    output wire                                 axis_rx_m_tvalid,
    input wire                                  axis_rx_m_tready,

    //Network Clocking
    input wire  axis_aclk,
    input wire  axis_aresetn,

    //Decoupled clock
    output wire axis_pr_aclk,
    output wire axis_pr_aresetn,



    //AXI-Lite interface into the application region (for accessing control of the HW App)
    //Write Address Channel  
    output wire  [31:0]                      axi_lite_m_ctrl_awaddr,
    output wire                              axi_lite_m_ctrl_awvalid,
    input reg                                axi_lite_m_ctrl_awready,
    //Write Data Channel
    output wire  [31:0]                      axi_lite_m_ctrl_wdata,
    output wire  [3:0]                       axi_lite_m_ctrl_wstrb,
    output wire                              axi_lite_m_ctrl_wvalid,
    input reg                                axi_lite_m_ctrl_wready,
    //Write Response Channel
    input reg [1:0]                          axi_lite_m_ctrl_bresp,
    input reg                                axi_lite_m_ctrl_bvalid,
    output wire                              axi_lite_m_ctrl_bready,
    //Read Address Channel 
    output wire  [31:0]                      axi_lite_m_ctrl_araddr,
    output wire                              axi_lite_m_ctrl_arvalid,
    input reg                                axi_lite_m_ctrl_arready,
    //Read Data Response Channel
    input reg [31:0]                         axi_lite_m_ctrl_rdata,
    input reg [1:0]                          axi_lite_m_ctrl_rresp,
    input reg                                axi_lite_m_ctrl_rvalid,
    output wire                              axi_lite_m_ctrl_rready,
    


    //The AXI-Lite Control Interface (access both the application region, and isolation cores)
    //Write Address Channel  
    input wire  [31:0]                      ctrl_awaddr,
    input wire                              ctrl_awvalid,
    output reg                              ctrl_awready,
    //Write Data Channel
    input wire  [31:0]                      ctrl_wdata,
    input wire  [3:0]                       ctrl_wstrb,
    input wire                              ctrl_wvalid,
    output reg                              ctrl_wready,
    //Write Response Channel
    output reg [1:0]                        ctrl_bresp,
    output reg                              ctrl_bvalid,
    input wire                              ctrl_bready,
    //Read Address Channel 
    input wire  [31:0]                      ctrl_araddr,
    input wire                              ctrl_arvalid,
    output reg                              ctrl_arready,
    //Read Data Response Channel
    output reg [31:0]                       ctrl_rdata,
    output reg [1:0]                        ctrl_rresp,
    output reg                              ctrl_rvalid,
    input wire                              ctrl_rready,

    //Ctrl Clocking
    input wire  ctrl_aclk,
    input wire  ctrl_aresetn,

    //Decoupled clock
    output wire  ctrl_pr_aclk,
    output wire  ctrl_pr_aresetn
);


    //--------------------------------------------------------//
    //   Network connection                                   //
    //--------------------------------------------------------//

    //Control interface for network isolation cores (sync to net clock)
    //Write Address Channel  
    wire [31:0]     net_iso_ctrl_awaddr;
    wire            net_iso_ctrl_awvalid;
    wire            net_iso_ctrl_awready;
    //Write Data Channel
    wire  [31:0]    net_iso_ctrl_wdata;
    wire            net_iso_ctrl_wvalid;
    wire            net_iso_ctrl_wready;
    //Write Response Channel
    wire [1:0]      net_iso_ctrl_bresp;
    wire            net_iso_ctrl_bvalid;
    wire            net_iso_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]    net_iso_ctrl_araddr;
    wire            net_iso_ctrl_arvalid;
    wire            net_iso_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]     net_iso_ctrl_rdata;
    wire [1:0]      net_iso_ctrl_rresp;
    wire            net_iso_ctrl_rvalid;
    wire            net_iso_ctrl_rready;

    //The network isolation wrapper
    net_iso_top
    #(
        .AXIS_BUS_WIDTH                     (NET_AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH                      (NET_AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH                    (NET_AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH                  (NET_MAX_PACKET_LENGTH),
        .INCLUDE_BW_SHAPER                  (NET_INCLUDE_BW_SHAPER),
        .DISALLOW_INGR_BACKPRESSURE         (NET_DISALLOW_INGR_BACKPRESSURE),
        .DISALLOW_INVALID_MID_PACKET_EGR    (NET_DISALLOW_INVALID_MID_PACKET_EGR),
        .INCLUDE_TIMEOUT_ERROR_INGR         (NET_INCLUDE_TIMEOUT_ERROR_INGR),
        .INGR_TIMEOUT_CYCLES                (NET_INGR_TIMEOUT_CYCLES),
        .TOKEN_COUNT_INT_WIDTH              (NET_TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH             (NET_TOKEN_COUNT_FRAC_WIDTH)
    )
    (
        //Egress Input AXI stream (the master interface to isolate connects to this)
        .axis_tx_s_tdata        (axis_tx_s_tdata),
        .axis_tx_s_tid          (axis_tx_s_tid),
        .axis_tx_s_tdest        (axis_tx_s_tdest),                                          
        .axis_tx_s_tkeep        (axis_tx_s_tkeep),
        .axis_tx_s_tlast        (axis_tx_s_tlast),
        .axis_tx_s_tvalid       (axis_tx_s_tvalid),
        .axis_tx_s_tready       (axis_tx_s_tready),

        //Egress Output AXI stream (connects to the slave expecting the isolated signal)
        .axis_tx_m_tdata        (axis_tx_m_tdata),
        .axis_tx_m_tid          (axis_tx_m_tid),
        .axis_tx_m_tdest        (axis_tx_m_tdest),                                           
        .axis_tx_m_tkeep        (axis_tx_m_tkeep),
        .axis_tx_m_tlast        (axis_tx_m_tlast),
        .axis_tx_m_tvalid       (axis_tx_m_tvalid),
        .axis_tx_m_tready       (axis_tx_m_tready),

        //Ingress Input AXI stream (connects to the master expecting the isolated signal)
        .axis_rx_s_tdata        (axis_rx_s_tdata),
        .axis_rx_s_tdest        (axis_rx_s_tdest),
        .axis_rx_s_tkeep        (axis_rx_s_tkeep),
        .axis_rx_s_tlast        (axis_rx_s_tlast),
        .axis_rx_s_tvalid       (axis_rx_s_tvalid),
        .axis_rx_s_tready       (axis_rx_s_tready),

        //Ingress Output AXI stream (the slave interface to isolate connects to this)
        .axis_rx_m_tdata        (axis_rx_m_tdata),
        .axis_rx_m_tdest        (axis_rx_m_tdest),
        .axis_rx_m_tkeep        (axis_rx_m_tkeep),
        .axis_rx_m_tlast        (axis_rx_m_tlast),
        .axis_rx_m_tvalid       (axis_rx_m_tvalid),
        .axis_rx_m_tready       (axis_rx_m_tready),
        
        //The AXI-Lite Control Interface
        .ctrl_awaddr            (net_iso_ctrl_awaddr),
        .ctrl_awvalid           (net_iso_ctrl_awvalid),
        .ctrl_awready           (net_iso_ctrl_awready),
        .ctrl_wdata             (net_iso_ctrl_wdata),
        .ctrl_wvalid            (net_iso_ctrl_wvalid),
        .ctrl_wready            (net_iso_ctrl_wready),
        .ctrl_bresp             (net_iso_ctrl_bresp),
        .ctrl_bvalid            (net_iso_ctrl_bvalid),
        .ctrl_bready            (net_iso_ctrl_bready),
        .ctrl_araddr            (net_iso_ctrl_araddr),
        .ctrl_arvalid           (net_iso_ctrl_arvalid),
        .ctrl_arready           (net_iso_ctrl_arready),
        .ctrl_rdata             (net_iso_ctrl_rdata),
        .ctrl_rresp             (net_iso_ctrl_rresp),
        .ctrl_rvalid            (net_iso_ctrl_rvalid),
        .ctrl_rready            (net_iso_ctrl_rready),

        //Clocking
        .aclk                   (axis_aclk),
        .aresetn                (axis_aresetn)
    );

    //Control interface for network isolation cores (sync to ctrl clock)
    //Write Address Channel  
    wire [31:0]     net_iso_sync_ctrl_awaddr;
    wire            net_iso_sync_ctrl_awvalid;
    wire            net_iso_sync_ctrl_awready;
    //Write Data Channel
    wire  [31:0]    net_iso_sync_ctrl_wdata;
    wire            net_iso_sync_ctrl_wvalid;
    wire            net_iso_sync_ctrl_wready;
    //Write Response Channel
    wire [1:0]      net_iso_sync_ctrl_bresp;
    wire            net_iso_sync_ctrl_bvalid;
    wire            net_iso_sync_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]    net_iso_sync_ctrl_araddr;
    wire            net_iso_sync_ctrl_arvalid;
    wire            net_iso_sync_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]     net_iso_sync_ctrl_rdata;
    wire [1:0]      net_iso_sync_ctrl_rresp;
    wire            net_iso_sync_ctrl_rvalid;
    wire            net_iso_sync_ctrl_rready;

    //[VENDOR SPECIFIC]
    //Insert vendor specific clock crossing register slice here
    //   - Input interface is net_iso_sync_ctrl_*, sync to ctrl_aclk
    //   - Output interface is net_iso_ctrl_*, sync to axis_aclk
    axi_lite_clock_cross net_iso_clock_cross 
    (
      .s_axi_aclk(ctrl_aclk),        // input wire s_axi_aclk
      .s_axi_aresetn(ctrl_aresetn),  // input wire s_axi_aresetn

      .s_axi_awaddr(net_iso_sync_ctrl_awaddr),    // input wire [11 : 0] s_axi_awaddr
      .s_axi_awprot(0),                           // input wire [2 : 0] s_axi_awprot
      .s_axi_awvalid(net_iso_sync_ctrl_awvalid),  // input wire s_axi_awvalid
      .s_axi_awready(net_iso_sync_ctrl_awready),  // output wire s_axi_awready
      .s_axi_wdata(net_iso_sync_ctrl_wdata),      // input wire [31 : 0] s_axi_wdata
      .s_axi_wstrb(0),                            // input wire [3 : 0] s_axi_wstrb
      .s_axi_wvalid(net_iso_sync_ctrl_wvalid),    // input wire s_axi_wvalid
      .s_axi_wready(net_iso_sync_ctrl_wready),    // output wire s_axi_wready
      .s_axi_bresp(net_iso_sync_ctrl_bresp),      // output wire [1 : 0] s_axi_bresp
      .s_axi_bvalid(net_iso_sync_ctrl_bvalid),    // output wire s_axi_bvalid
      .s_axi_bready(net_iso_sync_ctrl_bready),    // input wire s_axi_bready
      .s_axi_araddr(net_iso_sync_ctrl_araddr),    // input wire [11 : 0] s_axi_araddr
      .s_axi_arprot(0),                           // input wire [2 : 0] s_axi_arprot
      .s_axi_arvalid(net_iso_sync_ctrl_arvalid),  // input wire s_axi_arvalid
      .s_axi_arready(net_iso_sync_ctrl_arready),  // output wire s_axi_arready
      .s_axi_rdata(net_iso_sync_ctrl_rdata),      // output wire [31 : 0] s_axi_rdata
      .s_axi_rresp(net_iso_sync_ctrl_rresp),      // output wire [1 : 0] s_axi_rresp
      .s_axi_rvalid(net_iso_sync_ctrl_rvalid),    // output wire s_axi_rvalid
      .s_axi_rready(net_iso_sync_ctrl_rready),    // input wire s_axi_rready

      .m_axi_aclk(axis_aclk),        // input wire m_axi_aclk
      .m_axi_aresetn(axis_aresetn),  // input wire m_axi_aresetn

      .m_axi_awaddr(net_iso_ctrl_awaddr),    // output wire [11 : 0] m_axi_awaddr
      .m_axi_awprot( ),                      // output wire [2 : 0] m_axi_awprot
      .m_axi_awvalid(net_iso_ctrl_awvalid),  // output wire m_axi_awvalid
      .m_axi_awready(net_iso_ctrl_awready),  // input wire m_axi_awready
      .m_axi_wdata(net_iso_ctrl_wdata),      // output wire [31 : 0] m_axi_wdata
      .m_axi_wstrb( ),                       // output wire [3 : 0] m_axi_wstrb
      .m_axi_wvalid(net_iso_ctrl_wvalid),    // output wire m_axi_wvalid
      .m_axi_wready(net_iso_ctrl_wready),    // input wire m_axi_wready
      .m_axi_bresp(net_iso_ctrl_bresp),      // input wire [1 : 0] m_axi_bresp
      .m_axi_bvalid(net_iso_ctrl_bvalid),    // input wire m_axi_bvalid
      .m_axi_bready(net_iso_ctrl_bready),    // output wire m_axi_bready
      .m_axi_araddr(net_iso_ctrl_araddr),    // output wire [11 : 0] m_axi_araddr
      .m_axi_arprot( ),                      // output wire [2 : 0] m_axi_arprot
      .m_axi_arvalid(net_iso_ctrl_arvalid),  // output wire m_axi_arvalid
      .m_axi_arready(net_iso_ctrl_arready),  // input wire m_axi_arready
      .m_axi_rdata(net_iso_ctrl_rdata),      // input wire [31 : 0] m_axi_rdata
      .m_axi_rresp(net_iso_ctrl_rresp),      // input wire [1 : 0] m_axi_rresp
      .m_axi_rvalid(net_iso_ctrl_rvalid),    // input wire m_axi_rvalid
      .m_axi_rready(net_iso_ctrl_rready)    // output wire m_axi_rready
    );
        


    //--------------------------------------------------------//
    //   Control connection                                   //
    //--------------------------------------------------------//

    //Control interface for control isolation cores (sync to ctrl clock)
    //Write Address Channel  
    wire [31:0]     ctrl_iso_ctrl_awaddr;
    wire            ctrl_iso_ctrl_awvalid;
    wire            ctrl_iso_ctrl_awready;
    //Write Data Channel
    wire  [31:0]    ctrl_iso_ctrl_wdata;
    wire            ctrl_iso_ctrl_wvalid;
    wire            ctrl_iso_ctrl_wready;
    //Write Response Channel
    wire [1:0]      ctrl_iso_ctrl_bresp;
    wire            ctrl_iso_ctrl_bvalid;
    wire            ctrl_iso_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]    ctrl_iso_ctrl_araddr;
    wire            ctrl_iso_ctrl_arvalid;
    wire            ctrl_iso_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]     ctrl_iso_ctrl_rdata;
    wire [1:0]      ctrl_iso_ctrl_rresp;
    wire            ctrl_iso_ctrl_rvalid;
    wire            ctrl_iso_ctrl_rready;

    //Slave-side connection for application region control interface (sync to ctrl clock)
    //Write Address Channel  
    wire  [31:0]                      axi_lite_s_ctrl_awaddr;
    wire                              axi_lite_s_ctrl_awvalid;
    wire                              axi_lite_s_ctrl_awready;
    //Write Data Channel
    wire  [31:0]                      axi_lite_s_ctrl_wdata;
    wire  [3:0]                       axi_lite_s_ctrl_wstrb;
    wire                              axi_lite_s_ctrl_wvalid;
    wire                              axi_lite_s_ctrl_wready;
    //Write Response Channel
    wire [1:0]                        axi_lite_s_ctrl_bresp;
    wire                              axi_lite_s_ctrl_bvalid;
    wire                              axi_lite_s_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]                      axi_lite_s_ctrl_araddr;
    wire                              axi_lite_s_ctrl_arvalid;
    wire                              axi_lite_s_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]                       axi_lite_s_ctrl_rdata;
    wire [1:0]                        axi_lite_s_ctrl_rresp;
    wire                              axi_lite_s_ctrl_rvalid;
    wire                              axi_lite_s_ctrl_rready;

    //The control isolation wrapper
    ctrl_iso_top
    #(
        .AXI_ADDR_WIDTH         (32),
        .AXI_DATA_WIDTH         (32),        
        .AWTIMEOUT_CYCLES       (CTRL_AWTIMEOUT_CYCLES),
        .WTIMEOUT_CYCLES        (CTRL_WTIMEOUT_CYCLES),
        .BTIMEOUT_CYCLES        (CTRL_BTIMEOUT_CYCLES),
        .ARTIMEOUT_CYCLES       (CTRL_ARTIMEOUT_CYCLES),
        .RTIMEOUT_CYCLES        (CTRL_RTIMEOUT_CYCLES),
        .OUTSTANDING_WREQ       (CTRL_OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ       (CTRL_OUTSTANDING_RREQ),
        .INCLUDE_BACKPRESSURE   (CTRL_INCLUDE_BACKPRESSURE),
        .W_BEFORE_AW_CAPABLE    (CTRL_W_BEFORE_AW_CAPABLE)
    )
    ctrl_iso_inst
    (
        //AXI-Lite slave connection (connects to the master interface expecting a isolated signal)
        .axi_lite_s_awaddr      (axi_lite_s_ctrl_awaddr),
        .axi_lite_s_awvalid     (axi_lite_s_ctrl_awvalid),
        .axi_lite_s_awready     (axi_lite_s_ctrl_awready),
        .axi_lite_s_wdata       (axi_lite_s_ctrl_wdata),
        .axi_lite_s_wstrb       (axi_lite_s_ctrl_wstrb),
        .axi_lite_s_wvalid      (axi_lite_s_ctrl_wvalid),
        .axi_lite_s_wready      (axi_lite_s_ctrl_wready),
        .axi_lite_s_bresp       (axi_lite_s_ctrl_bresp),
        .axi_lite_s_bvalid      (axi_lite_s_ctrl_bvalid),
        .axi_lite_s_bready      (axi_lite_s_ctrl_bready),
        .axi_lite_s_araddr      (axi_lite_s_ctrl_araddr),
        .axi_lite_s_arvalid     (axi_lite_s_ctrl_arvalid),
        .axi_lite_s_arready     (axi_lite_s_ctrl_arready),
        .axi_lite_s_rdata       (axi_lite_s_ctrl_rdata),
        .axi_lite_s_rresp       (axi_lite_s_ctrl_rresp),
        .axi_lite_s_rvalid      (axi_lite_s_ctrl_rvalid),
        .axi_lite_s_rready      (axi_lite_s_ctrl_rready),

        //AXI4 master connection (the slave interface to isolate connects to this)
        .axi_lite_m_awaddr      (axi_lite_m_ctrl_awaddr),
        .axi_lite_m_awvalid     (axi_lite_m_ctrl_awvalid),
        .axi_lite_m_awready     (axi_lite_m_ctrl_awready),
        .axi_lite_m_wdata       (axi_lite_m_ctrl_wdata),
        .axi_lite_m_wstrb       (axi_lite_m_ctrl_wstrb),
        .axi_lite_m_wvalid      (axi_lite_m_ctrl_wvalid),
        .axi_lite_m_wready      (axi_lite_m_ctrl_wready),
        .axi_lite_m_bresp       (axi_lite_m_ctrl_bresp),
        .axi_lite_m_bvalid      (axi_lite_m_ctrl_bvalid),
        .axi_lite_m_bready      (axi_lite_m_ctrl_bready),
        .axi_lite_m_araddr      (axi_lite_m_ctrl_araddr),
        .axi_lite_m_arvalid     (axi_lite_m_ctrl_arvalid),
        .axi_lite_m_arready     (axi_lite_m_ctrl_arready),
        .axi_lite_m_rdata       (axi_lite_m_ctrl_rdata),
        .axi_lite_m_rresp       (axi_lite_m_ctrl_rresp),
        .axi_lite_m_rvalid      (axi_lite_m_ctrl_rvalid),
        .axi_lite_m_rready      (axi_lite_m_ctrl_rready),

        //The AXI-Lite Control Interface
        .ctrl_awaddr            (ctrl_iso_ctrl_awaddr),
        .ctrl_awvalid           (ctrl_iso_ctrl_awvalid),
        .ctrl_awready           (ctrl_iso_ctrl_awready),
        .ctrl_wdata             (ctrl_iso_ctrl_wdata),
        .ctrl_wvalid            (ctrl_iso_ctrl_wvalid),
        .ctrl_wready            (ctrl_iso_ctrl_wready),
        .ctrl_bresp             (ctrl_iso_ctrl_bresp),
        .ctrl_bvalid            (ctrl_iso_ctrl_bvalid),
        .ctrl_bready            (ctrl_iso_ctrl_bready),
        .ctrl_araddr            (ctrl_iso_ctrl_araddr),
        .ctrl_arvalid           (ctrl_iso_ctrl_arvalid),
        .ctrl_arready           (ctrl_iso_ctrl_arready),
        .ctrl_rdata             (ctrl_iso_ctrl_rdata),
        .ctrl_rresp             (ctrl_iso_ctrl_rresp),
        .ctrl_rvalid            (ctrl_iso_ctrl_rvalid),
        .ctrl_rready            (ctrl_iso_ctrl_rready),

        //Clocking
        .aclk                   (ctrl_aclk),
        .aresetn                (ctrl_aresetn)
    );



    //--------------------------------------------------------//
    //   Clock and Reset decoupling                           //
    //--------------------------------------------------------//

    //Control interface for clock decouplers (sync to ctrl clock)
    //Write Address Channel  
    wire [31:0]     clock_decouple_ctrl_awaddr;
    wire            clock_decouple_ctrl_awvalid;
    wire            clock_decouple_ctrl_awready;
    //Write Data Channel
    wire  [31:0]    clock_decouple_ctrl_wdata;
    wire            clock_decouple_ctrl_wvalid;
    wire            clock_decouple_ctrl_wready;
    //Write Response Channel
    wire [1:0]      clock_decouple_ctrl_bresp;
    wire            clock_decouple_ctrl_bvalid;
    wire            clock_decouple_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]    clock_decouple_ctrl_araddr;
    wire            clock_decouple_ctrl_arvalid;
    wire            clock_decouple_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]     clock_decouple_ctrl_rdata;
    wire [1:0]      clock_decouple_ctrl_rresp;
    wire            clock_decouple_ctrl_rvalid;
    wire            clock_decouple_ctrl_rready;

    //Outputs of clock decoupling controller
    wire decouple;
    wire assert_reset;

    //Clock decoupler controller
    clock_reset_decouple_controller
    (
        //The AXI-Lite interface
        .awaddr     (clock_decouple_ctrl_awaddr),
        .awvalid    (clock_decouple_ctrl_awvalid),
        .awready    (clock_decouple_ctrl_awready),
        .wdata      (clock_decouple_ctrl_wdata),
        .wvalid     (clock_decouple_ctrl_wvalid),
        .wready     (clock_decouple_ctrl_wready),
        .bresp      (clock_decouple_ctrl_bresp),
        .bvalid     (clock_decouple_ctrl_bvalid),
        .bready     (clock_decouple_ctrl_bready),
        .araddr     (clock_decouple_ctrl_araddr),
        .arvalid    (clock_decouple_ctrl_arvalid),
        .arready    (clock_decouple_ctrl_arready),
        .rdata      (clock_decouple_ctrl_rdata),
        .rresp      (clock_decouple_ctrl_rresp),
        .rvalid     (clock_decouple_ctrl_rvalid),
        .rready     (clock_decouple_ctrl_rready),
        
        //Outputs
        .decouple       (decouple),
        .assert_reset   (assert_reset),

        //Clocking
        .aclk           (ctrl_aclk),
        .aresetn        (ctrl_aresetn)
    );

    //[VENDOR SPECIFIC]
    //Insert vendor specific clock gating or clock decoupling core here
    //   - Input clocks are axis_aclk, and ctrl_aclk
    //   - Output clocks are axi_mem_pr_aclk, axis_pr_aclk, and ctrl_pr_aclk
    //   - the decouple signal should be used to decouple, or it's inverse as the clock enable
    two_clock_decouple clock_decouple_inst 
    (
      .s_clock_0_CLK(axis_aclk),    // input wire s_clock_0_CLK
      .rp_clock_0_CLK(axis_pr_aclk),  // output wire rp_clock_0_CLK
      
      .s_clock_1_CLK(ctrl_aclk),    // input wire s_clock_1_CLK
      .rp_clock_1_CLK(ctrl_pr_aclk),  // output wire rp_clock_1_CLK
      
      .decouple(decouple)              // input wire decouple
    );

    //Clock crossing for the assert reset signals
    wire assert_reset_net;

    //[VENDOR SPECIFIC]
    //Insert vendor specific synchronizer here for the assert_reset signal
    //   - Input is assert_reset (sync to ctrl_aclk)
    //   - Output is assert_reset_net (sync to axis_aclk)
    xpm_cdc_array_single
    #(
        .DEST_SYNC_FF(3),   //DECIMAL; range:2-10
        .INIT_SYNC_FF(0),   //DECIMAL; integer; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0), //DECIMAL; integer; 0=disable simulation messages, 1=enable simulation messages
        .SRC_INPUT_REG(1),  //DECIMAL; 0=do not register input, 1=register input
        .WIDTH(1)           //DECIMAL; range:1-1024
    )
    sync_net_reset_inst
    (
        .src_in     (assert_reset),
        .dest_out   (assert_reset_net),

        .src_clk    (ctrl_aclk),
        .dest_clk   (axis_aclk)        
    );

    //PR reset signal logic
    assign axis_pr_aresetn = axis_aresetn & ~assert_reset_net;
    assign ctrl_pr_aresetn = ctrl_aresetn & ~assert_reset;



    //--------------------------------------------------------//
    //   Control Path                                         //
    //--------------------------------------------------------//

    //[VENDOR SPECIFIC]
    //Insert vendor AXI-Lite switch/crossbar
    //   - Input master interface is ctrl_* (from top level), with address width 32
    //   - Output slave interfaces are
    //      - axi_lite_s_ctrl_* (connnects to ctrl isolation), with address width 32
    //      - net_iso_sync_ctrl_* (connects to net isolation, through async reg slice), with address width 32
    //      - ctrl_iso_ctrl_* (connect to ctrl isolation), with address width 32
    //      - clock_decouple_ctrl_* (connects to clock decouple controller), with address width 32
    //   - Note, other than the axi_lite_s, slave interfaces do not have wstrb signal
    //   - all signals synchronous to ctrl_aclk

    wire [3:0] axi_s3_wstrb_pad;
    wire [3:0] axi_s2_wstrb_pad;
    wire [3:0] axi_s1_wstrb_pad;

    intfc_axi_lite_crossbar axi_lite_xbar_inst 
    (
      .aclk(ctrl_aclk),                    // input wire aclk
      .aresetn(ctrl_aresetn),              // input wire aresetn
      
      .s_axi_awaddr(ctrl_awaddr),    // input wire [20 : 0] s_axi_awaddr
      .s_axi_awprot(0),              // input wire [2 : 0] s_axi_awprot
      .s_axi_awvalid(ctrl_awvalid),  // input wire [0 : 0] s_axi_awvalid
      .s_axi_awready(ctrl_awready),  // output wire [0 : 0] s_axi_awready
      .s_axi_wdata(ctrl_wdata),      // input wire [31 : 0] s_axi_wdata
      .s_axi_wstrb(ctrl_wstrb),      // input wire [3 : 0] s_axi_wstrb
      .s_axi_wvalid(ctrl_wvalid),    // input wire [0 : 0] s_axi_wvalid
      .s_axi_wready(ctrl_wready),    // output wire [0 : 0] s_axi_wready
      .s_axi_bresp(ctrl_bresp),      // output wire [1 : 0] s_axi_bresp
      .s_axi_bvalid(ctrl_bvalid),    // output wire [0 : 0] s_axi_bvalid
      .s_axi_bready(ctrl_bready),    // input wire [0 : 0] s_axi_bready
      .s_axi_araddr(ctrl_araddr),    // input wire [20 : 0] s_axi_araddr
      .s_axi_arprot(0),              // input wire [2 : 0] s_axi_arprot
      .s_axi_arvalid(ctrl_arvalid),  // input wire [0 : 0] s_axi_arvalid
      .s_axi_arready(ctrl_arready),  // output wire [0 : 0] s_axi_arready
      .s_axi_rdata(ctrl_rdata),      // output wire [31 : 0] s_axi_rdata
      .s_axi_rresp(ctrl_rresp),      // output wire [1 : 0] s_axi_rresp
      .s_axi_rvalid(ctrl_rvalid),    // output wire [0 : 0] s_axi_rvalid
      .s_axi_rready(ctrl_rready),    // input wire [0 : 0] s_axi_rready
      
      .m_axi_awaddr({   clock_decouple_ctrl_awaddr,
                        ctrl_iso_ctrl_awaddr,
                        net_iso_sync_ctrl_awaddr,
                        axi_lite_s_ctrl_awaddr }),    // output wire [104 : 0] m_axi_awaddr
      .m_axi_awprot( ),                       // output wire [14 : 0] m_axi_awprot
      .m_axi_awvalid({  clock_decouple_ctrl_awvalid,
                        ctrl_iso_ctrl_awvalid,
                        net_iso_sync_ctrl_awvalid,
                        axi_lite_s_ctrl_awvalid }),  // output wire [4 : 0] m_axi_awvalid
      .m_axi_awready({  clock_decouple_ctrl_awready,
                        ctrl_iso_ctrl_awready,
                        net_iso_sync_ctrl_awready,
                        axi_lite_s_ctrl_awready }),  // input wire [4 : 0] m_axi_awready
      .m_axi_wdata({    clock_decouple_ctrl_wdata,
                        ctrl_iso_ctrl_wdata,
                        net_iso_sync_ctrl_wdata,
                        axi_lite_s_ctrl_wdata }),      // output wire [159 : 0] m_axi_wdata
      .m_axi_wstrb({    axi_s3_wstrb_pad,
                        axi_s2_wstrb_pad,
                        axi_s1_wstrb_pad,
                        axi_lite_s_ctrl_wstrb }),      // output wire [19 : 0] m_axi_wstrb
      .m_axi_wvalid({   clock_decouple_ctrl_wvalid,
                        ctrl_iso_ctrl_wvalid,
                        net_iso_sync_ctrl_wvalid,
                        axi_lite_s_ctrl_wvalid }),    // output wire [4 : 0] m_axi_wvalid
      .m_axi_wready({   clock_decouple_ctrl_wready,
                        ctrl_iso_ctrl_wready,
                        net_iso_sync_ctrl_wready,
                        axi_lite_s_ctrl_wready }),    // input wire [4 : 0] m_axi_wready
      .m_axi_bresp({    clock_decouple_ctrl_bresp,
                        ctrl_iso_ctrl_bresp,
                        net_iso_sync_ctrl_bresp,
                        axi_lite_s_ctrl_bresp }),      // input wire [9 : 0] m_axi_bresp
      .m_axi_bvalid({   clock_decouple_ctrl_bvalid,
                        ctrl_iso_ctrl_bvalid,
                        net_iso_sync_ctrl_bvalid,
                        axi_lite_s_ctrl_bvalid }),    // input wire [4 : 0] m_axi_bvalid
      .m_axi_bready({   clock_decouple_ctrl_bready,
                        ctrl_iso_ctrl_bready,
                        net_iso_sync_ctrl_bready,
                        axi_lite_s_ctrl_bready }),    // output wire [4 : 0] m_axi_bready
      .m_axi_araddr({   clock_decouple_ctrl_araddr,
                        ctrl_iso_ctrl_araddr,
                        net_iso_sync_ctrl_araddr,
                        axi_lite_s_ctrl_araddr }),    // output wire [104 : 0] m_axi_araddr
      .m_axi_arprot( ),                       // output wire [14 : 0] m_axi_arprot
      .m_axi_arvalid({  clock_decouple_ctrl_arvalid,
                        ctrl_iso_ctrl_arvalid,
                        net_iso_sync_ctrl_arvalid,
                        axi_lite_s_ctrl_arvalid }),  // output wire [4 : 0] m_axi_arvalid
      .m_axi_arready({  clock_decouple_ctrl_arready,
                        ctrl_iso_ctrl_arready,
                        net_iso_sync_ctrl_arready,
                        axi_lite_s_ctrl_arready }),  // input wire [4 : 0] m_axi_arready
      .m_axi_rdata({    clock_decouple_ctrl_rdata,
                        ctrl_iso_ctrl_rdata,
                        net_iso_sync_ctrl_rdata,
                        axi_lite_s_ctrl_rdata }),      // input wire [159 : 0] m_axi_rdata
      .m_axi_rresp({    clock_decouple_ctrl_rresp,
                        ctrl_iso_ctrl_rresp,
                        net_iso_sync_ctrl_rresp,
                        axi_lite_s_ctrl_rresp }),      // input wire [9 : 0] m_axi_rresp
      .m_axi_rvalid({   clock_decouple_ctrl_rvalid,
                        ctrl_iso_ctrl_rvalid,
                        net_iso_sync_ctrl_rvalid,
                        axi_lite_s_ctrl_rvalid }),    // input wire [4 : 0] m_axi_rvalid
      .m_axi_rready({   clock_decouple_ctrl_rready,
                        ctrl_iso_ctrl_rready,
                        net_iso_sync_ctrl_rready,
                        axi_lite_s_ctrl_rready })    // output wire [4 : 0] m_axi_rready
    );


endmodule

`default_nettype wire