`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Interface Decoupler (bi-directional)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to allow secure decoupling of an AXI-Stream interface. 
   'Decoupling' in this context refers to ensuring that the signal changes from 
   one side of the interfaces are not propogated to the other. This is often 
   used in PR such that as a PR bitstream is being programmed, any inadvertant 
   assertions on signals do not effect downstream modules. This core specifically
   decouples in both tx and rx directions at the same time (named from
   the point of view of the region being decoupled). For tx packets, the
   decoupler waits for the end of the current packet before decoupling. For
   rx packets, the decoupler also waits for the end of the current packet,
   but once decoupled the rx channel accepts all data beats and drops them
   (effectively dropping any incoming packets). Also, for rx packets, once
   decouple is de-asserted, the decoupling remains until the end of the currently
   dropped packet.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of all AXI ID signals (zero is supported)
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals (zero is supported)
   DISALLOW_INGR_BACKPRESSURE - binary, whether the rx port is allowed to assert backpressure (the rx_tready overrided if enabled)

Ports:
   axis_tx_in_* - the input axi stream for the tx direction
   axis_tx_out_* - the output axi stream for the agress direction
   axis_rx_in_* - the input axi stream for the rx direction
   axis_rx_out_* - the output axi stream for the rx direction
   axis_tx_tlast_forced - whether the tlast signal for the tx axi-stream is forced to high somewhere downstream
   decouple - a passive decouple signal, will wait until the current oustanding transactions finish before decoupling
   decouple_force_tx - an active decouple signal, forces end of current transaction (tx direction)
   decouple_force_rx - an active decouple signal, forces immediate dropping of packets, even mid-transaction (rx direction)
   decouple_done - indicates when the decoupling has been completed
   decouple_status_vector - an array indicating various decoupling status information
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Status Vector Mapping:
   bit 0 - Whether tx direction has been decoupled
   bit 1 - Whether rx direction has been decoupled
*/


module axi_stream_decoupler
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Features to Implement
    parameter DISALLOW_INGR_BACKPRESSURE = 1
)
(
    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_tx_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_tx_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_tx_in_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_tx_in_tkeep,
    input wire                                                  axis_tx_in_tlast,
    input wire                                                  axis_tx_in_tvalid,
    output wire                                                 axis_tx_in_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_tx_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_tx_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_tx_out_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_tx_out_tkeep,
    output wire                                                 axis_tx_out_tlast,
    output wire                                                 axis_tx_out_tvalid,
    input wire                                                  axis_tx_out_tready,

    //Indicate tlast asserted by protocol corrector
    input wire                                                  axis_tx_tlast_forced,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_rx_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_rx_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_rx_in_tkeep,
    input wire                                                  axis_rx_in_tlast,
    input wire                                                  axis_rx_in_tvalid,
    output wire                                                 axis_rx_in_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_rx_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_rx_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_rx_out_tkeep,
    output wire                                                 axis_rx_out_tlast,
    output wire                                                 axis_rx_out_tvalid,
    input wire                                                  axis_rx_out_tready,

    //Decoupler signals
    input wire              decouple,
    input wire              decouple_force_tx,
    input wire              decouple_force_rx,

    output wire             decouple_done,
    output wire [1:0]       decouple_status_vector,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Any decouple request
    wire decoup_any_tx = decouple || decouple_force_tx;


    //--------------------------------------------------------//
    //   Egress Channel                                       //
    //--------------------------------------------------------//
    
    //Additional Necessary Signals
    wire safe_tx_decoup;
    wire effective_tx_tvalid = (safe_tx_decoup ? 1'b0 : axis_tx_in_tvalid);
    wire effective_tx_tready = (safe_tx_decoup ? 1'b0 : axis_tx_out_tready);

    //Assign effective values
    assign axis_tx_out_tvalid = effective_tx_tvalid;
    assign axis_tx_in_tready = effective_tx_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_tx_out_tdata = axis_tx_in_tdata;
    assign axis_tx_out_tid = axis_tx_in_tid;
    assign axis_tx_out_tdest = axis_tx_in_tdest;
    assign axis_tx_out_tkeep = axis_tx_in_tkeep;
    assign axis_tx_out_tlast = axis_tx_in_tlast;



    //--------------------------------------------------------//
    //   Egress Decoupling Logic                              //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_tx_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_tx_packet <= 0;
        else if(effective_tx_tvalid && effective_tx_tready) begin
            if(axis_tx_in_tlast || axis_tx_tlast_forced) outst_tx_packet <= 0;
            else outst_tx_packet <= 1;
        end 
    end 
    
    //Decoupling logic for tx channels
    assign safe_tx_decoup = (decoup_any_tx && !outst_tx_packet);
    
    //Output decoupling results
    wire tx_decoupled = safe_tx_decoup;



    //--------------------------------------------------------//
    //   Ingress Channel                                      //
    //--------------------------------------------------------//

    //Accept all data when decoupled
    reg safe_rx_decoup;
    wire effective_rx_tvalid = (safe_rx_decoup ? 1'b0 : axis_rx_in_tvalid);
    wire effective_rx_tready = (DISALLOW_INGR_BACKPRESSURE ? 1'b1 : (safe_rx_decoup ? 1'b1 : axis_rx_out_tready));

    //Assign effective values
    assign axis_rx_out_tvalid = effective_rx_tvalid;
    assign axis_rx_in_tready = effective_rx_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_rx_out_tdata = axis_rx_in_tdata;
    assign axis_rx_out_tdest = axis_rx_in_tdest;
    assign axis_rx_out_tkeep = axis_rx_in_tkeep;
    assign axis_rx_out_tlast = axis_rx_in_tlast;



    //--------------------------------------------------------//
    //   Ingress Decoupling Logic                             //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_rx_packet_nxt;
    reg outst_rx_packet;

    always@(*) begin
        if(~aresetn) outst_rx_packet_nxt = 0;
        else if(axis_rx_in_tvalid && effective_rx_tready) begin
            if(axis_rx_in_tlast) outst_rx_packet_nxt = 0;
            else outst_rx_packet_nxt = 1;
        end 
        else outst_rx_packet_nxt = outst_rx_packet;
    end

    always@(posedge aclk) outst_rx_packet <= outst_rx_packet_nxt;

    //Decoupling logic for rx channel
    always@(posedge aclk) begin
        if(~aresetn) safe_rx_decoup <= 0;
        else if(decouple_force_rx) safe_rx_decoup <= 1;
        else if(decouple && !outst_rx_packet_nxt) safe_rx_decoup <= 1;
        else if(!outst_rx_packet_nxt) safe_rx_decoup <= 0; //Wait to finish drop current packet before un-decoupling
    end
    
    //Output decoupling results
    wire rx_decoupled = safe_rx_decoup;

    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = decouple && !outst_tx_packet && !outst_rx_packet;
    
    //output status vector
    assign decouple_status_vector[0] = tx_decoupled;
    assign decouple_status_vector[1] = rx_decoupled;



endmodule

`default_nettype wire