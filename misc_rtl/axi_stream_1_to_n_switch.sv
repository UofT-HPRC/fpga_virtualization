`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream Switch Module (1 to N)

Author: Daniel Rozhko, PhD Candidate University of Toronto

***Note - This core has not been fully tested and may not work correctly

Description:
   An AXI Stream switch, with one input and N outputs. Routing based 
   on tdest field, with parameter specified mapping. Arbitration after 
   tlast transmitted (rather than per flit). One cycle of latency added 
   with a single register stage. Note, zero widths for any of the signals
   is not supported.

Defines:
   MAX_NUM_OUTPUTS - number of output interfaces, not all have to be used

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi streams
   AXIS_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   ADDR_RANGE_LOW_# - low-end of range to route to output #, inclusive
   ADDR_RANGE_HIGH_# - high-end of range to route to output #, inclusive
   NUM_OUTPUTS - number of outputs actually used, defailt to max number
   DEFAULT_OUTPUT - interface to target if no tdest range matches
   ENABLE_SECURE_OUTPUT - binary, whether to mask output of unselected output streams

Ports:
   axis_in_* - input axi stream to be routed
   axis_out_#_* - output axi stream corresponding to interface #
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


//Max number of outputs (less than or equal to 128 supported)
`define MAX_NUM_OUTPUTS 32

//Preprocessor functions (required for repeating)
`include "preproc_repeat.vh"



module axi_stream_1_to_n_switch
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //Address ranges for each output
    `define PARAM_LIMITS_DEF(n,d) \
    parameter ADDR_RANGE_LOW_``n = 0,\
    parameter ADDR_RANGE_HIGH_``n = 1,\

    `PP_REPEAT(`MAX_NUM_OUTPUTS,PARAM_LIMITS_DEF,0)

    //Additional params
    parameter NUM_OUTPUTS = `MAX_NUM_OUTPUTS, //Actual number of outputs in use (for parameterizability)
    parameter DEFAULT_OUTPUT = 0,
    parameter ENABLE_SECURE_OUTPUT = 1
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

    //Output AXI streams
    `define OUTPUT_PORTS_DEF(n,d) \
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_``n``_tdata,\
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_``n``_tkeep,\
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_``n``_tid,\
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_``n``_tdest,\
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_``n``_tuser,\
    output wire                             axis_out_``n``_tlast,\
    output wire                             axis_out_``n``_tvalid,\
    input wire                              axis_out_``n``_tready,\

    `PP_REPEAT(`MAX_NUM_OUTPUTS,OUTPUT_PORTS_DEF,0)

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Registers for the inputs (need to register to determine destination)
    reg [AXIS_BUS_WIDTH-1:0]         reg_tdata;
    reg [(AXIS_BUS_WIDTH/8)-1:0]     reg_tkeep;
    reg [AXIS_TID_WIDTH-1:0]         reg_tid;
    reg [AXIS_TDEST_WDITH-1:0]       reg_tdest;
    reg [AXIS_TUSER_WIDTH-1:0]       reg_tuser;
    reg                              reg_tlast;
    reg                              reg_tvalid;
    reg                              reg_tready;

    always@(posedge aclk) begin
        if(~aresten) begin
            reg_tdata <= 0;
            reg_tkeep <-0;
            reg_tid <= 0;
            reg_tdest <= 0;
            reg_tuser <= 0;
            reg_tlast <= 0;
            reg_tvalid <= 0;
        end
        else if(!reg_tvalid || reg_tready) begin
            reg_tdata <= axis_in_tdata;
            reg_tkeep <-axis_in_tkeep;
            reg_tid <= axis_in_tid;
            reg_tdest <= axis_in_tdest;
            reg_tuser <= axis_in_tuser;
            reg_tlast <= axis_in_tlast;
            reg_tvalid <= axis_in_tvalid;
        end 
    end 

    assign axis_in_tready = !reg_tvalid || reg_tready;



    //Determine proper destination
    localparam NUM_OUT_LOG2 = $clog2(NUM_OUTPUTS);
    reg [NUM_OUT_LOG2-1:0] current_output;
    reg last_beat_sent;

    always@(posedge aclk) begin
        if(~aresetn) begin
            current_output <= DEFAULT_OUTPUT;
        end
        else if(axis_in_tvalid && ( (reg_tlast && reg_tvalid && reg_tready) || last_beat_sent ) ) begin

            //Check each output range
            `define DEST_CHECK_DEF(n,d) \
            if(n < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_``n && axis_in_tdest <= ADDR_RANGE_HIGH_``n ) begin \
                current_output <= n; \
            end \
            else

            `PP_REPEAT(`MAX_NUM_OUTPUTS,DEST_CHECK_DEF,0)
            begin
                //Final else condition
                current_output <= DEFAULT_OUTPUT;
            end

        end 
    end 

    always@(posedge aclk) begin
        if(~aresetn) last_beat_sent <= 1;
        else if(!axis_in_tvalid && reg_tlast && reg_tvalid && reg_tready) last_beat_sent <= 1;
        else if(axis_in_tvalid) last_beat_sent <= 0;
    end 



    //Assign output values
    `define OUTPUT_STREAMS_DEF(n,d) \
    assign axis_out_``n``_tdata = ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tdata); \
    assign axis_out_``n``_tkeep = ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tkeep); \
    assign axis_out_``n``_tid =   ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tid); \
    assign axis_out_``n``_tdest = ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tdest); \
    assign axis_out_``n``_tuser = ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tuser); \
    assign axis_out_``n``_tlast = ((NUM_OUTPUTS <= n || (ENABLE_SECURE_OUTPUT && current_output != n)) ? 0 : reg_tlast); \
    assign axis_out_``n``_tvalid = ((NUM_OUTPUTS <= n || current_output != n) ? 0 : reg_tvalid); \

    `PP_REPEAT(`MAX_NUM_OUTPUTS,OUTPUT_STREAMS_DEF,0)


    //Ready signal
    always(*) begin

        `define READY_SIG_DEF(n,d) \
        if(n < NUM_OUTPUTS && current_output == n) begin \
            reg_tready = axis_out_``n``_tready; \
        end \
        else

        `PP_REPEAT(`MAX_NUM_OUTPUTS,READY_SIG_DEF,0)
        begin
            //Final else condition
            `define READY_DEFAULT_DEF(n,d) \
            if(DEFAULT_OUTPUT == n) reg_tready = axis_out_``n``_tready

            `PP_REPEAT(`MAX_NUM_OUTPUTS,READY_DEFAULT_DEF,0)
        end 

    end



endmodule

`undefineall
`default_nettype wire