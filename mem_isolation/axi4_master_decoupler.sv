`timescale 1ns / 1ps
`default_nettype none

/*
AXI4-MM Master Interface Decoupler (for use in PR and isolation)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to allow secure decoupling of an AXI4 Memory Mapped 
   interface. 'Decoupling' in this context refers to ensuring that the signal 
   changes from one side of the interfaces are not propogated to the other. 
   This is often used in PR such that as a PR bitstream is being programmed,
   any inadvertant assertions on signals do not effect downstream modules.
   This core specifically decouples the Master interface (the issuer) from
   the Slave interface (the memory). Note, zero widths for any of the signals 
   is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_RREQ - the maximum allowed outstanding read requests
   INCLUDE_BACKPRESSURE - binary, whether or not to assert backpressure when OUTSTANDING limits reached (recommended)
   W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface
   decouple - a passive decouple signal, will wait until the current oustanding transactions finish before decoupling
   decouple_force - an active decouple signal, forces outsatnding transactions to finish before decoupling
   decouple_done - indicates when the decoupling has been completed
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
   - If W data beats can be expected before the corresponding AW request has been
   accepted (param W_BEFORE_AW_CAPABLE), the core may generate forced AW requests
   in decouple_force mode to prevent deadlock
   - If W data beats cannot be expected before the AW request, the core ignores
   this possibility, but does not explictly check that this situation never occurs
   (if it in fact does, undefined bahaviour may occur)
   - For generated W data beats when decouple_force is asserted, the tlast signal
   may be incorrect (in either of the above two cases), and should be corrected if
   relied upon downstream
*/


module axi4_master_decoupler
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter INCLUDE_BACKPRESSURE = 1,
    parameter W_BEFORE_AW_CAPABLE = 0
)
(
    //AXI4 slave connection (master to decouple connects to this)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_awaddr,
    input wire [7:0]                        axi_s_awlen,
    input wire [2:0]                        axi_s_awsize,
    input wire [1:0]                        axi_s_awburst,
    input wire                              axi_s_awvalid,
    output wire                             axi_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_s_wstrb,
    input wire                              axi_s_wlast,
    input wire                              axi_s_wvalid,
    output wire                             axi_s_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_bid,
    output wire [1:0]                       axi_s_bresp,
    output wire                             axi_s_bvalid,
    input wire                              axi_s_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_araddr,
    input wire [7:0]                        axi_s_arlen,
    input wire [2:0]                        axi_s_arsize,
    input wire [1:0]                        axi_s_arburst,
    input wire                              axi_s_arvalid,
    output wire                             axi_s_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_rid,
    output wire [AXI_DATA_WIDTH-1:0]        axi_s_rdata,
    output wire [1:0]                       axi_s_rresp,
    output wire                             axi_s_rlast,
    output wire                             axi_s_rvalid,
    input wire                              axi_s_rready,

    //AXI4 master connection (connects to slave expecting decoupled signal)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output reg [AXI_ADDR_WIDTH-1:0]         axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output reg [2:0]                        axi_m_awsize,
    output reg [1:0]                        axi_m_awburst,
    output wire                             axi_m_awvalid,
    input wire                              axi_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_m_wdata,
    output reg [(AXI_DATA_WIDTH/8)-1:0]     axi_m_wstrb,
    output wire                             axi_m_wlast,
    output wire                             axi_m_wvalid,
    input wire                              axi_m_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_bid,
    input wire [1:0]                        axi_m_bresp,
    input wire                              axi_m_bvalid,
    output wire                             axi_m_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_araddr,
    output wire [7:0]                       axi_m_arlen,
    output wire [2:0]                       axi_m_arsize,
    output wire [1:0]                       axi_m_arburst,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,

    //Decoupler signals
    input wire              decouple,
    input wire              decouple_force,

    output wire             decouple_done,
    output wire [4:0]       decouple_status_vector,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Any decouple request
    wire decoup_any = decouple || decouple_force;



    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//
    
    //Additional necessary signals
    wire safe_awdecoup;
    reg effective_awvalid;
    reg effective_awready;
    reg [7:0] effective_awlen;
    reg sticky_awvalid;
    
    //Assign values depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_awdecoup) begin
            //Valid and ready signals deasserted
            effective_awvalid = 0;
            effective_awready = 0;
            
            //Other signals don't need to be decoupled (same as Xilinx decoupler)
            effective_awlen = axi_s_awlen;
            axi_m_awburst = axi_s_awburst;
            axi_m_awaddr = axi_s_awaddr;
            axi_m_awsize = axi_s_awsize;
        end
        
        //Generate requests until safe to decouple 
        //(Note - should never happen based on protocol verifier implementation)
        else if(decouple_force && W_BEFORE_AW_CAPABLE && !sticky_awvalid) begin
            //Ready signal unchanged
            effective_awready = axi_m_awready;
        
            //Forced requests
            effective_awlen = (4096/(AXI_DATA_WIDTH/8)) - 1;  //Maximum burst length (without 4k boundary crossing)
            axi_m_awburst = 2'b01;                          //INCR type burst
            axi_m_awaddr[11:0] = 0;                         //4k boundary aligned
            axi_m_awsize = $clog2(AXI_DATA_WIDTH/8);
            effective_awvalid = 1;
            
            //Values don't matter, pass-through to avoid logic overhead
            axi_m_awaddr[AXI_ADDR_WIDTH-1:12] = axi_s_awaddr[AXI_ADDR_WIDTH-1:12];
        end
        
        //Standard pass-through
        else begin
            effective_awlen = axi_s_awlen;
            axi_m_awburst = axi_s_awburst;
            axi_m_awaddr = axi_s_awaddr;
            axi_m_awsize = axi_s_awsize;
            effective_awvalid = axi_s_awvalid || sticky_awvalid; //Neeced to avoid erroneous de-aasertion
            effective_awready = axi_m_awready;
        end
    end

    //Assign effective values
    assign axi_m_awlen = effective_awlen;
    assign axi_m_awvalid = effective_awvalid;
    assign axi_s_awready = effective_awready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_m_awid = axi_s_awid;

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//

    //Additional necessary signals
    wire safe_wdecoup;
    reg effective_wvalid;
    reg effective_wready;
    
    //Assign values depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_wdecoup) begin
           //Valid and ready signals deasserted
           effective_wvalid = 0;
           effective_wready = 0;
           
           //Other signals don't need to be decoupled (same as Xilinx decoupler)
           axi_m_wstrb = axi_s_wstrb;
        end
        
        //Generate read beats until safe to decouple
        else if(decouple_force) begin
           //Ready signal unchanged
           effective_wready = axi_m_wready;
        
           //Forced beats
           axi_m_wstrb = 0;
           effective_wvalid = 1;
        end
        
        //Standard pass-through
        else begin
            axi_m_wstrb = axi_s_wstrb;
            effective_wvalid = axi_s_wvalid;
            effective_wready = axi_m_wready;
        end
    end

    //Assign effective values
    assign axi_m_wvalid = effective_wvalid;
    assign axi_s_wready = effective_wready;

    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_m_wdata = axi_s_wdata;
    assign axi_m_wlast = axi_s_wlast; //Note - may be set incorrectly, needs correcting in further stage (prot_handler)



    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//    
    
    //Additional necessary signals
    wire safe_bdecoup;
    reg effective_bvalid;
    reg effective_bready;
    
    //Drive ready and valid signals depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_bdecoup) begin
           //Valid and ready signals deasserted
           effective_bvalid = 0;
           effective_bready = 0;
        end
        
        //Accept all responses until safe to decouple
        else if(decouple_force) begin
           //Vaild signal unchanged
           effective_bvalid = axi_m_bvalid;
        
           //Forced response accept
           effective_bready = 1;
        end
        
        //Standard pass-through
        else begin
            effective_bvalid = axi_m_bvalid;
            effective_bready = axi_s_bready;
        end
    end

    //Assign effective values
    assign axi_m_bready = effective_bready;
    assign axi_s_bvalid = effective_bvalid;
    
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_s_bid = axi_m_bid;
    assign axi_s_bresp = axi_m_bresp;



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
        else if(effective_awvalid && effective_awready && effective_bvalid && effective_bready)
            outst_wresp <= outst_wresp;
        else if(effective_awvalid && effective_awready)
            outst_wresp <= outst_wresp + 1;
        else if(effective_bvalid && effective_bready)
            outst_wresp <= outst_wresp - 1;
    end
    
    //Count outstanding beats expected
    localparam OUTSTANDING_BEATS = OUTSTANDING_WREQ * 256 * (1 + W_BEFORE_AW_CAPABLE);
    reg signed [$clog2(OUTSTANDING_BEATS+1)-1:0] outst_wdata;
    wire no_outst_wdata = (outst_wdata == 0);
    wire neg_outst_data = W_BEFORE_AW_CAPABLE && (outst_wdata < 1'sb0);
    
    always @(posedge aclk) begin
        if(~aresetn)
            outst_wdata <= 0;
        else if(effective_awvalid && effective_awready && effective_wvalid && effective_wready)
            outst_wdata <= outst_wdata + effective_awlen;
        else if(effective_awvalid && effective_awready)
            outst_wdata <= outst_wdata + effective_awlen + 1;
        else if(effective_wvalid && effective_wready)
            outst_wdata <= outst_wdata - 1;
    end

    //Sticky awvalid bit (cannot deassert once asserted)
    always@(posedge aclk) begin
    	if(~aresetn) sticky_awvalid <= 0;
    	else if(axi_s_awvalid && !axi_m_awready && !decoup_any) sticky_awvalid <= 1;
    	else if(axi_m_awready) sticky_awvalid <= 0;
    end 
    
    //Decoupling logic for write channels
    assign safe_awdecoup = (decoup_any && !neg_outst_data && !sticky_awvalid) || (aw_full && INCLUDE_BACKPRESSURE);
    assign safe_wdecoup = (decoup_any && (no_outst_wdata || neg_outst_data));
    assign safe_bdecoup = (decoup_any && no_outst_wresp);
    
    //Output decoupling results
    wire awdecoupled = (decoup_any && !neg_outst_data && !sticky_awvalid); //safe_awdecoup without full indicator
    wire wdecoupled  = safe_wdecoup && safe_awdecoup;
    wire bdecoupled = safe_bdecoup && safe_awdecoup;

    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Sticky arvalid bit (cannot deassrt once asserted)
    reg sticky_arvalid;

    //Indicate safe to decouple
    wire safe_ardecoup;

    //Valid and ready signals
    wire effective_arvalid = (safe_ardecoup ? 0 : axi_s_arvalid || sticky_arvalid);
    wire effective_arready = (safe_ardecoup ? 0 : axi_m_arready);
    
    assign axi_m_arvalid = effective_arvalid;
    assign axi_s_arready = effective_arready;
    
    //All other signals, no need to decouple (same behaviour as Xilinx Decoupler)
    assign axi_m_araddr = axi_s_araddr;
    assign axi_m_arid = axi_s_arid;
    assign axi_m_arburst = axi_s_arburst;
    assign axi_m_arsize = axi_s_arsize;
    assign axi_m_arlen = axi_s_arlen;
    
    

    //--------------------------------------------------------//
    //   AXI Read Data Channel                                //
    //--------------------------------------------------------//
    
    //Additional necessary signals
    wire safe_rdecoup;
    reg effective_rvalid;
    reg effective_rready;
    
    //Drive ready and valid signals depending on decoupling state
    always@(*) begin
        //Decouple
        if(safe_rdecoup) begin
           //Valid and ready signals deasserted
           effective_rvalid = 0;
           effective_rready = 0;
        end
        
        //Accept all responses until safe to decouple
        else if(decouple_force) begin
           //Vaild signal unchanged
           effective_rvalid = axi_m_rvalid;
        
           //Forced response accept
           effective_rready = 1;
        end
        
        //Standard pass-through
        else begin
            effective_rvalid = axi_m_rvalid;
            effective_rready = axi_s_rready;
        end
    end
    
    //Assign effective values
    assign axi_s_rvalid = effective_rvalid;
    assign axi_m_rready = effective_rready;
    
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axi_s_rid = axi_m_rid;
    assign axi_s_rresp = axi_m_rresp;
    assign axi_s_rdata = axi_m_rdata;
    assign axi_s_rlast = axi_m_rlast; 

 
 
    //--------------------------------------------------------//
    //   AXI Read Decoupling                                  //
    //--------------------------------------------------------//  
    
    //Count outstanding responses expected
    reg [$clog2(OUTSTANDING_RREQ+1)-1:0] outst_rresp_last;
    wire no_outst_rresp = (outst_rresp_last == 0);
    wire ar_full = (outst_rresp_last >= OUTSTANDING_RREQ);
    
    always @(posedge aclk) begin
        if(~aresetn)
            outst_rresp_last <= 0;
        else if(effective_arvalid && effective_arready && effective_rvalid && effective_rready && axi_m_rlast)
            outst_rresp_last <= outst_rresp_last;
        else if(effective_arvalid && effective_arready)
            outst_rresp_last <= outst_rresp_last + 1;
        else if(effective_rvalid && effective_rready && axi_m_rlast)
            outst_rresp_last <= outst_rresp_last - 1;
    end

    //Sticky arvalid bit (cannot deassrt once asserted)
    always@(posedge aclk) begin
    	if(~aresetn) sticky_arvalid <= 0;
    	else if(axi_s_arvalid && !axi_m_arready && !decoup_any) sticky_arvalid <= 1;
    	else if(axi_m_arready) sticky_arvalid <= 0;
    end 
    
    //Decoupling logic for write channels
    assign safe_ardecoup = (decoup_any && !sticky_arvalid) || (ar_full && INCLUDE_BACKPRESSURE);
    assign safe_rdecoup = (decoup_any & no_outst_rresp);
    
    //Output decoupling results
    wire ardecoupled = (decoup_any && !sticky_arvalid); //safe_areceoup without full indicator
    wire rdecoupled = safe_rdecoup;
    
    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = no_outst_wdata && no_outst_wresp && no_outst_rresp && !sticky_awvalid && !sticky_arvalid && decouple;
    
    //output status vector
    assign decouple_status_vector[0] = awdecoupled;
    assign decouple_status_vector[1] = wdecoupled;
    assign decouple_status_vector[2] = bdecoupled;
    assign decouple_status_vector[3] = ardecoupled;
    assign decouple_status_vector[4] = rdecoupled;



endmodule

`default_nettype wire
