`timescale 1ns / 1ps
`default_nettype none

/*
AXI4-MM Bandwidth Shaper (unified read and write shaping)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to control the ammount of bandwidth allowed to
   pass from the slave side interface to the master side interface. The
   algorithm implemented includes a token count that is updated every
   cycle by some indicated upd amount, and which is initiailized to some
   indicated init amount (at reset and idle). A single token counts is
   used for the read and write channels. Note, zero widths for any of the 
   signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path
   AXI_AX_USER_WIDTH - the width of the AW and AR signals
   TOKEN_COUNT_INT_WIDTH - the token count integer component width (fixed point representation)
   TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width (fixed point representation)
   WTIMEOUT_CYCLES - total number of cycles to wait after receiving the AW request or the previous W beat before indicating a W-channel timeout (should be one less than a power of 2 for implementation efficiency)
   BTIMEOUT_CYCLES - total numner of cycles to wait after bready is asserted before indicating a B-channel timeout
   RTIMEOUT_CYCLES - total number of cycles to wait after rready is asserted before indicating an R-channel timeout (should be one less than a power of 2 for implementation efficiency)
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   SUM_RETIMING_STAGES - retiming registers to insert into token summing to meet timing
   ALLOW_RD_WR_SAME_TIME - binary, whether to allow reads and writes to be accepted in the same cycle

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface
   init_token - the initial token count, integer representation
   upd_token - the token update rate per cycle, fixed-point representation (1 integer bit, TOKEN_COUNT_FRAC_WIDTH fractional bits)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi4_bw_shaper_unified
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_AX_USER_WIDTH = 1,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,

    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8,

    //Retiming for adders
    parameter SUM_RETIMING_STAGES = 1,
    parameter ALLOW_RD_WR_SAME_TIME = 1
)
(
    //AXI4 slave connection (the master interface to apply bw shapping to connects to this)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_awaddr,
    input wire [7:0]                        axi_s_awlen,
    input wire [2:0]                        axi_s_awsize,
    input wire [1:0]                        axi_s_awburst,
    input wire [AXI_AX_USER_WIDTH-1:0]      axi_s_awuser,
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
    input wire [AXI_AX_USER_WIDTH-1:0]      axi_s_aruser,
    input wire                              axi_s_arvalid,
    output wire                             axi_s_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_rid,
    output wire [AXI_DATA_WIDTH-1:0]        axi_s_rdata,
    output wire [1:0]                       axi_s_rresp,
    output wire                             axi_s_rlast,
    output wire                             axi_s_rvalid,
    input wire                              axi_s_rready,

    //AXI4 master connection (the bw shaped signal to connect to the slave)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output wire [2:0]                       axi_m_awsize,
    output wire [1:0]                       axi_m_awburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     axi_m_awuser,
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
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_araddr,
    output wire [7:0]                       axi_m_arlen,
    output wire [2:0]                       axi_m_arsize,
    output wire [1:0]                       axi_m_arburst,
    output wire [AXI_AX_USER_WIDTH-1:0]     axi_m_aruser,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  init_token,
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    localparam TOKEN_COUNT_TOTAL_WIDTH = TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH;


    //--------------------------------------------------------//
    //   AXI Channel pass-through with decoupling             //
    //--------------------------------------------------------//
    
    //Decouple signals
    wire aw_decouple;
    wire w_decouple;
    wire ar_decouple;

    //Write Address channel
    assign axi_m_awid = axi_s_awid;
    assign axi_m_awaddr = axi_s_awaddr;
    assign axi_m_awlen = axi_s_awlen;
    assign axi_m_awsize = axi_s_awsize;
    assign axi_m_awburst = axi_s_awburst;
    assign axi_m_awuser = axi_s_awuser;
    assign axi_m_awvalid = (aw_decouple ? 1'b0 : axi_s_awvalid);
    assign axi_s_awready = (aw_decouple ? 1'b0 : axi_m_awready);
    
    //Write Data Channel
    assign axi_m_wdata = axi_s_wdata;
    assign axi_m_wstrb = axi_s_wstrb;
    assign axi_m_wlast = axi_s_wlast;
    assign axi_m_wvalid = (w_decouple ? 1'b0 : axi_s_wvalid);
    assign axi_s_wready = (w_decouple ? 1'b0 : axi_m_wready);

    //Write Response Channel
    assign axi_s_bid = axi_m_bid;
    assign axi_s_bresp = axi_m_bresp;
    assign axi_s_bvalid = axi_m_bvalid;
    assign axi_m_bready = axi_s_bready;

    //Read Address Channel
    assign axi_m_arid = axi_s_arid;
    assign axi_m_araddr = axi_s_araddr;
    assign axi_m_arlen = axi_s_arlen;
    assign axi_m_arsize = axi_s_arsize;
    assign axi_m_arburst = axi_s_arburst;
    assign axi_m_aruser = axi_s_aruser;
    assign axi_m_arvalid = (ar_decouple ? 1'b0 : axi_s_arvalid);
    assign axi_s_arready = (ar_decouple ? 1'b0 : axi_m_arready);

    //Read Data Response Channel
    assign axi_s_rid = axi_m_rid;
    assign axi_s_rdata = axi_m_rdata;
    assign axi_s_rresp = axi_m_rresp;
    assign axi_s_rlast = axi_m_rlast;
    assign axi_s_rvalid = axi_m_rvalid;
    assign axi_m_rready = axi_s_rready;



    //--------------------------------------------------------//
    //   Decouple W-channel                                   //
    //--------------------------------------------------------//

    //Indicate accepted beats
    wire aw_accepted = (axi_s_awvalid && axi_m_awready && !aw_decouple);
    wire ar_accepted = (axi_s_arvalid && axi_m_arready && !ar_decouple);
    wire w_last = (axi_s_wvalid && axi_m_wready && axi_s_wlast && !w_decouple);

    //Count outstanding write transfers expected
    localparam WREQ_CBITS = $clog2(OUTSTANDING_WREQ + 1);
    reg unsigned [WREQ_CBITS-1:0] outst_trans;
    assign w_decouple = (outst_trans == 0);
    wire aw_fifo_decouple = (outst_trans >= OUTSTANDING_WREQ);
    
    always @(posedge aclk) begin
        if(~aresetn)
            outst_trans <= 0;
        else if(aw_accepted && w_last)
            outst_trans <= outst_trans;
        else if(aw_accepted)
            outst_trans <= outst_trans + 1;
        else if(w_last)
            outst_trans <= outst_trans - 1;
    end
    


    //--------------------------------------------------------//
    //   Token mechanism                                      //
    //--------------------------------------------------------//

    //Token counter
    localparam EXTRA_BITS_OF = 2;
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] current_tokens;
    wire [TOKEN_COUNT_TOTAL_WIDTH+EXTRA_BITS_OF-1:0] token_update;
    wire token_overflow = |(token_update[TOKEN_COUNT_TOTAL_WIDTH+:EXTRA_BITS_OF]);
    wire token_gt_init = (current_tokens > { init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} });

    always@(posedge aclk) begin
        if(~aresetn) current_tokens <= 0;
        else if(  ( (axi_m_awready && !axi_s_awvalid) ||
                    (axi_m_arready && !axi_s_arvalid) ) &&
                  w_decouple && token_gt_init )
            current_tokens <= { init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
        else if(token_overflow) current_tokens <= '1;
        else current_tokens <= token_update[TOKEN_COUNT_TOTAL_WIDTH-1:0];
    end 

    //Added components
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] w_add;
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] b_add;
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] r_add;

    //All summed components (with retiming)
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] all_sum [SUM_RETIMING_STAGES:0];
    assign all_sum[0] = w_add + b_add + r_add + upd_token;

    generate for(genvar j = 0; j < SUM_RETIMING_STAGES; j = j + 1) begin :retim
        always@(posedge aclk) begin
            if(~aresetn) all_sum[j+1] <= 0;
            else all_sum[j+1] <= all_sum[j];
        end 
    end endgenerate


    //Calculate tokens for forthcoming transactions
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] aw_token_need =
        { ( (axi_s_awlen+1)*(WTIMEOUT_CYCLES+1) + BTIMEOUT_CYCLES ), {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };

    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] ar_token_need =
        { ( (axi_s_arlen+1)*(RTIMEOUT_CYCLES+1) ), {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };

    //Update token count
    wire do_aw = (axi_s_awvalid && axi_m_awready && !aw_decouple);
    wire do_ar = (axi_s_arvalid && axi_m_arready && !ar_decouple);
    generate if(ALLOW_RD_WR_SAME_TIME)
        assign token_update = current_tokens + all_sum[SUM_RETIMING_STAGES] - (do_aw ? aw_token_need : 0) - (do_ar ? ar_token_need : 0);
    else
        assign token_update = current_tokens + all_sum[SUM_RETIMING_STAGES] - ( do_aw ? aw_token_need : (do_ar ? ar_token_need : 0) );
    endgenerate

    //Calculate tokens to redeposit for write data transmission
    reg [$clog2(WTIMEOUT_CYCLES+1)-1:0] w_add_back;

    always@(posedge aclk) begin
        if(~aresetn || axi_s_wvalid) w_add_back <= WTIMEOUT_CYCLES;
        else if(axi_m_wready && !w_decouple && w_add_back != 0) w_add_back <= w_add_back - 1;
    end  

    assign w_add = ((axi_s_wvalid && axi_m_wready && !w_decouple) ? { w_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0);

    //Caclulate tokens to redposit for write response reception
    reg [$clog2(BTIMEOUT_CYCLES+1)-1:0] b_add_back;

    always@(posedge aclk) begin
        if(~aresetn || axi_s_bready) b_add_back <= BTIMEOUT_CYCLES;
        else if(axi_m_bvalid && b_add_back != 0) b_add_back <= b_add_back - 1;
    end  

    assign b_add = (axi_m_bvalid && axi_s_bready) ? { b_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0;

    //Calculate tokens to redeposit for read data reception
    reg [$clog2(RTIMEOUT_CYCLES+1)-1:0] r_add_back;

    always@(posedge aclk) begin
        if(~aresetn || axi_s_rready) r_add_back <= RTIMEOUT_CYCLES;
        else if(axi_m_rvalid && r_add_back != 0) r_add_back <= r_add_back - 1;
    end  

    assign r_add = ((axi_m_rvalid && axi_s_rready) ? { r_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0);



    //--------------------------------------------------------//
    //   Decoupling of AW-Channel                             //
    //--------------------------------------------------------//

    //Throttle if not enough tokens
    wire aw_throttled = (aw_token_need > current_tokens) || aw_fifo_decouple;
    wire ar_throttled = (ar_token_need > current_tokens);
    wire enough_for_both = ( (aw_token_need + ar_token_need) <= current_tokens);

    //Round robbin arbitration
    reg aw_has_priority;

    always@(posedge aclk) begin
        if(~aresetn) aw_has_priority <= 0;
        else if(aw_accepted) aw_has_priority <= 0;
        else if(ar_accepted) aw_has_priority <= 1;
    end

    //Stick AW valid bit once it's been raised (AXI4 standard)
    reg sticky_awvalid;

    always@(posedge aclk) begin
        if(~aresetn) sticky_awvalid <= 0;
        else if(axi_m_awready) sticky_awvalid <= 0;
        else if(axi_s_awvalid && !aw_decouple) sticky_awvalid <= 1;
    end

    //Stick AR valid bit once it's been raised (AXI4 standard)
    reg sticky_arvalid;

    always@(posedge aclk) begin
        if(~aresetn) sticky_arvalid <= 0;
        else if(axi_m_arready) sticky_arvalid <= 0;
        else if(axi_s_arvalid && !ar_decouple) sticky_arvalid <= 1;
    end

    //Decoupling signals
    assign aw_decouple =    !sticky_awvalid && //Cannot deassert valid signal once asserted
                            !( enough_for_both && ALLOW_RD_WR_SAME_TIME ) && //Don't decouple if enough tokens for rd and wr (if mode enabled)
                            ( aw_throttled || sticky_arvalid || (!aw_has_priority && axi_s_arvalid && !ar_throttled) ); //All decouple conditions
    assign ar_decouple =    !sticky_arvalid && //Cannot deassert valid signal once asserted
                            !( enough_for_both && ALLOW_RD_WR_SAME_TIME ) && //Don't decouple if enough tokens for rd and wr (if mode enabled)
                            ( ar_throttled || sticky_awvalid || (aw_has_priority && axi_s_awvalid && !aw_throttled) ); //All decouple conditions

endmodule

`default_nettype wire