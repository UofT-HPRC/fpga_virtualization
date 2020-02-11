`timescale 1ns / 1ps
`default_nettype none

/*
AXI4-MM Master Interface Protocol Verifier

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is used to verify the AXi4-MM interface for some common
   AXI4 protocol violations, correcting some of these errors. In the
   case of correction, the interface errors are only corrected with
   respect to the requests seen by the slave, the master should not
   expect correct results to be returned. In addition, it implements 
   timeout conditions for each channel that can be usedto identify a 
   hang, which can subsequently be used as the decouple_force signal of 
   the deocupler. Note, zero widths for any of the signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path
   WTIMEOUT_CYCLES - total number of cycles to wait after receiving the AW request or the previous W beat before indicating a W-channel timeout
   BTIMEOUT_CYCLES - total numner of cycles to wait after bvalid is asserted before indicating a B-channel timeout
   RTIMEOUT_CYCLES - total number of cycles to wait after rvalid is asserted before indicating an R-channel timeout
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface, added awuser and aruser signals indicate an uncorrected error detected
   timeout_errror_irq - indicates a timeout condition has occured
   timeout_error_clear - clears a timeout condition (i.e. ack of above), need be asserted for a cycle cycle
   timeout_status_vector - an array indicating which timeout conditions have been triggered
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Status Vector Mapping:
   bit 0 - Whether a W-channel timeout has occured
   bit 1 - Whether a B-channel timeout has occured
   bit 2 - Whether an R-channel timeour has occured

AXI Protocol Violations Detected
   AW-Channel
    - awsize larger than the interface width - CORRECTED (set to interface width instead)
    - incorrect awlen in WRAP mode - CORRECTED (INCR mode used instead)
    - unaligned access in WRAP mode - CORRECTED (aligned address sent to slave)
    - 4k page boundary crossing - DETECTED (indicated on awuser signal)
    - changing signals after awvalid asserted - CORRECTED (signals registered)
   W-Channel
    - tlast doesn't match corresponding AW request's awlen - CORRECTED (tlast asserted according to awlen)
    - changing signals after wvalid asserted - CORRECTED (signals registered)
    - timeout on sending W beats - DETERCTED (indicated on timeout_error_irq signal)
   B-Channel
    - timeout on receiving B responses - DETECTED (indicated on timeout_error_irq signal)
   AR-Channel
    - arsize larger than the interface width - CORRECTED (set to interface width instead)
    - incorrect arlen in WRAP mode - CORRECTED (INCR mode used instead)
    - unaligned access in WRAP mode - CORRECTED (aligned address sent to slave)
    - 4k page boundary crossing - DETECTED (indicated on aruser signal)
    - changing signals after arvalid asserted - CORRECTED (signals registered)
   R-Channel
    - timeout on receiving R data beats - DETECTED (indicated on timeout_error_irq signal)
*/


module axi4_master_verifier
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    
    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8
)
(
    //AXI4 slave connection (master to verify connects to this)
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

    //AXI4 master connection (connects to slave expecting verified signal)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output wire [2:0]                       axi_m_awsize,
    output wire [1:0]                       axi_m_awburst,
    output wire [0:0]                       axi_m_awuser,
    output wire                             axi_m_awvalid,
    input wire                              axi_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_m_wstrb,
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
    output wire [0:0]                       axi_m_aruser,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,

    //Protocol error indicators
    output wire         timeout_error_irq,
    output wire [2:0]   timeout_status_vector,

    input wire          timeout_error_clear,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AXI Write Address Channel protocol monitoring        //
    //--------------------------------------------------------//
    
    //Values to be modified below in AW correction
    wire [2:0] effective_awsize;
    wire [1:0] effective_awburst;
    wire [AXI_ADDR_WIDTH-1:0] effective_awaddr;
    wire effective_awready;
    wire effective_awvalid;

    //Correct awsize larger than interface error
    localparam MAX_AWSIZE = $clog2(AXI_DATA_WIDTH/8);
    assign effective_awsize = (axi_s_awsize <= MAX_AWSIZE ? axi_s_awsize : MAX_AWSIZE);

    //Correct WRAP mode length error (by changing to INCR mode if error found)
    wire write_is_burst = (axi_s_awburst == 2'b10);
    wire write_is_valid_burst_len = 
        (axi_s_awlen == 8'd15) ||
        (axi_s_awlen == 8'd7 ) ||
        (axi_s_awlen == 8'd3 ) ||
        (axi_s_awlen == 8'd1 );

    assign effective_awburst = ((write_is_burst && !write_is_valid_burst_len) ? 2'b01 : axi_s_awburst);

    //Correct WRAP mode unaligned access error
    wire [AXI_ADDR_WIDTH-1:0] awaddr_align_masks [7:0];

    genvar j;
    generate
        for(j = 0; j < 8; j = j + 1) begin : align_mask_asgn
            assign awaddr_align_masks[j] = {(AXI_ADDR_WIDTH){1'b1}} << j;
        end
    endgenerate

    wire [AXI_ADDR_WIDTH-1:0] awaddr_aligned = axi_s_awaddr & awaddr_align_masks[effective_awsize];
    assign effective_awaddr = (effective_awburst == 2'b10 ? awaddr_aligned : axi_s_awaddr);
    
    //Determine if crossing 4k boundary (cannot correct, simply generate error signal)
    //wire [2:0] write_wrap_bits = (axi_s_awlen[3]) ? 3'b100 : //awlen = 15 (16 transfers)
    //                             (axi_s_awlen[2]) ? 3'b011 : //awlen = 7  (8 transfers)
    //                             (axi_s_awlen[1]) ? 3'b010 : //awlen = 3  (4 transfers)
    //                             3'b001;                  //awlen = 1  (2 transfers), default value
    //                                            
    //wire [3:0] write_align_bits = (effective_awburst == 2'b10) ? effective_awsize + write_wrap_bits : effective_awsize;
    //wire [AXI_ADDR_WIDTH-1:0] write_align_mask = {AXI_ADDR_WIDTH{1'b1}} << effective_awsize; //write_align_bits;
    //wire [AXI_ADDR_WIDTH-1:0] write_align_addr = effective_awaddr & write_align_mask;
    wire [AXI_ADDR_WIDTH:0] write_last_addrp1 = /*write_align_addr*/awaddr_aligned + ((axi_s_awlen + 1) << effective_awsize);
    wire [AXI_ADDR_WIDTH:0] write_last_addr = write_last_addrp1 - 1;
    
    wire aw4kcrossing = (effective_awburst == 2'b01) && (write_last_addr[AXI_ADDR_WIDTH-1:12] != axi_s_awaddr[AXI_ADDR_WIDTH-1:12]);
    
    //FIFO for burst length values (to determine if last value asserted correctly in W Channel)
    wire fifo_rd_en;
    wire fifo_wr_en;
    wire fifo_full;
    wire fifo_empty;
    wire [7:0] awlen_fifo_out;
    
    simple_fifo
    #(
        .DATA_WIDTH (8),
        .BUFFER_DEPTH_LOG2 ($clog2(OUTSTANDING_WREQ))
    )
    awlen_fifo
    (
        .din        (axi_s_awlen),
        .wr_en      (fifo_wr_en),
        .full       (fifo_full),
        
        .dout       (awlen_fifo_out),
        .rd_en      (fifo_rd_en),
        .empty      (fifo_empty),
         
        .clk        (aclk),
        .rst        (~aresetn)
    );
    
    //FIFO writing logic
    assign fifo_wr_en = effective_awvalid && effective_awready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Address Channel protocol correction        //
    //--------------------------------------------------------//

    //Register value for output
    reg [AXI_ID_WIDTH-1:0]          reg_awid;
    reg [AXI_ADDR_WIDTH-1:0]        reg_awaddr;
    reg [7:0]                       reg_awlen;
    reg [2:0]                       reg_awsize;
    reg [1:0]                       reg_awburst;
    reg [0:0]                       reg_awuser;
    reg                             reg_awvalid;
    wire                            reg_awready;

    always@(posedge aclk) begin
        if(~aresetn) reg_awvalid <= 0;
        else if(effective_awvalid && reg_awready) begin
            reg_awid <= axi_s_awid;
            reg_awaddr <= effective_awaddr;
            reg_awlen <= axi_s_awlen;
            reg_awsize <= effective_awsize;
            reg_awburst <= effective_awburst;
            reg_awuser <= {aw4kcrossing};
            reg_awvalid <= 1;
        end 
        else if(axi_m_awready) reg_awvalid <= 0;
    end 

    assign reg_awready = (axi_m_awready || !reg_awvalid);

    //Modified valid signal if fifo full
    assign effective_awvalid = axi_s_awvalid && !fifo_full;
    assign effective_awready = reg_awready && !fifo_full;
    
    //Assign output values for AW channel
    assign axi_m_awid = reg_awid;
    assign axi_m_awaddr = reg_awaddr;
    assign axi_m_awlen = reg_awlen;
    assign axi_m_awsize = reg_awsize;
    assign axi_m_awburst = reg_awburst;
    assign axi_m_awuser = reg_awuser;
    assign axi_m_awvalid = reg_awvalid;

    assign axi_s_awready = effective_awready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel protocol monitoring           //
    //--------------------------------------------------------//
    
    //Values to be modified below in W correction
    wire effective_wready;
    wire effective_wvalid;
    wire effective_wlast;
    
    //FIFO Read logic
    reg [8:0] write_count;
    assign effective_wlast = (write_count == awlen_fifo_out);
    assign fifo_rd_en = effective_wlast & effective_wready & effective_wvalid;
    
    //Write counter
    always@(posedge aclk) begin
       if(~aresetn)
           write_count <= 0;
       else if(effective_wready & effective_wvalid)
           if(effective_wlast) write_count <= 0;
           else write_count <= write_count + 1;
    end
    
    //Timeout calculation
    reg [$clog2(WTIMEOUT_CYCLES+2)-1:0] wtime_count;
    wire wtimeout = (wtime_count > WTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
       if(~aresetn || (effective_wready && effective_wvalid) || timeout_error_clear)
           wtime_count <= 1;
       else if(effective_wready && ~effective_wvalid)
           wtime_count <= wtime_count + 1;
    end
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel protocol correction           //
    //--------------------------------------------------------//

    //Register value for output
    reg [AXI_DATA_WIDTH-1:0]        reg_wdata;
    reg [(AXI_DATA_WIDTH/8)-1:0]    reg_wstrb;
    reg                             reg_wlast;
    reg                             reg_wvalid;
    wire 							reg_wready;

    always@(posedge aclk) begin
        if(~aresetn) reg_wvalid <= 0;
        else if(effective_wvalid && reg_wready) begin
            reg_wdata <= axi_s_wdata;
            reg_wstrb <= axi_s_wstrb;
            reg_wlast <= effective_wlast;
            reg_wvalid <= 1;
        end
        else if(axi_m_wready) reg_wvalid <= 0;
    end 

    assign reg_wready = (axi_m_wready || !reg_wvalid);

    //Modified ready and valid signals if fifo empty
    assign effective_wready = reg_wready && !fifo_empty;
    assign effective_wvalid = axi_s_wvalid && !fifo_empty;
    
    //Assign output values for W channel
    assign axi_m_wdata = reg_wdata;
    assign axi_m_wstrb = reg_wstrb;
    assign axi_m_wlast = reg_wlast; //axi_s_wlast ignored
    assign axi_m_wvalid = reg_wvalid;

    assign axi_s_wready = effective_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel protocol monitoring       //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(BTIMEOUT_CYCLES+2)-1:0] btime_count;
    wire btimeout = (btime_count > BTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_s_bready && axi_m_bvalid) || timeout_error_clear)
            btime_count <= 1;
        else if(axi_m_bvalid && !axi_s_bready)
            btime_count <= btime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_m_bready = axi_s_bready;
    assign axi_s_bid = axi_m_bid;
    assign axi_s_bresp = axi_m_bresp;
    assign axi_s_bvalid = axi_m_bvalid;
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel protocol monitoring         //
    //--------------------------------------------------------//
    
    //Values to be modified below in AR correction
    wire [2:0] effective_arsize;
    wire [1:0] effective_arburst;
    wire [AXI_ADDR_WIDTH-1:0] effective_araddr;

    //Correct arsize larger than interface error
    localparam MAX_ARSIZE = $clog2(AXI_DATA_WIDTH/8);
    assign effective_arsize = (axi_s_arsize <= MAX_ARSIZE ? axi_s_arsize : MAX_ARSIZE);

    //Correct WRAP mode length error (by changing to INCR mode if error found)
    wire read_is_burst = (axi_s_arburst == 2'b10);
    wire read_is_valid_burst_len = 
        (axi_s_arlen == 8'd15) ||
        (axi_s_arlen == 8'd7 ) ||
        (axi_s_arlen == 8'd3 ) ||
        (axi_s_arlen == 8'd1 );

    assign effective_arburst = ((read_is_burst && !read_is_valid_burst_len) ? 2'b01 : axi_s_arburst);

    //Correct WRAP mode unaligned access error
    wire [AXI_ADDR_WIDTH-1:0] araddr_align_masks [7:0];

    generate
        for(j = 0; j < 8; j = j + 1) begin : align_mask_asgn2
            assign araddr_align_masks[j] = {(AXI_ADDR_WIDTH){1'b1}} << j;
        end
    endgenerate

    wire [AXI_ADDR_WIDTH-1:0] araddr_aligned = axi_s_araddr & araddr_align_masks[effective_arsize];
    assign effective_araddr = (effective_arburst == 2'b10 ? araddr_aligned : axi_s_araddr);
    
    //Determine if crossing 4k boundary (cannot correct, simply generate error signal)
    //wire [2:0] read_wrap_bits = (axi_s_arlen[3]) ? 3'b100 : //arlen = 15 (16 transfers)
    //                             (axi_s_arlen[2]) ? 3'b011 : //arlen = 7  (8 transfers)
    //                             (axi_s_arlen[1]) ? 3'b010 : //arlen = 3  (4 transfers)
    //                             3'b001;                  //arlen = 1  (2 transfers), default value
    //                                            
    //wire [3:0] read_align_bits = (effective_arburst == 2'b10) ? effective_arsize + read_wrap_bits : effective_arsize;
    //wire [AXI_ADDR_WIDTH-1:0] read_align_mask = {AXI_ADDR_WIDTH{1'b1}} << effective_arsize; //read_align_bits;
    //wire [AXI_ADDR_WIDTH-1:0] read_align_addr = effective_araddr & read_align_mask;
    wire [AXI_ADDR_WIDTH:0] read_last_addrp1 = /*read_align_addr*/araddr_aligned + ((axi_s_arlen + 1) << effective_arsize);
    wire [AXI_ADDR_WIDTH:0] read_last_addr = read_last_addrp1 - 1;
    
    wire ar4kcrossing = (effective_arburst == 2'b01) && (read_last_addr[AXI_ADDR_WIDTH-1:12] != axi_s_araddr[AXI_ADDR_WIDTH-1:12]);


    
    //--------------------------------------------------------//
    //   AXI Read Address Channel protocol correction         //
    //--------------------------------------------------------//
    
    //Register value for output
    reg [AXI_ID_WIDTH-1:0]          reg_arid;
    reg [AXI_ADDR_WIDTH-1:0]        reg_araddr;
    reg [7:0]                       reg_arlen;
    reg [2:0]                       reg_arsize;
    reg [1:0]                       reg_arburst;
    reg [0:0]                       reg_aruser;
    reg                             reg_arvalid;
    wire 							reg_arready;

    always@(posedge aclk) begin
        if(~aresetn) reg_arvalid <= 0;
        else if(axi_s_arvalid && reg_arready) begin
            reg_arid <= axi_s_arid;
            reg_araddr <= effective_araddr;
            reg_arlen <= axi_s_arlen;
            reg_arsize <= effective_arsize;
            reg_arburst <= effective_arburst;
            reg_aruser <= {ar4kcrossing};
            reg_arvalid <= axi_s_arvalid;
        end 
        else if(axi_m_arready) reg_arvalid <= 0;
    end 

    assign reg_arready = (axi_m_arready || !reg_arvalid);
    
    //Assign output values for AR channel
    assign axi_m_arid = reg_arid;
    assign axi_m_araddr = reg_araddr;
    assign axi_m_arlen = reg_arlen;
    assign axi_m_arsize = reg_arsize;
    assign axi_m_arburst = reg_arburst;
    assign axi_m_aruser = reg_aruser;
    assign axi_m_arvalid = reg_arvalid;  

    assign axi_s_arready = reg_arready;

    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(RTIMEOUT_CYCLES+2)-1:0] rtime_count;
    wire rtimeout = (rtime_count > RTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (axi_s_rready && axi_m_rvalid)  || timeout_error_clear)
            rtime_count <= 1;
        else if(axi_m_rvalid && !axi_s_rready)
            rtime_count <= rtime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign axi_m_rready = axi_s_rready;
    assign axi_s_rid = axi_m_rid;
    assign axi_s_rdata = axi_m_rdata;
    assign axi_s_rresp = axi_m_rresp;
    assign axi_s_rlast = axi_m_rlast;
    assign axi_s_rvalid = axi_m_rvalid;
    
    
    
    //--------------------------------------------------------//
    //   Interupt and Error signalling                        //
    //--------------------------------------------------------//
    
    //Register all timeout signals, sticky bits
    reg wtimeout_error;
    reg btimeout_error;
    reg rtimeout_error;
    reg timeout_error;

    always@(posedge aclk) begin
        if(~aresetn || timeout_error_clear) begin
            wtimeout_error <= 0;
            btimeout_error <= 0;
            rtimeout_error <= 0;
            timeout_error <= 0;
        end
        else begin
            if(wtimeout) wtimeout_error <= 1;
            if(btimeout) btimeout_error <= 1;
            if(rtimeout) rtimeout_error <= 1;
            if(wtimeout || btimeout || rtimeout) timeout_error <= 1;
        end
    end

    //Assign violation signals to protocol error status vector
    assign timeout_status_vector[0] = (wtimeout_error);
    assign timeout_status_vector[1] = (btimeout_error);
    assign timeout_status_vector[2] = (rtimeout_error);

    assign timeout_error_irq = wtimeout || btimeout || rtimeout || timeout_error;
        


endmodule

`default_nettype wire