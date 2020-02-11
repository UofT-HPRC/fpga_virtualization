`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Lite Slave Interface Protocol Verifier

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to verify the AXI-Lite interface for some common
   AXI-Lite protocol violations, correcting these errors. In the case of 
   correction, the interface errors are only corrected with respect to 
   the responses seen by the master, the slave should not expect correct 
   requests to be issued. The AXI-Lite interface has no unacceptable
   response types from the slave, therefore this core only implements
   timeout conditions that can be used to identify a hang condition, which
   can subsequently be used as the decouple_force signal for the decoupler. 
   Note, zero widths for any of the signals is not supported.

Parameters:
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path (must be 32 or 64)
   AWTIMEOUT_CYCLES - total number of cycles to wait after awvalid is asserted before indicating an AW-channel timeout
   WTIMEOUT_CYCLES - total number of cycles to wait after wvalid is asserted before indicating a W-channel timeout
   BTIMEOUT_CYCLES - total numner of cycles to wait after valid AW and W data have been received for a response before indicating a B-channel timeout
   ARTIMEOUT_CYCLES - total number of cycles to wait after arvalid is asserted before indicating an AR-channel timeout
   RTIMEOUT_CYCLES - total numner of cycles to wait after a valid AR request has been received for a response before indicating a B-channel timeout
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_RREQ - the maximum allowed outstanding read requests

Ports:
   axi_lite_s_* - the input memory mapped AXI interface
   axi_lite_m_* the output memory mapped AXI interface
   timeout_errror_irq - indicates a timeout condition has occured
   timeout_error_clear - clears a timeout condition (i.e. ack of above), need be asserted for a cycle cycle
   timeout_status_vector - an array indicating which timeout conditions have been triggered
   bresp_expected - input from decoupler indicating if a B response is outstanding (rather than duplicate logic)
   rresp_expected - input from decoupler indicating if an R response is outstanding (rather than duplicate logic)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Status Vector Mapping:
   bit 0 - Whether an AW-channel timeout has occured
   bit 1 - Whether a W-channel timeout has occured
   bit 2 - Whether a B-channel timeout has occured
   bit 3 - Whether an AR-channel timeout has occured
   bit 4 - Whether a R-channel timeout has occured 
*/


module axi_lite_slave_verifier
#(
    //AXI-Lite Interface Params
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    
    //Timeout limits
    parameter AWTIMEOUT_CYCLES = 15,
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 127,
    parameter ARTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 127,
    
    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8
)
(
    //AXI-Lite slave connection (connects to the master interface expecting a verified signal)
    //Write Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_awaddr,
    input wire                              axi_lite_s_awvalid,
    output wire                             axi_lite_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_lite_s_wstrb,
    input wire                              axi_lite_s_wvalid,
    output wire                             axi_lite_s_wready,
    //Write Response Channel
    output wire [1:0]                       axi_lite_s_bresp,
    output wire                             axi_lite_s_bvalid,
    input wire                              axi_lite_s_bready,
    //Read Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_araddr,
    input wire                              axi_lite_s_arvalid,
    output wire                             axi_lite_s_arready,
    //Read Data Response Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_lite_s_rdata,
    output wire [1:0]                       axi_lite_s_rresp,
    output wire                             axi_lite_s_rvalid,
    input wire                              axi_lite_s_rready,

    //AXI4 master connection (the slave interface to verify connects to this)
    //Write Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_awaddr,
    output wire                             axi_lite_m_awvalid,
    input wire                              axi_lite_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_lite_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_lite_m_wstrb,
    output wire                             axi_lite_m_wvalid,
    input wire                              axi_lite_m_wready,
    //Write Response Channel
    input wire [1:0]                        axi_lite_m_bresp,
    input wire                              axi_lite_m_bvalid,
    output wire                             axi_lite_m_bready,
    //Read Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_araddr,
    output wire                             axi_lite_m_arvalid,
    input wire                              axi_lite_m_arready,
    //Read Data Response Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_m_rdata,
    input wire [1:0]                        axi_lite_m_rresp,
    input wire                              axi_lite_m_rvalid,
    output wire                             axi_lite_m_rready,

    //Protocol error indicators
    output wire         timeout_error_irq,
    output wire [4:0]   timeout_status_vector,

    input wire          timeout_error_clear,

    //Inputs from Decoupler indicating if responses expected (rather than duplicating logic here)
    input wire          bresp_expected,
    input wire          rresp_expected,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AXI Write Address Channel protocol monitoring        //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(AWTIMEOUT_CYCLES+2)-1:0] awtime_count;
    wire awtimeout = (awtime_count > AWTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_lite_s_awvalid && axi_lite_m_awready) || timeout_error_clear)
            awtime_count <= 1;
        else if(axi_lite_s_awvalid && !axi_lite_m_awready)
            awtime_count <= awtime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_lite_m_awaddr = axi_lite_s_awaddr;
    assign axi_lite_m_awvalid = axi_lite_s_awvalid;
    assign axi_lite_s_awready = axi_lite_m_awready;



    //--------------------------------------------------------//
    //   AXI Write Data Channel protocol monitoring           //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(WTIMEOUT_CYCLES+2)-1:0] wtime_count;
    wire wtimeout = (wtime_count > WTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_lite_s_wvalid && axi_lite_m_wready) || timeout_error_clear)
            wtime_count <= 1;
        else if(axi_lite_s_wvalid && !axi_lite_m_wready)
            wtime_count <= wtime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_lite_m_wdata = axi_lite_s_wdata;
    assign axi_lite_m_wstrb = axi_lite_s_wstrb;
    assign axi_lite_m_wvalid = axi_lite_s_wvalid;
    assign axi_lite_s_wready = axi_lite_m_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel protocol monitoring       //
    //--------------------------------------------------------//

    //Timeout calculation
    reg [$clog2(BTIMEOUT_CYCLES+2)-1:0] btime_count;
    wire btimeout = (btime_count > BTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_lite_s_bready && axi_lite_m_bvalid) || timeout_error_clear)
            btime_count <= 1;
        else if(bresp_expected && !axi_lite_m_bvalid)
            btime_count <= btime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_lite_s_bresp = axi_lite_m_bresp;
    assign axi_lite_s_bvalid = axi_lite_m_bvalid;
    assign axi_lite_m_bready = axi_lite_s_bready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel protocol monitoring         //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(ARTIMEOUT_CYCLES+2)-1:0] artime_count;
    wire artimeout = (artime_count > ARTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_lite_s_arvalid && axi_lite_m_arready) || timeout_error_clear)
            artime_count <= 1;
        else if(axi_lite_s_arvalid && !axi_lite_m_arready)
            artime_count <= artime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_lite_m_araddr = axi_lite_s_araddr;
    assign axi_lite_m_arvalid = axi_lite_s_arvalid;
    assign axi_lite_s_arready = axi_lite_m_arready;

    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(RTIMEOUT_CYCLES+2)-1:0] rtime_count;
    wire rtimeout = (rtime_count > RTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_lite_s_rready && axi_lite_m_rvalid) || timeout_error_clear)
            rtime_count <= 1;
        else if(rresp_expected && !axi_lite_m_rvalid)
            rtime_count <= rtime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_lite_s_rdata = axi_lite_m_rdata;
    assign axi_lite_s_rresp = axi_lite_m_rresp;
    assign axi_lite_s_rvalid = axi_lite_m_rvalid;
    assign axi_lite_m_rready = axi_lite_s_rready;
    
    
    
    //--------------------------------------------------------//
    //   Interupt and Error signalling                        //
    //--------------------------------------------------------//
    
    //Register all timeout signals, sticky bits
    reg awtimeout_error;
    reg wtimeout_error;
    reg btimeout_error;
    reg artimeout_error;
    reg rtimeout_error;
    reg timeout_error;

    always@(posedge aclk) begin
        if(~aresetn || timeout_error_clear) begin
            awtimeout_error <= 0;
            wtimeout_error <= 0;
            btimeout_error <= 0;
            artimeout_error <= 0;
            rtimeout_error <= 0;
            timeout_error <= 0;
        end
        else begin
            if(awtimeout) awtimeout_error <= 1;
            if(wtimeout) wtimeout_error <= 1;
            if(btimeout) btimeout_error <= 1;
            if(artimeout) artimeout_error <= 1;
            if(rtimeout) rtimeout_error <= 1;
            if(awtimeout || wtimeout || btimeout || artimeout || rtimeout) timeout_error <= 1;
        end
    end

    //Assign violation signals to protocol error status vector
    assign timeout_status_vector[0] = (awtimeout_error);
    assign timeout_status_vector[1] = (wtimeout_error);
    assign timeout_status_vector[2] = (btimeout_error);
    assign timeout_status_vector[3] = (artimeout_error);
    assign timeout_status_vector[4] = (rtimeout_error);

    assign timeout_error_irq = awtimeout || wtimeout || btimeout || artimeout || rtimeout || timeout_error;
        


endmodule

`default_nettype wire