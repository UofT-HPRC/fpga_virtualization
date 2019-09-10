`timescale 1ns / 1ps
`default_nettype none


//The MMU
module simple_mmu
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 5,
    parameter AXI_IN_ADDR_WIDTH = 31,
    parameter AXI_OUT_ADDR_WIDTH = 33,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_AX_USER_WIDTH = 1, //ignored

    //Error inclusion
    parameter ERROR_BIT_LOCATION = AXI_OUT_ADDR_WIDTH-1,
    
    //MMU parameterization
    parameter ID_BITS_USED = AXI_OUT_ADDR_WIDTH-AXI_IN_ADDR_WIDTH,
    parameter IGNORE_ID_MSB = 1
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_awid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      mem_in_awaddr,
    input wire [7:0]                        mem_in_awlen,
    input wire [2:0]                        mem_in_awsize,
    input wire [1:0]                        mem_in_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      mem_in_awuser,
    input wire                              mem_in_awvalid,
    output wire                             mem_in_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         mem_in_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     mem_in_wstrb,
    input wire                              mem_in_wlast,
    input wire                              mem_in_wvalid,
    output wire                             mem_in_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_bid,
    output wire [1:0]                       mem_in_bresp,
    output wire                             mem_in_bvalid,
    input wire                              mem_in_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_arid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      mem_in_araddr,
    input wire [7:0]                        mem_in_arlen,
    input wire [2:0]                        mem_in_arsize,
    input wire [1:0]                        mem_in_arburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      mem_in_aruser,
    input wire                              mem_in_arvalid,
    output wire                             mem_in_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_rid,
    output wire [AXI_DATA_WIDTH-1:0]        mem_in_rdata,
    output wire [1:0]                       mem_in_rresp,
    output wire                             mem_in_rlast,
    output wire                             mem_in_rvalid,
    input wire                              mem_in_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_awid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    mem_out_awaddr,
    output wire [7:0]                       mem_out_awlen,
    output wire [2:0]                       mem_out_awsize,
    output wire [1:0]                       mem_out_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     mem_out_awuser,
    output wire                             mem_out_awvalid,
    input wire                              mem_out_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        mem_out_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    mem_out_wstrb,
    output wire                             mem_out_wlast,
    output wire                             mem_out_wvalid,
    input wire                              mem_out_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_bid,
    input wire [1:0]                        mem_out_bresp,
    input wire                              mem_out_bvalid,
    output wire                             mem_out_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_arid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    mem_out_araddr,
    output wire [7:0]                       mem_out_arlen,
    output wire [2:0]                       mem_out_arsize,
    output wire [1:0]                       mem_out_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     mem_out_aruser,
    output wire                             mem_out_arvalid,
    input wire                              mem_out_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_rid,
    input wire [AXI_DATA_WIDTH-1:0]         mem_out_rdata,
    input wire [1:0]                        mem_out_rresp,
    input wire                              mem_out_rlast,
    input wire                              mem_out_rvalid,
    output wire                             mem_out_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//
    
    //Assign output values that don't need to be remapped
    assign mem_out_awid = mem_in_awid;
    assign mem_out_awburst = mem_in_awburst;
    assign mem_out_awsize = mem_in_awsize;
    assign mem_out_awlen = mem_in_awlen;
    assign mem_out_awuser = mem_in_awuser;
    assign mem_out_awvalid = mem_in_awvalid;
    assign mem_in_awready = mem_out_awready;

    //Calculate remapped address
    wire [AXI_OUT_ADDR_WIDTH:0] remapped_awaddr = 
    	{	mem_in_awid[AXI_ID_WIDTH-IGNORE_ID_MSB-1-:ID_BITS_USED],
    		mem_in_awaddr[0+:AXI_OUT_ADDR_WIDTH-ID_BITS_USED]			};

    assign mem_out_awaddr = (IGNORE_ID_MSB && mem_in_awid[AXI_ID_WIDTH-1] == 1'b1) ?  
    	mem_in_awaddr : remapped_awaddr;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign mem_out_wdata = mem_in_wdata;
    assign mem_out_wstrb = mem_in_wstrb;
    assign mem_out_wlast = mem_in_wlast;
    assign mem_out_wvalid = mem_in_wvalid;
    assign mem_in_wready = mem_out_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign mem_out_bready = mem_in_bready;
    assign mem_in_bid = mem_out_bid;
    assign mem_in_bresp = mem_out_bresp;
    assign mem_in_bvalid = mem_out_bvalid;
        
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Assign output values that don't need to be remapped
    assign mem_out_arid = mem_in_arid;
    assign mem_out_arburst = mem_in_arburst;
    assign mem_out_arsize = mem_in_arsize;
    assign mem_out_arlen = mem_in_arlen;
    assign mem_out_aruser = mem_in_aruser;
    assign mem_out_arvalid = mem_in_arvalid;
    assign mem_in_arready = mem_out_arready;

    //Calculate remapped address
    wire [AXI_OUT_ADDR_WIDTH:0] remapped_araddr = 
    	{	mem_in_arid[AXI_ID_WIDTH-IGNORE_ID_MSB-1-:ID_BITS_USED],
    		mem_in_araddr[0+:AXI_OUT_ADDR_WIDTH-ID_BITS_USED]			};

    assign mem_out_araddr = (IGNORE_ID_MSB && mem_in_arid[AXI_ID_WIDTH-1] == 1'b1) ?  
    	mem_in_araddr : remapped_araddr;
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//

    //Nothing to do, simply forward
    assign mem_out_rready = mem_in_rready;
    assign mem_in_rid = mem_out_rid;
    assign mem_in_rdata = mem_out_rdata;
    assign mem_in_rresp = mem_out_rresp;
    assign mem_in_rlast = mem_out_rlast;
    assign mem_in_rvalid = mem_out_rvalid;



endmodule

`default_nettype wire