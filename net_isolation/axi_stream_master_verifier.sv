`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Master Interface Protocol Verifier

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to verify the AXI-Stream interface for some common
   AXI protocol violations, correcting some of these errors. In the case 
   of correction, the interface errors are only corrected with respect to 
   the requests seen by the slave. In addition, it implements a test for
   oversized packet sending (with a parameterized MTU), which can be used
   to decouple the sender. Note, zero widths for any of the signals is not
   supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of all AXI ID signals
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals
   MAX_PACKET_LENGTH - the maximum packet length to support (for forced tlast)
   DISALLOW_INVALID_MID_PACKET - binary, whether to expect (and enforce) a continuous stream of flits for egress

Ports:
   axis_s_* - the input axi stream for the egress direction
   axis_m_* - the output axi stream for the agress direction
   axis_tlast_forced - whether the tlast signal for the egress axi-stream is forced to high somewhere downstream
   oversize_error_irq - indicates an oversize egress packet condition has occured, egress
   oversize_error_clear - clears an oversize error condition (i.e. ack of above), need be asserted for a cycle cycle
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

AXI Protocol Violations Detected
   Egress Direction
    - tvalid goes low mid-packet - CORRECTED (held high even with invalid data)
    - tlast not asserted before max packet size reached - CORRECTED (tlast asserted automatically at limit, oversize_error_irq also asserted)
    - changing signals after tvalid asserted - CORRECTED (signals registered)
*/


module axi_stream_master_verifier
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Core Features
    parameter DISALLOW_INVALID_MID_PACKET = 1
)
(
    //Egress Input AXI stream (the master interface to verify connects to this)
    input wire [AXIS_BUS_WIDTH-1:0]         axis_s_tdata,
    input wire [AXIS_ID_WIDTH-1:0]          axis_s_tid,
    input wire [AXIS_DEST_WIDTH-1:0]        axis_s_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_s_tkeep,
    input wire                              axis_s_tlast,
    input wire                              axis_s_tvalid,
    output wire                             axis_s_tready,

    //Egress Output AXI stream (connects to the slave expecting the verified signal)
    output wire [AXIS_BUS_WIDTH-1:0]        axis_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]         axis_m_tid,
    output wire [AXIS_DEST_WIDTH-1:0]       axis_m_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_m_tkeep,
    output wire                             axis_m_tlast,
    output wire                             axis_m_tvalid,
    input wire                              axis_m_tready,

    //Indicate tlast asserted
    output wire                             axis_tlast_forced,

    //Protocol error indicators
    output wire                             oversize_error_irq,
    input wire                              oversize_error_clear,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Egress Channel monitoring                            //
    //--------------------------------------------------------//
    
    //Values to be modified in egress correction
    wire effective_tready;
    wire effective_tvalid;
    wire effective_tlast;

    //Keep track of outstanding packet, ensure tvalid is not deasserted until tlast
    reg outst_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_packet <= 0;
        else if(effective_tvalid && effective_tready) begin
            if(effective_tlast) outst_packet <= 0;
            else outst_packet <= 1;
        end 
    end

    //Correct the tvalid value
    assign effective_tvalid = axis_s_tvalid || (outst_packet && DISALLOW_INVALID_MID_PACKET);

    //Count beats sent in current packet
    localparam MAX_BEATS = 
        (MAX_PACKET_LENGTH / (AXIS_BUS_WIDTH/8) ) + (MAX_PACKET_LENGTH % (AXIS_BUS_WIDTH/8) == 0 ? 0 : 1);
    reg [$clog2(MAX_BEATS+1)-1:0] beat_count;

    always@(posedge aclk) begin
        if(~aresetn) beat_count <= 0;
        else if(effective_tvalid && effective_tready) begin
            if(effective_tlast) beat_count <= 0;
            else beat_count <= beat_count + 1;
        end 
    end

    //Correct tlast value
    assign axis_tlast_forced = (beat_count == (MAX_BEATS-1));
    assign effective_tlast = (axis_s_tlast || axis_tlast_forced);

    //track oversize errors
    reg oversize_error;
    wire curr_oversize_error = (axis_tlast_forced && !axis_s_tlast);

    always@(posedge aclk) begin
        if(~aresetn || oversize_error_clear) oversize_error <= 0;
        else if(curr_oversize_error) oversize_error <= 1;
    end 

    assign oversize_error_irq = (curr_oversize_error || oversize_error);



    //--------------------------------------------------------//
    //   Egress Channel Correction                            //
    //--------------------------------------------------------//

    //Register for output value
    reg [AXIS_BUS_WIDTH-1:0]        reg_tdata;
    reg [AXIS_ID_WIDTH-1:0]         reg_tid;
    reg [AXIS_DEST_WIDTH-1:0]       reg_tdest;
    reg [(AXIS_BUS_WIDTH/8)-1:0]    reg_tkeep;
    reg                             reg_tlast;
    reg                             reg_tvalid;
    wire                            reg_tready;

    always@(posedge aclk) begin
        if(~aresetn) reg_tvalid <= 0;
        else if(effective_tvalid && effective_tready) begin
            reg_tdata <= axis_s_tdata;
            reg_tid <= axis_s_tid;
            reg_tdest <= axis_s_tdest;
            reg_tkeep <= axis_s_tkeep;
            reg_tlast <= effective_tlast;
            reg_tvalid <= 1;
        end 
        else if(axis_m_tready) reg_tvalid <= 0;
    end

    assign reg_tready = (axis_m_tready || !reg_tvalid);

    //Assign output values for egress channel
    assign axis_m_tdata = reg_tdata;
    assign axis_m_tid = reg_tid;
    assign axis_m_tdest = reg_tdest;
    assign axis_m_tkeep = reg_tkeep;
    assign axis_m_tlast = reg_tlast;
    assign axis_m_tvalid = reg_tvalid;

    assign effective_tready = reg_tready;
    assign axis_s_tready = effective_tready;
    


endmodule

`default_nettype wire