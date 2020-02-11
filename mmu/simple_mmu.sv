`timescale 1ns / 1ps
`default_nettype none

/*
Simple MMU Module

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This simple MMU simply splits the memory space equally between all
   of the accessors. The number of accessors is simply determined by the
   difference between the input and output address signal widths. The MSBs 
   of the AXI ID field is used to identify the accessor. Note, zero widths 
   for any of the signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_IN_ADDR_WIDTH - the width of the input address field
   AXI_OUT_ADDR_WIDTH - the width of the output address field
   AXI_DATA_WIDTH - the width of the data path

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module simple_mmu
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 5,
    parameter AXI_IN_ADDR_WIDTH = 31,
    parameter AXI_OUT_ADDR_WIDTH = 33,
    parameter AXI_DATA_WIDTH = 128
    
    //MMU parameterization
    //parameter ID_BITS_USED = AXI_OUT_ADDR_WIDTH-AXI_IN_ADDR_WIDTH, //should only ever use default value
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      axi_s_awaddr,
    input wire [7:0]                        axi_s_awlen,
    input wire [2:0]                        axi_s_awsize,
    input wire [1:0]                        axi_s_awburst,
    input wire                              axi_s_awvalid,
    output wire                             axi_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_s_wstrb,
    input wire                              axi_s_wlast,
    input wire                              axi_s_wvalid,
    output wire                             axi_s_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_bid,
    output wire [1:0]                       axi_s_bresp,
    output wire                             axi_s_bvalid,
    input wire                              axi_s_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_arid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      axi_s_araddr,
    input wire [7:0]                        axi_s_arlen,
    input wire [2:0]                        axi_s_arsize,
    input wire [1:0]                        axi_s_arburst,
    input wire                              axi_s_arvalid,
    output wire                             axi_s_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_rid,
    output wire [AXI_DATA_WIDTH-1:0]        axi_s_rdata,
    output wire [1:0]                       axi_s_rresp,
    output wire                             axi_s_rlast,
    output wire                             axi_s_rvalid,
    input wire                              axi_s_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output wire [2:0]                       axi_m_awsize,
    output wire [1:0]                       axi_m_awburst,
    output wire                             axi_m_awvalid,
    input wire                              axi_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_m_wstrb,
    output wire                             axi_m_wlast,
    output wire                             axi_m_wvalid,
    input wire                              axi_m_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_bid,
    input wire [1:0]                        axi_m_bresp,
    input wire                              axi_m_bvalid,
    output wire                             axi_m_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_arid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    axi_m_araddr,
    output wire [7:0]                       axi_m_arlen,
    output wire [2:0]                       axi_m_arsize,
    output wire [1:0]                       axi_m_arburst,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

	localparam ID_BITS_USED = AXI_OUT_ADDR_WIDTH-AXI_IN_ADDR_WIDTH,

    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//
    
    //Assign output values that don't need to be remapped
    assign axi_m_awid = axi_s_awid;
    assign axi_m_awburst = axi_s_awburst;
    assign axi_m_awsize = axi_s_awsize;
    assign axi_m_awlen = axi_s_awlen;
    assign axi_m_awvalid = axi_s_awvalid;
    assign axi_s_awready = axi_m_awready;

    //Calculate remapped address
    wire [AXI_OUT_ADDR_WIDTH-1:0] remapped_awaddr = 
    	{ axi_s_awid[AXI_ID_WIDTH-1-:ID_BITS_USED], axi_s_awaddr };

    assign axi_m_awaddr = remapped_awaddr;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign axi_m_wdata = axi_s_wdata;
    assign axi_m_wstrb = axi_s_wstrb;
    assign axi_m_wlast = axi_s_wlast;
    assign axi_m_wvalid = axi_s_wvalid;
    assign axi_s_wready = axi_m_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign axi_m_bready = axi_s_bready;
    assign axi_s_bid = axi_m_bid;
    assign axi_s_bresp = axi_m_bresp;
    assign axi_s_bvalid = axi_m_bvalid;
        
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Assign output values that don't need to be remapped
    assign axi_m_arid = axi_s_arid;
    assign axi_m_arburst = axi_s_arburst;
    assign axi_m_arsize = axi_s_arsize;
    assign axi_m_arlen = axi_s_arlen;
    assign axi_m_arvalid = axi_s_arvalid;
    assign axi_s_arready = axi_m_arready;

    //Calculate remapped address
    wire [AXI_OUT_ADDR_WIDTH-1:0] remapped_araddr = 
    	{ axi_s_arid[AXI_ID_WIDTH-1-:ID_BITS_USED], axi_s_araddr };

    assign axi_m_araddr = remapped_araddr;
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//

    //Nothing to do, simply forward
    assign axi_m_rready = axi_s_rready;
    assign axi_s_rid = axi_m_rid;
    assign axi_s_rdata = axi_m_rdata;
    assign axi_s_rresp = axi_m_rresp;
    assign axi_s_rlast = axi_m_rlast;
    assign axi_s_rvalid = axi_m_rvalid;



endmodule

`default_nettype wire