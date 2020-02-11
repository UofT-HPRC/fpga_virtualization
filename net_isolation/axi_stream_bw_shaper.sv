`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Bandwidth Shaper

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to control the ammount of bandwidth allowed to pass 
   through an axi-stream interface.The algorithm implemented includes a 
   token count that is updated every cycle by some indicated upd amount, and 
   which is initiailized to some indicated init amount (at reset and idle).
   Note, zero widths for any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of all AXI ID signals
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals
   MAX_PACKET_LENGTH - the maximum packet length to support (for forced tlast)
   TOKEN_COUNT_INT_WIDTH - the token count integer component width (fixed point representation)
   TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width (fixed point representation)

Ports:
   axis_s_* - the input axi stream for the egress direction
   axis_m_* - the output axi stream for the agress direction
   init_token - the initial token count, integer representation
   upd_token - the token update rate per cycle, fixed-point representation (1 integer bit, TOKEN_COUNT_FRAC_WIDTH fractional bits)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_bw_shaper
#(
    //AXIS Interface Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8
)
(
   //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]             axis_s_tdata,
    input wire [AXIS_ID_WIDTH-1:0]              axis_s_tid,
    input wire [AXIS_DEST_WIDTH-1:0]            axis_s_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]         axis_s_tkeep,
    input wire                                  axis_s_tlast,
    input wire                                  axis_s_tvalid,
    output wire                                 axis_s_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]            axis_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]             axis_m_tid,
    output wire [AXIS_DEST_WIDTH-1:0]           axis_m_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]        axis_m_tkeep,
    output wire                                 axis_m_tlast,
    output wire                                 axis_m_tvalid,
    input wire                                  axis_m_tready,

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]      init_token,
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]       upd_token,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    localparam MAX_BEATS = (MAX_PACKET_LENGTH/AXIS_BUS_WIDTH) + (MAX_PACKET_LENGTH%AXIS_BUS_WIDTH == 0 ? 0 : 1);
    localparam TOKEN_COUNT_TOTAL_WIDTH = TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH;

    //--------------------------------------------------------//
    //   Pass-through with decoupling                         //
    //--------------------------------------------------------//
    
    //Decouple signals
    wire decouple;

    //Egress channel
    assign axis_m_tdata = axis_s_tdata;
    assign axis_m_tid = axis_s_tid;
    assign axis_m_tdest = axis_s_tdest;
    assign axis_m_tkeep = axis_s_tkeep;
    assign axis_m_tlast = axis_s_tlast;
    assign axis_m_tvalid = (decouple ? 1'b0 : axis_s_tvalid);
    assign axis_s_tready = (decouple ? 1'b0 : axis_m_tready);




    //--------------------------------------------------------//
    //   Signals needed                                       //
    //--------------------------------------------------------//

    //Signals needed later
    wire new_packet_start;

    //Valid beat indicator
    wire valid_beat = axis_s_tvalid && axis_m_tready && !decouple;
    wire first_beat = valid_beat && new_packet_start;
    wire last_beat = valid_beat && axis_s_tlast;



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
        else if(axis_m_tready && token_gt_init && new_packet_start && !axis_s_tvalid) 
            current_tokens <= { init_token, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
        else if(tok_overflow) current_tokens <= '1;
        else current_tokens <= token_update[TOKEN_COUNT_TOTAL_WIDTH-1:0];
    end 

    //Added/subtracted components
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] sub;
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] add_back;
    assign token_update = current_tokens + add_back + upd_token - sub;

    //Calculate tokens for forthcoming transaction
    wire [TOKEN_COUNT_TOTAL_WIDTH-1:0] token_need = { MAX_BEATS, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} };
    assign sub = (first_beat ? token_need : 0);

    //Calculate tokens to redposit for data tranmission
    reg [$clog2(MAX_BEATS)-1:0] add_back_count;

    always@(posedge aclk) begin
    	if(~aresetn || last_beat) add_back_count <= MAX_BEATS-1;
    	else if(valid_beat && add_back_count != 0) add_back_count <= add_back_count -1;
    end

    assign add_back = (last_beat ? { add_back_count, {TOKEN_COUNT_FRAC_WIDTH{1'b0}} } : 0);



    //--------------------------------------------------------//
    //   Decoupling of Egress Channel                         //
    //--------------------------------------------------------//

    //Keep track of whether a packet is currently being processed
    reg outst_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_packet <= 0;
        else if(valid_beat) begin
            if(axis_s_tlast) outst_packet <= 0;
            else outst_packet <= 1;
        end 
    end

    assign new_packet_start = !outst_packet;

    //Final decoupling signal
    wire throttled = (token_need < current_tokens);
    assign decouple = (!outst_packet && throttled);



endmodule

`default_nettype wire