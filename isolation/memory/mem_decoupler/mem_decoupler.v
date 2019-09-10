`timescale 1ns / 1ps
`default_nettype none


//The memory decoupler
module mem_decoupler
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter INCLUDE_BACKPRESSURE = 0,
    parameter W_BEFORE_AW_CAPABLE = 0
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         mem_in_awaddr,
    input wire [7:0]                        mem_in_awlen,
    input wire [2:0]                        mem_in_awsize,
    input wire [1:0]                        mem_in_awburst,
    input wire                              mem_in_awvalid,
    output wire                             mem_in_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         mem_in_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     mem_in_wstrb,
    input wire                              mem_in_wlast,
    input wire                              mem_in_wvalid,
    output wire                             mem_in_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_bid,
    output wire [1:0]                       mem_in_bresp,
    output wire                             mem_in_bvalid,
    input wire                              mem_in_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         mem_in_araddr,
    input wire [7:0]                        mem_in_arlen,
    input wire [2:0]                        mem_in_arsize,
    input wire [1:0]                        mem_in_arburst,
    input wire                              mem_in_arvalid,
    output wire                             mem_in_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_rid,
    output wire [AXI_DATA_WIDTH-1:0]        mem_in_rdata,
    output wire [1:0]                       mem_in_rresp,
    output wire                             mem_in_rlast,
    output wire                             mem_in_rvalid,
    input wire                              mem_in_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_awid,
    output reg [AXI_ADDR_WIDTH-1:0]         mem_out_awaddr,
    output wire [7:0]                       mem_out_awlen,
    output reg [2:0]                        mem_out_awsize,
    output reg [1:0]                        mem_out_awburst,
    output wire                             mem_out_awvalid,
    input wire                              mem_out_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        mem_out_wdata,
    output reg [(AXI_DATA_WIDTH/8)-1:0]     mem_out_wstrb,
    output wire                             mem_out_wlast,
    output wire                             mem_out_wvalid,
    input wire                              mem_out_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_bid,
    input wire [1:0]                        mem_out_bresp,
    input wire                              mem_out_bvalid,
    output wire                             mem_out_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        mem_out_araddr,
    output wire [7:0]                       mem_out_arlen,
    output wire [2:0]                       mem_out_arsize,
    output wire [1:0]                       mem_out_arburst,
    output wire                             mem_out_arvalid,
    input wire                              mem_out_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_rid,
    input wire [AXI_DATA_WIDTH-1:0]         mem_out_rdata,
    input wire [1:0]                        mem_out_rresp,
    input wire                              mem_out_rlast,
    input wire                              mem_out_rvalid,
    output wire                             mem_out_rready,

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
            effective_awlen = mem_in_awlen;
            mem_out_awburst = mem_in_awburst;
            mem_out_awaddr = mem_in_awaddr;
            mem_out_awsize = mem_in_awsize;
        end
        
        //Generate requests until safe to decouple 
        //(Note - should never happen based on protocol verifier implementation)
        else if(decouple_force && W_BEFORE_AW_CAPABLE && !sticky_awvalid) begin
            //Ready signal unchanged
            effective_awready = mem_out_awready;
        
            //Forced requests
            effective_awlen = (4096/(AXI_DATA_WIDTH/8)) - 1;    //Maximum burst length (without 4k boundary crossing)
            mem_out_awburst = 2'b01;                          //INCR type burst
            mem_out_awaddr[11:0] = 0;                         //4k boundary aligned
            mem_out_awsize = $clog2(AXI_DATA_WIDTH/8);
            effective_awvalid = 1;
            
            //Values don't matter, pass-through to avoid logic overhead
            mem_out_awaddr[AXI_ADDR_WIDTH-1:12] = mem_in_awaddr[AXI_ADDR_WIDTH-1:12];
        end
        
        //Standard pass-through
        else begin
            effective_awlen = mem_in_awlen;
            mem_out_awburst = mem_in_awburst;
            mem_out_awaddr = mem_in_awaddr;
            mem_out_awsize = mem_in_awsize;
            effective_awvalid = mem_in_awvalid;
            effective_awready = mem_out_awready;
        end
    end

    //Assign effective values
    assign mem_out_awlen = effective_awlen;
    assign mem_out_awvalid = effective_awvalid;
    assign mem_in_awready = effective_awready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign mem_out_awid = mem_in_awid;

    
    
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
           mem_out_wstrb = mem_in_wstrb;
        end
        
        //Generate read beats until safe to decouple
        else if(decouple_force) begin
           //Ready signal unchanged
           effective_wready = mem_out_wready;
        
           //Forced beats
           mem_out_wstrb = 0;
           effective_wvalid = 1;
        end
        
        //Standard pass-through
        else begin
            mem_out_wstrb = mem_in_wstrb;
            effective_wvalid = mem_in_wvalid;
            effective_wready = mem_out_wready;
        end
    end

    //Assign effective values
    assign mem_out_wvalid = effective_wvalid;
    assign mem_in_wready = effective_wready;

    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign mem_out_wdata = mem_in_wdata;
    assign mem_out_wlast = mem_in_wlast; //Note - may be set incorrectly, needs correcting in further stage (prot_handler)



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
        /*if(safe_bdecoup) begin
           //Valid and ready signals deasserted
           effective_bvalid = 0;
           effective_bready = 0;
        end
        
        //Accept all responses until safe to decouple
        else if(decouple_force) begin*/
        if(decouple_force && !safe_bdecoup) begin
           //Vaild signal unchanged
           effective_bvalid = mem_out_bvalid;
        
           //Forced response accept
           effective_bready = 1;
        end
        
        //Standard pass-through
        else begin
            effective_bvalid = mem_out_bvalid;
            effective_bready = mem_in_bready;
        end
    end

    //Assign effective values
    assign mem_out_bready = effective_bready;
    assign mem_in_bvalid = effective_bvalid;
    
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign mem_in_bid = mem_out_bid;
    assign mem_in_bresp = mem_out_bresp;



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
    	else if(mem_in_awvalid && !mem_out_awready && !decoup_any) sticky_awvalid <= 1;
    	else if(mem_out_awready) sticky_awvalid <= 0;
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
    
    //Indicate safe to decouple
    wire safe_ardecoup;

    //Valid and ready signals
    wire effective_arvalid = (safe_ardecoup) ? 0 : mem_in_arvalid;
    wire effective_arready = (safe_ardecoup) ? 0 : mem_out_arready;
    
    assign mem_out_arvalid = effective_arvalid;
    assign mem_in_arready = effective_arready;
    
    //All other signals, no need to decouple (same behaviour as Xilinx Decoupler)
    assign mem_out_araddr = mem_in_araddr;
    assign mem_out_arid = mem_in_arid;
    assign mem_out_arburst = mem_in_arburst;
    assign mem_out_arsize = mem_in_arsize;
    assign mem_out_arlen = mem_in_arlen;
    
    

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
        /*if(safe_rdecoup) begin
           //Valid and ready signals deasserted
           effective_rvalid = 0;
           effective_rready = 0;
        end
        
        //Accept all responses until safe to decouple
        else if(decouple_force) begin*/
        if(decouple_force && !safe_rdecoup) begin
           //Vaild signal unchanged
           effective_rvalid = mem_out_rvalid;
        
           //Forced response accept
           effective_rready = 1;
        end
        
        //Standard pass-through
        else begin
            effective_rvalid = mem_out_rvalid;
            effective_rready = mem_in_rready;
        end
    end
    
    //Assign effective values
    assign mem_in_rvalid = effective_rvalid;
    assign mem_out_rready = effective_rready;
    
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign mem_in_rid = mem_out_rid;
    assign mem_in_rresp = mem_out_rresp;
    assign mem_in_rdata = mem_out_rdata;
    assign mem_in_rlast = mem_out_rlast; 

 
 
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
        else if(effective_arvalid && effective_arready && effective_rvalid && effective_rready && mem_out_rlast)
            outst_rresp_last <= outst_rresp_last;
        else if(effective_arvalid && effective_arready)
            outst_rresp_last <= outst_rresp_last + 1;
        else if(effective_rvalid && effective_rready && mem_out_rlast)
            outst_rresp_last <= outst_rresp_last - 1;
    end

    //Sticky arvalid bit (cannot deassrt once asserted)
    reg sticky_arvalid;

    always@(posedge aclk) begin
    	if(~aresetn) sticky_arvalid <= 0;
    	else if(mem_in_arvalid && !mem_out_arready && !decoup_any) sticky_arvalid <= 1;
    	else if(mem_out_arready) sticky_arvalid <= 0;
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
