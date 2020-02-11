`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Interface Protocol Verifier

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to verify the AXI-Stream interface for some common
   AXI protocol violations, correcting some of these errors. In the case 
   of correction, the interface errors are only corrected with respect to 
   the requests seen by the slave (axi_out for tx), the master should not
   expect correct results to be returned. In addition, it implements optional
   timeout conditions for the rx channel that can be used to identify a 
   hang, which can subsequently be used as the decouple_force signal of 
   the decoupler.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of all AXI ID signals (zero is supported)
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals (zero is supported)
   MAX_PACKET_LENGTH - the maximum packet length to support (for forced tlast)
   DISALLOW_INVALID_MID_PACKET_EGR - binary, whether to expect (and enforce) a continuous stream of flits for tx
   INCLUDE_TIMEOUT_ERROR_INGR - binary, whether to check for timeouts on rx (useless if rx channel cannot assert backpressure)
   INGR_TIMEOUT_CYCLES - total numner of cycles to wait after tvalid is asserted before indicating an rx timeout

Ports:
   axis_tx_in_* - the input axi stream for the tx direction
   axis_tx_out_* - the output axi stream for the agress direction
   axis_rx_in_* - the input axi stream for the rx direction
   axis_rx_out_* - the output axi stream for the rx direction
   axis_tx_tlast_forced - whether the tlast signal for the tx axi-stream is forced to high somewhere downstream
   oversize_errror_irq - indicates an oversize tx packet condition has occured, tx
   oversize_error_clear - clears an oversize error condition (i.e. ack of above), need be asserted for a cycle cycle
   timeout_errror_irq - indicates a timeout condition has occured, rx
   timeout_error_clear - clears a timeout condition (i.e. ack of above), need be asserted for a cycle cycle
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

AXI Protocol Violations Detected
   Egress Direction
    - tvalid goes low mid-packet - CORRECTED (held high even with invalid data)
    - tlast not asserted before max packet size reached - CORRECTED (tlast asserted automatically at limit, oversize_error_irq also asserted)
    - changing signals after tvalid asserted - CORRECTED (signals registered)
   Ingress Direction
    - timeout on receiving rx beats - DETECTED (indicated on timeout_error_irq signal)
*/


module axi_stream_prot_verifier
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Core Features
    parameter DISALLOW_INVALID_MID_PACKET_EGR = 1,
    parameter INCLUDE_TIMEOUT_ERROR_INGR = 0

    //Timeout Limits
    parameter INGR_TIMEOUT_CYCLES = 15
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

    //Indicate tlast asserted
    output wire                                                 axis_tx_tlast_forced,

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

    //Protocol error indicators
    output wire         oversize_errror_irq,
    input wire          oversize_error_clear,

    output wire         timeout_error_irq,
    input wire          timeout_error_clear,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Egress Channel monitoring                            //
    //--------------------------------------------------------//
    
    //Values to be modified in tx correction
    wire effective_tx_tready;
    wire effective_tx_tvalid;
    wire effective_tx_tlast;

    //Keep track of outstanding packet, ensure tvalid is not deasserted until tlast
    reg outst_tx_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_tx_packet <= 0;
        else if(effective_tx_tvalid && effective_tx_tready) begin
            if(effective_tx_tlast) outst_tx_packet <= 0;
            else outst_tx_packet <= 1;
        end 
    end

    //Correct the tvalid value
    assign effective_tx_tvalid = axis_tx_in_tvalid || (outst_tx_packet && DISALLOW_INVALID_MID_PACKET_EGR);

    //Count beats sent in current packet
    localparam MAX_BEATS = 
        (MAX_PACKET_LENGTH/AXIS_BUS_WIDTH) + (MAX_PACKET_LENGTH % AXIS_BUS_WIDTH == 0 ? 0 : 1);
    reg [$clog2(MAX_BEATS+1)-1:0] tx_beat_count;

    always@(posedge aclk) begin
        if(~aresetn) tx_beat_count <= 0;
        else if(effective_tx_tvalid && effective_tx_tready) begin
            if(effective_tx_tlast) tx_beat_count <= 0;
            else tx_beat_count <= tx_beat_count + 1;
        end 
    end

    //Correct tlast value
    assign axis_tx_tlast_forced = (tx_beat_count == (MAX_BEATS-1));
    assign effective_tx_tlast = (axis_tx_in_tlast || axis_tx_tlast_forced);

    //track oversize errors
    reg oversize_error;
    wire curr_oversize_error = (axis_tx_tlast_forced && !axis_tx_in_tlast);

    always@(posedge aclk) begin
        if(~aresetn || oversize_error_clear) oversize_error <= 0;
        else if(curr_oversize_error) oversize_error <= 1;
    end 

    assign oversize_errror_irq = (curr_oversize_error || oversize_error);



    //--------------------------------------------------------//
    //   Egress Channel Correction                            //
    //--------------------------------------------------------//

    //Register for output value
    reg [AXIS_BUS_WIDTH-1:0]                            reg_tx_tdata;
    reg [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       reg_tx_tid;
    reg [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   reg_tx_tdest;
    reg [(AXIS_BUS_WIDTH/8)-1:0]                        reg_tx_tkeep;
    reg                                                 reg_tx_tlast;
    reg                                                 reg_tx_tvalid;
    wire                                                reg_tx_tready;

    always@(posedge aclk) begin
        if(~aresetn) reg_tx_tvalid <= 0;
        else if(effective_tx_tvalid && effective_tx_tready) begin
            reg_tx_tdata <= axis_tx_in_tdata;
            reg_tx_tid <= axis_tx_in_tid;
            reg_tx_tdest <= axis_tx_in_tdest;
            reg_tx_tkeep <= axis_tx_in_tkeep;
            reg_tx_tlast <= effective_tx_tlast;
            reg_tx_tvalid <= 1;
        end 
        else if(axis_tx_out_tready) reg_tx_tvalid <= 0;
    end

    assign reg_tx_tready = (axis_tx_out_tready || !reg_tx_tvalid);

    //Assign output values for tx channel
    assign axis_tx_out_tdata = reg_tx_tdata;
    assign axis_tx_out_tid = reg_tx_tid;
    assign axis_tx_out_tdest = reg_tx_tdest;
    assign axis_tx_out_tkeep = reg_tx_tkeep;
    assign axis_tx_out_tlast = reg_tx_tlast;
    assign axis_tx_out_tvalid = reg_tx_tvalid;

    assign effective_tx_tready = reg_tx_tready;
    assign axis_tx_in_tready = effective_tx_tready;



    //--------------------------------------------------------//
    //   Ingress Channel monitoring                           //
    //--------------------------------------------------------//

    //Timeout calculation
    reg [$clog2(INGR_TIMEOUT_CYCLES+1)-1:0] rx_time_count;
    wire rx_timeout = (rx_time_count == INGR_TIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
       if(~aresetn || (axis_rx_out_tready && axis_rx_in_tvalid) || timeout_error_clear)
           rx_time_count <= 0;
       else if(axis_rx_in_tvalid && !axis_rx_out_tready && !rx_timeout)
           rx_time_count <= rx_time_count + 1;
    end

    //track timeout errors
    reg timeout_error;

    always@(posedge aclk) begin
        if(~aresetn || timeout_error_clear) timeout_error <= 0;
        else if(rx_timeout) timeout_error <= 1;
    end 

    assign timeout_error_irq = (rx_timeout || timeout_error) && INCLUDE_TIMEOUT_ERROR_INGR;



    //--------------------------------------------------------//
    //   Inress Channel Passthrough                           //
    //--------------------------------------------------------//
    assign axis_rx_out_tdata = axis_rx_in_tdata;
    assign axis_rx_out_tdest = axis_rx_in_tdest;
    assign axis_rx_out_tkeep = axis_rx_in_tkeep;
    assign axis_rx_out_tlast = axis_rx_in_tlast;
    assign axis_rx_out_tvalid = axis_rx_in_tvalid;
    assign axis_rx_in_tready = axis_rx_out_tready;
    


endmodule

`default_nettype wire