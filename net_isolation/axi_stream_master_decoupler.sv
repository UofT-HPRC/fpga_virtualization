`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Master Interface Decoupler

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to allow secure decoupling of an AXI-Stream interface. 
   'Decoupling' in this context refers to ensuring that the signal changes from 
   one side of the interfaces are not propogated to the other. This is often 
   used in PR such that as a PR bitstream is being programmed, any inadvertant 
   assertions on signals do not effect downstream modules. This core specifically
   decouples the master side (the issuer) from the slave side (the receiver). The
   decoupler waits for the end of the current packet before decoupling. Note, zero
   widths for any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of all AXI ID signals
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals

Ports:
   axis_s_* - the input axi stream
   axis_m_* - the output axi stream
   axis_tlast_forced - whether the tlast signal for the egress axi-stream is forced to high somewhere downstream
   decouple - a passive decouple signal, will wait until the current oustanding transactions finish before decoupling
   decouple_force - an active decouple signal, forces end of current transaction (egress direction)
   decouple_done - indicates when the decoupling has been completed
   decoupled - indicates that the core is decoupled (differs from above in that it doesn't wait for a requested decouple action)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_master_decoupler
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4
)
(
    //Egress Input AXI stream (the master interface to decouple connects to this)
    input wire [AXIS_BUS_WIDTH-1:0]         axis_s_tdata,
    input wire [AXIS_ID_WIDTH-1:0]          axis_s_tid,
    input wire [AXIS_DEST_WIDTH-1:0]        axis_s_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_s_tkeep,
    input wire                              axis_s_tlast,
    input wire                              axis_s_tvalid,
    output wire                             axis_s_tready,

    //Egress Output AXI stream (connects to the slave expecting the decoupled signal)
    output wire [AXIS_BUS_WIDTH-1:0]        axis_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]         axis_m_tid,
    output wire [AXIS_DEST_WIDTH-1:0]       axis_m_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_m_tkeep,
    output wire                             axis_m_tlast,
    output wire                             axis_m_tvalid,
    input wire                              axis_m_tready,

    //Indicate tlast asserted by protocol corrector
    input wire                              axis_tlast_forced,

    //Decoupler signals
    input wire                              decouple,
    input wire                              decouple_force,

    output wire                             decouple_done,
    output wire                             decoupled,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Any decouple request
    wire decoup_any = decouple || decouple_force;


    //--------------------------------------------------------//
    //   Master Channel                                       //
    //--------------------------------------------------------//
    
    //Additional Necessary Signals
    wire safe_decoup;
    wire effective_tvalid = (safe_decoup ? 1'b0 : axis_s_tvalid);
    wire effective_tready = (safe_decoup ? 1'b0 : axis_m_tready);

    //Assign effective values
    assign axis_m_tvalid = effective_tvalid;
    assign axis_s_tready = effective_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_m_tdata = axis_s_tdata;
    assign axis_m_tid = axis_s_tid;
    assign axis_m_tdest = axis_s_tdest;
    assign axis_m_tkeep = axis_s_tkeep;
    assign axis_m_tlast = axis_s_tlast;



    //--------------------------------------------------------//
    //   Master Decoupling Logic                              //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_packet <= 0;
        else if(effective_tvalid && effective_tready) begin
            if(axis_s_tlast || axis_tlast_forced) outst_packet <= 0;
            else outst_packet <= 1;
        end 
    end 
    
    //Decoupling logic for egress channels
    assign safe_decoup = (decoup_any && !outst_packet);
    
    //Output decoupling results
    wire egr_decoupled = safe_decoup;

    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = decouple && !outst_packet;
    assign decoupled = egr_decoupled;



endmodule

`default_nettype wire