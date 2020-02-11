`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream Switch Module (1 to N, max 32)

Author: Daniel Rozhko, PhD Candidate University of Toronto

***Note - This core has not been fully tested and may not work correctly

Description:
   An AXI Stream switch, with one input and N outputs. Routing based 
   on tdest field, with parameter specified mapping. Arbitration after 
   tlast transmitted (rather than per flit). One cycle of latency added 
   with a single register stage. Note, zero widths for any of the signals
   is not supported. Maximum outputs supported is 32.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi streams
   AXIS_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   ADDR_RANGE_LOW_# - low-end of range to route to output #, inclusive
   ADDR_RANGE_HIGH_# - high-end of range to route to output #, inclusive
   NUM_OUTPUTS - number of outputs actually used, default to 2
   DEFAULT_OUTPUT - interface to target if no tdest range matches
   ENABLE_SECURE_OUTPUT - binary, whether to mask output of unselected output streams

Ports:
   axis_in_* - input axi stream to be routed
   axis_out_#_* - output axi stream corresponding to interface #
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_1_to_n_switch
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //Address ranges for each output
    parameter ADDR_RANGE_LOW_0 = 0,
    parameter ADDR_RANGE_HIGH_0 = 1,
 
    parameter ADDR_RANGE_LOW_1 = 0,
    parameter ADDR_RANGE_HIGH_1 = 1,
 
    parameter ADDR_RANGE_LOW_2 = 0,
    parameter ADDR_RANGE_HIGH_2 = 1,
 
    parameter ADDR_RANGE_LOW_3 = 0,
    parameter ADDR_RANGE_HIGH_3 = 1,
 
    parameter ADDR_RANGE_LOW_4 = 0,
    parameter ADDR_RANGE_HIGH_4 = 1,
 
    parameter ADDR_RANGE_LOW_5 = 0,
    parameter ADDR_RANGE_HIGH_5 = 1,
 
    parameter ADDR_RANGE_LOW_6 = 0,
    parameter ADDR_RANGE_HIGH_6 = 1,
 
    parameter ADDR_RANGE_LOW_7 = 0,
    parameter ADDR_RANGE_HIGH_7 = 1,
 
    parameter ADDR_RANGE_LOW_8 = 0,
    parameter ADDR_RANGE_HIGH_8 = 1,
 
    parameter ADDR_RANGE_LOW_9 = 0,
    parameter ADDR_RANGE_HIGH_9 = 1,
 
    parameter ADDR_RANGE_LOW_10 = 0,
    parameter ADDR_RANGE_HIGH_10 = 1,
 
    parameter ADDR_RANGE_LOW_11 = 0,
    parameter ADDR_RANGE_HIGH_11 = 1,
 
    parameter ADDR_RANGE_LOW_12 = 0,
    parameter ADDR_RANGE_HIGH_12 = 1,
 
    parameter ADDR_RANGE_LOW_13 = 0,
    parameter ADDR_RANGE_HIGH_13 = 1,
 
    parameter ADDR_RANGE_LOW_14 = 0,
    parameter ADDR_RANGE_HIGH_14 = 1,
 
    parameter ADDR_RANGE_LOW_15 = 0,
    parameter ADDR_RANGE_HIGH_15 = 1,
 
    parameter ADDR_RANGE_LOW_16 = 0,
    parameter ADDR_RANGE_HIGH_16 = 1,
 
    parameter ADDR_RANGE_LOW_17 = 0,
    parameter ADDR_RANGE_HIGH_17 = 1,
 
    parameter ADDR_RANGE_LOW_18 = 0,
    parameter ADDR_RANGE_HIGH_18 = 1,
 
    parameter ADDR_RANGE_LOW_19 = 0,
    parameter ADDR_RANGE_HIGH_19 = 1,
 
    parameter ADDR_RANGE_LOW_20 = 0,
    parameter ADDR_RANGE_HIGH_20 = 1,
 
    parameter ADDR_RANGE_LOW_21 = 0,
    parameter ADDR_RANGE_HIGH_21 = 1,
 
    parameter ADDR_RANGE_LOW_22 = 0,
    parameter ADDR_RANGE_HIGH_22 = 1,
 
    parameter ADDR_RANGE_LOW_23 = 0,
    parameter ADDR_RANGE_HIGH_23 = 1,
 
    parameter ADDR_RANGE_LOW_24 = 0,
    parameter ADDR_RANGE_HIGH_24 = 1,
 
    parameter ADDR_RANGE_LOW_25 = 0,
    parameter ADDR_RANGE_HIGH_25 = 1,
 
    parameter ADDR_RANGE_LOW_26 = 0,
    parameter ADDR_RANGE_HIGH_26 = 1,
 
    parameter ADDR_RANGE_LOW_27 = 0,
    parameter ADDR_RANGE_HIGH_27 = 1,
 
    parameter ADDR_RANGE_LOW_28 = 0,
    parameter ADDR_RANGE_HIGH_28 = 1,
 
    parameter ADDR_RANGE_LOW_29 = 0,
    parameter ADDR_RANGE_HIGH_29 = 1,
 
    parameter ADDR_RANGE_LOW_30 = 0,
    parameter ADDR_RANGE_HIGH_30 = 1,
 
    parameter ADDR_RANGE_LOW_31 = 0,
    parameter ADDR_RANGE_HIGH_31 = 1,


    //Additional params
    parameter NUM_OUTPUTS = 2,
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
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_0_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_0_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_0_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_0_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_0_tuser,
    output wire                             axis_out_0_tlast,
    output wire                             axis_out_0_tvalid,
    input wire                              axis_out_0_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_1_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_1_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_1_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_1_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_1_tuser,
    output wire                             axis_out_1_tlast,
    output wire                             axis_out_1_tvalid,
    input wire                              axis_out_1_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_2_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_2_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_2_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_2_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_2_tuser,
    output wire                             axis_out_2_tlast,
    output wire                             axis_out_2_tvalid,
    input wire                              axis_out_2_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_3_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_3_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_3_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_3_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_3_tuser,
    output wire                             axis_out_3_tlast,
    output wire                             axis_out_3_tvalid,
    input wire                              axis_out_3_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_4_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_4_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_4_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_4_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_4_tuser,
    output wire                             axis_out_4_tlast,
    output wire                             axis_out_4_tvalid,
    input wire                              axis_out_4_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_5_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_5_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_5_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_5_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_5_tuser,
    output wire                             axis_out_5_tlast,
    output wire                             axis_out_5_tvalid,
    input wire                              axis_out_5_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_6_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_6_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_6_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_6_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_6_tuser,
    output wire                             axis_out_6_tlast,
    output wire                             axis_out_6_tvalid,
    input wire                              axis_out_6_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_7_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_7_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_7_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_7_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_7_tuser,
    output wire                             axis_out_7_tlast,
    output wire                             axis_out_7_tvalid,
    input wire                              axis_out_7_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_8_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_8_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_8_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_8_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_8_tuser,
    output wire                             axis_out_8_tlast,
    output wire                             axis_out_8_tvalid,
    input wire                              axis_out_8_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_9_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_9_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_9_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_9_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_9_tuser,
    output wire                             axis_out_9_tlast,
    output wire                             axis_out_9_tvalid,
    input wire                              axis_out_9_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_10_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_10_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_10_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_10_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_10_tuser,
    output wire                             axis_out_10_tlast,
    output wire                             axis_out_10_tvalid,
    input wire                              axis_out_10_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_11_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_11_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_11_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_11_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_11_tuser,
    output wire                             axis_out_11_tlast,
    output wire                             axis_out_11_tvalid,
    input wire                              axis_out_11_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_12_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_12_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_12_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_12_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_12_tuser,
    output wire                             axis_out_12_tlast,
    output wire                             axis_out_12_tvalid,
    input wire                              axis_out_12_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_13_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_13_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_13_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_13_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_13_tuser,
    output wire                             axis_out_13_tlast,
    output wire                             axis_out_13_tvalid,
    input wire                              axis_out_13_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_14_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_14_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_14_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_14_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_14_tuser,
    output wire                             axis_out_14_tlast,
    output wire                             axis_out_14_tvalid,
    input wire                              axis_out_14_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_15_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_15_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_15_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_15_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_15_tuser,
    output wire                             axis_out_15_tlast,
    output wire                             axis_out_15_tvalid,
    input wire                              axis_out_15_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_16_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_16_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_16_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_16_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_16_tuser,
    output wire                             axis_out_16_tlast,
    output wire                             axis_out_16_tvalid,
    input wire                              axis_out_16_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_17_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_17_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_17_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_17_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_17_tuser,
    output wire                             axis_out_17_tlast,
    output wire                             axis_out_17_tvalid,
    input wire                              axis_out_17_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_18_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_18_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_18_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_18_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_18_tuser,
    output wire                             axis_out_18_tlast,
    output wire                             axis_out_18_tvalid,
    input wire                              axis_out_18_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_19_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_19_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_19_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_19_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_19_tuser,
    output wire                             axis_out_19_tlast,
    output wire                             axis_out_19_tvalid,
    input wire                              axis_out_19_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_20_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_20_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_20_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_20_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_20_tuser,
    output wire                             axis_out_20_tlast,
    output wire                             axis_out_20_tvalid,
    input wire                              axis_out_20_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_21_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_21_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_21_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_21_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_21_tuser,
    output wire                             axis_out_21_tlast,
    output wire                             axis_out_21_tvalid,
    input wire                              axis_out_21_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_22_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_22_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_22_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_22_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_22_tuser,
    output wire                             axis_out_22_tlast,
    output wire                             axis_out_22_tvalid,
    input wire                              axis_out_22_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_23_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_23_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_23_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_23_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_23_tuser,
    output wire                             axis_out_23_tlast,
    output wire                             axis_out_23_tvalid,
    input wire                              axis_out_23_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_24_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_24_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_24_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_24_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_24_tuser,
    output wire                             axis_out_24_tlast,
    output wire                             axis_out_24_tvalid,
    input wire                              axis_out_24_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_25_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_25_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_25_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_25_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_25_tuser,
    output wire                             axis_out_25_tlast,
    output wire                             axis_out_25_tvalid,
    input wire                              axis_out_25_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_26_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_26_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_26_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_26_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_26_tuser,
    output wire                             axis_out_26_tlast,
    output wire                             axis_out_26_tvalid,
    input wire                              axis_out_26_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_27_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_27_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_27_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_27_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_27_tuser,
    output wire                             axis_out_27_tlast,
    output wire                             axis_out_27_tvalid,
    input wire                              axis_out_27_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_28_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_28_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_28_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_28_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_28_tuser,
    output wire                             axis_out_28_tlast,
    output wire                             axis_out_28_tvalid,
    input wire                              axis_out_28_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_29_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_29_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_29_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_29_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_29_tuser,
    output wire                             axis_out_29_tlast,
    output wire                             axis_out_29_tvalid,
    input wire                              axis_out_29_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_30_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_30_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_30_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_30_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_30_tuser,
    output wire                             axis_out_30_tlast,
    output wire                             axis_out_30_tvalid,
    input wire                              axis_out_30_tready,
 
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_31_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_31_tkeep,
    output wire [AXIS_TID_WIDTH-1:0]        axis_out_31_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_31_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_31_tuser,
    output wire                             axis_out_31_tlast,
    output wire                             axis_out_31_tvalid,
    input wire                              axis_out_31_tready,


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
            if(0 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_0 && axis_in_tdest <= ADDR_RANGE_HIGH_0 ) begin 
                current_output <= 0; 
            end 
            else if(1 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_1 && axis_in_tdest <= ADDR_RANGE_HIGH_1 ) begin 
                current_output <= 1; 
            end 
            else if(2 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_2 && axis_in_tdest <= ADDR_RANGE_HIGH_2 ) begin 
                current_output <= 2; 
            end 
            else if(3 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_3 && axis_in_tdest <= ADDR_RANGE_HIGH_3 ) begin 
                current_output <= 3; 
            end 
            else if(4 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_4 && axis_in_tdest <= ADDR_RANGE_HIGH_4 ) begin 
                current_output <= 4; 
            end 
            else if(5 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_5 && axis_in_tdest <= ADDR_RANGE_HIGH_5 ) begin 
                current_output <= 5; 
            end 
            else if(6 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_6 && axis_in_tdest <= ADDR_RANGE_HIGH_6 ) begin 
                current_output <= 6; 
            end 
            else if(7 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_7 && axis_in_tdest <= ADDR_RANGE_HIGH_7 ) begin 
                current_output <= 7; 
            end 
            else if(8 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_8 && axis_in_tdest <= ADDR_RANGE_HIGH_8 ) begin 
                current_output <= 8; 
            end 
            else if(9 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_9 && axis_in_tdest <= ADDR_RANGE_HIGH_9 ) begin 
                current_output <= 9; 
            end 
            else if(10 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_10 && axis_in_tdest <= ADDR_RANGE_HIGH_10 ) begin 
                current_output <= 10; 
            end 
            else if(11 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_11 && axis_in_tdest <= ADDR_RANGE_HIGH_11 ) begin 
                current_output <= 11; 
            end 
            else if(12 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_12 && axis_in_tdest <= ADDR_RANGE_HIGH_12 ) begin 
                current_output <= 12; 
            end 
            else if(13 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_13 && axis_in_tdest <= ADDR_RANGE_HIGH_13 ) begin 
                current_output <= 13; 
            end 
            else if(14 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_14 && axis_in_tdest <= ADDR_RANGE_HIGH_14 ) begin 
                current_output <= 14; 
            end 
            else if(15 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_15 && axis_in_tdest <= ADDR_RANGE_HIGH_15 ) begin 
                current_output <= 15; 
            end 
            else if(16 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_16 && axis_in_tdest <= ADDR_RANGE_HIGH_16 ) begin 
                current_output <= 16; 
            end 
            else if(17 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_17 && axis_in_tdest <= ADDR_RANGE_HIGH_17 ) begin 
                current_output <= 17; 
            end 
            else if(18 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_18 && axis_in_tdest <= ADDR_RANGE_HIGH_18 ) begin 
                current_output <= 18; 
            end 
            else if(19 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_19 && axis_in_tdest <= ADDR_RANGE_HIGH_19 ) begin 
                current_output <= 19; 
            end 
            else if(20 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_20 && axis_in_tdest <= ADDR_RANGE_HIGH_20 ) begin 
                current_output <= 20; 
            end 
            else if(21 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_21 && axis_in_tdest <= ADDR_RANGE_HIGH_21 ) begin 
                current_output <= 21; 
            end 
            else if(22 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_22 && axis_in_tdest <= ADDR_RANGE_HIGH_22 ) begin 
                current_output <= 22; 
            end 
            else if(23 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_23 && axis_in_tdest <= ADDR_RANGE_HIGH_23 ) begin 
                current_output <= 23; 
            end 
            else if(24 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_24 && axis_in_tdest <= ADDR_RANGE_HIGH_24 ) begin 
                current_output <= 24; 
            end 
            else if(25 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_25 && axis_in_tdest <= ADDR_RANGE_HIGH_25 ) begin 
                current_output <= 25; 
            end 
            else if(26 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_26 && axis_in_tdest <= ADDR_RANGE_HIGH_26 ) begin 
                current_output <= 26; 
            end 
            else if(27 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_27 && axis_in_tdest <= ADDR_RANGE_HIGH_27 ) begin 
                current_output <= 27; 
            end 
            else if(28 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_28 && axis_in_tdest <= ADDR_RANGE_HIGH_28 ) begin 
                current_output <= 28; 
            end 
            else if(29 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_29 && axis_in_tdest <= ADDR_RANGE_HIGH_29 ) begin 
                current_output <= 29; 
            end 
            else if(30 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_30 && axis_in_tdest <= ADDR_RANGE_HIGH_30 ) begin 
                current_output <= 30; 
            end 
            else if(31 < NUM_OUTPUTS && axis_in_tdest >= ADDR_RANGE_LOW_31 && axis_in_tdest <= ADDR_RANGE_HIGH_31 ) begin 
                current_output <= 31; 
            end 
            else begin
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
    assign axis_out_0_tdata = ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tdata); 
    assign axis_out_0_tkeep = ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tkeep); 
    assign axis_out_0_tid =   ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tid); 
    assign axis_out_0_tdest = ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tdest); 
    assign axis_out_0_tuser = ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tuser); 
    assign axis_out_0_tlast = ((NUM_OUTPUTS <= 0 || (ENABLE_SECURE_OUTPUT && current_output != 0)) ? 0 : reg_tlast); 
    assign axis_out_0_tvalid = ((NUM_OUTPUTS <= 0 || current_output != 0) ? 0 : reg_tvalid); 
 
    assign axis_out_1_tdata = ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tdata); 
    assign axis_out_1_tkeep = ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tkeep); 
    assign axis_out_1_tid =   ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tid); 
    assign axis_out_1_tdest = ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tdest); 
    assign axis_out_1_tuser = ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tuser); 
    assign axis_out_1_tlast = ((NUM_OUTPUTS <= 1 || (ENABLE_SECURE_OUTPUT && current_output != 1)) ? 0 : reg_tlast); 
    assign axis_out_1_tvalid = ((NUM_OUTPUTS <= 1 || current_output != 1) ? 0 : reg_tvalid); 
 
    assign axis_out_2_tdata = ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tdata); 
    assign axis_out_2_tkeep = ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tkeep); 
    assign axis_out_2_tid =   ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tid); 
    assign axis_out_2_tdest = ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tdest); 
    assign axis_out_2_tuser = ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tuser); 
    assign axis_out_2_tlast = ((NUM_OUTPUTS <= 2 || (ENABLE_SECURE_OUTPUT && current_output != 2)) ? 0 : reg_tlast); 
    assign axis_out_2_tvalid = ((NUM_OUTPUTS <= 2 || current_output != 2) ? 0 : reg_tvalid); 
 
    assign axis_out_3_tdata = ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tdata); 
    assign axis_out_3_tkeep = ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tkeep); 
    assign axis_out_3_tid =   ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tid); 
    assign axis_out_3_tdest = ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tdest); 
    assign axis_out_3_tuser = ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tuser); 
    assign axis_out_3_tlast = ((NUM_OUTPUTS <= 3 || (ENABLE_SECURE_OUTPUT && current_output != 3)) ? 0 : reg_tlast); 
    assign axis_out_3_tvalid = ((NUM_OUTPUTS <= 3 || current_output != 3) ? 0 : reg_tvalid); 
 
    assign axis_out_4_tdata = ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tdata); 
    assign axis_out_4_tkeep = ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tkeep); 
    assign axis_out_4_tid =   ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tid); 
    assign axis_out_4_tdest = ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tdest); 
    assign axis_out_4_tuser = ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tuser); 
    assign axis_out_4_tlast = ((NUM_OUTPUTS <= 4 || (ENABLE_SECURE_OUTPUT && current_output != 4)) ? 0 : reg_tlast); 
    assign axis_out_4_tvalid = ((NUM_OUTPUTS <= 4 || current_output != 4) ? 0 : reg_tvalid); 
 
    assign axis_out_5_tdata = ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tdata); 
    assign axis_out_5_tkeep = ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tkeep); 
    assign axis_out_5_tid =   ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tid); 
    assign axis_out_5_tdest = ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tdest); 
    assign axis_out_5_tuser = ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tuser); 
    assign axis_out_5_tlast = ((NUM_OUTPUTS <= 5 || (ENABLE_SECURE_OUTPUT && current_output != 5)) ? 0 : reg_tlast); 
    assign axis_out_5_tvalid = ((NUM_OUTPUTS <= 5 || current_output != 5) ? 0 : reg_tvalid); 
 
    assign axis_out_6_tdata = ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tdata); 
    assign axis_out_6_tkeep = ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tkeep); 
    assign axis_out_6_tid =   ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tid); 
    assign axis_out_6_tdest = ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tdest); 
    assign axis_out_6_tuser = ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tuser); 
    assign axis_out_6_tlast = ((NUM_OUTPUTS <= 6 || (ENABLE_SECURE_OUTPUT && current_output != 6)) ? 0 : reg_tlast); 
    assign axis_out_6_tvalid = ((NUM_OUTPUTS <= 6 || current_output != 6) ? 0 : reg_tvalid); 
 
    assign axis_out_7_tdata = ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tdata); 
    assign axis_out_7_tkeep = ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tkeep); 
    assign axis_out_7_tid =   ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tid); 
    assign axis_out_7_tdest = ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tdest); 
    assign axis_out_7_tuser = ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tuser); 
    assign axis_out_7_tlast = ((NUM_OUTPUTS <= 7 || (ENABLE_SECURE_OUTPUT && current_output != 7)) ? 0 : reg_tlast); 
    assign axis_out_7_tvalid = ((NUM_OUTPUTS <= 7 || current_output != 7) ? 0 : reg_tvalid); 
 
    assign axis_out_8_tdata = ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tdata); 
    assign axis_out_8_tkeep = ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tkeep); 
    assign axis_out_8_tid =   ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tid); 
    assign axis_out_8_tdest = ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tdest); 
    assign axis_out_8_tuser = ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tuser); 
    assign axis_out_8_tlast = ((NUM_OUTPUTS <= 8 || (ENABLE_SECURE_OUTPUT && current_output != 8)) ? 0 : reg_tlast); 
    assign axis_out_8_tvalid = ((NUM_OUTPUTS <= 8 || current_output != 8) ? 0 : reg_tvalid); 
 
    assign axis_out_9_tdata = ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tdata); 
    assign axis_out_9_tkeep = ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tkeep); 
    assign axis_out_9_tid =   ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tid); 
    assign axis_out_9_tdest = ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tdest); 
    assign axis_out_9_tuser = ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tuser); 
    assign axis_out_9_tlast = ((NUM_OUTPUTS <= 9 || (ENABLE_SECURE_OUTPUT && current_output != 9)) ? 0 : reg_tlast); 
    assign axis_out_9_tvalid = ((NUM_OUTPUTS <= 9 || current_output != 9) ? 0 : reg_tvalid); 
 
    assign axis_out_10_tdata = ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tdata); 
    assign axis_out_10_tkeep = ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tkeep); 
    assign axis_out_10_tid =   ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tid); 
    assign axis_out_10_tdest = ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tdest); 
    assign axis_out_10_tuser = ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tuser); 
    assign axis_out_10_tlast = ((NUM_OUTPUTS <= 10 || (ENABLE_SECURE_OUTPUT && current_output != 10)) ? 0 : reg_tlast); 
    assign axis_out_10_tvalid = ((NUM_OUTPUTS <= 10 || current_output != 10) ? 0 : reg_tvalid); 
 
    assign axis_out_11_tdata = ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tdata); 
    assign axis_out_11_tkeep = ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tkeep); 
    assign axis_out_11_tid =   ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tid); 
    assign axis_out_11_tdest = ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tdest); 
    assign axis_out_11_tuser = ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tuser); 
    assign axis_out_11_tlast = ((NUM_OUTPUTS <= 11 || (ENABLE_SECURE_OUTPUT && current_output != 11)) ? 0 : reg_tlast); 
    assign axis_out_11_tvalid = ((NUM_OUTPUTS <= 11 || current_output != 11) ? 0 : reg_tvalid); 
 
    assign axis_out_12_tdata = ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tdata); 
    assign axis_out_12_tkeep = ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tkeep); 
    assign axis_out_12_tid =   ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tid); 
    assign axis_out_12_tdest = ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tdest); 
    assign axis_out_12_tuser = ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tuser); 
    assign axis_out_12_tlast = ((NUM_OUTPUTS <= 12 || (ENABLE_SECURE_OUTPUT && current_output != 12)) ? 0 : reg_tlast); 
    assign axis_out_12_tvalid = ((NUM_OUTPUTS <= 12 || current_output != 12) ? 0 : reg_tvalid); 
 
    assign axis_out_13_tdata = ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tdata); 
    assign axis_out_13_tkeep = ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tkeep); 
    assign axis_out_13_tid =   ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tid); 
    assign axis_out_13_tdest = ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tdest); 
    assign axis_out_13_tuser = ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tuser); 
    assign axis_out_13_tlast = ((NUM_OUTPUTS <= 13 || (ENABLE_SECURE_OUTPUT && current_output != 13)) ? 0 : reg_tlast); 
    assign axis_out_13_tvalid = ((NUM_OUTPUTS <= 13 || current_output != 13) ? 0 : reg_tvalid); 
 
    assign axis_out_14_tdata = ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tdata); 
    assign axis_out_14_tkeep = ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tkeep); 
    assign axis_out_14_tid =   ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tid); 
    assign axis_out_14_tdest = ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tdest); 
    assign axis_out_14_tuser = ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tuser); 
    assign axis_out_14_tlast = ((NUM_OUTPUTS <= 14 || (ENABLE_SECURE_OUTPUT && current_output != 14)) ? 0 : reg_tlast); 
    assign axis_out_14_tvalid = ((NUM_OUTPUTS <= 14 || current_output != 14) ? 0 : reg_tvalid); 
 
    assign axis_out_15_tdata = ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tdata); 
    assign axis_out_15_tkeep = ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tkeep); 
    assign axis_out_15_tid =   ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tid); 
    assign axis_out_15_tdest = ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tdest); 
    assign axis_out_15_tuser = ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tuser); 
    assign axis_out_15_tlast = ((NUM_OUTPUTS <= 15 || (ENABLE_SECURE_OUTPUT && current_output != 15)) ? 0 : reg_tlast); 
    assign axis_out_15_tvalid = ((NUM_OUTPUTS <= 15 || current_output != 15) ? 0 : reg_tvalid); 
 
    assign axis_out_16_tdata = ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tdata); 
    assign axis_out_16_tkeep = ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tkeep); 
    assign axis_out_16_tid =   ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tid); 
    assign axis_out_16_tdest = ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tdest); 
    assign axis_out_16_tuser = ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tuser); 
    assign axis_out_16_tlast = ((NUM_OUTPUTS <= 16 || (ENABLE_SECURE_OUTPUT && current_output != 16)) ? 0 : reg_tlast); 
    assign axis_out_16_tvalid = ((NUM_OUTPUTS <= 16 || current_output != 16) ? 0 : reg_tvalid); 
 
    assign axis_out_17_tdata = ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tdata); 
    assign axis_out_17_tkeep = ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tkeep); 
    assign axis_out_17_tid =   ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tid); 
    assign axis_out_17_tdest = ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tdest); 
    assign axis_out_17_tuser = ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tuser); 
    assign axis_out_17_tlast = ((NUM_OUTPUTS <= 17 || (ENABLE_SECURE_OUTPUT && current_output != 17)) ? 0 : reg_tlast); 
    assign axis_out_17_tvalid = ((NUM_OUTPUTS <= 17 || current_output != 17) ? 0 : reg_tvalid); 
 
    assign axis_out_18_tdata = ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tdata); 
    assign axis_out_18_tkeep = ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tkeep); 
    assign axis_out_18_tid =   ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tid); 
    assign axis_out_18_tdest = ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tdest); 
    assign axis_out_18_tuser = ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tuser); 
    assign axis_out_18_tlast = ((NUM_OUTPUTS <= 18 || (ENABLE_SECURE_OUTPUT && current_output != 18)) ? 0 : reg_tlast); 
    assign axis_out_18_tvalid = ((NUM_OUTPUTS <= 18 || current_output != 18) ? 0 : reg_tvalid); 
 
    assign axis_out_19_tdata = ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tdata); 
    assign axis_out_19_tkeep = ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tkeep); 
    assign axis_out_19_tid =   ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tid); 
    assign axis_out_19_tdest = ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tdest); 
    assign axis_out_19_tuser = ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tuser); 
    assign axis_out_19_tlast = ((NUM_OUTPUTS <= 19 || (ENABLE_SECURE_OUTPUT && current_output != 19)) ? 0 : reg_tlast); 
    assign axis_out_19_tvalid = ((NUM_OUTPUTS <= 19 || current_output != 19) ? 0 : reg_tvalid); 
 
    assign axis_out_20_tdata = ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tdata); 
    assign axis_out_20_tkeep = ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tkeep); 
    assign axis_out_20_tid =   ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tid); 
    assign axis_out_20_tdest = ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tdest); 
    assign axis_out_20_tuser = ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tuser); 
    assign axis_out_20_tlast = ((NUM_OUTPUTS <= 20 || (ENABLE_SECURE_OUTPUT && current_output != 20)) ? 0 : reg_tlast); 
    assign axis_out_20_tvalid = ((NUM_OUTPUTS <= 20 || current_output != 20) ? 0 : reg_tvalid); 
 
    assign axis_out_21_tdata = ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tdata); 
    assign axis_out_21_tkeep = ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tkeep); 
    assign axis_out_21_tid =   ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tid); 
    assign axis_out_21_tdest = ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tdest); 
    assign axis_out_21_tuser = ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tuser); 
    assign axis_out_21_tlast = ((NUM_OUTPUTS <= 21 || (ENABLE_SECURE_OUTPUT && current_output != 21)) ? 0 : reg_tlast); 
    assign axis_out_21_tvalid = ((NUM_OUTPUTS <= 21 || current_output != 21) ? 0 : reg_tvalid); 
 
    assign axis_out_22_tdata = ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tdata); 
    assign axis_out_22_tkeep = ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tkeep); 
    assign axis_out_22_tid =   ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tid); 
    assign axis_out_22_tdest = ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tdest); 
    assign axis_out_22_tuser = ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tuser); 
    assign axis_out_22_tlast = ((NUM_OUTPUTS <= 22 || (ENABLE_SECURE_OUTPUT && current_output != 22)) ? 0 : reg_tlast); 
    assign axis_out_22_tvalid = ((NUM_OUTPUTS <= 22 || current_output != 22) ? 0 : reg_tvalid); 
 
    assign axis_out_23_tdata = ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tdata); 
    assign axis_out_23_tkeep = ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tkeep); 
    assign axis_out_23_tid =   ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tid); 
    assign axis_out_23_tdest = ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tdest); 
    assign axis_out_23_tuser = ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tuser); 
    assign axis_out_23_tlast = ((NUM_OUTPUTS <= 23 || (ENABLE_SECURE_OUTPUT && current_output != 23)) ? 0 : reg_tlast); 
    assign axis_out_23_tvalid = ((NUM_OUTPUTS <= 23 || current_output != 23) ? 0 : reg_tvalid); 
 
    assign axis_out_24_tdata = ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tdata); 
    assign axis_out_24_tkeep = ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tkeep); 
    assign axis_out_24_tid =   ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tid); 
    assign axis_out_24_tdest = ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tdest); 
    assign axis_out_24_tuser = ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tuser); 
    assign axis_out_24_tlast = ((NUM_OUTPUTS <= 24 || (ENABLE_SECURE_OUTPUT && current_output != 24)) ? 0 : reg_tlast); 
    assign axis_out_24_tvalid = ((NUM_OUTPUTS <= 24 || current_output != 24) ? 0 : reg_tvalid); 
 
    assign axis_out_25_tdata = ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tdata); 
    assign axis_out_25_tkeep = ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tkeep); 
    assign axis_out_25_tid =   ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tid); 
    assign axis_out_25_tdest = ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tdest); 
    assign axis_out_25_tuser = ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tuser); 
    assign axis_out_25_tlast = ((NUM_OUTPUTS <= 25 || (ENABLE_SECURE_OUTPUT && current_output != 25)) ? 0 : reg_tlast); 
    assign axis_out_25_tvalid = ((NUM_OUTPUTS <= 25 || current_output != 25) ? 0 : reg_tvalid); 
 
    assign axis_out_26_tdata = ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tdata); 
    assign axis_out_26_tkeep = ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tkeep); 
    assign axis_out_26_tid =   ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tid); 
    assign axis_out_26_tdest = ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tdest); 
    assign axis_out_26_tuser = ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tuser); 
    assign axis_out_26_tlast = ((NUM_OUTPUTS <= 26 || (ENABLE_SECURE_OUTPUT && current_output != 26)) ? 0 : reg_tlast); 
    assign axis_out_26_tvalid = ((NUM_OUTPUTS <= 26 || current_output != 26) ? 0 : reg_tvalid); 
 
    assign axis_out_27_tdata = ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tdata); 
    assign axis_out_27_tkeep = ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tkeep); 
    assign axis_out_27_tid =   ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tid); 
    assign axis_out_27_tdest = ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tdest); 
    assign axis_out_27_tuser = ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tuser); 
    assign axis_out_27_tlast = ((NUM_OUTPUTS <= 27 || (ENABLE_SECURE_OUTPUT && current_output != 27)) ? 0 : reg_tlast); 
    assign axis_out_27_tvalid = ((NUM_OUTPUTS <= 27 || current_output != 27) ? 0 : reg_tvalid); 
 
    assign axis_out_28_tdata = ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tdata); 
    assign axis_out_28_tkeep = ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tkeep); 
    assign axis_out_28_tid =   ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tid); 
    assign axis_out_28_tdest = ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tdest); 
    assign axis_out_28_tuser = ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tuser); 
    assign axis_out_28_tlast = ((NUM_OUTPUTS <= 28 || (ENABLE_SECURE_OUTPUT && current_output != 28)) ? 0 : reg_tlast); 
    assign axis_out_28_tvalid = ((NUM_OUTPUTS <= 28 || current_output != 28) ? 0 : reg_tvalid); 
 
    assign axis_out_29_tdata = ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tdata); 
    assign axis_out_29_tkeep = ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tkeep); 
    assign axis_out_29_tid =   ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tid); 
    assign axis_out_29_tdest = ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tdest); 
    assign axis_out_29_tuser = ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tuser); 
    assign axis_out_29_tlast = ((NUM_OUTPUTS <= 29 || (ENABLE_SECURE_OUTPUT && current_output != 29)) ? 0 : reg_tlast); 
    assign axis_out_29_tvalid = ((NUM_OUTPUTS <= 29 || current_output != 29) ? 0 : reg_tvalid); 
 
    assign axis_out_30_tdata = ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tdata); 
    assign axis_out_30_tkeep = ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tkeep); 
    assign axis_out_30_tid =   ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tid); 
    assign axis_out_30_tdest = ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tdest); 
    assign axis_out_30_tuser = ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tuser); 
    assign axis_out_30_tlast = ((NUM_OUTPUTS <= 30 || (ENABLE_SECURE_OUTPUT && current_output != 30)) ? 0 : reg_tlast); 
    assign axis_out_30_tvalid = ((NUM_OUTPUTS <= 30 || current_output != 30) ? 0 : reg_tvalid); 
 
    assign axis_out_31_tdata = ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tdata); 
    assign axis_out_31_tkeep = ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tkeep); 
    assign axis_out_31_tid =   ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tid); 
    assign axis_out_31_tdest = ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tdest); 
    assign axis_out_31_tuser = ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tuser); 
    assign axis_out_31_tlast = ((NUM_OUTPUTS <= 31 || (ENABLE_SECURE_OUTPUT && current_output != 31)) ? 0 : reg_tlast); 
    assign axis_out_31_tvalid = ((NUM_OUTPUTS <= 31 || current_output != 31) ? 0 : reg_tvalid); 



    //Ready signal
    always(*) begin

        if(0 < NUM_OUTPUTS && current_output == 0) begin 
            reg_tready = axis_out_0_tready; 
        end 
        else if(1 < NUM_OUTPUTS && current_output == 1) begin 
            reg_tready = axis_out_1_tready; 
        end 
        else if(2 < NUM_OUTPUTS && current_output == 2) begin 
            reg_tready = axis_out_2_tready; 
        end 
        else if(3 < NUM_OUTPUTS && current_output == 3) begin 
            reg_tready = axis_out_3_tready; 
        end 
        else if(4 < NUM_OUTPUTS && current_output == 4) begin 
            reg_tready = axis_out_4_tready; 
        end 
        else if(5 < NUM_OUTPUTS && current_output == 5) begin 
            reg_tready = axis_out_5_tready; 
        end 
        else if(6 < NUM_OUTPUTS && current_output == 6) begin 
            reg_tready = axis_out_6_tready; 
        end 
        else if(7 < NUM_OUTPUTS && current_output == 7) begin 
            reg_tready = axis_out_7_tready; 
        end 
        else if(8 < NUM_OUTPUTS && current_output == 8) begin 
            reg_tready = axis_out_8_tready; 
        end 
        else if(9 < NUM_OUTPUTS && current_output == 9) begin 
            reg_tready = axis_out_9_tready; 
        end 
        else if(10 < NUM_OUTPUTS && current_output == 10) begin 
            reg_tready = axis_out_10_tready; 
        end 
        else if(11 < NUM_OUTPUTS && current_output == 11) begin 
            reg_tready = axis_out_11_tready; 
        end 
        else if(12 < NUM_OUTPUTS && current_output == 12) begin 
            reg_tready = axis_out_12_tready; 
        end 
        else if(13 < NUM_OUTPUTS && current_output == 13) begin 
            reg_tready = axis_out_13_tready; 
        end 
        else if(14 < NUM_OUTPUTS && current_output == 14) begin 
            reg_tready = axis_out_14_tready; 
        end 
        else if(15 < NUM_OUTPUTS && current_output == 15) begin 
            reg_tready = axis_out_15_tready; 
        end 
        else if(16 < NUM_OUTPUTS && current_output == 16) begin 
            reg_tready = axis_out_16_tready; 
        end 
        else if(17 < NUM_OUTPUTS && current_output == 17) begin 
            reg_tready = axis_out_17_tready; 
        end 
        else if(18 < NUM_OUTPUTS && current_output == 18) begin 
            reg_tready = axis_out_18_tready; 
        end 
        else if(19 < NUM_OUTPUTS && current_output == 19) begin 
            reg_tready = axis_out_19_tready; 
        end 
        else if(20 < NUM_OUTPUTS && current_output == 20) begin 
            reg_tready = axis_out_20_tready; 
        end 
        else if(21 < NUM_OUTPUTS && current_output == 21) begin 
            reg_tready = axis_out_21_tready; 
        end 
        else if(22 < NUM_OUTPUTS && current_output == 22) begin 
            reg_tready = axis_out_22_tready; 
        end 
        else if(23 < NUM_OUTPUTS && current_output == 23) begin 
            reg_tready = axis_out_23_tready; 
        end 
        else if(24 < NUM_OUTPUTS && current_output == 24) begin 
            reg_tready = axis_out_24_tready; 
        end 
        else if(25 < NUM_OUTPUTS && current_output == 25) begin 
            reg_tready = axis_out_25_tready; 
        end 
        else if(26 < NUM_OUTPUTS && current_output == 26) begin 
            reg_tready = axis_out_26_tready; 
        end 
        else if(27 < NUM_OUTPUTS && current_output == 27) begin 
            reg_tready = axis_out_27_tready; 
        end 
        else if(28 < NUM_OUTPUTS && current_output == 28) begin 
            reg_tready = axis_out_28_tready; 
        end 
        else if(29 < NUM_OUTPUTS && current_output == 29) begin 
            reg_tready = axis_out_29_tready; 
        end 
        else if(30 < NUM_OUTPUTS && current_output == 30) begin 
            reg_tready = axis_out_30_tready; 
        end 
        else if(31 < NUM_OUTPUTS && current_output == 31) begin 
            reg_tready = axis_out_31_tready; 
        end 
        else begin

            if(DEFAULT_OUTPUT == 0) reg_tready = axis_out_0_tready 
            if(DEFAULT_OUTPUT == 1) reg_tready = axis_out_1_tready 
            if(DEFAULT_OUTPUT == 2) reg_tready = axis_out_2_tready 
            if(DEFAULT_OUTPUT == 3) reg_tready = axis_out_3_tready 
            if(DEFAULT_OUTPUT == 4) reg_tready = axis_out_4_tready 
            if(DEFAULT_OUTPUT == 5) reg_tready = axis_out_5_tready 
            if(DEFAULT_OUTPUT == 6) reg_tready = axis_out_6_tready 
            if(DEFAULT_OUTPUT == 7) reg_tready = axis_out_7_tready 
            if(DEFAULT_OUTPUT == 8) reg_tready = axis_out_8_tready 
            if(DEFAULT_OUTPUT == 9) reg_tready = axis_out_9_tready 
            if(DEFAULT_OUTPUT == 10) reg_tready = axis_out_10_tready 
            if(DEFAULT_OUTPUT == 11) reg_tready = axis_out_11_tready 
            if(DEFAULT_OUTPUT == 12) reg_tready = axis_out_12_tready 
            if(DEFAULT_OUTPUT == 13) reg_tready = axis_out_13_tready 
            if(DEFAULT_OUTPUT == 14) reg_tready = axis_out_14_tready 
            if(DEFAULT_OUTPUT == 15) reg_tready = axis_out_15_tready 
            if(DEFAULT_OUTPUT == 16) reg_tready = axis_out_16_tready 
            if(DEFAULT_OUTPUT == 17) reg_tready = axis_out_17_tready 
            if(DEFAULT_OUTPUT == 18) reg_tready = axis_out_18_tready 
            if(DEFAULT_OUTPUT == 19) reg_tready = axis_out_19_tready 
            if(DEFAULT_OUTPUT == 20) reg_tready = axis_out_20_tready 
            if(DEFAULT_OUTPUT == 21) reg_tready = axis_out_21_tready 
            if(DEFAULT_OUTPUT == 22) reg_tready = axis_out_22_tready 
            if(DEFAULT_OUTPUT == 23) reg_tready = axis_out_23_tready 
            if(DEFAULT_OUTPUT == 24) reg_tready = axis_out_24_tready 
            if(DEFAULT_OUTPUT == 25) reg_tready = axis_out_25_tready 
            if(DEFAULT_OUTPUT == 26) reg_tready = axis_out_26_tready 
            if(DEFAULT_OUTPUT == 27) reg_tready = axis_out_27_tready 
            if(DEFAULT_OUTPUT == 28) reg_tready = axis_out_28_tready 
            if(DEFAULT_OUTPUT == 29) reg_tready = axis_out_29_tready 
            if(DEFAULT_OUTPUT == 30) reg_tready = axis_out_30_tready 
            if(DEFAULT_OUTPUT == 31) reg_tready = axis_out_31_tready
            
        end 

    end



endmodule


`default_nettype wire