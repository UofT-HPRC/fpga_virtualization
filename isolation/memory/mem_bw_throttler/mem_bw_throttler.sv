`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module mem_bw_throttler
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_AX_USER_WIDTH = 1,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam TOKEN_COUNT_TOTAL_WIDTH = TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH,

    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    localparam WREQ_CBITS = $clog2(OUTSTANDING_WREQ + 1),
    localparam RREQ_CBITS = $clog2(OUTSTANDING_RREQ + 1),

    //Retiming for adders
    parameter AW_RETIMING_STAGES = 0,
    parameter AR_RETIMING_STAGES = 0,

    //Features to Implement
    parameter bit ALLOW_OVERRIDE = 1,
    parameter bit INCLUDE_BACKPRESSURE = 0
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_in_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         mem_in_awaddr,
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
    input wire [AXI_ADDR_WIDTH-1:0]         mem_in_araddr,
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
    output wire [AXI_ADDR_WIDTH-1:0]        mem_out_awaddr,
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
    output wire [AXI_ADDR_WIDTH-1:0]        mem_out_araddr,
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

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  aw_init_token,
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   aw_upd_token,

    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  ar_init_token,
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   ar_upd_token,

    //Override token decoupling
    input wire aw_override,
    input wire ar_override,

    output wire aw_has_outstanding,
    output wire aw_can_override,
    output wire ar_has_outstanding,
    output wire ar_can_override,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AXI Channel pass-through with decoupling             //
    //--------------------------------------------------------//
    
    //Decouple signals
    wire aw_decouple;
    wire w_decouple;
    wire ar_decouple;

    //Write Address channel
    assign mem_out_awid = mem_in_awid;
    assign mem_out_awaddr = mem_in_awaddr;
    assign mem_out_awlen = mem_in_awlen;
    assign mem_out_awsize = mem_in_awsize;
    assign mem_out_awburst = mem_in_awburst;
    assign mem_out_awuser = mem_in_awuser;
    assign mem_out_awvalid = (aw_decouple) ? 1'b0 : mem_in_awvalid;
    assign mem_in_awready = (aw_decouple) ? 1'b0 : mem_out_awready;
    
    //Write Data Channel
    assign mem_out_wdata = mem_in_wdata;
    assign mem_out_wstrb = mem_in_wstrb;
    assign mem_out_wlast = mem_in_wlast;
    assign mem_out_wvalid = (w_decouple) ? 1'b0 : mem_in_wvalid;
    assign mem_in_wready = (w_decouple) ? 1'b0 : mem_out_wready;

    //Write Response Channel
    assign mem_in_bid = mem_out_bid;
    assign mem_in_bresp = mem_out_bresp;
    assign mem_in_bvalid = mem_out_bvalid;
    assign mem_out_bready = mem_in_bready;

    //Read Address Channel
    assign mem_out_arid = mem_in_arid;
    assign mem_out_araddr = mem_in_araddr;
    assign mem_out_arlen = mem_in_arlen;
    assign mem_out_arsize = mem_in_arsize;
    assign mem_out_arburst = mem_in_arburst;
    assign mem_out_aruser = mem_in_aruser;
    assign mem_out_arvalid = (ar_decouple) ? 1'b0 : mem_in_arvalid;
    assign mem_in_arready = (ar_decouple) ? 1'b0 : mem_out_arready;

    //Read Data Response Channel
    assign mem_in_rid = mem_out_rid;
    assign mem_in_rdata = mem_out_rdata;
    assign mem_in_rresp = mem_out_rresp;
    assign mem_in_rlast = mem_out_rlast;
    assign mem_in_rvalid = mem_out_rvalid;
    assign mem_out_rready = mem_in_rready;



    //--------------------------------------------------------//
    //   Remember override status and/or decouple W-channel   //
    //--------------------------------------------------------//

    wire aw_fifo_decouple;
    wire effective_aw_override;
    wire w_override;
    wire b_override;

generate if(ALLOW_OVERRIDE) begin : override_if //Save status and decouple W-channel

    //W-channel FIFO
    wire w_fifo_wr_en = (mem_in_awvalid && mem_out_awready && !aw_decouple);
    wire w_fifo_rd_en = (mem_in_wvalid && mem_out_wready && mem_in_wlast);

    small_distram_fifo
    #(
        .DATA_WIDTH (1),
        .ADDR_WIDTH ($clog2(OUTSTANDING_WREQ))
    )
    w_fifo
    (
        .din        (effective_aw_override),
        .wr_en      (w_fifo_wr_en),
        .full       (),
        
        .dout       (w_override),
        .rd_en      (w_fifo_rd_en),
        .empty      (w_decouple),
         
        .clk        (aclk),
        .rst        (~aresetn)
    );

    //B-channel FIFO
    wire b_fifo_wr_en = (mem_in_awvalid && mem_out_awready && !aw_decouple);
    wire b_fifo_rd_en = (mem_out_bvalid && mem_in_bready);

    small_distram_fifo
    #(
        .DATA_WIDTH (1),
        .ADDR_WIDTH ($clog2(OUTSTANDING_WREQ))
    )
    b_fifo
    (
        .din        (effective_aw_override),
        .wr_en      (b_fifo_wr_en),
        .full       (aw_fifo_decouple),
        
        .dout       (b_override),
        .rd_en      (b_fifo_rd_en),
        .empty      (),
         
        .clk        (aclk),
        .rst        (~aresetn)
    );

end else begin : override_else //Just decouple W-channel

    //Indicate accepted beats
    wire aw_accepted = (mem_in_awvalid && mem_out_awready && !aw_decouple);
    wire w_last = (mem_in_wvalid && mem_out_wready && mem_in_wlast && !w_decouple);

    //Count outstanding write transfers expected
    reg unsigned [WREQ_CBITS-1:0] outst_trans;
    assign w_decouple = (outst_trans == 0);
    assign aw_fifo_decouple = (outst_trans >= OUTSTANDING_WREQ) && INCLUDE_BACKPRESSURE;
    
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

    //Zero unused signals
    assign w_override = 1'b0;
    assign b_override = 1'b0;

end endgenerate



    //--------------------------------------------------------//
    //   AW Channel token mechanism                           //
    //--------------------------------------------------------//

    //Token counter
    localparam EXTRA_BITS_OF = 2;
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] current_aw_tokens;
    wire [TOKEN_COUNT_TOTAL_WIDTH+EXTRA_BITS_OF-1:0] token_aw_update;
    wire aw_overflow = |(token_aw_update[TOKEN_COUNT_TOTAL_WIDTH+:EXTRA_BITS_OF]);
    wire aw_token_gt_init = (current_aw_tokens > { aw_init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} });

    always@(posedge aclk) begin
        if(~aresetn) current_aw_tokens <= 0;
        else if(mem_out_awready && aw_token_gt_init && !mem_in_awvalid && w_decouple) 
            current_aw_tokens <= { aw_init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
        else if(aw_overflow) current_aw_tokens <= '1;
        else current_aw_tokens <= token_aw_update[TOKEN_COUNT_TOTAL_WIDTH-1:0];
    end 

    //Bank to store tokens to be redposited
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] aw_token_bank;

    //Added components
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] w_add;
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] b_add;
    wire do_aw;

    //All summed components (with retiming)
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] aw_all_sum [AW_RETIMING_STAGES:0];
    assign aw_all_sum[0] = w_add + b_add + aw_upd_token;

    generate for(genvar j = 0; j < AW_RETIMING_STAGES; j = j + 1) begin :retim_aw
        always@(posedge aclk) begin
            if(~aresetn) aw_all_sum[j+1] <= 0;
            else aw_all_sum[j+1] <= aw_all_sum[j];
        end 
    end endgenerate

    //Implement banking (split from main token counter for timing)
    always@(posedge aclk) begin
        if(~aresetn) aw_token_bank <= 0;
        else if(!do_aw) aw_token_bank <= aw_all_sum[AW_RETIMING_STAGES];
        else aw_token_bank <= aw_token_bank + aw_all_sum[AW_RETIMING_STAGES];
    end

    //Calculate tokens for forthcoming transaction
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] aw_token_need =
        { ( (mem_in_awlen+1)*(WTIMEOUT_CYCLES+1) + BTIMEOUT_CYCLES ), {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };

    //Update token count with bank deposit or aw withdrawl
    assign do_aw = (mem_in_awvalid && mem_out_awready && !aw_decouple && !effective_aw_override);
    assign token_aw_update = (do_aw) ? current_aw_tokens - aw_token_need : current_aw_tokens + aw_token_bank;

    //Calculate tokens to redeposit for write data transmission
    reg [$clog2(WTIMEOUT_CYCLES+1)-1:0] w_add_back;

    always@(posedge aclk) begin
        if(~aresetn || mem_in_wvalid) w_add_back <= WTIMEOUT_CYCLES;
        else if(mem_out_wready && !w_decouple && w_add_back != 0) w_add_back <= w_add_back - 1;
    end  

    assign w_add = (mem_in_wvalid && mem_out_wready && !w_decouple && !w_override) ?
        { w_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0;

    //Caclulate tokens to redposit for write response reception
    reg [$clog2(BTIMEOUT_CYCLES+1)-1:0] b_add_back;

    always@(posedge aclk) begin
        if(~aresetn || mem_in_bready) b_add_back <= BTIMEOUT_CYCLES;
        else if(mem_out_bvalid && b_add_back != 0) b_add_back <= b_add_back - 1;
    end  

    assign b_add = (mem_out_bvalid && mem_in_bready && !b_override) ?
        { b_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0;



    //--------------------------------------------------------//
    //   Decoupling of AW-Channel, with sticky valid          //
    //--------------------------------------------------------//

    //Sticky valid to make sure it isn't lowered again (AXI4 standard)
    reg sticky_awvalid;

    always@(posedge aclk) begin
        if(~aresetn || (mem_out_awready && sticky_awvalid)) sticky_awvalid <= 0;
        else if(aw_can_override && aw_override && ALLOW_OVERRIDE) sticky_awvalid <= 1;
    end

    //Output status to override engine
    wire aw_throttled = (aw_token_need > current_aw_tokens);
    assign aw_has_outstanding = !w_decouple || sticky_awvalid || (mem_in_awvalid && !aw_throttled);
    assign aw_can_override = mem_in_awvalid && aw_throttled && !aw_fifo_decouple;
    assign effective_aw_override = sticky_awvalid;

    //Final decoupling signal
    assign aw_decouple = aw_fifo_decouple || (!sticky_awvalid && aw_throttled);



    //--------------------------------------------------------//
    //   Remember override status for AR-channel              //
    //--------------------------------------------------------//

    localparam NUM_FIFO = 2 ** AXI_ID_WIDTH;

    wire ar_fifo_decouple;
    wire effective_ar_override;
    wire r_override [NUM_FIFO-1:0];

genvar j;
generate if(ALLOW_OVERRIDE) begin : override_if2

    wire [NUM_FIFO-1:0] r_fifo_full;

    //Decoders for IDs
    wire [NUM_FIFO-1:0] arid_decode = (1'b1 << mem_in_arid);
    wire [NUM_FIFO-1:0] rid_decode = (1'b1 << mem_out_rid);

    //R-channel FIFO (per ID)
    for(j = 0; j < NUM_FIFO; j = j + 1) begin : r_ovr_fifos

        wire r_fifo_wr_en = (mem_in_arvalid && mem_out_arready && !ar_decouple && arid_decode[j] );
        wire r_fifo_rd_en = (mem_out_rvalid && mem_in_rready && mem_out_rlast && rid_decode[j] );

        small_distram_fifo
        #(
            .DATA_WIDTH (1),
            .ADDR_WIDTH ($clog2(OUTSTANDING_RREQ))
        )
        r_fifo
        (
            .din        (effective_ar_override),
            .wr_en      (r_fifo_wr_en),
            .full       (r_fifo_full[j]),
            
            .dout       (r_override[j]),
            .rd_en      (r_fifo_rd_en),
            .empty      ( ),
             
            .clk        (aclk),
            .rst        (~aresetn)
        );

    end 

    assign ar_fifo_decouple = |r_fifo_full;

end else begin : override_else2

    //Zero unused signals
    assign ar_fifo_decouple = 1'b0;

    for(j = 0; j < NUM_FIFO; j = j + 1) 
        assign r_override[j] = 1'b0;

end endgenerate



    //--------------------------------------------------------//
    //   AR Channel token mechanism                           //
    //--------------------------------------------------------//

    //Token counter
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] current_ar_tokens;
    wire [TOKEN_COUNT_TOTAL_WIDTH+EXTRA_BITS_OF-1:0] token_ar_update;
    wire ar_overflow = |(token_ar_update[TOKEN_COUNT_TOTAL_WIDTH+:EXTRA_BITS_OF]);
    wire ar_token_gt_init = (current_ar_tokens > { ar_init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} });

    always@(posedge aclk) begin
        if(~aresetn) current_ar_tokens <= 0;
        else if(mem_out_arready && ar_token_gt_init && !mem_in_arvalid) 
            current_ar_tokens <= { ar_init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
        else if(ar_overflow) current_ar_tokens <= '1;
        else current_ar_tokens <= token_ar_update[TOKEN_COUNT_TOTAL_WIDTH-1:0];
    end 

    //Bank to store tokens to be redposited
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] ar_token_bank;

    //Added/subtracted components
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] r_add;
    wire do_ar;

    //All summed components (with retiming)
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] ar_all_sum [AR_RETIMING_STAGES:0];
    assign ar_all_sum[0] = r_add + ar_upd_token;

    generate for(genvar j = 0; j < AR_RETIMING_STAGES; j = j + 1) begin :retime_ar
        always@(posedge aclk) begin
            if(~aresetn) ar_all_sum[j+1] <= 0;
            else ar_all_sum[j+1] <= ar_all_sum[j];
        end 
    end endgenerate

    //Implement banking (split from main token counter for timing)
    always@(posedge aclk) begin
        if(~aresetn) ar_token_bank <= 0;
        else if(!do_ar) ar_token_bank <= ar_all_sum[AR_RETIMING_STAGES];
        else ar_token_bank <= ar_token_bank + ar_all_sum[AR_RETIMING_STAGES];
    end

    //Calculate tokens for forthcoming transaction
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] ar_token_need =
        { ( (mem_in_arlen+1)*(RTIMEOUT_CYCLES+1) ), {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };

    //Update token count with bank deposit or ar withdrawl
    assign do_ar = (mem_in_arvalid && mem_out_arready && !ar_decouple && !effective_ar_override);
    assign token_ar_update = (do_ar) ? current_aw_tokens - ar_token_need : current_aw_tokens + ar_token_bank;

    //Calculate tokens to redeposit for read data reception
    reg [$clog2(RTIMEOUT_CYCLES+1)-1:0] r_add_back;

    always@(posedge aclk) begin
        if(~aresetn || mem_in_rready) r_add_back <= RTIMEOUT_CYCLES;
        else if(mem_out_rvalid && r_add_back != 0) r_add_back <= r_add_back - 1;
    end  

    assign r_add = ( mem_out_rvalid && mem_in_rready && !r_override[mem_out_rid] ) ?
        { r_add_back, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0;



    //--------------------------------------------------------//
    //   Decoupling of AR-Channel, with sticky valid          //
    //--------------------------------------------------------//

    //Sticky valid to make sure it isn't lowered again (AXI4 standard)
    reg sticky_arvalid;

    always@(posedge aclk) begin
        if(~aresetn || (mem_out_arready && sticky_arvalid)) sticky_arvalid <= 0;
        else if(ar_can_override && ar_override && ALLOW_OVERRIDE) sticky_arvalid <= 1;
    end

    //Output status to override engine
    wire ar_throttled = (ar_token_need > current_ar_tokens);
    assign ar_has_outstanding = sticky_arvalid || (mem_in_arvalid && !ar_throttled);
    assign ar_can_override = mem_in_arvalid && ar_throttled && !ar_fifo_decouple;
    assign effective_ar_override = sticky_arvalid;

    //Final decoupling signal
    assign ar_decouple = ar_fifo_decouple || (!sticky_arvalid && ar_throttled);



endmodule

`default_nettype wire