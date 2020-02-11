`timescale 1ns / 1ps
`default_nettype none

/*
AXI4-MM Dummy Slave

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is implements an axi4 slave that simply replies
   with a SLVERR condition for every request issued to it.

Parameters:
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path (must be 32 or 64)
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_WREQ - the maximum allowed oustanding read requests
   W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted

Ports:
   axi_s_* - the input memory mapped AXI interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi4_dummy_slave
#(
    //AXI-Lite Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter W_BEFORE_AW_CAPABLE = 0
)
(
    //AXI4 slave connection
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_awaddr,
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
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_araddr,
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

    //Clocking
    input wire  aclk,
    input wire  aresetn
);


    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire aw_full;
    assign axi_s_awready = (aw_full ? 0 : 1);

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire w_full;
    assign axi_s_wready = (w_full ? 0 : 1);



    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//    
    
    //Indicates that there is a bresp that needs to be sent
    wire bresp_expected;
    wire [AXI_ID_WIDTH-1:0] bid_expected;

    assign axi_s_bvalid = (bresp_expected ? 1 : 0);
    assign axi_s_bresp = 2'b10; //Always indicate slave error
    assign axi_s_bid = bid_expected;



    //--------------------------------------------------------//
    //   AXI Write Logic                                      //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wresp;
    
    always @(posedge aclk) begin
        if(~aresetn) 
            outst_wresp <= 0;
        else if(axi_s_awvalid && axi_s_awready && axi_s_bvalid && axi_s_bready)
            outst_wresp <= outst_wresp;
        else if(axi_s_awvalid && axi_s_awready)
            outst_wresp <= outst_wresp + 1;
        else if(axi_s_bvalid && axi_s_bready)
            outst_wresp <= outst_wresp - 1;
    end
    
    //Count outstanding last beats expected
    generate if(W_BEFORE_AW_CAPABLE) begin : signed_count_if

        reg signed [$clog2(OUTSTANDING_WREQ+1):0] outst_wdata_last; // Note - extra bit for sign
        wire neg_outst_data = (outst_wdata_last < 1'sb0);
        assign w_full = (outst_wdata_last >= OUTSTANDING_WREQ) || (outst_wdata_last <= -OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata_last) && !neg_outst_data;
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata_last <= 0;
            else if(axi_s_awvalid && axi_s_awready && axi_s_wvalid && axi_s_wready && axi_s_wlast)
                outst_wdata_last <= outst_wdata_last;
            else if(axi_s_awvalid && axi_s_awready)
                outst_wdata_last <= outst_wdata_last + 1;
            else if(axi_s_wvalid && axi_s_wready && axi_s_wlast)
                outst_wdata_last <= outst_wdata_last - 1;
        end

    end else begin

        reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wdata_last; // Note - unsigned version
        assign w_full = (outst_wdata_last >= OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata_last);
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata_last <= 0;
            else if(axi_s_awvalid && axi_s_awready && axi_s_wvalid && axi_s_wready && axi_s_wlast)
                outst_wdata_last <= outst_wdata_last;
            else if(axi_s_awvalid && axi_s_awready)
                outst_wdata_last <= outst_wdata_last + 1;
            else if(axi_s_wvalid && axi_s_wready && axi_s_wlast)
                outst_wdata_last <= outst_wdata_last - 1;
        end

    end endgenerate

    //FIFO the ID signal
    simple_fifo
    #(
        .DATA_WIDTH         (AXI_ID_WIDTH),
        .BUFFER_DEPTH_LOG2  ($clog2(OUTSTANDING_WREQ))
    )
    aw_id_fifo_inst
    (
        //Input interface
        .din    (axi_s_awid),
        .wr_en  (axi_s_awvalid && axi_s_awready),
        .full   (aw_full),

        //Output Interface
        .dout   (bid_expected),
        .rd_en  (axi_s_bvalid && axi_s_bready),
        .empty  ( ),
        
        //Clocking
        .clk    (aclk),
        .rst    (~aresetn)
    );

    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//

    //Accept beats all the time, except when full
    wire ar_full;
    assign axi_s_arready = (ar_full ? 0 : 1);
    
    

    //--------------------------------------------------------//
    //   AXI Read Data Channel                                //
    //--------------------------------------------------------//

    //Indicates that there is a rresp that needs to be sent
    wire rresp_expected;
    wire rlast_expected;
    wire [AXI_ID_WIDTH-1:0] rid_expected;

    assign axi_s_rvalid = (rresp_expected ? 1 : 0);
    assign axi_s_rdata = 0; //Don't care about data
    assign axi_s_rresp = 2'b10; //Always indicate slave error
    assign axi_s_rlast = rlast_expected;
    assign axi_s_rid = rid_expected;

 
 
    //--------------------------------------------------------//
    //   AXI Read Logic                                       //
    //--------------------------------------------------------// 

    //FIFO the burst length and the ID
    wire [7:0] out_len;
    wire ar_fifo_empty;

    simple_fifo
    #(
        .DATA_WIDTH         (AXI_ID_WIDTH + 8),
        .BUFFER_DEPTH_LOG2  ($clog2(OUTSTANDING_RREQ))
    )
    ar_id_len_fifo_inst
    (
        //Input interface
        .din    ({axi_s_arid,axi_s_arlen}),
        .wr_en  (axi_s_arvalid && axi_s_arready),
        .full   (ar_full),

        //Output Interface
        .dout   ({rid_expected,out_len}),
        .rd_en  (axi_s_rvalid && axi_s_rready && axi_s_rlast),
        .empty  (ar_fifo_empty),
        
        //Clocking
        .clk    (aclk),
        .rst    (~aresetn)
    );

    assign rresp_expected = !ar_fifo_empty;

    //Count beats to determine when to assert rlast
    reg [8:0] r_beat_count;

    always@(posedge aclk) begin
        if(~aresetn) r_beat_count <= 0;
        else if(axi_s_rvalid && axi_s_rready) begin
            if(axi_s_rlast) r_beat_count <= 0;
            else r_beat_count <= r_beat_count + 1;
        end 
    end

    assign rlast_expected = (r_beat_count == out_len);



endmodule

`default_nettype wire