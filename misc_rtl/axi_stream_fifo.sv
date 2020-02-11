`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream FIFO

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   An AXI Stream FIFO, targetting an inferred BRAM or LUTRAM implementation. 
   Can support packet mode by parameterization. Also transparently handles
   dropping of packets with backpressure asserted and a tuser-based packet 
   keep signal. See parameters below for details. Note, zero widths for any 
   of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi streams
   AXIS_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   BUFFER_DEPTH_LOG2 - the FIFO depth, in LOG2 (only powers of 2 supported)
   DROP_ON_BACK_PRESSURE - binary, whether or not to drop whole packets when back pressure encountered, including portion already buffered (alternative is propogating the back pressure)
   DROP_ON_TUSER_SIG - binary, whether or not to drop a packet when the indicated tuser signal is asserted mid packet (a packet poison signal)
   DROP_TUSER_SIG_INDEX - the bit index of the TUSER signal to use for the above feature
   IGNORE_TUSER_DROP_IF_STABLE - binary, some other TUSER signal to override the poison signal if asserted (used to indicate okay to stop buffering, don't need to wait to see if poisoned)
   STABLE_TUSER_SIG_INDEX - the bit index of the TUSER signal to use for the above feature
   DROP_ON_UNSTABLE_TLAST - binary, drop packets if the stable signal is not asserted by the time tlast is seen, see above parameter
   WAIT_UNTIL_TLAST - binary, hold packets until the tlast signal is bufferd (so-called packet-mode)
   WAIT_UNTIL_TUSER_SIG - binary, hold packets until a specific signal is asserted on tuser (used to indicate done processing usually)
   WAIT_TUSER_SIG_INDEX - the bit index of the TUSER signal to use for the above feature
   WRITE_SIDE_ONCE_ON_STABLE - binary, whether the side-channel signals should be regsistered only once (rather than for every flit), on first cycle where STABLE signal asserted
   WRITE_SIDE_ONCE_ON_BUFFER_DONE - "                                                                                              ", on final held (i.e. WAIT_UNTIL_*) flit written to main FIFO

TUSER Signals:
   The module supports 3 types of TUSER signals, a DROP signal, a STABLE
   signal, and a WAIT_UNTIL signal. 

   The DROP signal indicates mid packet that the packet should be dropped. 
   There is an implcit wait condition created here that forces packets to be 
   buffered until a DROP can no longer be encounterd, which is at tlast or 
   at STABLE (depending on the parameterization).

   The STABLE signal indicates that the packet has reached some user defined
   stable state and buffering can be ceased (except if other wait conditions
   exist). This is generally used to indicate that a DROP signal is no
   longer expected, and the packet no longer needs to be buffered. It can
   also be used to drop packets that never reach a stable state. An example
   use-case for this signal: to be asserted when some headers of the packet 
   have been processed, indicating that the end of the headers has been reached 
   and no DROP errors can be expected beyond this point, but also that the 
   packet is well-formed (the headers are all there). If the packet is not 
   well-formed (the headers aren't all there), the signal is never asserted
   before tlast and the packet should be dropped. Other use-cases may exist.

   The WAIT_UNTIL signal is used to indicate that the packet must be buffered
   until this signal is asserted. Can be used to set a user defined buffering
   condition seperate from the above implied conditions.

Buffering Conditions:
   Packets are buffered until TLAST in 3 different cases:
     1. WAIT_UNTIL_TLAST is enabled
     2. DROP_ON_BACK_PRESSURE is enabled
     3. DROP_ON_TUSER_SIG is enabled and IGNORE_TUSER_DROP_IF_STABLE is diabled
   Packets are bufferd until WAIT_UNTIL TUSER signal in the following case:
     1. WAIT_UNTIL_TUSER_SIG is enabled
   Packets are buffered until STABLE TUSER signal in 2 different cases:
     1. DROP_ON_TUSER_SIG is enabled and IGNORE_TUSER_DROP_IF_STABLE is enabled
     2. SROP_ON_UNSTABLE_TLAST is enabled
   In the case of multiple conditions, packets are buffered until all conditions
   are met (effectively the largest buffering condition).

Ports:
   axis_in_* - input axi stream
   axis_out_* - output axi stream
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_fifo
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //FIFO Depth
    parameter BUFFER_DEPTH_LOG2 = 8,

    //Dropping features
    parameter DROP_ON_BACK_PRESSURE = 1,
    parameter DROP_ON_TUSER_SIG = 1,
    parameter DROP_TUSER_SIG_INDEX = 0,
    parameter IGNORE_TUSER_DROP_IF_STABLE = 1,
    parameter STABLE_TUSER_SIG_INDEX = 0,
    parameter DROP_ON_UNSTABLE_TLAST = 1,

    //Wait features (buffer packet before transmitting)
    parameter WAIT_UNTIL_TLAST = 1,
    parameter WAIT_UNTIL_TUSER_SIG = 1,
    parameter WAIT_TUSER_SIG_INDEX = 0,

    //Seperate Side-Channel festures (only one should be enabled)
    parameter WRITE_SIDE_ONCE_ON_STABLE = 0,
    parameter WRITE_SIDE_ONCE_ON_BUFFER_DONE = 1
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_tkeep,
    input wire [AXIS_TID_WIDTH-1:0]         axis_in_tid,
    input wire [AXIS_TDEST_WDITH-1:0]       axis_in_tdest,
    input wire [AXIS_TUSER_WIDTH-1:0]       axis_in_tuser,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_tuser,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Indicate whether a packet was dropped
    output wire                             packet_dropped,
  
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Setup params and signals                             //
    //--------------------------------------------------------//

    //Derived params for buffer
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8;
    localparam BUFFER_DEPTH = 2 ** BUFFER_DEPTH_LOG2;
    localparam BUFFER_DEPTH_CBITS = BUFFER_DEPTH_LOG2 + 1;

    //Derived wait conditions
    localparam EFF_WAIT_UNTIL_TALST = WAIT_UNTIL_TLAST || DROP_ON_BACK_PRESSURE || (DROP_ON_TUSER_SIG && !IGNORE_TUSER_DROP_IF_STABLE);
    localparam EFF_WAIT_UNTIL_TUSER_SIG = WAIT_UNTIL_TUSER_SIG && !EFF_WAIT_UNTIL_TALST; //If waiting for tlast, don't care about any other wait conditions
    localparam WAIT_UNTIL_STABLE = (DROP_ON_TUSER_SIG && IGNORE_TUSER_DROP_IF_STABLE) || DROP_ON_UNSTABLE_TLAST;
    localparam EFF_WAIT_UNTIL_STABLE = WAIT_UNTIL_STABLE && !EFF_WAIT_UNTIL_TALST; //If waiting for tlast, don't care about any other wait conditions

    //Signals from tuser
    wire axis_in_error = axis_in_tuser[DROP_TUSER_SIG_INDEX];
    wire axis_in_stable = axis_in_tuser[STABLE_TUSER_SIG_INDEX];
    wire axis_in_done = axis_in_tuser[WAIT_TUSER_SIG_INDEX];



    //--------------------------------------------------------//
    //   The actual FIFO                                      //
    //--------------------------------------------------------//

    //FIFO data
    reg [AXIS_BUS_WIDTH-1:0]   fifo_tdata [BUFFER_DEPTH-1:0];
    reg [NUM_BUS_BYTES-1:0]    fifo_tkeep [BUFFER_DEPTH-1:0];
    reg [AXIS_TID_WIDTH-1:0]   fifo_tid   [BUFFER_DEPTH-1:0];
    reg [AXIS_TDEST_WDITH-1:0] fifo_tdest [BUFFER_DEPTH-1:0];
    reg [AXIS_TUSER_WIDTH-1:0] fifo_tuser [BUFFER_DEPTH-1:0];
    reg                        fifo_tlast [BUFFER_DEPTH-1:0];

    //FIFO output registers
    reg [AXIS_BUS_WIDTH-1:0]   out_tdata;
    reg [NUM_BUS_BYTES-1:0]    out_tkeep;
    reg [AXIS_TID_WIDTH-1:0]   out_tid;
    reg [AXIS_TDEST_WDITH-1:0] out_tdest;
    reg [AXIS_TUSER_WIDTH-1:0] out_tuser;
    reg                        out_tlast;
    reg                        out_tvalid;

    //Signals for the main FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]    fifo_rd_pointer_main;
    reg [BUFFER_DEPTH_CBITS-1:0]    fifo_wr_pointer_main; //Lagging wr_pointer, used on the read side of the FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]    temp_wr_pointer_main; //Leading wr_pointer, used on the write side of the FIFO

    wire [BUFFER_DEPTH_CBITS-1:0]   next_rd_pointer_main = fifo_rd_pointer_main + 1;
    wire [BUFFER_DEPTH_CBITS-1:0]   next_wr_pointer_main = temp_wr_pointer_main + 1;
    
    wire                            fifo_empty = (fifo_rd_pointer_main == fifo_wr_pointer_main); //Read-side signal
    wire                            fifo_full =  (  fifo_rd_pointer_main[BUFFER_DEPTH_LOG2-1:0] == temp_wr_pointer_main[BUFFER_DEPTH_LOG2-1:0]
                                                 && fifo_rd_pointer_main[BUFFER_DEPTH_CBITS-1]  != temp_wr_pointer_main[BUFFER_DEPTH_CBITS-1]  ); //Write-side signal
    wire                            fifo_rd_ram_en_main; //Read from RAM into register
    wire                            fifo_rd_reg_en; //Read register values at output
    wire                            fifo_wr_en_main; //Write into RAM
    wire                            temp_copy_to_wr;
    wire                            temp_restore_from_wr;
    
    //Pointer updates for main FIFO
    always@(posedge aclk) begin
        if(~aresetn) begin
            fifo_rd_pointer_main <= 0;
            fifo_wr_pointer_main <= 0;
            temp_wr_pointer_main <= 0;
        end
        else begin

            //Rd pointer
            if(fifo_rd_ram_en_main) fifo_rd_pointer_main <= next_rd_pointer_main;

            //Temp Wr pointer
            if(temp_restore_from_wr) temp_wr_pointer_main <= fifo_wr_pointer_main;
            else if(fifo_wr_en_main) temp_wr_pointer_main <= next_wr_pointer_main;

            //Wr pointer
            if(fifo_wr_en_main && temp_copy_to_wr) fifo_wr_pointer_main <= next_wr_pointer_main;
            else if(temp_copy_to_wr) fifo_wr_pointer_main <= temp_wr_pointer_main;

        end
    end

    //Signals for Side-Channel FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]    fifo_rd_pointer_side;
    reg [BUFFER_DEPTH_CBITS-1:0]    fifo_wr_pointer_side; //Lagging wr_pointer, used on the read side of the FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]    temp_wr_pointer_side; //Leading wr_pointer, used on the write side of the FIFO

    wire [BUFFER_DEPTH_CBITS-1:0]   next_rd_pointer_side = fifo_rd_pointer_side + 1;
    wire [BUFFER_DEPTH_CBITS-1:0]   next_wr_pointer_side = temp_wr_pointer_side + 1;
    
    wire                            fifo_rd_ram_en_side; //Read from RAM into register
    wire                            fifo_wr_en_side; //Write into RAM

    //Pointer updates for Side-Channel FIFO
    always@(posedge aclk) begin
        if(~aresetn) begin
            fifo_rd_pointer_side <= 0;
            fifo_wr_pointer_side <= 0;
            temp_wr_pointer_side <= 0;
        end
        else begin

            //Rd pointer
            if(fifo_rd_ram_en_side) fifo_rd_pointer_side <= next_rd_pointer_side;

            //Temp Wr pointer
            if(temp_restore_from_wr) temp_wr_pointer_side <= fifo_wr_pointer_side;
            else if(fifo_wr_en_side) temp_wr_pointer_side <= next_wr_pointer_side;

            //Wr pointer
            if(fifo_wr_en_side && temp_copy_to_wr) fifo_wr_pointer_side <= next_wr_pointer_side;
            else if(temp_copy_to_wr) fifo_wr_pointer_side <= temp_wr_pointer_side;

        end
    end

    //Read output registers inferred (for BRAM inference)
    always@(posedge aclk) begin
        if(~aresetn) begin
            out_tdata <= 0;
            out_tkeep <= 0;
            out_tlast <= 0;

            out_tid <= 0;
            out_tdest <= 0;
            out_tuser <= 0;

            out_tvalid <= 0;
        end 
        else if(fifo_rd_ram_en_main) begin //The side-channal is always read when main fifo is read, can read on this same enable signal
            out_tdata  <= fifo_tdata [fifo_rd_pointer_main];
            out_tkeep  <= fifo_tkeep [fifo_rd_pointer_main];
            out_tlast  <= fifo_tlast [fifo_rd_pointer_main];

            out_tid    <= fifo_tid   [fifo_rd_pointer_side];
            out_tdest  <= fifo_tdest [fifo_rd_pointer_side];
            out_tuser  <= fifo_tuser [fifo_rd_pointer_side];

            out_tvalid <= 1;
        end
        else if(fifo_rd_reg_en) begin
            out_tvalid <= 0;
        end 
    end

    //Read values assigned to output
    assign axis_out_tdata = out_tdata;
    assign axis_out_tkeep = out_tkeep;
    assign axis_out_tid = out_tid;
    assign axis_out_tdest = out_tdest;
    assign axis_out_tuser = out_tuser;
    assign axis_out_tlast = out_tlast;
    assign axis_out_tvalid = out_tvalid;

    //Infer write port for main FIFO
    always@(posedge aclk) begin
        if(fifo_wr_en_main) begin
            fifo_tdata [temp_wr_pointer_main] <= axis_in_tdata;
            fifo_tkeep [temp_wr_pointer_main] <= axis_in_tkeep;
            fifo_tlast [temp_wr_pointer_main] <= axis_in_tlast;
        end
    end

    //Infer write port for side-channel FIFO
    always@(posedge aclk) begin
        if(fifo_wr_en_side) begin
            fifo_tid   [temp_wr_pointer_side] <= axis_in_tid;
            fifo_tdest [temp_wr_pointer_side] <= axis_in_tdest;
            fifo_tuser [temp_wr_pointer_side] <= axis_in_tuser;
        end
    end

    //Back pressure from FIFO
    assign axis_in_tready = (DROP_ON_BACK_PRESSURE ? 1'b1 : !fifo_full); //Don't assert back pressure if we're dropping on back pressure, silent drop



    //--------------------------------------------------------//
    //   Control the FIFOs                                    //
    //--------------------------------------------------------//

    //Reading from FIFO into registers
    assign fifo_rd_ram_en_main = (!out_tvalid || fifo_rd_reg_en) && !fifo_empty;
    assign fifo_rd_ram_en_side = fifo_rd_ram_en_main & ((WRITE_SIDE_ONCE_ON_STABLE || WRITE_SIDE_ONCE_ON_BUFFER_DONE) ? fifo_tlast [fifo_rd_pointer_main] : 1'b1);

    //Reading from registers to output
    assign fifo_rd_reg_en = out_tvalid && axis_out_tready;


    //Track stable signal (avoid glitches by saving state)
    reg stable_saved;
    wire stable = axis_in_stable || stable_saved;

    always@(posedge aclk) begin
        if(~aresetn) stable_saved <= 0;
        else if(axis_in_tlast && axis_in_tvalid && axis_in_tready) stable_saved <= 0;
        else if(axis_in_stable) stable_saved <= 1;
    end

    //Drop conditions
    wire drop_now = axis_in_tvalid && ( 
                            (DROP_ON_BACK_PRESSURE && fifo_full) ||
                            (DROP_ON_TUSER_SIG && axis_in_error) ||
                            (DROP_ON_UNSTABLE_TLAST && axis_in_tlast && !stable)
                    );

    //Wait done conditions
    wire wait_done_now = axis_in_tvalid && (
                                (!EFF_WAIT_UNTIL_TALST || axis_in_tlast) &&
                                (!EFF_WAIT_UNTIL_STABLE || axis_in_stable) &&
                                (!EFF_WAIT_UNTIL_TUSER_SIG || axis_in_done)
                         );

    //Drop and wait status saved
    reg drop_saved;
    reg wait_done_saved;

    wire dropped = drop_now || drop_saved;
    wire waiting_done = wait_done_now || wait_done_saved;

    always@(posedge aclk) begin
        if(~aresetn) begin
            drop_saved <= 0;
            wait_done_saved <= 0;
        end 
        else if(axis_in_tlast && axis_in_tvalid && axis_in_tready) begin
            drop_saved <= 0;
            wait_done_saved <= 0;
        end 
        else begin
            if(drop_now) drop_saved <= 1;
            if(wait_done_now) wait_done_saved <= 1;
        end 
    end

    //Writing to FIFO
    assign fifo_wr_en_main = axis_in_tvalid && !fifo_full && !dropped;
    assign fifo_wr_en_side = fifo_wr_en_main &
    	(WRITE_SIDE_ONCE_ON_STABLE ? // if (WRITE_SIDE_ONCE_ON_STABLE)
    		!stable_saved & axis_in_stable
    	: (WRITE_SIDE_ONCE_ON_BUFFER_DONE ? // else if (WRITE_SIDE_ONCE_ON_BUFFER_DONE)
    		!wait_done_saved & wait_done_now
    	: // else
    		1'b1
        ));

    //Roll back to old wr pointer
    assign temp_restore_from_wr = drop_now;

    //Update to advanced wr pointer
    assign temp_copy_to_wr = !dropped && waiting_done;

    //Indicate packet dropped
    assign packet_dropped = dropped;

    
   
endmodule

`default_nettype wire
