`timescale 1ns / 1ps
`default_nettype none

/*
AXI4 Data Width Upsizer (Ver 2)

Author: Daniel Rozhko, PhD Candidate University of Toronto

***Note - This core has not been fully tested and may not work correctly

Description:
   An AXI4 Data Width Upsizer, used to connect and AXI4 master to an AXI4 slave
   where the data width of the AXI4 slave is larger than the data width of the
   AXI4 master. This core explicitly preserves the AXI ID values at the output
   without serializing requests. Meant to be a performant replacement for typical
   upsizers that can only preserve ID information by sending out one request at a
   time per ID. This implementation does not support narrow transfers, unmodifiable
   transfers, or FIXED type bursts. The core does not explicitly check for these
   unsupported transfers, and as such would produce undefined beahviour in these
   cases. Implemented using a single FIFO for the read channel and a set of state
   registers, whose depth and number are determined by OUTSTANDING_RREQ. The LUTRAM
   utilization should be lower though the logic complexity will be higher compared
   to using a FIFO per ID. Note, zero widths for any of the signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of the AXI ID signal
   AXI_ADDR_WIDTH - the width of the address signal
   AXI_IN_DATA_WIDTH - the width of the input slave interface
   AXI_OUT_DATA_WIDTH - the width of the output master interface (must be larger than AXI_IN_DATA_WIDTH)
   OUTSTANDING_WREQ - maximum number of outstanding write requests before decoupling write address channel
   OUTSTANDING_RREQ - maximum number of outstanding read requests per ID before decoupling read address channel                                                                        ", on final held (i.e. WAIT_UNTIL_*) flit written to main FIFO

Ports:
   axi_in_* - the input slave interface (the narrower interface)
   axi_out_* - the output master interface (the wider interface)
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Unsupproted Transfers:
   Narrow transfers are not supported
   Unmodifiable transfers are not supported
   FIXED type burst transactions are not supported
*/


module axi4_upsizer
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_IN_DATA_WIDTH = 128,
    parameter AXI_OUT_DATA_WIDTH = 256,

    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_in_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_in_awaddr,
    input wire [7:0]                        axi_in_awlen,
    input wire [2:0]                        axi_in_awsize,
    input wire [1:0]                        axi_in_awburst,
    input wire                              axi_in_awvalid,
    output wire                             axi_in_awready,
    //Write Data Channel
    input wire [AXI_IN_DATA_WIDTH-1:0]      axi_in_wdata,
    input wire [(AXI_IN_DATA_WIDTH/8)-1:0]  axi_in_wstrb,
    input wire                              axi_in_wlast,
    input wire                              axi_in_wvalid,
    output wire                             axi_in_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_in_bid,
    output wire [1:0]                       axi_in_bresp,
    output wire                             axi_in_bvalid,
    input wire                              axi_in_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_in_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_in_araddr,
    input wire [7:0]                        axi_in_arlen,
    input wire [2:0]                        axi_in_arsize,
    input wire [1:0]                        axi_in_arburst,
    input wire                              axi_in_arvalid,
    output wire                             axi_in_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_in_rid,
    output wire [AXI_IN_DATA_WIDTH-1:0]     axi_in_rdata,
    output wire [1:0]                       axi_in_rresp,
    output wire                             axi_in_rlast,
    output wire                             axi_in_rvalid,
    input wire                              axi_in_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_out_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_out_awaddr,
    output wire [7:0]                       axi_out_awlen,
    output wire [2:0]                       axi_out_awsize,
    output wire [1:0]                       axi_out_awburst,
    output wire                             axi_out_awvalid,
    input wire                              axi_out_awready,
    //Write Data Channel
    output wire [AXI_OUT_DATA_WIDTH-1:0]    axi_out_wdata,
    output wire [(AXI_OUT_DATA_WIDTH/8)-1:0]axi_out_wstrb,
    output wire                             axi_out_wlast,
    output wire                             axi_out_wvalid,
    input wire                              axi_out_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_out_bid,
    input wire [1:0]                        axi_out_bresp,
    input wire                              axi_out_bvalid,
    output wire                             axi_out_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_out_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_out_araddr,
    output wire [7:0]                       axi_out_arlen,
    output wire [2:0]                       axi_out_arsize,
    output wire [1:0]                       axi_out_arburst,
    output wire                             axi_out_arvalid,
    input wire                              axi_out_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_out_rid,
    input wire [AXI_OUT_DATA_WIDTH-1:0]     axi_out_rdata,
    input wire [1:0]                        axi_out_rresp,
    input wire                              axi_out_rlast,
    input wire                              axi_out_rvalid,
    output wire                             axi_out_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Assume no narrow transfers
    localparam IN_SIZE = $clog2(AXI_IN_DATA_WIDTH/8);
    localparam OUT_SIZE = $clog2(AXI_OUT_DATA_WIDTH/8);
    localparam RATIO = AXI_OUT_DATA_WIDTH / AXI_IN_DATA_WIDTH;
    localparam RATIO_LOG2 = $clogs(RATIO);



    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//

    //Decouple if we cannot accept more requests
    wire aw_decouple;
    wire w_decouple;

    //Assign values (wider size, reduced length)
    assign axi_out_awid = axi_in_awid;
    assign axi_out_awaddr = axi_in_awaddr;
    //assign axi_out_awlen = ( ( (axi_in_awlen + 1) >> RATIO_LOG2 ) - 1) ;
    assign axi_out_awsize = OUT_SIZE;
    assign axi_out_awburst = axi_in_awburst;
    assign axi_out_awvalid = (aw_decouple ? 0 : axi_in_awvalid);
    assign axi_in_awready = (aw_decouple ? 0 : axi_out_awready);
    
    //Calculate the new awlen value
    wire [RATIO_LOG2-1:0] aw_start_offset = (axi_in_awaddr >> IN_SIZE)[0+:RATIO_LOG2];
    wire [RATIO_LOG2-1:0] w_start_offset;

    wire [RATIO_LOG2:0] aw_start_beats = RATIO - aw_start_offset;
    wire [7:0] aw_rest_beats = axi_in_awlen - aw_start_beats;
    wire [7:0] aw_new_rest_beats = aw_rest_beats >> RATIO_LOG2;

    assign axi_out_awlen = (axi_in_awlen >= aw_start_beats ? aw_new_rest_beats + 1 : 0);

    //FIFO to hold expected start offsets
    wire aw_fifo_wr_en = axi_out_awvalid && axi_out_awready;
    wire aw_fifo_rd_en = axi_in_wvalid & axi_in_wlast & axi_in_wready;

    simple_fifo
    #(
        .DATA_WIDTH (RATIO_LOG2),
        .BUFFER_DEPTH_LOG2 ($clog2(OUTSTANDING_WREQ))
    )
    aw_fifo
    (
        .din        (aw_start_offset),
        .wr_en      (aw_fifo_wr_en),
        .full       (aw_decouple),
        
        .dout       (w_start_offset),
        .rd_en      (aw_fifo_rd_en),
        .empty      (w_decouple),
         
        .clk        (aclk),
        .rst        (~aresetn)
    );


    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//

    //Register to store partial data
    reg [AXI_IN_DATA_WIDTH-1:0]     wdata_parts [RATIO-2:0];
    reg [(AXI_IN_DATA_WIDTH/8)-1:0] wdata_parts_strb [RATIO-2:0];
    reg [RATIO-2:0]                 wdata_parts_valid;
    reg [RATIO-2:0]                 wdata_parts_last;

    wire [RATIO-2:0]                wdata_parts_wr;
    wire                            wdata_parts_clr;

    genvar j;
    generate for(j = 0; j < RATIO-1; j = j + 1) begin : parts
        always@(posedge aclk) begin
            if(~aresetn) begin
                wdata_parts_valid[j] <= 0;
                wdata_parts_last[j] <= 0;
            end else if(wdata_parts_wr[j]) begin
                wdata_parts[j] <= axi_in_wdata;
                wdata_parts_strb[j] <= axi_in_wstrb;
                wdata_parts_valid[j] <= 1;
                wdata_parts_last[j] <= axi_in_wlast;
            end else(wdata_parts_clr) begin
                wdata_parts_valid[j] <= 0;
                wdata_parts_last[j] <= 0;
            end
        end 

        //Connect to output signals
        assign axi_out_wdata[(j*AXI_IN_DATA_WIDTH)+:AXI_IN_DATA_WIDTH] = wdata_parts[j];
        assign axi_out_wstrb[(j*(AXI_IN_DATA_WIDTH/8))+:(AXI_IN_DATA_WIDTH/8)] = (wdata_parts_valid[j] ? wdata_parts_strb[j] : 0);

    end endgenerate

    wire final_write; // = ~(|wdata_parts_wr);
    wire parts_wlast = |wdata_parts_last;
    wire corner_case = final_write && parts_wlast;

    //Connect remaining to output signals
    assign axi_out_wdata[((RATIO-1)*AXI_IN_DATA_WIDTH)+:AXI_IN_DATA_WIDTH] = axi_in_wdata;
    assign axi_out_wstrb[((RATIO-1)*(AXI_IN_DATA_WIDTH/8))+:(AXI_IN_DATA_WIDTH/8)] = ((final_write && !corner_case) ? axi_in_wstrb : 0);
    assign axi_out_wlast = axi_in_wlast || parts_wlast;
    assign axi_out_wvalid = (w_decouple) 0 : (axi_in_wvalid && final_write) || parts_wlast;
    assign axi_in_wready = (w_decouple) 0 : axi_out_wready && !corner_case;

    //Logic to control packing
    reg is_n_first;

    always@(posedge aclk) begin
        if(~aresetn) is_n_first <= 0;
        else if(axi_in_wvalid && axi_in_wready)
            if(axi_in_wlast) is_n_first <= 0;
            else is_n_first <= 1;
    end

    reg [RATIO-1:0] roatating_write;
    wire [RATIO-1:0] rotate_first = (1 << w_start_offset);
    wire [RATIO-1:0] rotating_write_out = (is_n_first ? roatating_write : rotate_first); 

    always@(posedge aclk) begin
        if(~aresetn) roatating_write <= 1;
        else if(axi_in_wvalid && axi_in_wready)
            roatating_write <= {rotating_write_out[RATIO-2:0],rotating_write_out[RATIO-1]};
    end

    assign wdata_parts_wr = roatating_write[RATIO-2:0] & {(RATIO-1){axi_in_wvalid}};
    assign final_write = roatating_write[RATIO-1];

    assign wdata_parts_clr = axi_out_wvalid && axi_out_wready;



    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//    
    
    //Assign values (unchanged)
    assign axi_in_bid = axi_out_bid;
    assign axi_in_bresp = axi_out_bresp;
    assign axi_in_bvalid = axi_out_bvalid;
    assign axi_out_bready = axi_in_bready;

    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Decouple if we cannot accept more requests
    wire ar_decouple;

    //Assign values (wider size, reduced length)
    assign axi_out_arid = axi_in_arid;
    assign axi_out_araddr = axi_in_araddr;
    //assign axi_out_arlen = ( ( (axi_in_arlen + 1) >> RATIO_LOG2 ) - 1) ;
    assign axi_out_arsize = OUT_SIZE;
    assign axi_out_arburst = axi_in_arburst;
    assign axi_out_arvalid = (ar_decouple ? 0 : axi_in_arvalid);
    assign axi_in_arready = (ar_decouple ? 0 : axi_out_arready);
    
    //Calculate the new arlen value
    wire [RATIO_LOG2-1:0] ar_start_offset = (axi_in_araddr >> IN_SIZE)[0+:RATIO_LOG2];
    wire [RATIO_LOG2-1:0] ar_end_offset = (axi_in_arlen + ar_start_offset)[0+:RATIO_LOG2];

    wire [RATIO_LOG2:0] ar_start_beats = RATIO - ar_start_offset;
    wire [7:0] ar_rest_beats = axi_in_arlen - ar_start_beats;
    wire [7:0] ar_new_rest_beats = ar_rest_beats >> RATIO_LOG2;

    assign axi_out_arlen = (axi_in_arlen >= ar_start_beats ? ar_new_rest_beats + 1 : 0);

    //Outstanding transactions counts per ID
    localparam NUM_ID = AXI_ID_WIDTH ** 2;
    localparam OUTST_RBITS = $clog2(OUTSTANDING_RREQ+1);
    localparam OUTST_LOG2 = $clog2(OUTSTANDING_RREQ);
    reg [OUTST_RBITS-1:0] outst_counts [NUM_ID-1:0];

    generate for(j = 0; j < NUM_ID; j = j + 1) begin : ar_counts

        wire incr = axi_out_arvalid && axi_out_arready && (axi_out_arid == j);
        wire decr = axi_in_rvalid && axi_in_rlast && axi_in_rready && (axi_in_rid == j);

        always@(posedge aclk) begin
            if(~aresetn) outst_counts[j] <= 0;
            else outst_counts[j] <+ outst_counts[j] + incr - decr;
        end 

    end endgenerate



    //--------------------------------------------------------//
    //   Read Transaction Trackers                            //
    //--------------------------------------------------------//

    //FIFO to indicate available tracker units
    localparam FIFO_LOG2 = $clog2(OUTSTANDING_RREQ);
    localparam FIFO_DEPTH = 2 ** FIFO_LOG2;
    localparam FIFO_CBITS = $clog2(FIFO_DEPTH + 1);

    reg [OUTST_LOG2-1:0] free_track_fifo [FIFO_DEPTH-1:0];
    reg [FIFO_CBITS-1:0] free_track_fifo_count;
    reg [FIFO_LOG2-1:0] free_tack_fifo_rd_pntr;
    reg [FIFO_LOG2-1:0] free_track_fifo_wr_pntr;

    //Signals to drive fifo
    wire free_fifo_wr_en = axi_in_rvalid && axi_in_rready && axi_in_rlast;
    wire free_fifo_rd_en = axi_out_arvalid && axi_out_arready;
    wire free_fifo_full = (free_track_fifo_count == OUTSTANDING_RREQ);
    wire free_fifo_empty = (free_track_fifo_count == 0);
    wire free_fifo_do_wr = free_fifo_wr_en; // && !free_fifo_full;
    wire free_fifo_do_rd = free_fifo_rd_en; // && !free_fifo_empty;

    assign ar_decouple = free_fifo_empty;

    //Read and write ports
    wire [OUTST_LOG2-1:0] free_track_fifo_rdata;
    reg [OUTST_LOG2-1:0] free_track_fifo_wdata;

    //FIFO implementation;
    integer i;
    always@(posedge aclk) begin
        if(~aresetn) begin
            for(i = 0; i < FIFO_DEPTH; i = i + 1) begin
                free_track_fifo[i] <= i;
            end 
            free_track_fifo_count <= OUTSTANDING_RREQ;
            free_tack_fifo_rd_pntr <= 0;
            free_track_fifo_wr_pntr <= OUTSTANDING_RREQ;
        end 
        else begin
            if(free_fifo_do_wr && free_fifo_do_rd) begin
                free_track_fifo[free_track_fifo_wr_pntr] <= free_track_fifo_wdata;
                //free_track_fifo_count <= free_track_fifo_count;
                free_tack_fifo_rd_pntr <= free_tack_fifo_rd_pntr + 1;
                free_track_fifo_wr_pntr <= free_track_fifo_wr_pntr + 1;
            end 
            else if(free_fifo_do_wr) begin
                free_track_fifo[free_track_fifo_wr_pntr] <= free_track_fifo_wdata;
                free_track_fifo_count <= free_track_fifo_count + 1;
                //free_tack_fifo_rd_pntr <= free_tack_fifo_rd_pntr + 1;
                free_track_fifo_wr_pntr <= free_track_fifo_wr_pntr + 1;
            end 
            else if(free_fifo_do_rd) begin
                //free_track_fifo[free_track_fifo_wr_pntr] <= free_track_fifo_wdata;
                free_track_fifo_count <= free_track_fifo_count - 1;
                free_tack_fifo_rd_pntr <= free_tack_fifo_rd_pntr + 1;
                //free_track_fifo_wr_pntr <= free_track_fifo_wr_pntr + 1;
            end 
        end 
    end 

    assign free_track_fifo_rdata = free_track_fifo[free_tack_fifo_rd_pntr];


    //The tracker registers
    reg [RATIO_LOG2-1:0]    track_start_offset [OUTSTANDING_RREQ-1:0];
    reg [RATIO_LOG2-1:0]    track_end_offset [OUTSTANDING_RREQ-1:0];
    reg [AXI_ID_WIDTH-1:0]  track_id [OUTSTANDING_RREQ-1:0];
    reg [OUTST_RBITS-1:0]   track_outst_count [OUTSTANDING_RREQ-1:0];
    reg                     track_is_n_first [OUTSTANDING_RREQ-1:0];
    reg                     track_valid [OUTSTANDING_RREQ-1:0];

    //The tracker units
    generate for(j = 0; j < OUTSTANDING_RREQ; j = j + 1) begin : rd_trackers

        //Whether the tracker is being used
        wire is_current_rid = (axi_in_rid == track_id[j]);
        wire is_current_tracker = is_current_rid && (track_outst_count[j] == 0);

        //Write to the registers when new request accepted
        wire write_to_tracker = free_fifo_do_rd && (free_track_fifo_rdata == j);
        wire clear_tracker = free_fifo_do_wr && is_current_tracker;

        always@(posedge aclk) begin
            if(~aresetn) begin
                track_valid[j] <= 0;
            end else if(write_to_tracker) begin
                track_start_offset[j] <= ar_start_offset;
                track_end_offset[j] <= ar_end_offset;
                track_id[j] <= axi_out_arid;
                track_valid[j] <= 1;
            end else if(clear_tracker) begin
                track_valid[j] <= 0;
            end 
        end 

        //Update outstanding count
        wire decr = axi_in_rvalid && axi_in_rlast && axi_in_rready && is_current_rid;

        always@(posedge aclk) begin
            if(~aresetn) track_outst_count[j] <= 0;
            else if(write_to_tracker) track_outst_count[j] <= outst_counts[axi_out_arid];
            else if(decr) track_outst_count[j] <= track_outst_count[j] - 1;
        end 

        //Update the read start indicators
        always@(posedge aclk) begin
            if(~aresetn) track_is_n_first[j] <= 0;
            else if(write_to_tracker) track_is_n_first[j] <= 0;
            else if(axi_in_rvalid && axi_in_rready && is_current_tracker)
                track_is_n_first[j] <= 1;
        end

    end endgenerate



    //--------------------------------------------------------//
    //   Read Data Channel                                    //
    //--------------------------------------------------------//

    //Values that indicate the start and end offset expected
    reg [RATIO_LOG2-1:0] r_start_offset;
    reg [RATIO_LOG2-1:0] r_end_offset;
    reg is_n_first;

    //Choose value from the trackers, based on mataching ID
    always@(*) begin

        //Default assignments
        r_start_offset = 0;
        r_end_offset = 0;
        is_n_first = 0;
        free_track_fifo_wdata = 0

        for(i = 0; i < OUTSTANDING_RREQ; i = i + 1) begin

            //Check if ith tracker matches
            if( (track_id[i] == axi_in_rid) && (track_outst_count[i] == 0) && track_valid[i] ) begin
                r_start_offset = track_start_offset[i];
                r_end_offset = track_end_offset[i];
                is_n_first = track_is_n_first[i];
                free_track_fifo_wdata = i; //return tracker to free FIFO if rlast
            end 

        end 
    end 


    //Register to store partial data
    reg [AXI_IN_DATA_WIDTH-1:0]     rdata_parts [RATIO-1:0];
    reg [AXI_ID_WIDTH-1:0]          rdata_parts_id;
    reg [1:0]                       rdata_parts_resp;
    reg                             rdata_parts_last;
    reg                             rdata_parts_valid;

    wire                            rdata_parts_wr;
    wire                            rdata_parts_clr;

    always @(posedge aclk) begin
        if(~aresetn) begin
            rdata_parts_valid <= 0;
        end else if(rdata_parts_wr) begin
            integer i;
            for(i = 0; i < RATIO; i = i + 1) begin
                rdata_parts[i] <= axi_out_rdata[(i*AXI_IN_DATA_WIDTH)+:AXI_IN_DATA_WIDTH];
            end 
            rdata_parts_id <= axi_out_rid;
            rdata_parts_resp <= axi_out_rresp;
            rdata_parts_last <= axi_out_rlast;
            rdata_parts_valid <= 1;
        end else if(rdata_parts_clr) begin
            rdata_parts_valid <= 0;
        end 
    end 

    //Current Offset to send
    reg [RATIO_LOG2-1:0] curr_offset;
    wire [RATIO_LOG2-1:0] curr_offset_nxt;
    wire [RATIO_LOG2-1:0] curr_offset_out = (is_n_first ? curr_offset : r_start_offset);

    always@(*) begin
        if(~aresetn) curr_offset_nxt = 0;
        else if(axi_in_rvalid && axi_in_rready) begin
            if(axi_in_rlast) curr_offset_nxt = 0;
            else curr_offset_nxt = curr_offset_out + 1;
        end else 
            curr_offset_nxt = curr_offset;
    end

    always @(posedge aclk) curr_offset <= curr_offset_nxt;

    //Assign outputs
    assign axi_in_rid = rdata_parts_id;
    assign axi_in_rdata = rdata_parts[curr_offset_out];
    assign axi_in_rresp = rdata_parts_resp;
    assign axi_in_rlast = rdata_parts_last && (curr_offset_out == r_end_offset);
    assign axi_in_rvalid = rdata_parts_valid;

    //Control the registering of the data
    assign rdata_parts_clr = axi_in_rready && (curr_offset_nxt == 0);
    assign axi_out_rready = rdata_parts_clr || !rdata_parts_valid;
    assign rdata_parts_wr = axi_out_rvalid && axi_out_rready;



endmodule

`default_nettype wire
