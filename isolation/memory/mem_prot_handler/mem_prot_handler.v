`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module mem_prot_handler
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,

    //Additional parasm based on above
    localparam AX_USER_WIDTH = 1,
    
    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8
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
    output wire [AXI_ADDR_WIDTH-1:0]        mem_out_awaddr,
    output wire [7:0]                       mem_out_awlen,
    output wire [2:0]                       mem_out_awsize,
    output wire [1:0]                       mem_out_awburst,
    output wire [AX_USER_WIDTH-1:0]         mem_out_awuser,
    output wire                             mem_out_awvalid,
    input wire                              mem_out_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        mem_out_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    mem_out_wstrb,
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
    output wire [AX_USER_WIDTH-1:0]         mem_out_aruser,
    output wire                             mem_out_arvalid,
    input wire                              mem_out_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_rid,
    input wire [AXI_DATA_WIDTH-1:0]         mem_out_rdata,
    input wire [1:0]                        mem_out_rresp,
    input wire                              mem_out_rlast,
    input wire                              mem_out_rvalid,
    output wire                             mem_out_rready,

    //Protocol error indicators
    output wire         timeout_errror_irq,
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
    assign effective_awsize = (mem_in_awsize <= MAX_AWSIZE) ? mem_in_awsize : MAX_AWSIZE;

    //Correct WRAP mode length error (by changing to INCR mode if error found)
    wire write_is_burst = (mem_in_awburst == 2'b10);
    wire write_is_valid_burst_len = 
        (mem_in_awlen == 8'd15) ||
        (mem_in_awlen == 8'd7 ) ||
        (mem_in_awlen == 8'd3 ) ||
        (mem_in_awlen == 8'd1 );

    assign effective_awburst = (write_is_burst && !write_is_valid_burst_len) ? 2'b01 : mem_in_awburst;

    //Correct WRAP mode unaligned access error
    wire [AXI_ADDR_WIDTH-1:0] awaddr_align_masks [7:0];

    genvar j;
    generate
        for(j = 0; j < 8; j = j + 1) begin : align_mask_asgn
            assign awaddr_align_masks[j] = {(AXI_ADDR_WIDTH){1'b1}} << j;
        end
    endgenerate

    wire [AXI_ADDR_WIDTH-1:0] awaddr_aligned = mem_in_awaddr & awaddr_align_masks[effective_awsize];
    assign effective_awaddr = (effective_awburst == 2'b10) ? awaddr_aligned : mem_in_awaddr;
    
    //Determine if crossing 4k boundary (cannot correct, simply generate error signal)
    //wire [2:0] write_wrap_bits = (mem_in_awlen[3]) ? 3'b100 : //awlen = 15 (16 transfers)
    //                             (mem_in_awlen[2]) ? 3'b011 : //awlen = 7  (8 transfers)
    //                             (mem_in_awlen[1]) ? 3'b010 : //awlen = 3  (4 transfers)
    //                             3'b001;                  //awlen = 1  (2 transfers), default value
    //                                            
    //wire [3:0] write_align_bits = (effective_awburst == 2'b10) ? effective_awsize + write_wrap_bits : effective_awsize;
    //wire [AXI_ADDR_WIDTH-1:0] write_align_mask = {AXI_ADDR_WIDTH{1'b1}} << effective_awsize; //write_align_bits;
    //wire [AXI_ADDR_WIDTH-1:0] write_align_addr = effective_awaddr & write_align_mask;
    wire [AXI_ADDR_WIDTH:0] write_last_addrp1 = /*write_align_addr*/awaddr_aligned + ((mem_in_awlen + 1) << effective_awsize);
    wire [AXI_ADDR_WIDTH:0] write_last_addr = write_last_addrp1 - 1;
    
    wire aw4kcrossing = (effective_awburst == 2'b01) && (write_last_addr[AXI_ADDR_WIDTH-1:12] != mem_in_awaddr[AXI_ADDR_WIDTH-1:12]);
    
    //FIFO for burst length values (to determine if last value asserted correctly in W Channel)
    wire fifo_rd_en;
    wire fifo_wr_en;
    wire fifo_full;
    wire fifo_empty;
    wire [7:0] awlen_fifo_out;
    
    small_distram_fifo
    #(
        .DATA_WIDTH (8),
        .ADDR_WIDTH ($clog2(OUTSTANDING_WREQ))
    )
    awlen_fifo
    (
        .din        (mem_in_awlen),
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
    reg [AX_USER_WIDTH-1:0]         reg_awuser;
    reg                             reg_awvalid;
    wire                            reg_awready = (mem_out_awready || !reg_awvalid);

    always@(posedge aclk) begin
        if(~aresetn) reg_awvalid <= 0;
        else if(effective_awvalid && reg_awready) begin
            reg_awid <= mem_in_awid;
            reg_awaddr <= effective_awaddr;
            reg_awlen <= mem_in_awlen;
            reg_awsize <= effective_awsize;
            reg_awburst <= effective_awburst;
            reg_awuser <= {aw4kcrossing};
            reg_awvalid <= 1;
        end 
        else if(mem_out_awready) reg_awvalid <= 0;
    end 

    //Modified  valid signal if fifo full
    assign effective_awvalid = mem_in_awvalid && !fifo_full;
    assign effective_awready = reg_awready && !fifo_full;
    
    //Assign output values for AW channel
    assign mem_out_awid = reg_awid;
    assign mem_out_awaddr = reg_awaddr;
    assign mem_out_awlen = reg_awlen;
    assign mem_out_awsize = reg_awsize;
    assign mem_out_awburst = reg_awburst;
    assign mem_out_awuser = reg_awuser;
    assign mem_out_awvalid = reg_awvalid;

    assign mem_in_awready = effective_awready;
    
    
    
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
    assign fifo_rd_en = effective_wlast & mem_out_wready & mem_in_wvalid;
    
    //Write counter
    always@(posedge aclk) begin
       if(~aresetn)
           write_count <= 0;
       else if(effective_wready & effective_wvalid)
           if(effective_wlast)
               write_count <= 0;
           else
               write_count <= write_count + 1;
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
    wire 							reg_awready = (mem_out_wready || !reg_wvalid);

    //Modified ready and valid signals if fifo empty
    assign effective_wready = reg_awready && !fifo_empty;
    assign effective_wvalid = mem_in_wvalid && !fifo_empty;

    always@(posedge aclk) begin
        if(~aresetn) reg_wvalid <= 0;
        else if(effective_wvalid && reg_awready) begin
            reg_wdata <= mem_in_wdata;
            reg_wstrb <= mem_in_wstrb;
            reg_wlast <= effective_wlast;
            reg_wvalid <= 1;
        end
        else if(mem_out_wready) reg_wvalid <= 0;
    end 
    
    //Assign output values for W channel
    assign mem_out_wdata = reg_wdata;
    assign mem_out_wstrb = reg_wstrb;
    assign mem_out_wlast = reg_wlast; //mem_in_wlast ignored
    assign mem_out_wvalid = reg_wvalid;

    assign mem_in_wready = (effective_wready || !reg_wvalid);
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel protocol monitoring       //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(BTIMEOUT_CYCLES+2)-1:0] btime_count;
    wire btimeout = (btime_count > BTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (mem_in_bready && mem_out_bvalid) || timeout_error_clear)
            btime_count <= 1;
        else if(mem_out_bvalid && ~mem_in_bready)
            btime_count <= btime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign mem_out_bready = mem_in_bready;
    assign mem_in_bid = mem_out_bid;
    assign mem_in_bresp = mem_out_bresp;
    assign mem_in_bvalid = mem_out_bvalid;
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel protocol monitoring         //
    //--------------------------------------------------------//
    
    //Values to be modified below in AR correction
    wire [2:0] effective_arsize;
    wire [1:0] effective_arburst;
    wire [AXI_ADDR_WIDTH-1:0] effective_araddr;
    wire effective_arready;
    wire effective_arvalid;

    //Correct arsize larger than interface error
    localparam MAX_ARSIZE = $clog2(AXI_DATA_WIDTH/8);
    assign effective_arsize = (mem_in_arsize <= MAX_ARSIZE) ? mem_in_arsize : MAX_ARSIZE;

    //Correct WRAP mode length error (by changing to INCR mode if error found)
    wire read_is_burst = (mem_in_arburst == 2'b10);
    wire read_is_valid_burst_len = 
        (mem_in_arlen == 8'd15) ||
        (mem_in_arlen == 8'd7 ) ||
        (mem_in_arlen == 8'd3 ) ||
        (mem_in_arlen == 8'd1 );

    assign effective_arburst = (read_is_burst && !read_is_valid_burst_len) ? 2'b01 : mem_in_arburst;

    //Correct WRAP mode unaligned access error
    wire [AXI_ADDR_WIDTH-1:0] araddr_align_masks [7:0];

    generate
        for(j = 0; j < 8; j = j + 1) begin : align_mask_asgn2
            assign araddr_align_masks[j] = {(AXI_ADDR_WIDTH){1'b1}} << j;
        end
    endgenerate

    wire [AXI_ADDR_WIDTH-1:0] araddr_aligned = mem_in_araddr & araddr_align_masks[effective_arsize];
    assign effective_araddr = (effective_arburst == 2'b10) ? araddr_aligned : mem_in_araddr;
    
    //Determine if crossing 4k boundary (cannot correct, simply generate error signal)
    //wire [2:0] read_wrap_bits = (mem_in_arlen[3]) ? 3'b100 : //arlen = 15 (16 transfers)
    //                             (mem_in_arlen[2]) ? 3'b011 : //arlen = 7  (8 transfers)
    //                             (mem_in_arlen[1]) ? 3'b010 : //arlen = 3  (4 transfers)
    //                             3'b001;                  //arlen = 1  (2 transfers), default value
    //                                            
    //wire [3:0] read_align_bits = (effective_arburst == 2'b10) ? effective_arsize + read_wrap_bits : effective_arsize;
    //wire [AXI_ADDR_WIDTH-1:0] read_align_mask = {AXI_ADDR_WIDTH{1'b1}} << effective_arsize; //read_align_bits;
    //wire [AXI_ADDR_WIDTH-1:0] read_align_addr = effective_araddr & read_align_mask;
    wire [AXI_ADDR_WIDTH:0] read_last_addrp1 = /*read_align_addr*/araddr_aligned + ((mem_in_arlen + 1) << effective_arsize);
    wire [AXI_ADDR_WIDTH:0] read_last_addr = read_last_addrp1 - 1;
    
    wire ar4kcrossing = (effective_arburst == 2'b01) && (read_last_addr[AXI_ADDR_WIDTH-1:12] != mem_in_araddr[AXI_ADDR_WIDTH-1:12]);


    
    //--------------------------------------------------------//
    //   AXI Read Address Channel protocol correction         //
    //--------------------------------------------------------//
    
    //Register value for output
    reg [AXI_ID_WIDTH-1:0]          reg_arid;
    reg [AXI_ADDR_WIDTH-1:0]        reg_araddr;
    reg [7:0]                       reg_arlen;
    reg [2:0]                       reg_arsize;
    reg [1:0]                       reg_arburst;
    reg [AX_USER_WIDTH-1:0]         reg_aruser;
    reg                             reg_arvalid;
    wire 							reg_arready = (mem_out_arready || !reg_arvalid);

    always@(posedge aclk) begin
        if(~aresetn) reg_arvalid <= 0;
        else if(mem_in_arvalid && reg_arready) begin
            reg_arid <= mem_in_arid;
            reg_araddr <= effective_araddr;
            reg_arlen <= mem_in_arlen;
            reg_arsize <= effective_arsize;
            reg_arburst <= effective_arburst;
            reg_aruser <= {ar4kcrossing};
            reg_arvalid <= mem_in_arvalid;
        end 
        else if(mem_out_arready) reg_arvalid <= 0;
    end 
    
    //Assign output values for AR channel
    assign mem_out_arid = reg_arid;
    assign mem_out_araddr = reg_araddr;
    assign mem_out_arlen = reg_arlen;
    assign mem_out_arsize = reg_arsize;
    assign mem_out_arburst = reg_arburst;
    assign mem_out_aruser = reg_aruser;
    assign mem_out_arvalid = reg_arvalid;  

    assign mem_in_arready = reg_arready;

    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//
    
    //Timeout calculation
    reg [$clog2(RTIMEOUT_CYCLES+2)-1:0] rtime_count;
    wire rtimeout = (rtime_count > RTIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
        if(~aresetn || (mem_in_rready && mem_out_rvalid)  || timeout_error_clear)
            rtime_count <= 1;
        else if(mem_out_rvalid && ~mem_in_rready)
            rtime_count <= rtime_count + 1;
    end
    
    //Signal Assignments (no corrections necessary)
    assign mem_out_rready = mem_in_rready;
    assign mem_in_rid = mem_out_rid;
    assign mem_in_rdata = mem_out_rdata;
    assign mem_in_rresp = mem_out_rresp;
    assign mem_in_rlast = mem_out_rlast;
    assign mem_in_rvalid = mem_out_rvalid;
    
    
    
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

    assign timeout_errror_irq = wtimeout || btimeout || rtimeout || timeout_error;
        


endmodule

`default_nettype wire