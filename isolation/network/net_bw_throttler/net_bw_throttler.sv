`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module net_bw_throttler
#(
    //AXIS Interface Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    localparam MAX_BEATS = 
        (MAX_PACKET_LENGTH/AXIS_BUS_WIDTH) + (MAX_PACKET_LENGTH%AXIS_BUS_WIDTH == 0) ? 0 : 1,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam TOKEN_COUNT_TOTAL_WIDTH = TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH
)
(
   //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in_tkeep,
    input wire                                                  axis_egr_in_tlast,
    input wire                                                  axis_egr_in_tvalid,
    output wire                                                 axis_egr_in_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out_tkeep,
    output wire                                                 axis_egr_out_tlast,
    output wire                                                 axis_egr_out_tvalid,
    input wire                                                  axis_egr_out_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in_tkeep,
    input wire                                                  axis_ingr_in_tlast,
    input wire                                                  axis_ingr_in_tvalid,
    output wire                                                 axis_ingr_in_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out_tkeep,
    output wire                                                 axis_ingr_out_tlast,
    output wire                                                 axis_ingr_out_tvalid,
    input wire                                                  axis_ingr_out_tready,

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  init_token,
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Pass-through with decoupling                         //
    //--------------------------------------------------------//
    
    //Decouple signals
    wire egr_decouple;

    //Egress channel
    assign axis_egr_out_tdata = axis_egr_in_tdata;
    assign axis_egr_out_tid = axis_egr_in_tid;
    assign axis_egr_out_tdest = axis_egr_in_tdest;
    assign axis_egr_out_tkeep = axis_egr_in_tkeep;
    assign axis_egr_out_tlast = axis_egr_in_tlast;
    assign axis_egr_out_tvalid = (egr_decouple) ? 1'b0 : axis_egr_in_tvalid;
    assign axis_egr_in_tready = (egr_decouple) ? 1'b0 : axis_egr_out_tready;

    //Ingress channel (no throttling or decoupling)
    assign axis_ingr_out_tdata = axis_ingr_in_tdata;
    assign axis_ingr_out_tdest = axis_ingr_in_tdest;
    assign axis_ingr_out_tkeep = axis_ingr_in_tkeep;
    assign axis_ingr_out_tlast = axis_ingr_in_tlast;
    assign axis_ingr_out_tvalid = axis_ingr_in_tvalid;
    assign axis_ingr_in_tready = axis_ingr_out_tready;



    //--------------------------------------------------------//
    //   Signals needed                                       //
    //--------------------------------------------------------//

    //Signals needed later
    wire new_packet_start;

    //Valid beat indicator
    wire valid_beat = axis_egr_in_tvalid && axis_egr_out_tready && !egr_decouple;
    wire first_beat = valid_beat && new_packet_start;
    wire last_beat = valid_beat && axis_egr_in_tlast;



    //--------------------------------------------------------//
    //   Egress Channel token mechanism                       //
    //--------------------------------------------------------//

    //Token counter
    localparam EXTRA_BITS_OF = 2;
    reg [TOKEN_COUNT_TOTAL_WIDTH-1:0] current_tokens;
    wire [TOKEN_COUNT_TOTAL_WIDTH+EXTRA_BITS_OF-1:0] token_update;
    wire tok_overflow = |(token_update[TOKEN_COUNT_TOTAL_WIDTH+:EXTRA_BITS_OF]);
    wire token_gt_init = (current_tokens > { init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} });

    always@(posedge aclk) begin
        if(~aresetn) current_tokens <= 0;
        else if(axis_egr_out_tready && token_gt_init && new_packet_start && !axis_egr_in_tvalid) 
            current_tokens <= { init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
        else if(tok_overflow) current_tokens <= '1;
        else current_tokens <= token_update[TOKEN_COUNT_TOTAL_WIDTH-1:0];
    end 

    //Added/subtracted components
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] egr_sub;
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] add_back;
    assign token_update = current_tokens + add_back + upd_token - egr_sub;

    //Calculate tokens for forthcoming transaction
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] token_need = { MAX_BEATS, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
    assign egr_sub = (first_beat) ? token_need : 0;

    //Calculate tokens to redposit for data tranmission
    reg [$clog2(MAX_BEATS)-1:0] add_back_count;

    always@(posedge aclk) begin
    	if(~aresetn || last_beat) add_back_count <= MAX_BEATS-1;
    	else if(valid_beat && add_back_count != 0) add_back_count <= add_back_count -1;
    end

    assign add_back = (last_beat) ? { add_back_count, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0;



    //--------------------------------------------------------//
    //   Decoupling of Egress Channel                         //
    //--------------------------------------------------------//

    //Keep track of whether a packet is currently being processed
    reg outst_egr_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_egr_packet <= 0;
        else if(valid_beat) begin
            if(axis_egr_in_tlast) outst_egr_packet <= 0;
            else outst_egr_packet <= 1;
        end 
    end

    assign new_packet_start = !outst_egr_packet;

    //Final decoupling signal
    wire throttled = (token_need < current_tokens);
    assign egr_decouple = (!outst_egr_packet && throttled);



endmodule

`default_nettype wire