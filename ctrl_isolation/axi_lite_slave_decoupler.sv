`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Lite Slave Interface Decoupler (for use in PR and isolation)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to allow secure decoupling of an AXI-Lite Memory Mapped 
   interface. 'Decoupling' in this context refers to ensuring that the signal 
   changes from one side of the interfaces are not propogated to the other. 
   This is often used in PR such that as a PR bitstream is being programmed,
   any inadvertant assertions on signals do not effect downstream modules.
   This core specifically decouples the Slave interface (the peripheral) from
   the Master interface (the issuer). Note, zero widths for any of the signals 
   is not supported.

Parameters:
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path (must be 32 or 64)
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_RREQ - the maximum allowed outstanding read requests
   INCLUDE_BACKPRESSURE - binary, whether or not to assert backpressure when OUTSTANDING limits reached (recommended)
   W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted

Ports:
   axi_lite_s_* - the input memory mapped AXI interface
   axi_lite_m_* the output memory mapped AXI interface
   decouple - a passive decouple signal, will wait until the current oustanding transactions finish before decoupling
   decouple_force - an active decouple signal, forces outsatnding transactions to finish before decoupling
   decouple_done - indicates when the decoupling has been completed
   bresp_expected - output to verifier indicating if a B response is outstanding (rather than duplicate logic)
   rresp_expected - output to verifier indicating if an R response is outstanding (rather than duplicate logic)
   decouple_status_vector - an array indicating various decoupling status information
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Status Vector Mapping:
   bit 0 - Whether AW channel has been decoupled
   bit 1 - Whether W channel has been decoupled
   bit 2 - Whether B channel has been decoupled
   bit 3 - Whether AR channel has been decoupled
   bit 4 - Whether R channel has been decoupled

Notes:
   - If decouple_force is asserted, forced responses on the bresp and rresp channels
   are issued, with a SLVERR indicated (slave error), if any outstanding responses
   are expected
   - Once the decoupler enters a stable decoupling state, requests to the ctrl
   interface are accepted and forced responses are issued, with a SLVERR indicated
   (slave error)
*/


module axi_lite_slave_decoupler
#(
    //AXI-Lite Interface Params
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter INCLUDE_BACKPRESSURE = 1,
    parameter W_BEFORE_AW_CAPABLE = 1
)
(
    //AXI-Lite slave connection (connects to the master interface expecting a decoupled signal)
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

    //AXI4 master connection (the slave interface to decouple connects to this)
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
    output reg                              axi_lite_m_bready,
    //Read Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_araddr,
    output wire                             axi_lite_m_arvalid,
    input wire                              axi_lite_m_arready,
    //Read Data Response Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_m_rdata,
    input wire [1:0]                        axi_lite_m_rresp,
    input wire                              axi_lite_m_rvalid,
    output reg                              axi_lite_m_rready,

    //Decoupler signals
    input wire              decouple,
    input wire              decouple_force,

    output wire             decouple_done,
    output wire [4:0]       decouple_status_vector,

    //Signal to Verifier to indicate responses expected (Rather than duplicate logic there)
    output wire             bresp_expected,
    output wire             rresp_expected,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Any decouple request
    wire decoup_any = decouple || decouple_force;

    //Register indicates and active decoupling state
    reg active_decoupled;



    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//
    
    //Indicates safe to decouple AW
    wire safe_awdecoup;

    //Determine appropriate valid and ready signals
    assign axi_lite_m_awvalid = ((safe_awdecoup || active_decoupled) ? 0 : axi_lite_s_awvalid);
    wire effective_awready = (active_decoupled ? 1 : (safe_awdecoup ? 0 : axi_lite_m_awready)); //Accept any requests in decoupled mode
    assign axi_lite_s_awready = effective_awready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_lite_m_awaddr = axi_lite_s_awaddr;

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//

    //Indicates safe to decouple W
    wire safe_wdecoup;

    //Determine appropriate valid and ready signals
    assign axi_lite_m_wvalid = ((safe_wdecoup || active_decoupled) ? 0 : axi_lite_s_wvalid);
    wire effective_wready = (active_decoupled ? 1 : (safe_wdecoup ? 0 : axi_lite_m_wready)); //Accept any requests in decoupled mode
    assign axi_lite_s_wready = effective_wready;

    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_lite_m_wdata = axi_lite_s_wdata;
    assign axi_lite_m_wstrb = axi_lite_s_wstrb;



    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//    
    
    //Indicates safe to decouple B, but also that no beats need be forced in decouple_force or active_decoupled modes
    wire safe_bdecoup;

    reg effective_bvalid;
    reg [1:0] effective_bresp;
    
    //Drive ready and valid signals depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_bdecoup) begin
           //Valid and ready signals deasserted
           effective_bvalid = 0;
           axi_lite_m_bready = 0;

           //Other signals pass-through (don't care)
           effective_bresp = axi_lite_m_bresp;
        end
        
        //Force responses until safe to decouple
        else if(decouple_force || active_decoupled) begin
           //Forced response send
           effective_bresp = 2'b10; //Indicate slave error
           effective_bvalid = 1;

           //Decouple ready signal
           axi_lite_m_bready = 0;
        end
        
        //Standard pass-through
        else begin
            effective_bresp = axi_lite_m_bresp;
            effective_bvalid = axi_lite_m_bvalid;
            axi_lite_m_bready = axi_lite_s_bready;
        end
    end

    //Assign effective values
    assign axi_lite_s_bvalid = effective_bvalid;
    assign axi_lite_s_bresp = effective_bresp;



    //--------------------------------------------------------//
    //   AXI Write Decoupling                                 //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wresp;
    wire no_outst_wresp = (outst_wresp == 0);
    wire aw_full = (outst_wresp >= OUTSTANDING_WREQ);
    
    always @(posedge aclk) begin
        if(~aresetn) 
            outst_wresp <= 0;
        else if(axi_lite_s_awvalid && effective_awready && effective_bvalid && axi_lite_s_bready)
            outst_wresp <= outst_wresp;
        else if(axi_lite_s_awvalid && effective_awready)
            outst_wresp <= outst_wresp + 1;
        else if(effective_bvalid && axi_lite_s_bready)
            outst_wresp <= outst_wresp - 1;
    end

    //Decouple status stored
    wire no_outst_wdata;
    wire awdecoupled;
    wire wdecoupled;
    wire bdecoupled;
    
    //Count outstanding beats expected
    generate if(W_BEFORE_AW_CAPABLE) begin : signed_count_if

        reg signed [$clog2(OUTSTANDING_WREQ+1):0] outst_wdata; // Note - extra bit for sign
        assign no_outst_wdata = (outst_wdata == 0);
        wire neg_outst_data = (outst_wdata < 1'sb0);
        wire w_full = (outst_wdata >= OUTSTANDING_WREQ) || (outst_wdata <= -OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata) && !neg_outst_data;
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata <= 0;
            else if(axi_lite_s_awvalid && axi_lite_s_awready && axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata;
            else if(axi_lite_s_awvalid && axi_lite_s_awready)
                outst_wdata <= outst_wdata + 1;
            else if(axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata - 1;
        end

        //Decoupling logic for write channels
        assign safe_awdecoup = (decoup_any && !neg_outst_data) || (aw_full && INCLUDE_BACKPRESSURE);
        assign safe_wdecoup = (decoup_any && (no_outst_wdata || neg_outst_data)) || (w_full && INCLUDE_BACKPRESSURE);
        assign safe_bdecoup = ((decoup_any || active_decoupled) && !bresp_expected); //Don't send responses until all data received
        
        //Output decoupling results
        assign awdecoupled = (decoup_any && !neg_outst_data); //safe_awdecoup without full indicator
        assign wdecoupled  = (decoup_any && (no_outst_wdata || neg_outst_data)) && safe_awdecoup; //safe_wdecoup without full indicator
        assign bdecoupled = safe_bdecoup && safe_awdecoup && safe_wdecoup;

    end else begin

        reg [$clog2(OUTSTANDING_WREQ+1)-1:0] outst_wdata; // Note - unsigned version
        assign no_outst_wdata = (outst_wdata == 0);
        wire w_full = (outst_wdata >= OUTSTANDING_WREQ);
        assign bresp_expected = (outst_wresp != outst_wdata);
        
        always @(posedge aclk) begin
            if(~aresetn)
                outst_wdata <= 0;
            else if(axi_lite_s_awvalid && axi_lite_s_awready && axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata;
            else if(axi_lite_s_awvalid && axi_lite_s_awready)
                outst_wdata <= outst_wdata + 1;
            else if(axi_lite_s_wvalid && axi_lite_s_wready)
                outst_wdata <= outst_wdata - 1;
        end

        //Decoupling logic for write channels
        assign safe_awdecoup = (decoup_any) || (aw_full && INCLUDE_BACKPRESSURE);
        assign safe_wdecoup = (decoup_any && no_outst_wdata) || (w_full && INCLUDE_BACKPRESSURE);
        assign safe_bdecoup = ((decoup_any || active_decoupled) && !bresp_expected); //Don't send responses until all data received
        
        //Output decoupling results
        assign awdecoupled = (decoup_any); //safe_awdecoup without full indicator
        assign wdecoupled  = (decoup_any && no_outst_wdata) && safe_awdecoup; //safe_wdecoup without full indicator
        assign bdecoupled = safe_bdecoup && safe_awdecoup && safe_wdecoup;

    end endgenerate

    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Indicates safe to decouple AR
    wire safe_ardecoup;

    //Valid and ready signals
    assign axi_lite_m_arvalid = ((safe_ardecoup || active_decoupled) ? 0 : axi_lite_s_arvalid);
    wire effective_arready = (active_decoupled ? 1 : (safe_ardecoup ? 0 : axi_lite_m_arready)); //Accept any requests in decoupled mode
    assign axi_lite_s_arready = effective_arready;
    
    //All other signals, no need to decouple (same behaviour as Xilinx Decoupler)
    assign axi_lite_m_araddr = axi_lite_s_araddr;
    
    

    //--------------------------------------------------------//
    //   AXI Read Data Channel                                //
    //--------------------------------------------------------//
    
    //Indicates safe to decouple R, but also that no beats need be forced in decouple_force or active_decoupled modes
    wire safe_rdecoup;

    reg effective_rvalid;
    reg [1:0] effective_rresp;
    
    //Drive ready and valid signals depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_rdecoup) begin
           //Valid and ready signals deasserted
           effective_rvalid = 0;
           axi_lite_m_rready = 0;

           //Other signals pass through unchanged (don't care)
           effective_rresp = axi_lite_m_rresp;
        end
        
        //Force responses until safe to decouple
        else if(decouple_force || active_decoupled) begin
           //Forced response send
           effective_rresp = 2'b10; //Indicate slave error
           effective_rvalid = 1;

           //Decouple ready signal
           axi_lite_m_rready = 0;
        end
        
        //Standard pass-through
        else begin
            effective_rresp = axi_lite_m_rresp;
            effective_rvalid = axi_lite_m_rvalid;
            axi_lite_m_rready = axi_lite_s_rready;
        end
    end
    
    //Assign effective values
    assign axi_lite_s_rresp = effective_rresp;
    assign axi_lite_s_rvalid = effective_rvalid;
    
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_lite_s_rdata = axi_lite_m_rdata;

 
 
    //--------------------------------------------------------//
    //   AXI Read Decoupling                                  //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_RREQ+1)-1:0] outst_rresp;
    wire no_outst_rresp = (outst_rresp == 0);
    assign rresp_expected = !no_outst_rresp;
    wire ar_full = (outst_rresp >= OUTSTANDING_RREQ);
    
    always @(posedge aclk) begin
        if(~aresetn)
            outst_rresp <= 0;
        else if(axi_lite_s_arvalid && effective_arready && effective_rvalid && axi_lite_s_rready)
            outst_rresp <= outst_rresp;
        else if(axi_lite_s_arvalid && effective_arready)
            outst_rresp <= outst_rresp + 1;
        else if(effective_rvalid && axi_lite_s_rready)
            outst_rresp <= outst_rresp - 1;
    end

    //Decoupling logic for write channels
    assign safe_ardecoup = decoup_any || (ar_full && INCLUDE_BACKPRESSURE);
    assign safe_rdecoup = ((decoup_any || active_decoupled) && no_outst_rresp);
    
    //Output decoupling results
    wire ardecoupled = decoup_any; //safe_areceoup without full indicator
    wire rdecoupled = safe_rdecoup;
    
    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = no_outst_wdata && no_outst_wresp && no_outst_rresp && decouple;

    //active decouple register (Waits for outsatnding transactions to complete before un-decoupling)
    always@(posedge aclk) begin
        if(~aresetn) active_decoupled <= 0;
        else if(no_outst_wdata && no_outst_wresp && no_outst_rresp) begin
            if(decoup_any) active_decoupled <= 1;
            else active_decoupled <= 0;
        end
    end
    
    //output status vector
    assign decouple_status_vector[0] = awdecoupled;
    assign decouple_status_vector[1] = wdecoupled;
    assign decouple_status_vector[2] = bdecoupled;
    assign decouple_status_vector[3] = ardecoupled;
    assign decouple_status_vector[4] = rdecoupled;



endmodule

`default_nettype wire
