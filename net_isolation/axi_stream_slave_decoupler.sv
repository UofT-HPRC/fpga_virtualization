`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Slave Interface Decoupler

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to allow secure decoupling of an AXI-Stream interface. 
   'Decoupling' in this context refers to ensuring that the signal changes from 
   one side of the interfaces are not propogated to the other. This is often 
   used in PR such that as a PR bitstream is being programmed, any inadvertant 
   assertions on signals do not effect downstream modules. This core specifically
   decouples the slave side (the receiver) from the master side (the issuer). 
   For ingress packets, the decoupler waits for the end of the current packet,
   but once decoupled the ingress channel accepts all data beats and drops them
   (effectively dropping any incoming packets). Also, for ingress packets, once
   decouple is de-asserted, the decoupling remains until the end of the currently
   dropped packet. Note, zero widths for any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals
   DISALLOW_BACKPRESSURE - binary, whether the input port is allowed to assert backpressure (the ingr_tready overrided if enabled)

Ports:
   axis_s_* - the input axi stream for the ingress direction
   axis_m_* - the output axi stream for the ingress direction
   decouple - a passive decouple signal, will wait until the current oustanding transactions finishes before decoupling
   decouple_force - an active decouple signal, forces immediate dropping of packets, even mid-transaction (ingress direction)
   decouple_done - indicates when the decoupling has been completed
   decoupled - indicates that the core is decoupled (differs from above in that it doesn't wait for a requested decouple action)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_slave_decoupler
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_DEST_WIDTH = 4,

    //Features to Implement
    parameter DISALLOW_BACKPRESSURE = 1
)
(
    //Ingress Input AXI stream (connects to the master interface that expects a decoupled signal)
    input wire [AXIS_BUS_WIDTH-1:0]         axis_s_tdata,
    input wire [AXIS_DEST_WIDTH-1:0]        axis_s_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_s_tkeep,
    input wire                              axis_s_tlast,
    input wire                              axis_s_tvalid,
    output wire                             axis_s_tready,

    //Ingress Output AXI stream (the slave interface to decouple connects to this)
    output wire [AXIS_BUS_WIDTH-1:0]        axis_m_tdata,
    output wire [AXIS_DEST_WIDTH-1:0]       axis_m_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_m_tkeep,
    output wire                             axis_m_tlast,
    output wire                             axis_m_tvalid,
    input wire                              axis_m_tready,

    //Decoupler signals
    input wire                              decouple,
    input wire                              decouple_force,

    output wire                             decouple_done,
    output wire                             decoupled,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Slave Channel                                        //
    //--------------------------------------------------------//

    //Accept all data when decoupled
    reg safe_decoup;
    wire effective_tvalid = (safe_decoup ? 1'b0 : axis_s_tvalid);
    wire effective_tready = (DISALLOW_BACKPRESSURE ? 1'b1 : (safe_decoup ? 1'b1 : axis_m_tready));

    //Assign effective values
    assign axis_m_tvalid = effective_tvalid;
    assign axis_s_tready = effective_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_m_tdata = axis_s_tdata;
    assign axis_m_tdest = axis_s_tdest;
    assign axis_m_tkeep = axis_s_tkeep;
    assign axis_m_tlast = axis_s_tlast;



    //--------------------------------------------------------//
    //   Ingress Decoupling Logic                             //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_packet_nxt;
    reg outst_packet;

    always@(*) begin
        if(~aresetn) outst_packet_nxt = 0;
        else if(axis_s_tvalid && effective_tready) begin
            if(axis_s_tlast) outst_packet_nxt = 0;
            else outst_packet_nxt = 1;
        end 
        else outst_packet_nxt = outst_packet;
    end

    always@(posedge aclk) outst_packet <= outst_packet_nxt;

    //Decoupling logic for ingress channel
    always@(posedge aclk) begin
        if(~aresetn) safe_decoup <= 0;
        else if(decouple_force) safe_decoup <= 1;
        else if(decouple && !outst_packet_nxt) safe_decoup <= 1;
        else if(!outst_packet_nxt) safe_decoup <= 0; //Wait to finish drop current packet before un-decoupling
    end
    
    //Output decoupling results
    wire ingr_decoupled = safe_decoup;

    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = decouple && !outst_packet;
    assign decoupled = ingr_decoupled;



endmodule

`default_nettype wire