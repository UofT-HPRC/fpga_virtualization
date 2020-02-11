`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Lite Dummy Slave

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is implements an axi-lite slave that simply replies
   with a SLVERR condition for every request issued to it.

Parameters:
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path (must be 32 or 64)
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_WREQ - the maximum allowed oustanding read requests
   W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted

Ports:
   axi_lite_s_* - the input memory mapped AXI interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_lite_dummy_slave
#(
    //AXI-Lite Interface Params
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter W_BEFORE_AW_CAPABLE = 1
)
(
    //AXI-Lite slave connection
    //Write Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_awaddr,
    input wire                              axi_lite_s_awvalid,
    output wire                             axi_lite_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_lite_s_wstrb,
    input wire                              axi_lite_s_wvalid,
    output wire                             axi_lite_s_wready,
    //Write Response Channel
    output wire [1:0]                       axi_lite_s_bresp,
    output wire                             axi_lite_s_bvalid,
    input wire                              axi_lite_s_bready,
    //Read Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_araddr,
    input wire                              axi_lite_s_arvalid,
    output wire                             axi_lite_s_arready,
    //Read Data Response Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_lite_s_rdata,
    output wire [1:0]                       axi_lite_s_rresp,
    output wire                             axi_lite_s_rvalid,
    input wire                              axi_lite_s_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);


    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire aw_full;
    assign axi_lite_s_awready = (aw_full ? 0 : 1);

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire w_full;
    assign axi_lite_s_wready = (w_full ? 0 : 1);



    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//    
    
    //Indicates that there is a bresp that needs to be sent
    wire bresp_expected;
    assign axi_lite_s_bvalid = (bresp_expected ? 1 : 0);
    assign axi_lite_s_bresp = 2'b10; //Always indicate slave error



    //--------------------------------------------------------//
    //   AXI Write Logic                                      //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wresp;
    assign aw_full = (outst_wresp >= OUTSTANDING_WREQ);
    
    always @(posedge aclk) begin
        if(~aresetn) 
            outst_wresp <= 0;
        else if(axi_lite_s_awvalid && axi_lite_s_awready && axi_lite_s_bvalid && axi_lite_s_bready)
            outst_wresp <= outst_wresp;
        else if(axi_lite_s_awvalid && axi_lite_s_awready)
            outst_wresp <= outst_wresp + 1;
        else if(axi_lite_s_bvalid && axi_lite_s_bready)
            outst_wresp <= outst_wresp - 1;
    end
    
    //Count outstanding beats expected
    generate if(W_BEFORE_AW_CAPABLE) begin : signed_count_if

        reg signed [$clog2(OUTSTANDING_WREQ+1):0] outst_wdata; // Note - extra bit for sign
        wire neg_outst_data = (outst_wdata < 1'sb0);
        assign w_full = (outst_wdata >= OUTSTANDING_WREQ) || (outst_wdata <= -OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata) && !neg_outst_data;
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata <= 0;
            else if(axi_lite_s_awvalid && axi_lite_s_awready && axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata;
            else if(axi_lite_s_awvalid && axi_lite_s_awready)
                outst_wdata <= outst_wdata + 1;
            else if(axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata - 1;
        end

    end else begin

        reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wdata; // Note - unsigned version
        assign w_full = (outst_wdata >= OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata);
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata <= 0;
            else if(axi_lite_s_awvalid && axi_lite_s_awready && axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata;
            else if(axi_lite_s_awvalid && axi_lite_s_awready)
                outst_wdata <= outst_wdata + 1;
            else if(axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata - 1;
        end

    end endgenerate

    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire ar_full;
    assign axi_lite_s_arready = (ar_full ? 0 : 1);
    
    

    //--------------------------------------------------------//
    //   AXI Read Data Channel                                //
    //--------------------------------------------------------//

    //Indicates that there is a rresp that needs to be sent
    wire rresp_expected;
    assign axi_lite_s_rvalid = (rresp_expected ? 1 : 0);
    assign axi_lite_s_rdata = 0; //Don't care about data
    assign axi_lite_s_rresp = 2'b10; //Always indicate slave error

 
 
    //--------------------------------------------------------//
    //   AXI Read Logic                                       //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_RREQ+1)-1:0] outst_rresp;
    assign rresp_expected = (outst_rresp != 0);
    assign ar_full = (outst_rresp >= OUTSTANDING_RREQ);
    
    always @(posedge aclk) begin
        if(~aresetn)
            outst_rresp <= 0;
        else if(axi_lite_s_arvalid && axi_lite_s_arready && axi_lite_s_rvalid && axi_lite_s_rready)
            outst_rresp <= outst_rresp;
        else if(axi_lite_s_arvalid && axi_lite_s_arready)
            outst_rresp <= outst_rresp + 1;
        else if(axi_lite_s_rvalid && axi_lite_s_rready)
            outst_rresp <= outst_rresp - 1;
    end



endmodule

`default_nettype wire