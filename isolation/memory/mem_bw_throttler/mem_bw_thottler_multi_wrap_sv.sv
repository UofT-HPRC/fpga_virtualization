`timescale 1ns / 1ps
`default_nettype none


//Number of masters
`define NUM_MASTERS 4
`define INC_M1
`define INC_M2
`define INC_M3
`define INC_M4
//`define INC_M5
//`define INC_M6
//`define INC_M7
//`define INC_M8

//The memory prtocol checker/corrector
module mem_bw_throttler_multi_wrap_sv
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_AX_USER_WIDTH = 1,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam BW_THROT_BITS_PER_MAST = (TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH + 1) * 2,
    localparam BW_THROT_REG_WIDTH =  BW_THROT_BITS_PER_MAST * `NUM_MASTERS,

    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,

    //Retiming for adders
    parameter AW_RETIMING_STAGES = 0,
    parameter AR_RETIMING_STAGES = 0,

    //Features to Implement
    parameter ALLOW_OVERRIDE = 1,
    parameter INCLUDE_BACKPRESSURE = 0
)
(

`ifdef INC_M1

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in1_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in1_awaddr,
    input wire [7:0]                        in1_awlen,
    input wire [2:0]                        in1_awsize,
    input wire [1:0]                        in1_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in1_awuser,
    input wire                              in1_awvalid,
    output wire                             in1_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in1_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in1_wstrb,
    input wire                              in1_wlast,
    input wire                              in1_wvalid,
    output wire                             in1_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in1_bid,
    output wire [1:0]                       in1_bresp,
    output wire                             in1_bvalid,
    input wire                              in1_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in1_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in1_araddr,
    input wire [7:0]                        in1_arlen,
    input wire [2:0]                        in1_arsize,
    input wire [1:0]                        in1_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in1_aruser,
    input wire                              in1_arvalid,
    output wire                             in1_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in1_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in1_rdata,
    output wire [1:0]                       in1_rresp,
    output wire                             in1_rlast,
    output wire                             in1_rvalid,
    input wire                              in1_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out1_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out1_awaddr,
    output wire [7:0]                       out1_awlen,
    output wire [2:0]                       out1_awsize,
    output wire [1:0]                       out1_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out1_awuser,
    output wire                             out1_awvalid,
    input wire                              out1_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out1_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out1_wstrb,
    output wire                             out1_wlast,
    output wire                             out1_wvalid,
    input wire                              out1_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out1_bid,
    input wire [1:0]                        out1_bresp,
    input wire                              out1_bvalid,
    output wire                             out1_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out1_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out1_araddr,
    output wire [7:0]                       out1_arlen,
    output wire [2:0]                       out1_arsize,
    output wire [1:0]                       out1_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out1_aruser,
    output wire                             out1_arvalid,
    input wire                              out1_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out1_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out1_rdata,
    input wire [1:0]                        out1_rresp,
    input wire                              out1_rlast,
    input wire                              out1_rvalid,
    output wire                             out1_rready,

`endif

`ifdef INC_M2

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in2_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in2_awaddr,
    input wire [7:0]                        in2_awlen,
    input wire [2:0]                        in2_awsize,
    input wire [1:0]                        in2_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in2_awuser,
    input wire                              in2_awvalid,
    output wire                             in2_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in2_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in2_wstrb,
    input wire                              in2_wlast,
    input wire                              in2_wvalid,
    output wire                             in2_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in2_bid,
    output wire [1:0]                       in2_bresp,
    output wire                             in2_bvalid,
    input wire                              in2_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in2_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in2_araddr,
    input wire [7:0]                        in2_arlen,
    input wire [2:0]                        in2_arsize,
    input wire [1:0]                        in2_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in2_aruser,
    input wire                              in2_arvalid,
    output wire                             in2_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in2_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in2_rdata,
    output wire [1:0]                       in2_rresp,
    output wire                             in2_rlast,
    output wire                             in2_rvalid,
    input wire                              in2_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out2_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out2_awaddr,
    output wire [7:0]                       out2_awlen,
    output wire [2:0]                       out2_awsize,
    output wire [1:0]                       out2_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out2_awuser,
    output wire                             out2_awvalid,
    input wire                              out2_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out2_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out2_wstrb,
    output wire                             out2_wlast,
    output wire                             out2_wvalid,
    input wire                              out2_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out2_bid,
    input wire [1:0]                        out2_bresp,
    input wire                              out2_bvalid,
    output wire                             out2_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out2_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out2_araddr,
    output wire [7:0]                       out2_arlen,
    output wire [2:0]                       out2_arsize,
    output wire [1:0]                       out2_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out2_aruser,
    output wire                             out2_arvalid,
    input wire                              out2_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out2_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out2_rdata,
    input wire [1:0]                        out2_rresp,
    input wire                              out2_rlast,
    input wire                              out2_rvalid,
    output wire                             out2_rready,

`endif

`ifdef INC_M3

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in3_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in3_awaddr,
    input wire [7:0]                        in3_awlen,
    input wire [2:0]                        in3_awsize,
    input wire [1:0]                        in3_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in3_awuser,
    input wire                              in3_awvalid,
    output wire                             in3_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in3_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in3_wstrb,
    input wire                              in3_wlast,
    input wire                              in3_wvalid,
    output wire                             in3_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in3_bid,
    output wire [1:0]                       in3_bresp,
    output wire                             in3_bvalid,
    input wire                              in3_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in3_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in3_araddr,
    input wire [7:0]                        in3_arlen,
    input wire [2:0]                        in3_arsize,
    input wire [1:0]                        in3_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in3_aruser,
    input wire                              in3_arvalid,
    output wire                             in3_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in3_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in3_rdata,
    output wire [1:0]                       in3_rresp,
    output wire                             in3_rlast,
    output wire                             in3_rvalid,
    input wire                              in3_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out3_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out3_awaddr,
    output wire [7:0]                       out3_awlen,
    output wire [2:0]                       out3_awsize,
    output wire [1:0]                       out3_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out3_awuser,
    output wire                             out3_awvalid,
    input wire                              out3_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out3_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out3_wstrb,
    output wire                             out3_wlast,
    output wire                             out3_wvalid,
    input wire                              out3_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out3_bid,
    input wire [1:0]                        out3_bresp,
    input wire                              out3_bvalid,
    output wire                             out3_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out3_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out3_araddr,
    output wire [7:0]                       out3_arlen,
    output wire [2:0]                       out3_arsize,
    output wire [1:0]                       out3_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out3_aruser,
    output wire                             out3_arvalid,
    input wire                              out3_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out3_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out3_rdata,
    input wire [1:0]                        out3_rresp,
    input wire                              out3_rlast,
    input wire                              out3_rvalid,
    output wire                             out3_rready,

`endif

`ifdef INC_M4

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in4_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in4_awaddr,
    input wire [7:0]                        in4_awlen,
    input wire [2:0]                        in4_awsize,
    input wire [1:0]                        in4_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in4_awuser,
    input wire                              in4_awvalid,
    output wire                             in4_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in4_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in4_wstrb,
    input wire                              in4_wlast,
    input wire                              in4_wvalid,
    output wire                             in4_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in4_bid,
    output wire [1:0]                       in4_bresp,
    output wire                             in4_bvalid,
    input wire                              in4_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in4_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in4_araddr,
    input wire [7:0]                        in4_arlen,
    input wire [2:0]                        in4_arsize,
    input wire [1:0]                        in4_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in4_aruser,
    input wire                              in4_arvalid,
    output wire                             in4_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in4_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in4_rdata,
    output wire [1:0]                       in4_rresp,
    output wire                             in4_rlast,
    output wire                             in4_rvalid,
    input wire                              in4_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out4_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out4_awaddr,
    output wire [7:0]                       out4_awlen,
    output wire [2:0]                       out4_awsize,
    output wire [1:0]                       out4_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out4_awuser,
    output wire                             out4_awvalid,
    input wire                              out4_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out4_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out4_wstrb,
    output wire                             out4_wlast,
    output wire                             out4_wvalid,
    input wire                              out4_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out4_bid,
    input wire [1:0]                        out4_bresp,
    input wire                              out4_bvalid,
    output wire                             out4_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out4_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out4_araddr,
    output wire [7:0]                       out4_arlen,
    output wire [2:0]                       out4_arsize,
    output wire [1:0]                       out4_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out4_aruser,
    output wire                             out4_arvalid,
    input wire                              out4_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out4_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out4_rdata,
    input wire [1:0]                        out4_rresp,
    input wire                              out4_rlast,
    input wire                              out4_rvalid,
    output wire                             out4_rready,

`endif

`ifdef INC_M5

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in5_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in5_awaddr,
    input wire [7:0]                        in5_awlen,
    input wire [2:0]                        in5_awsize,
    input wire [1:0]                        in5_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in5_awuser,
    input wire                              in5_awvalid,
    output wire                             in5_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in5_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in5_wstrb,
    input wire                              in5_wlast,
    input wire                              in5_wvalid,
    output wire                             in5_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in5_bid,
    output wire [1:0]                       in5_bresp,
    output wire                             in5_bvalid,
    input wire                              in5_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in5_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in5_araddr,
    input wire [7:0]                        in5_arlen,
    input wire [2:0]                        in5_arsize,
    input wire [1:0]                        in5_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in5_aruser,
    input wire                              in5_arvalid,
    output wire                             in5_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in5_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in5_rdata,
    output wire [1:0]                       in5_rresp,
    output wire                             in5_rlast,
    output wire                             in5_rvalid,
    input wire                              in5_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out5_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out5_awaddr,
    output wire [7:0]                       out5_awlen,
    output wire [2:0]                       out5_awsize,
    output wire [1:0]                       out5_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out5_awuser,
    output wire                             out5_awvalid,
    input wire                              out5_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out5_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out5_wstrb,
    output wire                             out5_wlast,
    output wire                             out5_wvalid,
    input wire                              out5_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out5_bid,
    input wire [1:0]                        out5_bresp,
    input wire                              out5_bvalid,
    output wire                             out5_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out5_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out5_araddr,
    output wire [7:0]                       out5_arlen,
    output wire [2:0]                       out5_arsize,
    output wire [1:0]                       out5_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out5_aruser,
    output wire                             out5_arvalid,
    input wire                              out5_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out5_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out5_rdata,
    input wire [1:0]                        out5_rresp,
    input wire                              out5_rlast,
    input wire                              out5_rvalid,
    output wire                             out5_rready,

`endif

`ifdef INC_M6

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in6_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in6_awaddr,
    input wire [7:0]                        in6_awlen,
    input wire [2:0]                        in6_awsize,
    input wire [1:0]                        in6_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in6_awuser,
    input wire                              in6_awvalid,
    output wire                             in6_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in6_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in6_wstrb,
    input wire                              in6_wlast,
    input wire                              in6_wvalid,
    output wire                             in6_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in6_bid,
    output wire [1:0]                       in6_bresp,
    output wire                             in6_bvalid,
    input wire                              in6_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in6_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in6_araddr,
    input wire [7:0]                        in6_arlen,
    input wire [2:0]                        in6_arsize,
    input wire [1:0]                        in6_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in6_aruser,
    input wire                              in6_arvalid,
    output wire                             in6_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in6_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in6_rdata,
    output wire [1:0]                       in6_rresp,
    output wire                             in6_rlast,
    output wire                             in6_rvalid,
    input wire                              in6_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out6_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out6_awaddr,
    output wire [7:0]                       out6_awlen,
    output wire [2:0]                       out6_awsize,
    output wire [1:0]                       out6_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out6_awuser,
    output wire                             out6_awvalid,
    input wire                              out6_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out6_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out6_wstrb,
    output wire                             out6_wlast,
    output wire                             out6_wvalid,
    input wire                              out6_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out6_bid,
    input wire [1:0]                        out6_bresp,
    input wire                              out6_bvalid,
    output wire                             out6_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out6_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out6_araddr,
    output wire [7:0]                       out6_arlen,
    output wire [2:0]                       out6_arsize,
    output wire [1:0]                       out6_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out6_aruser,
    output wire                             out6_arvalid,
    input wire                              out6_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out6_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out6_rdata,
    input wire [1:0]                        out6_rresp,
    input wire                              out6_rlast,
    input wire                              out6_rvalid,
    output wire                             out6_rready,

`endif

`ifdef INC_M7

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in7_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in7_awaddr,
    input wire [7:0]                        in7_awlen,
    input wire [2:0]                        in7_awsize,
    input wire [1:0]                        in7_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in7_awuser,
    input wire                              in7_awvalid,
    output wire                             in7_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in7_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in7_wstrb,
    input wire                              in7_wlast,
    input wire                              in7_wvalid,
    output wire                             in7_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in7_bid,
    output wire [1:0]                       in7_bresp,
    output wire                             in7_bvalid,
    input wire                              in7_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in7_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in7_araddr,
    input wire [7:0]                        in7_arlen,
    input wire [2:0]                        in7_arsize,
    input wire [1:0]                        in7_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in7_aruser,
    input wire                              in7_arvalid,
    output wire                             in7_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in7_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in7_rdata,
    output wire [1:0]                       in7_rresp,
    output wire                             in7_rlast,
    output wire                             in7_rvalid,
    input wire                              in7_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out7_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out7_awaddr,
    output wire [7:0]                       out7_awlen,
    output wire [2:0]                       out7_awsize,
    output wire [1:0]                       out7_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out7_awuser,
    output wire                             out7_awvalid,
    input wire                              out7_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out7_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out7_wstrb,
    output wire                             out7_wlast,
    output wire                             out7_wvalid,
    input wire                              out7_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out7_bid,
    input wire [1:0]                        out7_bresp,
    input wire                              out7_bvalid,
    output wire                             out7_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out7_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out7_araddr,
    output wire [7:0]                       out7_arlen,
    output wire [2:0]                       out7_arsize,
    output wire [1:0]                       out7_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out7_aruser,
    output wire                             out7_arvalid,
    input wire                              out7_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out7_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out7_rdata,
    input wire [1:0]                        out7_rresp,
    input wire                              out7_rlast,
    input wire                              out7_rvalid,
    output wire                             out7_rready,

`endif

`ifdef INC_M8

    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in8_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         in8_awaddr,
    input wire [7:0]                        in8_awlen,
    input wire [2:0]                        in8_awsize,
    input wire [1:0]                        in8_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in8_awuser,
    input wire                              in8_awvalid,
    output wire                             in8_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in8_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in8_wstrb,
    input wire                              in8_wlast,
    input wire                              in8_wvalid,
    output wire                             in8_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in8_bid,
    output wire [1:0]                       in8_bresp,
    output wire                             in8_bvalid,
    input wire                              in8_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in8_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         in8_araddr,
    input wire [7:0]                        in8_arlen,
    input wire [2:0]                        in8_arsize,
    input wire [1:0]                        in8_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      in8_aruser,
    input wire                              in8_arvalid,
    output wire                             in8_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in8_rid,
    output wire [AXI_DATA_WIDTH-1:0]        in8_rdata,
    output wire [1:0]                       in8_rresp,
    output wire                             in8_rlast,
    output wire                             in8_rvalid,
    input wire                              in8_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out8_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        out8_awaddr,
    output wire [7:0]                       out8_awlen,
    output wire [2:0]                       out8_awsize,
    output wire [1:0]                       out8_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out8_awuser,
    output wire                             out8_awvalid,
    input wire                              out8_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out8_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out8_wstrb,
    output wire                             out8_wlast,
    output wire                             out8_wvalid,
    input wire                              out8_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out8_bid,
    input wire [1:0]                        out8_bresp,
    input wire                              out8_bvalid,
    output wire                             out8_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out8_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        out8_araddr,
    output wire [7:0]                       out8_arlen,
    output wire [2:0]                       out8_arsize,
    output wire [1:0]                       out8_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     out8_aruser,
    output wire                             out8_arvalid,
    input wire                              out8_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out8_rid,
    input wire [AXI_DATA_WIDTH-1:0]         out8_rdata,
    input wire [1:0]                        out8_rresp,
    input wire                              out8_rlast,
    input wire                              out8_rvalid,
    output wire                             out8_rready,

`endif

    //Packed Register signals
    input wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*2*`NUM_MASTERS)-1:0]     
                                            bw_throt_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Input signal declarations                            //
    //--------------------------------------------------------//
    
    //AXI4 slave connection (input of requests)
    //Write Address Channel
    wire [AXI_ID_WIDTH-1:0]           in_all_awid [`NUM_MASTERS-1:0];
    wire [AXI_ADDR_WIDTH-1:0]         in_all_awaddr [`NUM_MASTERS-1:0];
    wire [7:0]                        in_all_awlen [`NUM_MASTERS-1:0];
    wire [2:0]                        in_all_awsize [`NUM_MASTERS-1:0];
    wire [1:0]                        in_all_awburst [`NUM_MASTERS-1:0];
    wire [AXI_AX_USER_WIDTH-1:0]      in_all_awuser [`NUM_MASTERS-1:0];
    wire                              in_all_awvalid [`NUM_MASTERS-1:0];
    wire                              in_all_awready [`NUM_MASTERS-1:0];
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]         in_all_wdata [`NUM_MASTERS-1:0];
    wire [(AXI_DATA_WIDTH/8)-1:0]     in_all_wstrb [`NUM_MASTERS-1:0];
    wire                              in_all_wlast [`NUM_MASTERS-1:0];
    wire                              in_all_wvalid [`NUM_MASTERS-1:0];
    wire                              in_all_wready [`NUM_MASTERS-1:0];
    //Write Response Channel
    wire [AXI_ID_WIDTH-1:0]           in_all_bid [`NUM_MASTERS-1:0];
    wire [1:0]                        in_all_bresp [`NUM_MASTERS-1:0];
    wire                              in_all_bvalid [`NUM_MASTERS-1:0];
    wire                              in_all_bready [`NUM_MASTERS-1:0];
    //Read Address Channel     
    wire [AXI_ID_WIDTH-1:0]           in_all_arid [`NUM_MASTERS-1:0];
    wire [AXI_ADDR_WIDTH-1:0]         in_all_araddr [`NUM_MASTERS-1:0];
    wire [7:0]                        in_all_arlen [`NUM_MASTERS-1:0];
    wire [2:0]                        in_all_arsize [`NUM_MASTERS-1:0];
    wire [1:0]                        in_all_arburst [`NUM_MASTERS-1:0];
    wire [AXI_AX_USER_WIDTH-1:0]      in_all_aruser [`NUM_MASTERS-1:0];
    wire                              in_all_arvalid [`NUM_MASTERS-1:0];
    wire                              in_all_arready [`NUM_MASTERS-1:0];
    //Read Data Response Channel
    wire [AXI_ID_WIDTH-1:0]           in_all_rid [`NUM_MASTERS-1:0];
    wire [AXI_DATA_WIDTH-1:0]         in_all_rdata [`NUM_MASTERS-1:0];
    wire [1:0]                        in_all_rresp [`NUM_MASTERS-1:0];
    wire                              in_all_rlast [`NUM_MASTERS-1:0];
    wire                              in_all_rvalid [`NUM_MASTERS-1:0];
    wire                              in_all_rready [`NUM_MASTERS-1:0];

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    wire [AXI_ID_WIDTH-1:0]           out_all_awid [`NUM_MASTERS-1:0];
    wire [AXI_ADDR_WIDTH-1:0]         out_all_awaddr [`NUM_MASTERS-1:0];
    wire [7:0]                        out_all_awlen [`NUM_MASTERS-1:0];
    wire [2:0]                        out_all_awsize [`NUM_MASTERS-1:0];
    wire [1:0]                        out_all_awburst [`NUM_MASTERS-1:0];
    wire [AXI_AX_USER_WIDTH-1:0]      out_all_awuser [`NUM_MASTERS-1:0];
    wire                              out_all_awvalid [`NUM_MASTERS-1:0];
    wire                              out_all_awready [`NUM_MASTERS-1:0];
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]         out_all_wdata [`NUM_MASTERS-1:0];
    wire [(AXI_DATA_WIDTH/8)-1:0]     out_all_wstrb [`NUM_MASTERS-1:0];
    wire                              out_all_wlast [`NUM_MASTERS-1:0];
    wire                              out_all_wvalid [`NUM_MASTERS-1:0];
    wire                              out_all_wready [`NUM_MASTERS-1:0];
    //Write Response Channel
    wire [AXI_ID_WIDTH-1:0]           out_all_bid [`NUM_MASTERS-1:0];
    wire [1:0]                        out_all_bresp [`NUM_MASTERS-1:0];
    wire                              out_all_bvalid [`NUM_MASTERS-1:0];
    wire                              out_all_bready [`NUM_MASTERS-1:0];
    //Read Address Channel     
    wire [AXI_ID_WIDTH-1:0]           out_all_arid [`NUM_MASTERS-1:0];
    wire [AXI_ADDR_WIDTH-1:0]         out_all_araddr [`NUM_MASTERS-1:0];
    wire [7:0]                        out_all_arlen [`NUM_MASTERS-1:0];
    wire [2:0]                        out_all_arsize [`NUM_MASTERS-1:0];
    wire [1:0]                        out_all_arburst [`NUM_MASTERS-1:0];
    wire [AXI_AX_USER_WIDTH-1:0]      out_all_aruser [`NUM_MASTERS-1:0];
    wire                              out_all_arvalid [`NUM_MASTERS-1:0];
    wire                              out_all_arready [`NUM_MASTERS-1:0];
    //Read Data Response Channel
    wire [AXI_ID_WIDTH-1:0]           out_all_rid [`NUM_MASTERS-1:0];
    wire [AXI_DATA_WIDTH-1:0]         out_all_rdata [`NUM_MASTERS-1:0];
    wire [1:0]                        out_all_rresp [`NUM_MASTERS-1:0];
    wire                              out_all_rlast [`NUM_MASTERS-1:0];
    wire                              out_all_rvalid [`NUM_MASTERS-1:0];
    wire                              out_all_rready [`NUM_MASTERS-1:0];



    //--------------------------------------------------------//
    //   AXI Input Assignments                                //
    //--------------------------------------------------------//    

`ifdef INC_M1

    assign in_all_awid[0] = in1_awid;
    assign in_all_awaddr[0] = in1_awaddr;
    assign in_all_awlen[0] = in1_awlen;
    assign in_all_awsize[0] = in1_awsize;
    assign in_all_awburst[0] = in1_awburst;
    assign in_all_awuser[0] = in1_awuser;
    assign in_all_awvalid[0] = in1_awvalid;
    assign in1_awready = in_all_awready[0];

    assign in_all_wdata[0] = in1_wdata;
    assign in_all_wstrb[0] = in1_wstrb;
    assign in_all_wlast[0] = in1_wlast;
    assign in_all_wvalid[0] = in1_wvalid;
    assign in1_wready = in_all_wready[0];

    assign in1_bid = in_all_bid[0];
    assign in1_bresp = in_all_bresp[0];
    assign in1_bvalid = in_all_bvalid[0];
    assign in_all_bready[0] = in1_bready;

    assign in_all_arid[0] = in1_arid;
    assign in_all_araddr[0] = in1_araddr;
    assign in_all_arlen[0] = in1_arlen;
    assign in_all_arsize[0] = in1_arsize;
    assign in_all_arburst[0] = in1_arburst;
    assign in_all_aruser[0] = in1_aruser;
    assign in_all_arvalid[0] = in1_arvalid;
    assign in1_arready = in_all_arready[0];

    assign in1_rid = in_all_rid[0];
    assign in1_rdata = in_all_rdata[0];
    assign in1_rresp = in_all_rresp[0];
    assign in1_rlast = in_all_rlast[0];
    assign in1_rvalid = in_all_rvalid[0];
    assign in_all_rready[0] = in1_rready;



    assign out1_awid = out_all_awid[0];
    assign out1_awaddr = out_all_awaddr[0];
    assign out1_awlen = out_all_awlen[0];
    assign out1_awsize = out_all_awsize[0];
    assign out1_awburst = out_all_awburst[0];
    assign out1_awuser = out_all_awuser[0];
    assign out1_awvalid = out_all_awvalid[0];
    assign out_all_awready[0] = out1_awready;

    assign out1_wdata = out_all_wdata[0];
    assign out1_wstrb = out_all_wstrb[0];
    assign out1_wlast = out_all_wlast[0];
    assign out1_wvalid = out_all_wvalid[0];
    assign out_all_wready[0] = out1_wready;

    assign out_all_bid[0] = out1_bid;
    assign out_all_bresp[0] = out1_bresp;
    assign out_all_bvalid[0] = out1_bvalid;
    assign out1_bready = out_all_bready[0];

    assign out1_arid = out_all_arid[0];
    assign out1_araddr = out_all_araddr[0];
    assign out1_arlen = out_all_arlen[0];
    assign out1_arsize = out_all_arsize[0];
    assign out1_arburst = out_all_arburst[0];
    assign out1_aruser = out_all_aruser[0];
    assign out1_arvalid = out_all_arvalid[0];
    assign out_all_arready[0] = out1_arready;

    assign out_all_rid[0] = out1_rid;
    assign out_all_rdata[0] = out1_rdata;
    assign out_all_rresp[0] = out1_rresp;
    assign out_all_rlast[0] = out1_rlast;
    assign out_all_rvalid[0] = out1_rvalid;
    assign out1_rready = out_all_rready[0];

`endif

`ifdef INC_M2

    assign in_all_awid[1] = in2_awid;
    assign in_all_awaddr[1] = in2_awaddr;
    assign in_all_awlen[1] = in2_awlen;
    assign in_all_awsize[1] = in2_awsize;
    assign in_all_awburst[1] = in2_awburst;
    assign in_all_awuser[1] = in2_awuser;
    assign in_all_awvalid[1] = in2_awvalid;
    assign in2_awready = in_all_awready[1];

    assign in_all_wdata[1] = in2_wdata;
    assign in_all_wstrb[1] = in2_wstrb;
    assign in_all_wlast[1] = in2_wlast;
    assign in_all_wvalid[1] = in2_wvalid;
    assign in2_wready = in_all_wready[1];

    assign in2_bid = in_all_bid[1];
    assign in2_bresp = in_all_bresp[1];
    assign in2_bvalid = in_all_bvalid[1];
    assign in_all_bready[1] = in2_bready;

    assign in_all_arid[1] = in2_arid;
    assign in_all_araddr[1] = in2_araddr;
    assign in_all_arlen[1] = in2_arlen;
    assign in_all_arsize[1] = in2_arsize;
    assign in_all_arburst[1] = in2_arburst;
    assign in_all_aruser[1] = in2_aruser;
    assign in_all_arvalid[1] = in2_arvalid;
    assign in2_arready = in_all_arready[1];

    assign in2_rid = in_all_rid[1];
    assign in2_rdata = in_all_rdata[1];
    assign in2_rresp = in_all_rresp[1];
    assign in2_rlast = in_all_rlast[1];
    assign in2_rvalid = in_all_rvalid[1];
    assign in_all_rready[1] = in2_rready;



    assign out2_awid = out_all_awid[1];
    assign out2_awaddr = out_all_awaddr[1];
    assign out2_awlen = out_all_awlen[1];
    assign out2_awsize = out_all_awsize[1];
    assign out2_awburst = out_all_awburst[1];
    assign out2_awuser = out_all_awuser[1];
    assign out2_awvalid = out_all_awvalid[1];
    assign out_all_awready[1] = out2_awready;

    assign out2_wdata = out_all_wdata[1];
    assign out2_wstrb = out_all_wstrb[1];
    assign out2_wlast = out_all_wlast[1];
    assign out2_wvalid = out_all_wvalid[1];
    assign out_all_wready[1] = out2_wready;

    assign out_all_bid[1] = out2_bid;
    assign out_all_bresp[1] = out2_bresp;
    assign out_all_bvalid[1] = out2_bvalid;
    assign out2_bready = out_all_bready[1];

    assign out2_arid = out_all_arid[1];
    assign out2_araddr = out_all_araddr[1];
    assign out2_arlen = out_all_arlen[1];
    assign out2_arsize = out_all_arsize[1];
    assign out2_arburst = out_all_arburst[1];
    assign out2_aruser = out_all_aruser[1];
    assign out2_arvalid = out_all_arvalid[1];
    assign out_all_arready[1] = out2_arready;

    assign out_all_rid[1] = out2_rid;
    assign out_all_rdata[1] = out2_rdata;
    assign out_all_rresp[1] = out2_rresp;
    assign out_all_rlast[1] = out2_rlast;
    assign out_all_rvalid[1] = out2_rvalid;
    assign out2_rready = out_all_rready[1];

`endif 

`ifdef INC_M3

    assign in_all_awid[2] = in3_awid;
    assign in_all_awaddr[2] = in3_awaddr;
    assign in_all_awlen[2] = in3_awlen;
    assign in_all_awsize[2] = in3_awsize;
    assign in_all_awburst[2] = in3_awburst;
    assign in_all_awuser[2] = in3_awuser;
    assign in_all_awvalid[2] = in3_awvalid;
    assign in3_awready = in_all_awready[2];

    assign in_all_wdata[2] = in3_wdata;
    assign in_all_wstrb[2] = in3_wstrb;
    assign in_all_wlast[2] = in3_wlast;
    assign in_all_wvalid[2] = in3_wvalid;
    assign in3_wready = in_all_wready[2];

    assign in3_bid = in_all_bid[2];
    assign in3_bresp = in_all_bresp[2];
    assign in3_bvalid = in_all_bvalid[2];
    assign in_all_bready[2] = in3_bready;

    assign in_all_arid[2] = in3_arid;
    assign in_all_araddr[2] = in3_araddr;
    assign in_all_arlen[2] = in3_arlen;
    assign in_all_arsize[2] = in3_arsize;
    assign in_all_arburst[2] = in3_arburst;
    assign in_all_aruser[2] = in3_aruser;
    assign in_all_arvalid[2] = in3_arvalid;
    assign in3_arready = in_all_arready[2];

    assign in3_rid = in_all_rid[2];
    assign in3_rdata = in_all_rdata[2];
    assign in3_rresp = in_all_rresp[2];
    assign in3_rlast = in_all_rlast[2];
    assign in3_rvalid = in_all_rvalid[2];
    assign in_all_rready[2] = in3_rready;



    assign out3_awid = out_all_awid[2];
    assign out3_awaddr = out_all_awaddr[2];
    assign out3_awlen = out_all_awlen[2];
    assign out3_awsize = out_all_awsize[2];
    assign out3_awburst = out_all_awburst[2];
    assign out3_awuser = out_all_awuser[2];
    assign out3_awvalid = out_all_awvalid[2];
    assign out_all_awready[2] = out3_awready;

    assign out3_wdata = out_all_wdata[2];
    assign out3_wstrb = out_all_wstrb[2];
    assign out3_wlast = out_all_wlast[2];
    assign out3_wvalid = out_all_wvalid[2];
    assign out_all_wready[2] = out3_wready;

    assign out_all_bid[2] = out3_bid;
    assign out_all_bresp[2] = out3_bresp;
    assign out_all_bvalid[2] = out3_bvalid;
    assign out3_bready = out_all_bready[2];

    assign out3_arid = out_all_arid[2];
    assign out3_araddr = out_all_araddr[2];
    assign out3_arlen = out_all_arlen[2];
    assign out3_arsize = out_all_arsize[2];
    assign out3_arburst = out_all_arburst[2];
    assign out3_aruser = out_all_aruser[2];
    assign out3_arvalid = out_all_arvalid[2];
    assign out_all_arready[2] = out3_arready;

    assign out_all_rid[2] = out3_rid;
    assign out_all_rdata[2] = out3_rdata;
    assign out_all_rresp[2] = out3_rresp;
    assign out_all_rlast[2] = out3_rlast;
    assign out_all_rvalid[2] = out3_rvalid;
    assign out3_rready = out_all_rready[2];

`endif 

`ifdef INC_M4

    assign in_all_awid[3] = in4_awid;
    assign in_all_awaddr[3] = in4_awaddr;
    assign in_all_awlen[3] = in4_awlen;
    assign in_all_awsize[3] = in4_awsize;
    assign in_all_awburst[3] = in4_awburst;
    assign in_all_awuser[3] = in4_awuser;
    assign in_all_awvalid[3] = in4_awvalid;
    assign in4_awready = in_all_awready[3];

    assign in_all_wdata[3] = in4_wdata;
    assign in_all_wstrb[3] = in4_wstrb;
    assign in_all_wlast[3] = in4_wlast;
    assign in_all_wvalid[3] = in4_wvalid;
    assign in4_wready = in_all_wready[3];

    assign in4_bid = in_all_bid[3];
    assign in4_bresp = in_all_bresp[3];
    assign in4_bvalid = in_all_bvalid[3];
    assign in_all_bready[3] = in4_bready;

    assign in_all_arid[3] = in4_arid;
    assign in_all_araddr[3] = in4_araddr;
    assign in_all_arlen[3] = in4_arlen;
    assign in_all_arsize[3] = in4_arsize;
    assign in_all_arburst[3] = in4_arburst;
    assign in_all_aruser[3] = in4_aruser;
    assign in_all_arvalid[3] = in4_arvalid;
    assign in4_arready = in_all_arready[3];

    assign in4_rid = in_all_rid[3];
    assign in4_rdata = in_all_rdata[3];
    assign in4_rresp = in_all_rresp[3];
    assign in4_rlast = in_all_rlast[3];
    assign in4_rvalid = in_all_rvalid[3];
    assign in_all_rready[3] = in4_rready;



    assign out4_awid = out_all_awid[3];
    assign out4_awaddr = out_all_awaddr[3];
    assign out4_awlen = out_all_awlen[3];
    assign out4_awsize = out_all_awsize[3];
    assign out4_awburst = out_all_awburst[3];
    assign out4_awuser = out_all_awuser[3];
    assign out4_awvalid = out_all_awvalid[3];
    assign out_all_awready[3] = out4_awready;

    assign out4_wdata = out_all_wdata[3];
    assign out4_wstrb = out_all_wstrb[3];
    assign out4_wlast = out_all_wlast[3];
    assign out4_wvalid = out_all_wvalid[3];
    assign out_all_wready[3] = out4_wready;

    assign out_all_bid[3] = out4_bid;
    assign out_all_bresp[3] = out4_bresp;
    assign out_all_bvalid[3] = out4_bvalid;
    assign out4_bready = out_all_bready[3];

    assign out4_arid = out_all_arid[3];
    assign out4_araddr = out_all_araddr[3];
    assign out4_arlen = out_all_arlen[3];
    assign out4_arsize = out_all_arsize[3];
    assign out4_arburst = out_all_arburst[3];
    assign out4_aruser = out_all_aruser[3];
    assign out4_arvalid = out_all_arvalid[3];
    assign out_all_arready[3] = out4_arready;

    assign out_all_rid[3] = out4_rid;
    assign out_all_rdata[3] = out4_rdata;
    assign out_all_rresp[3] = out4_rresp;
    assign out_all_rlast[3] = out4_rlast;
    assign out_all_rvalid[3] = out4_rvalid;
    assign out4_rready = out_all_rready[3];

`endif 

`ifdef INC_M5

    assign in_all_awid[4] = in5_awid;
    assign in_all_awaddr[4] = in5_awaddr;
    assign in_all_awlen[4] = in5_awlen;
    assign in_all_awsize[4] = in5_awsize;
    assign in_all_awburst[4] = in5_awburst;
    assign in_all_awuser[4] = in5_awuser;
    assign in_all_awvalid[4] = in5_awvalid;
    assign in5_awready = in_all_awready[4];

    assign in_all_wdata[4] = in5_wdata;
    assign in_all_wstrb[4] = in5_wstrb;
    assign in_all_wlast[4] = in5_wlast;
    assign in_all_wvalid[4] = in5_wvalid;
    assign in5_wready = in_all_wready[4];

    assign in5_bid = in_all_bid[4];
    assign in5_bresp = in_all_bresp[4];
    assign in5_bvalid = in_all_bvalid[4];
    assign in_all_bready[4] = in5_bready;

    assign in_all_arid[4] = in5_arid;
    assign in_all_araddr[4] = in5_araddr;
    assign in_all_arlen[4] = in5_arlen;
    assign in_all_arsize[4] = in5_arsize;
    assign in_all_arburst[4] = in5_arburst;
    assign in_all_aruser[4] = in5_aruser;
    assign in_all_arvalid[4] = in5_arvalid;
    assign in5_arready = in_all_arready[4];

    assign in5_rid = in_all_rid[4];
    assign in5_rdata = in_all_rdata[4];
    assign in5_rresp = in_all_rresp[4];
    assign in5_rlast = in_all_rlast[4];
    assign in5_rvalid = in_all_rvalid[4];
    assign in_all_rready[4] = in5_rready;



    assign out5_awid = out_all_awid[4];
    assign out5_awaddr = out_all_awaddr[4];
    assign out5_awlen = out_all_awlen[4];
    assign out5_awsize = out_all_awsize[4];
    assign out5_awburst = out_all_awburst[4];
    assign out5_awuser = out_all_awuser[4];
    assign out5_awvalid = out_all_awvalid[4];
    assign out_all_awready[4] = out5_awready;

    assign out5_wdata = out_all_wdata[4];
    assign out5_wstrb = out_all_wstrb[4];
    assign out5_wlast = out_all_wlast[4];
    assign out5_wvalid = out_all_wvalid[4];
    assign out_all_wready[4] = out5_wready;

    assign out_all_bid[4] = out5_bid;
    assign out_all_bresp[4] = out5_bresp;
    assign out_all_bvalid[4] = out5_bvalid;
    assign out5_bready = out_all_bready[4];

    assign out5_arid = out_all_arid[4];
    assign out5_araddr = out_all_araddr[4];
    assign out5_arlen = out_all_arlen[4];
    assign out5_arsize = out_all_arsize[4];
    assign out5_arburst = out_all_arburst[4];
    assign out5_aruser = out_all_aruser[4];
    assign out5_arvalid = out_all_arvalid[4];
    assign out_all_arready[4] = out5_arready;

    assign out_all_rid[4] = out5_rid;
    assign out_all_rdata[4] = out5_rdata;
    assign out_all_rresp[4] = out5_rresp;
    assign out_all_rlast[4] = out5_rlast;
    assign out_all_rvalid[4] = out5_rvalid;
    assign out5_rready = out_all_rready[4];

`endif 

`ifdef INC_M6

    assign in_all_awid[5] = in6_awid;
    assign in_all_awaddr[5] = in6_awaddr;
    assign in_all_awlen[5] = in6_awlen;
    assign in_all_awsize[5] = in6_awsize;
    assign in_all_awburst[5] = in6_awburst;
    assign in_all_awuser[5] = in6_awuser;
    assign in_all_awvalid[5] = in6_awvalid;
    assign in6_awready = in_all_awready[5];

    assign in_all_wdata[5] = in6_wdata;
    assign in_all_wstrb[5] = in6_wstrb;
    assign in_all_wlast[5] = in6_wlast;
    assign in_all_wvalid[5] = in6_wvalid;
    assign in6_wready = in_all_wready[5];

    assign in6_bid = in_all_bid[5];
    assign in6_bresp = in_all_bresp[5];
    assign in6_bvalid = in_all_bvalid[5];
    assign in_all_bready[5] = in6_bready;

    assign in_all_arid[5] = in6_arid;
    assign in_all_araddr[5] = in6_araddr;
    assign in_all_arlen[5] = in6_arlen;
    assign in_all_arsize[5] = in6_arsize;
    assign in_all_arburst[5] = in6_arburst;
    assign in_all_aruser[5] = in6_aruser;
    assign in_all_arvalid[5] = in6_arvalid;
    assign in6_arready = in_all_arready[5];

    assign in6_rid = in_all_rid[5];
    assign in6_rdata = in_all_rdata[5];
    assign in6_rresp = in_all_rresp[5];
    assign in6_rlast = in_all_rlast[5];
    assign in6_rvalid = in_all_rvalid[5];
    assign in_all_rready[5] = in6_rready;



    assign out6_awid = out_all_awid[5];
    assign out6_awaddr = out_all_awaddr[5];
    assign out6_awlen = out_all_awlen[5];
    assign out6_awsize = out_all_awsize[5];
    assign out6_awburst = out_all_awburst[5];
    assign out6_awuser = out_all_awuser[5];
    assign out6_awvalid = out_all_awvalid[5];
    assign out_all_awready[5] = out6_awready;

    assign out6_wdata = out_all_wdata[5];
    assign out6_wstrb = out_all_wstrb[5];
    assign out6_wlast = out_all_wlast[5];
    assign out6_wvalid = out_all_wvalid[5];
    assign out_all_wready[5] = out6_wready;

    assign out_all_bid[5] = out6_bid;
    assign out_all_bresp[5] = out6_bresp;
    assign out_all_bvalid[5] = out6_bvalid;
    assign out6_bready = out_all_bready[5];

    assign out6_arid = out_all_arid[5];
    assign out6_araddr = out_all_araddr[5];
    assign out6_arlen = out_all_arlen[5];
    assign out6_arsize = out_all_arsize[5];
    assign out6_arburst = out_all_arburst[5];
    assign out6_aruser = out_all_aruser[5];
    assign out6_arvalid = out_all_arvalid[5];
    assign out_all_arready[5] = out6_arready;

    assign out_all_rid[5] = out6_rid;
    assign out_all_rdata[5] = out6_rdata;
    assign out_all_rresp[5] = out6_rresp;
    assign out_all_rlast[5] = out6_rlast;
    assign out_all_rvalid[5] = out6_rvalid;
    assign out6_rready = out_all_rready[5];

`endif 

`ifdef INC_M7

    assign in_all_awid[6] = in7_awid;
    assign in_all_awaddr[6] = in7_awaddr;
    assign in_all_awlen[6] = in7_awlen;
    assign in_all_awsize[6] = in7_awsize;
    assign in_all_awburst[6] = in7_awburst;
    assign in_all_awuser[6] = in7_awuser;
    assign in_all_awvalid[6] = in7_awvalid;
    assign in7_awready = in_all_awready[6];

    assign in_all_wdata[6] = in7_wdata;
    assign in_all_wstrb[6] = in7_wstrb;
    assign in_all_wlast[6] = in7_wlast;
    assign in_all_wvalid[6] = in7_wvalid;
    assign in7_wready = in_all_wready[6];

    assign in7_bid = in_all_bid[6];
    assign in7_bresp = in_all_bresp[6];
    assign in7_bvalid = in_all_bvalid[6];
    assign in_all_bready[6] = in7_bready;

    assign in_all_arid[6] = in7_arid;
    assign in_all_araddr[6] = in7_araddr;
    assign in_all_arlen[6] = in7_arlen;
    assign in_all_arsize[6] = in7_arsize;
    assign in_all_arburst[6] = in7_arburst;
    assign in_all_aruser[6] = in7_aruser;
    assign in_all_arvalid[6] = in7_arvalid;
    assign in7_arready = in_all_arready[6];

    assign in7_rid = in_all_rid[6];
    assign in7_rdata = in_all_rdata[6];
    assign in7_rresp = in_all_rresp[6];
    assign in7_rlast = in_all_rlast[6];
    assign in7_rvalid = in_all_rvalid[6];
    assign in_all_rready[6] = in7_rready;



    assign out7_awid = out_all_awid[6];
    assign out7_awaddr = out_all_awaddr[6];
    assign out7_awlen = out_all_awlen[6];
    assign out7_awsize = out_all_awsize[6];
    assign out7_awburst = out_all_awburst[6];
    assign out7_awuser = out_all_awuser[6];
    assign out7_awvalid = out_all_awvalid[6];
    assign out_all_awready[6] = out7_awready;

    assign out7_wdata = out_all_wdata[6];
    assign out7_wstrb = out_all_wstrb[6];
    assign out7_wlast = out_all_wlast[6];
    assign out7_wvalid = out_all_wvalid[6];
    assign out_all_wready[6] = out7_wready;

    assign out_all_bid[6] = out7_bid;
    assign out_all_bresp[6] = out7_bresp;
    assign out_all_bvalid[6] = out7_bvalid;
    assign out7_bready = out_all_bready[6];

    assign out7_arid = out_all_arid[6];
    assign out7_araddr = out_all_araddr[6];
    assign out7_arlen = out_all_arlen[6];
    assign out7_arsize = out_all_arsize[6];
    assign out7_arburst = out_all_arburst[6];
    assign out7_aruser = out_all_aruser[6];
    assign out7_arvalid = out_all_arvalid[6];
    assign out_all_arready[6] = out7_arready;

    assign out_all_rid[6] = out7_rid;
    assign out_all_rdata[6] = out7_rdata;
    assign out_all_rresp[6] = out7_rresp;
    assign out_all_rlast[6] = out7_rlast;
    assign out_all_rvalid[6] = out7_rvalid;
    assign out7_rready = out_all_rready[6];

`endif 

`ifdef INC_M8

    assign in_all_awid[7] = in8_awid;
    assign in_all_awaddr[7] = in8_awaddr;
    assign in_all_awlen[7] = in8_awlen;
    assign in_all_awsize[7] = in8_awsize;
    assign in_all_awburst[7] = in8_awburst;
    assign in_all_awuser[7] = in8_awuser;
    assign in_all_awvalid[7] = in8_awvalid;
    assign in8_awready = in_all_awready[7];

    assign in_all_wdata[7] = in8_wdata;
    assign in_all_wstrb[7] = in8_wstrb;
    assign in_all_wlast[7] = in8_wlast;
    assign in_all_wvalid[7] = in8_wvalid;
    assign in8_wready = in_all_wready[7];

    assign in8_bid = in_all_bid[7];
    assign in8_bresp = in_all_bresp[7];
    assign in8_bvalid = in_all_bvalid[7];
    assign in_all_bready[7] = in8_bready;

    assign in_all_arid[7] = in8_arid;
    assign in_all_araddr[7] = in8_araddr;
    assign in_all_arlen[7] = in8_arlen;
    assign in_all_arsize[7] = in8_arsize;
    assign in_all_arburst[7] = in8_arburst;
    assign in_all_aruser[7] = in8_aruser;
    assign in_all_arvalid[7] = in8_arvalid;
    assign in8_arready = in_all_arready[7];

    assign in8_rid = in_all_rid[7];
    assign in8_rdata = in_all_rdata[7];
    assign in8_rresp = in_all_rresp[7];
    assign in8_rlast = in_all_rlast[7];
    assign in8_rvalid = in_all_rvalid[7];
    assign in_all_rready[7] = in8_rready;



    assign out8_awid = out_all_awid[7];
    assign out8_awaddr = out_all_awaddr[7];
    assign out8_awlen = out_all_awlen[7];
    assign out8_awsize = out_all_awsize[7];
    assign out8_awburst = out_all_awburst[7];
    assign out8_awuser = out_all_awuser[7];
    assign out8_awvalid = out_all_awvalid[7];
    assign out_all_awready[7] = out8_awready;

    assign out8_wdata = out_all_wdata[7];
    assign out8_wstrb = out_all_wstrb[7];
    assign out8_wlast = out_all_wlast[7];
    assign out8_wvalid = out_all_wvalid[7];
    assign out_all_wready[7] = out8_wready;

    assign out_all_bid[7] = out8_bid;
    assign out_all_bresp[7] = out8_bresp;
    assign out_all_bvalid[7] = out8_bvalid;
    assign out8_bready = out_all_bready[7];

    assign out8_arid = out_all_arid[7];
    assign out8_araddr = out_all_araddr[7];
    assign out8_arlen = out_all_arlen[7];
    assign out8_arsize = out_all_arsize[7];
    assign out8_arburst = out_all_arburst[7];
    assign out8_aruser = out_all_aruser[7];
    assign out8_arvalid = out_all_arvalid[7];
    assign out_all_arready[7] = out8_arready;

    assign out_all_rid[7] = out8_rid;
    assign out_all_rdata[7] = out8_rdata;
    assign out_all_rresp[7] = out8_rresp;
    assign out_all_rlast[7] = out8_rlast;
    assign out_all_rvalid[7] = out8_rvalid;
    assign out8_rready = out_all_rready[7];

`endif



    //--------------------------------------------------------//
    //   Unpack Register values                               //
    //--------------------------------------------------------// 

    wire [TOKEN_COUNT_INT_WIDTH-1:0]  aw_init_token [`NUM_MASTERS-1:0];
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   aw_upd_token [`NUM_MASTERS-1:0];

    wire [TOKEN_COUNT_INT_WIDTH-1:0]  ar_init_token [`NUM_MASTERS-1:0];
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   ar_upd_token [`NUM_MASTERS-1:0];

    genvar j;
    generate for(j = 0; j < `NUM_MASTERS; j = j + 1) begin : reg_unpack

        assign {ar_upd_token[j],ar_init_token[j],aw_upd_token[j],aw_init_token[j]}
            = bw_throt_regs[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST];

    end endgenerate



    //--------------------------------------------------------//
    //   Instantiate throttlers                               //
    //--------------------------------------------------------// 

    mem_bw_throttler_multi
    #(
        .AXI_ID_WIDTH           (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .AXI_AX_USER_WIDTH      (AXI_AX_USER_WIDTH),
        .NUM_MASTERS            (`NUM_MASTERS),
        .TOKEN_COUNT_INT_WIDTH  (TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH (TOKEN_COUNT_FRAC_WIDTH),
        .WTIMEOUT_CYCLES        (WTIMEOUT_CYCLES),
        .BTIMEOUT_CYCLES        (BTIMEOUT_CYCLES),
        .RTIMEOUT_CYCLES        (RTIMEOUT_CYCLES),
        .OUTSTANDING_WREQ       (OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ       (OUTSTANDING_RREQ),
        .AW_RETIMING_STAGES     (AW_RETIMING_STAGES),
        .AR_RETIMING_STAGES     (AR_RETIMING_STAGES),
        .ALLOW_OVERRIDE         (ALLOW_OVERRIDE),
        .INCLUDE_BACKPRESSURE   (INCLUDE_BACKPRESSURE)
    )
    throttlers 
    (
        .*
    );



endmodule

`default_nettype wire