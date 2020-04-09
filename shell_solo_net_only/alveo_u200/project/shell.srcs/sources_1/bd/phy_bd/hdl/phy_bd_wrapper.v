//Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2019.1.3 (lin64) Build 2644227 Wed Sep  4 09:44:18 MDT 2019
//Date        : Wed Apr  8 08:52:30 2020
//Host        : agent-3 running 64-bit Ubuntu 16.04.2 LTS
//Command     : generate_target phy_bd_wrapper.bd
//Design      : phy_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module phy_bd_wrapper
   (M_AXI_LITE_araddr,
    M_AXI_LITE_arprot,
    M_AXI_LITE_arready,
    M_AXI_LITE_arvalid,
    M_AXI_LITE_awaddr,
    M_AXI_LITE_awprot,
    M_AXI_LITE_awready,
    M_AXI_LITE_awvalid,
    M_AXI_LITE_bready,
    M_AXI_LITE_bresp,
    M_AXI_LITE_bvalid,
    M_AXI_LITE_rdata,
    M_AXI_LITE_rready,
    M_AXI_LITE_rresp,
    M_AXI_LITE_rvalid,
    M_AXI_LITE_wdata,
    M_AXI_LITE_wready,
    M_AXI_LITE_wstrb,
    M_AXI_LITE_wvalid,
    axis_rx_tdata,
    axis_rx_tkeep,
    axis_rx_tlast,
    axis_rx_tuser,
    axis_rx_tvalid,
    axis_tx_tdata,
    axis_tx_tkeep,
    axis_tx_tlast,
    axis_tx_tready,
    axis_tx_tuser,
    axis_tx_tvalid,
    pci_express_x1_rxn,
    pci_express_x1_rxp,
    pci_express_x1_txn,
    pci_express_x1_txp,
    pcie_aclk,
    pcie_aresetn,
    pcie_perstn,
    pcie_refclk_clk_n,
    pcie_refclk_clk_p,
    qsfp0_156mhz_clk_n,
    qsfp0_156mhz_clk_p,
    qsfp0_1x_grx_n,
    qsfp0_1x_grx_p,
    qsfp0_1x_gtx_n,
    qsfp0_1x_gtx_p,
    qsfp0_aclk,
    qsfp0_aresetn,
    refclk_300mhz_clk_n,
    refclk_300mhz_clk_p);
  output [31:0]M_AXI_LITE_araddr;
  output [2:0]M_AXI_LITE_arprot;
  input M_AXI_LITE_arready;
  output M_AXI_LITE_arvalid;
  output [31:0]M_AXI_LITE_awaddr;
  output [2:0]M_AXI_LITE_awprot;
  input M_AXI_LITE_awready;
  output M_AXI_LITE_awvalid;
  output M_AXI_LITE_bready;
  input [1:0]M_AXI_LITE_bresp;
  input M_AXI_LITE_bvalid;
  input [31:0]M_AXI_LITE_rdata;
  output M_AXI_LITE_rready;
  input [1:0]M_AXI_LITE_rresp;
  input M_AXI_LITE_rvalid;
  output [31:0]M_AXI_LITE_wdata;
  input M_AXI_LITE_wready;
  output [3:0]M_AXI_LITE_wstrb;
  output M_AXI_LITE_wvalid;
  output [63:0]axis_rx_tdata;
  output [7:0]axis_rx_tkeep;
  output axis_rx_tlast;
  output [0:0]axis_rx_tuser;
  output axis_rx_tvalid;
  input [63:0]axis_tx_tdata;
  input [7:0]axis_tx_tkeep;
  input axis_tx_tlast;
  output axis_tx_tready;
  input [0:0]axis_tx_tuser;
  input axis_tx_tvalid;
  input pci_express_x1_rxn;
  input pci_express_x1_rxp;
  output pci_express_x1_txn;
  output pci_express_x1_txp;
  output pcie_aclk;
  output pcie_aresetn;
  input pcie_perstn;
  input pcie_refclk_clk_n;
  input pcie_refclk_clk_p;
  input qsfp0_156mhz_clk_n;
  input qsfp0_156mhz_clk_p;
  input qsfp0_1x_grx_n;
  input qsfp0_1x_grx_p;
  output qsfp0_1x_gtx_n;
  output qsfp0_1x_gtx_p;
  output qsfp0_aclk;
  output qsfp0_aresetn;
  input refclk_300mhz_clk_n;
  input refclk_300mhz_clk_p;

  wire [31:0]M_AXI_LITE_araddr;
  wire [2:0]M_AXI_LITE_arprot;
  wire M_AXI_LITE_arready;
  wire M_AXI_LITE_arvalid;
  wire [31:0]M_AXI_LITE_awaddr;
  wire [2:0]M_AXI_LITE_awprot;
  wire M_AXI_LITE_awready;
  wire M_AXI_LITE_awvalid;
  wire M_AXI_LITE_bready;
  wire [1:0]M_AXI_LITE_bresp;
  wire M_AXI_LITE_bvalid;
  wire [31:0]M_AXI_LITE_rdata;
  wire M_AXI_LITE_rready;
  wire [1:0]M_AXI_LITE_rresp;
  wire M_AXI_LITE_rvalid;
  wire [31:0]M_AXI_LITE_wdata;
  wire M_AXI_LITE_wready;
  wire [3:0]M_AXI_LITE_wstrb;
  wire M_AXI_LITE_wvalid;
  wire [63:0]axis_rx_tdata;
  wire [7:0]axis_rx_tkeep;
  wire axis_rx_tlast;
  wire [0:0]axis_rx_tuser;
  wire axis_rx_tvalid;
  wire [63:0]axis_tx_tdata;
  wire [7:0]axis_tx_tkeep;
  wire axis_tx_tlast;
  wire axis_tx_tready;
  wire [0:0]axis_tx_tuser;
  wire axis_tx_tvalid;
  wire pci_express_x1_rxn;
  wire pci_express_x1_rxp;
  wire pci_express_x1_txn;
  wire pci_express_x1_txp;
  wire pcie_aclk;
  wire pcie_aresetn;
  wire pcie_perstn;
  wire pcie_refclk_clk_n;
  wire pcie_refclk_clk_p;
  wire qsfp0_156mhz_clk_n;
  wire qsfp0_156mhz_clk_p;
  wire qsfp0_1x_grx_n;
  wire qsfp0_1x_grx_p;
  wire qsfp0_1x_gtx_n;
  wire qsfp0_1x_gtx_p;
  wire qsfp0_aclk;
  wire qsfp0_aresetn;
  wire refclk_300mhz_clk_n;
  wire refclk_300mhz_clk_p;

  phy_bd phy_bd_i
       (.M_AXI_LITE_araddr(M_AXI_LITE_araddr),
        .M_AXI_LITE_arprot(M_AXI_LITE_arprot),
        .M_AXI_LITE_arready(M_AXI_LITE_arready),
        .M_AXI_LITE_arvalid(M_AXI_LITE_arvalid),
        .M_AXI_LITE_awaddr(M_AXI_LITE_awaddr),
        .M_AXI_LITE_awprot(M_AXI_LITE_awprot),
        .M_AXI_LITE_awready(M_AXI_LITE_awready),
        .M_AXI_LITE_awvalid(M_AXI_LITE_awvalid),
        .M_AXI_LITE_bready(M_AXI_LITE_bready),
        .M_AXI_LITE_bresp(M_AXI_LITE_bresp),
        .M_AXI_LITE_bvalid(M_AXI_LITE_bvalid),
        .M_AXI_LITE_rdata(M_AXI_LITE_rdata),
        .M_AXI_LITE_rready(M_AXI_LITE_rready),
        .M_AXI_LITE_rresp(M_AXI_LITE_rresp),
        .M_AXI_LITE_rvalid(M_AXI_LITE_rvalid),
        .M_AXI_LITE_wdata(M_AXI_LITE_wdata),
        .M_AXI_LITE_wready(M_AXI_LITE_wready),
        .M_AXI_LITE_wstrb(M_AXI_LITE_wstrb),
        .M_AXI_LITE_wvalid(M_AXI_LITE_wvalid),
        .axis_rx_tdata(axis_rx_tdata),
        .axis_rx_tkeep(axis_rx_tkeep),
        .axis_rx_tlast(axis_rx_tlast),
        .axis_rx_tuser(axis_rx_tuser),
        .axis_rx_tvalid(axis_rx_tvalid),
        .axis_tx_tdata(axis_tx_tdata),
        .axis_tx_tkeep(axis_tx_tkeep),
        .axis_tx_tlast(axis_tx_tlast),
        .axis_tx_tready(axis_tx_tready),
        .axis_tx_tuser(axis_tx_tuser),
        .axis_tx_tvalid(axis_tx_tvalid),
        .pci_express_x1_rxn(pci_express_x1_rxn),
        .pci_express_x1_rxp(pci_express_x1_rxp),
        .pci_express_x1_txn(pci_express_x1_txn),
        .pci_express_x1_txp(pci_express_x1_txp),
        .pcie_aclk(pcie_aclk),
        .pcie_aresetn(pcie_aresetn),
        .pcie_perstn(pcie_perstn),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .pcie_refclk_clk_p(pcie_refclk_clk_p),
        .qsfp0_156mhz_clk_n(qsfp0_156mhz_clk_n),
        .qsfp0_156mhz_clk_p(qsfp0_156mhz_clk_p),
        .qsfp0_1x_grx_n(qsfp0_1x_grx_n),
        .qsfp0_1x_grx_p(qsfp0_1x_grx_p),
        .qsfp0_1x_gtx_n(qsfp0_1x_gtx_n),
        .qsfp0_1x_gtx_p(qsfp0_1x_gtx_p),
        .qsfp0_aclk(qsfp0_aclk),
        .qsfp0_aresetn(qsfp0_aresetn),
        .refclk_300mhz_clk_n(refclk_300mhz_clk_n),
        .refclk_300mhz_clk_p(refclk_300mhz_clk_p));
endmodule
