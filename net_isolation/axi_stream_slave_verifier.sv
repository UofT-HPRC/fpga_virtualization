`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Slave Interface Protocol Verifier

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to verify the AXI-Stream interface for some common
   AXI protocol violations, correcting some of these errors. Since the
   verification is from the persepective of the slave (i.e. the decoupled
   interface does not send any data), the only error to check for is a
   timeout condition. The timeour check can be used to identify a hang, 
   which can subsequently be used as the decouple_force signal of the 
   decoupler. Note, zero widths for any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals
   INCLUDE_TIMEOUT_ERROR - binary, whether to check for timeouts on ingress (useless if ingress channel cannot assert backpressure)
   TIMEOUT_CYCLES - total numner of cycles to wait after tvalid is asserted before indicating an ingress timeout

Ports:
   axis_s_* - the input axi stream for the ingress direction
   axis_m_* - the output axi stream for the ingress direction
   timeout_errror_irq - indicates a timeout condition has occured, ingress
   timeout_error_clear - clears a timeout condition (i.e. ack of above), need be asserted for a cycle cycle
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

AXI Protocol Violations Detected
   Ingress Direction
    - timeout on receiving ingress beats - DETECTED (indicated on timeout_error_irq signal)
*/


module axi_stream_slave_verifier
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_DEST_WIDTH = 4,

    //Core Features
    parameter INCLUDE_TIMEOUT_ERROR = 0,

    //Timeout Limits
    parameter TIMEOUT_CYCLES = 15
)
(
    //Ingress Input AXI stream (connects to the master interface that expects a verified signal)
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_s_tdata,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_s_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_s_tkeep,
    input wire                                                  axis_s_tlast,
    input wire                                                  axis_s_tvalid,
    output wire                                                 axis_s_tready,

    //Ingress Output AXI stream (the slave interface to verify connects to this)
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_m_tdata,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_m_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_m_tkeep,
    output wire                                                 axis_m_tlast,
    output wire                                                 axis_m_tvalid,
    input wire                                                  axis_m_tready,

    //Protocol error indicators
    output wire         timeout_error_irq,
    input wire          timeout_error_clear,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Ingress Channel monitoring                           //
    //--------------------------------------------------------//

    //Timeout calculation
    reg [$clog2(TIMEOUT_CYCLES+1)-1:0] time_count;
    wire timeout = (time_count == TIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
       if(~aresetn || (axis_m_tready && axis_s_tvalid) || timeout_error_clear)
           time_count <= 0;
       else if(axis_s_tvalid && !axis_m_tready && !timeout)
           time_count <= time_count + 1;
    end

    //track timeout errors
    reg timeout_error;

    always@(posedge aclk) begin
        if(~aresetn || timeout_error_clear) timeout_error <= 0;
        else if(timeout) timeout_error <= 1;
    end 

    assign timeout_error_irq = (timeout || timeout_error) && INCLUDE_TIMEOUT_ERROR;



    //--------------------------------------------------------//
    //   Inress Channel Passthrough                           //
    //--------------------------------------------------------//
    assign axis_m_tdata = axis_s_tdata;
    assign axis_m_tdest = axis_s_tdest;
    assign axis_m_tkeep = axis_s_tkeep;
    assign axis_m_tlast = axis_s_tlast;
    assign axis_m_tvalid = axis_s_tvalid;
    assign axis_s_tready = axis_m_tready;
    


endmodule

`default_nettype wire