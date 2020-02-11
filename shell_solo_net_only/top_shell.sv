`timescale 1ns / 1ps
`default_nettype none

/*
Top-level for the shell

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   The top level module, instantiates the Phy Shell, the Interface 
   Shell, and the application region

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

Notes:
   - all platform specific ports need to be added to the file "phy_signals.svh" for 
   each platform implementation
*/


module top_shell
#(
    //Network AXI Stream Params
    parameter NET_AXIS_BUS_WIDTH = 64,
    parameter NET_AXIS_ID_WIDTH = 1,
    parameter NET_AXIS_DEST_WIDTH = 1,

    //Network Packet Params
    parameter NET_MAX_PACKET_LENGTH = 1522,

    //Network Isolation Options
    parameter NET_INCLUDE_BW_SHAPER = 0,
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

    //Physical layer ports (from include file)
    `include "phy_signals.svh"

);

   //--------------------------------------------------------//
   //   PHY Shell                                            //
   //--------------------------------------------------------//

   //Egress Output AXI stream (TX packets to Phy)
   wire [NET_AXIS_BUS_WIDTH-1:0]          axis_tx_tdata;
   wire [(NET_AXIS_BUS_WIDTH/8)-1:0]      axis_tx_tkeep;
   wire                                   axis_tx_tlast;
   wire                                   axis_tx_tvalid;
   wire                                   axis_tx_tready;
   //Ingress Input AXI stream (RX packets from Phy)
   wire [NET_AXIS_BUS_WIDTH-1:0]          axis_rx_tdata;
   wire [(NET_AXIS_BUS_WIDTH/8)-1:0]      axis_rx_tkeep;
   wire                                   axis_rx_tlast;
   wire                                   axis_rx_tvalid;
   wire                                   axis_rx_tready;
   //Network Clocking
   wire  axis_aclk;
   wire  axis_aresetn;
    

   //The AXI-Lite Control Interface (from control, e.g. PCIe)
   //Write Address Channel  
   wire  [31:0]                         top_ctrl_awaddr;
   wire                                 top_ctrl_awvalid;
   wire                                 top_ctrl_awready;
   //Write Data Channel
   wire  [31:0]                         top_ctrl_wdata;
   wire  [3:0]                          top_ctrl_wstrb;
   wire                                 top_ctrl_wvalid;
   wire                                 top_ctrl_wready;
   //Write Response Channel
   wire [1:0]                           top_ctrl_bresp;
   wire                                 top_ctrl_bvalid;
   wire                                 top_ctrl_bready;
   //Read Address Channel 
   wire  [31:0]                         top_ctrl_araddr;
   wire                                 top_ctrl_arvalid;
   wire                                 top_ctrl_arready;
   //Read Data Response Channel
   wire [31:0]                          top_ctrl_rdata;
   wire [1:0]                           top_ctrl_rresp;
   wire                                 top_ctrl_rvalid;
   wire                                 top_ctrl_rready;

   //Ctrl Clocking
   wire  top_aclk;
   wire  top_aresetn;



   //The Phy Shell Instantiated
   phy_shell
   #(
      .NET_AXIS_BUS_WIDTH      (NET_AXIS_BUS_WIDTH),
      .NET_MAX_PACKET_LENGTH   (NET_MAX_PACKET_LENGTH)
   )
   phy_shell_inst
   (
      //Egress Output AXI stream (TX packets to Phy)
      .axis_tx_s_tdata     (axis_tx_tdata),
      .axis_tx_s_tkeep     (axis_tx_tkeep),
      .axis_tx_s_tlast     (axis_tx_tlast),
      .axis_tx_s_tvalid    (axis_tx_tvalid),
      .axis_tx_s_tready    (axis_tx_tready),
      //Ingress Input AXI stream (RX packets from Phy)
      .axis_rx_m_tdata     (axis_rx_tdata),
      .axis_rx_m_tkeep     (axis_rx_tkeep),
      .axis_rx_m_tlast     (axis_rx_tlast),
      .axis_rx_m_tvalid    (axis_rx_tvalid),
      .axis_rx_m_tready    (axis_rx_tready),
      //Network Clocking
      .axis_aclk           (axis_aclk),
      .axis_aresetn        (axis_aresetn),
      
      //The AXI-Lite Control Interface (from control, e.g. PCIe)
      //Write Address Channel  
      .top_ctrl_awaddr     (top_ctrl_awaddr),
      .top_ctrl_awvalid    (top_ctrl_awvalid),
      .top_ctrl_awready    (top_ctrl_awready),
      //Write Data Channel
      .top_ctrl_wdata      (top_ctrl_wdata),
      .top_ctrl_wstrb      (top_ctrl_wstrb),
      .top_ctrl_wvalid     (top_ctrl_wvalid),
      .top_ctrl_wready     (top_ctrl_wready),
      //Write Response Channel
      .top_ctrl_bresp      (top_ctrl_bresp),
      .top_ctrl_bvalid     (top_ctrl_bvalid),
      .top_ctrl_bready     (top_ctrl_bready),
      //Read Address Channel 
      .top_ctrl_araddr     (top_ctrl_araddr),
      .top_ctrl_arvalid    (top_ctrl_arvalid),
      .top_ctrl_arready    (top_ctrl_arready),
      //Read Data Response Channel
      .top_ctrl_rdata      (top_ctrl_rdata),
      .top_ctrl_rresp      (top_ctrl_rresp),
      .top_ctrl_rvalid     (top_ctrl_rvalid),
      .top_ctrl_rready     (top_ctrl_rready),

      //Ctrl Clocking
      .top_aclk            (top_aclk),
      .top_aresetn         (top_aresetn),
      
      //Platform specific ports, assumes same port names
      .*
   );



    //--------------------------------------------------------//
    //   Interface Shell                                      //
    //--------------------------------------------------------//

    //Connections to app region

    //TX AXI stream
    wire [NET_AXIS_BUS_WIDTH-1:0]         axis_tx_app_tdata;
    wire [NET_AXIS_ID_WIDTH-1:0]          axis_tx_app_tid;
    wire [NET_AXIS_DEST_WIDTH-1:0]        axis_tx_app_tdest;
    wire [(NET_AXIS_BUS_WIDTH/8)-1:0]     axis_tx_app_tkeep;
    wire                                  axis_tx_app_tlast;
    wire                                  axis_tx_app_tvalid;
    wire                                  axis_tx_app_tready;
    //RX AXI stream
    wire [NET_AXIS_BUS_WIDTH-1:0]         axis_rx_app_tdata;
    wire [NET_AXIS_ID_WIDTH-1:0]          axis_rx_app_tdest;
    wire [(NET_AXIS_BUS_WIDTH/8)-1:0]     axis_rx_app_tkeep;
    wire                                  axis_rx_app_tlast;
    wire                                  axis_rx_app_tvalid;
    wire                                  axis_rx_app_tready;
    //Decoupled network clock
    wire axis_pr_aclk;
    wire axis_pr_aresetn;

    //AXI-Lite interface
    //Write Address Channel  
    wire  [31:0]                       axi_lite_app_ctrl_awaddr;
    wire                               axi_lite_app_ctrl_awvalid;
    wire                               axi_lite_app_ctrl_awready;
    //Write Data Channel
    wire  [31:0]                       axi_lite_app_ctrl_wdata;
    wire  [3:0]                        axi_lite_app_ctrl_wstrb;
    wire                               axi_lite_app_ctrl_wvalid;
    wire                               axi_lite_app_ctrl_wready;
    //Write Response Channel
    wire [1:0]                         axi_lite_app_ctrl_bresp;
    wire                               axi_lite_app_ctrl_bvalid;
    wire                               axi_lite_app_ctrl_bready;
    //Read Address Channel 
    wire  [31:0]                       axi_lite_app_ctrl_araddr;
    wire                               axi_lite_app_ctrl_arvalid;
    wire                               axi_lite_app_ctrl_arready;
    //Read Data Response Channel
    wire [31:0]                        axi_lite_app_ctrl_rdata;
    wire [1:0]                         axi_lite_app_ctrl_rresp;
    wire                               axi_lite_app_ctrl_rvalid;
    wire                               axi_lite_app_ctrl_rready;
    //Decoupled control clock
    wire  ctrl_pr_aclk;
    wire  ctrl_pr_aresetn;



   //The Interface shell instantiated
   interface_shell
   #(
      .NET_AXIS_BUS_WIDTH                    (NET_AXIS_BUS_WIDTH),
      .NET_AXIS_ID_WIDTH                     (NET_AXIS_ID_WIDTH),
      .NET_AXIS_DEST_WIDTH                   (NET_AXIS_DEST_WIDTH),
      .NET_MAX_PACKET_LENGTH                 (NET_MAX_PACKET_LENGTH),
      .NET_INCLUDE_BW_SHAPER                 (NET_INCLUDE_BW_SHAPER),
      .NET_DISALLOW_INGR_BACKPRESSURE        (NET_DISALLOW_INGR_BACKPRESSURE),
      .NET_DISALLOW_INVALID_MID_PACKET_EGR   (NET_DISALLOW_INVALID_MID_PACKET_EGR),
      .NET_INCLUDE_TIMEOUT_ERROR_INGR        (NET_INCLUDE_TIMEOUT_ERROR_INGR),
      .NET_INGR_TIMEOUT_CYCLES               (NET_INGR_TIMEOUT_CYCLES),
      .NET_TOKEN_COUNT_INT_WIDTH             (NET_TOKEN_COUNT_INT_WIDTH),
      .NET_TOKEN_COUNT_FRAC_WIDTH            (NET_TOKEN_COUNT_FRAC_WIDTH),

      .CTRL_AWTIMEOUT_CYCLES                 (CTRL_AWTIMEOUT_CYCLES),
      .CTRL_WTIMEOUT_CYCLES                  (CTRL_WTIMEOUT_CYCLES),
      .CTRL_BTIMEOUT_CYCLES                  (CTRL_BTIMEOUT_CYCLES),
      .CTRL_ARTIMEOUT_CYCLES                 (CTRL_ARTIMEOUT_CYCLES),
      .CTRL_RTIMEOUT_CYCLES                  (CTRL_RTIMEOUT_CYCLES),
      .CTRL_OUTSTANDING_WREQ                 (CTRL_OUTSTANDING_WREQ),
      .CTRL_OUTSTANDING_RREQ                 (CTRL_OUTSTANDING_RREQ),
      .CTRL_INCLUDE_BACKPRESSURE             (CTRL_INCLUDE_BACKPRESSURE),
      .CTRL_W_BEFORE_AW_CAPABLE              (CTRL_W_BEFORE_AW_CAPABLE)
   )
   intfc_shell_inst
   (
      //Egress Input AXI stream (application region send packets to this interface)
      .axis_tx_s_tdata        (axis_tx_app_tdata),
      .axis_tx_s_tid          (axis_tx_app_tid),
      .axis_tx_s_tdest        (axis_tx_app_tdest),
      .axis_tx_s_tkeep        (axis_tx_app_tkeep),
      .axis_tx_s_tlast        (axis_tx_app_tlast),
      .axis_tx_s_tvalid       (axis_tx_app_tvalid),
      .axis_tx_s_tready       (axis_tx_app_tready),
      //Egress Output AXI stream (TX packets go to Phy from this interface)
      .axis_tx_m_tdata        (axis_tx_tdata),
      .axis_tx_m_tkeep        (axis_tx_tkeep),
      .axis_tx_m_tlast        (axis_tx_tlast),
      .axis_tx_m_tvalid       (axis_tx_tvalid),
      .axis_tx_m_tready       (axis_tx_tready),
      //Ingress Input AXI stream (RX packets from Phy connect to this interafce)
      .axis_rx_s_tdata        (axis_rx_tdata),
      .axis_rx_s_tkeep        (axis_rx_tkeep),
      .axis_rx_s_tlast        (axis_rx_tlast),
      .axis_rx_s_tvalid       (axis_rx_tvalid),
      .axis_rx_s_tready       (axis_rx_tready),
      //Ingress Output AXI stream (application region receive packets from this interface)
      .axis_rx_m_tdata        (axis_rx_app_tdata),
      .axis_rx_m_tdest        (axis_rx_app_tdest),
      .axis_rx_m_tkeep        (axis_rx_app_tkeep),
      .axis_rx_m_tlast        (axis_rx_app_tlast),
      .axis_rx_m_tvalid       (axis_rx_app_tvalid),
      .axis_rx_m_tready       (axis_rx_app_tready),

      //Network Clocking
      .axis_aclk              (axis_aclk),
      .axis_aresetn           (axis_aresetn),
      //Decoupled clock
      .axis_pr_aclk           (axis_pr_aclk),
      .axis_pr_aresetn        (axis_pr_aresetn),

      //AXI-Lite interface into the application region (for accessing control of the HW App)
      //Write Address Channel  
      .axi_lite_m_ctrl_awaddr    (axi_lite_app_ctrl_awaddr),
      .axi_lite_m_ctrl_awvalid   (axi_lite_app_ctrl_awvalid),
      .axi_lite_m_ctrl_awready   (axi_lite_app_ctrl_awready),
      //Write Data Channel
      .axi_lite_m_ctrl_wdata     (axi_lite_app_ctrl_wdata),
      .axi_lite_m_ctrl_wstrb     (axi_lite_app_ctrl_wstrb),
      .axi_lite_m_ctrl_wvalid    (axi_lite_app_ctrl_wvalid),
      .axi_lite_m_ctrl_wready    (axi_lite_app_ctrl_wready),
      //Write Response Channel
      .axi_lite_m_ctrl_bresp     (axi_lite_app_ctrl_bresp),
      .axi_lite_m_ctrl_bvalid    (axi_lite_app_ctrl_bvalid),
      .axi_lite_m_ctrl_bready    (axi_lite_app_ctrl_bready),
      //Read Address Channel 
      .axi_lite_m_ctrl_araddr    (axi_lite_app_ctrl_araddr),
      .axi_lite_m_ctrl_arvalid   (axi_lite_app_ctrl_arvalid),
      .axi_lite_m_ctrl_arready   (axi_lite_app_ctrl_arready),
      //Read Data Response Channel
      .axi_lite_m_ctrl_rdata     (axi_lite_app_ctrl_rdata),
      .axi_lite_m_ctrl_rresp     (axi_lite_app_ctrl_rresp),
      .axi_lite_m_ctrl_rvalid    (axi_lite_app_ctrl_rvalid),
      .axi_lite_m_ctrl_rready    (axi_lite_app_ctrl_rready),
      
      //The AXI-Lite Control Interface (access both the application region, and isolation cores)
      //Write Address Channel  
      .ctrl_awaddr           (top_ctrl_awaddr),
      .ctrl_awvalid          (top_ctrl_awvalid),
      .ctrl_awready          (top_ctrl_awready),
      //Write Data Channel
      .ctrl_wdata            (top_ctrl_wdata),
      .ctrl_wstrb            (top_ctrl_wstrb),
      .ctrl_wvalid           (top_ctrl_wvalid),
      .ctrl_wready           (top_ctrl_wready),
      //Write Response Channel
      .ctrl_bresp            (top_ctrl_bresp),
      .ctrl_bvalid           (top_ctrl_bvalid),
      .ctrl_bready           (top_ctrl_bready),
      //Read Address Channel 
      .ctrl_araddr           (top_ctrl_araddr),
      .ctrl_arvalid          (top_ctrl_arvalid),
      .ctrl_arready          (top_ctrl_arready),
      //Read Data Response Channel
      .ctrl_rdata            (top_ctrl_rdata),
      .ctrl_rresp            (top_ctrl_rresp),
      .ctrl_rvalid           (top_ctrl_rvalid),
      .ctrl_rready           (top_ctrl_rready),

      //Ctrl Clocking
      .ctrl_aclk                 (top_aclk),
      .ctrl_aresetn              (top_aresetn),
      //Decoupled clock
      .ctrl_pr_aclk              (ctrl_pr_aclk),
      .ctrl_pr_aresetn           (ctrl_pr_aresetn)
   );



   //--------------------------------------------------------//
   //   App Region                                           //
   //--------------------------------------------------------//

   //The application Region (PR Region)
   app_region
   #(
      .NET_AXIS_BUS_WIDTH     (NET_AXIS_BUS_WIDTH),
      .NET_AXIS_ID_WIDTH      (NET_AXIS_ID_WIDTH),
      .NET_AXIS_DEST_WIDTH    (NET_AXIS_DEST_WIDTH),
      .NET_MAX_PACKET_LENGTH  (NET_MAX_PACKET_LENGTH)
   )
   app_reg_inst
   (
      //Egress Input AXI stream (application regions send packets to this interface)
      .axis_tx_m_tdata     (axis_tx_app_tdata),
      .axis_tx_m_tid       (axis_tx_app_tid),
      .axis_tx_m_tdest     (axis_tx_app_tdest),                                          
      .axis_tx_m_tkeep     (axis_tx_app_tkeep),
      .axis_tx_m_tlast     (axis_tx_app_tlast),
      .axis_tx_m_tvalid    (axis_tx_app_tvalid),
      .axis_tx_m_tready    (axis_tx_app_tready),
      //Ingress Output AXI stream (application regions receive packets from this interface)
      .axis_rx_s_tdata     (axis_rx_app_tdata),
      .axis_rx_s_tdest     (axis_rx_app_tdest),
      .axis_rx_s_tkeep     (axis_rx_app_tkeep),
      .axis_rx_s_tlast     (axis_rx_app_tlast),
      .axis_rx_s_tvalid    (axis_rx_app_tvalid),
      .axis_rx_s_tready    (axis_rx_app_tready),
      //Decoupled network clock
      .axis_aclk           (axis_pr_aclk),
      .axis_aresetn        (axis_pr_aresetn),

      //AXI-Lite interface (to expose registers to control)
      //Write Address Channel  
      .axi_lite_s_ctrl_awaddr    (axi_lite_app_ctrl_awaddr),
      .axi_lite_s_ctrl_awvalid   (axi_lite_app_ctrl_awvalid),
      .axi_lite_s_ctrl_awready   (axi_lite_app_ctrl_awready),
      //Write Data Channel
      .axi_lite_s_ctrl_wdata     (axi_lite_app_ctrl_wdata),
      .axi_lite_s_ctrl_wstrb     (axi_lite_app_ctrl_wstrb),
      .axi_lite_s_ctrl_wvalid    (axi_lite_app_ctrl_wvalid),
      .axi_lite_s_ctrl_wready    (axi_lite_app_ctrl_wready),
      //Write Response Channel
      .axi_lite_s_ctrl_bresp     (axi_lite_app_ctrl_bresp),
      .axi_lite_s_ctrl_bvalid    (axi_lite_app_ctrl_bvalid),
      .axi_lite_s_ctrl_bready    (axi_lite_app_ctrl_bready),
      //Read Address Channel 
      .axi_lite_s_ctrl_araddr    (axi_lite_app_ctrl_araddr),
      .axi_lite_s_ctrl_arvalid   (axi_lite_app_ctrl_arvalid),
      .axi_lite_s_ctrl_arready   (axi_lite_app_ctrl_arready),
      //Read Data Response Channel
      .axi_lite_s_ctrl_rdata     (axi_lite_app_ctrl_rdata),
      .axi_lite_s_ctrl_rresp     (axi_lite_app_ctrl_rresp),
      .axi_lite_s_ctrl_rvalid    (axi_lite_app_ctrl_rvalid),
      .axi_lite_s_ctrl_rready    (axi_lite_app_ctrl_rready),

      //Ctrl Clocking
      .ctrl_aclk                 (ctrl_pr_aclk),
      .ctrl_aresetn              (ctrl_pr_aresetn)
   );




endmodule

`default_nettype wire