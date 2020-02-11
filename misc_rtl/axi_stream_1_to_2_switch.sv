`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream Switch Module (1 to 2)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   An AXI Stream switch, with one input and two outputs. Routing based 
   on tdest field, with parameter specified mapping. Arbitration after 
   tlast transmitted (rather than per flit). One cycle of latency added 
   with a single register stage. Note, zero widths for any of the signals
   is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi stream
   AXIS_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   ADDR_RANGE_LOW_# - low-end of range to route to output #, inclusive
   ADDR_RANGE_HIGH_# - high-end of range to route to output #, inclusive
   DEFAULT_OUTPUT - interface to target if no tdest range matches
   ENABLE_SECURE_OUTPUT - binary, whether to mask output of unselected output streams

Ports:
   axis_in_* - input axi stream to be routed
   axis_out_#_* - output axi stream corresponding to interface #
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_1_to_2_switch
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

    //Number of outputs actually used
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
    reg current_output;
    reg last_beat_sent;

    always@(posedge aclk) begin
        if(~aresetn) begin
            current_output <= DEFAULT_OUTPUT;
        end
        else if(axis_in_tvalid && ( (reg_tlast && reg_tvalid && reg_tready) || last_beat_sent ) ) begin

            //Check each output range
            if(axis_in_tdest >= ADDR_RANGE_LOW_0 && axis_in_tdest <= ADDR_RANGE_HIGH0 ) begin 
                current_output <= 0; 
            end 
            else if(axis_in_tdest >= ADDR_RANGE_LOW_1 && axis_in_tdest <= ADDR_RANGE_HIGH1 ) begin 
                current_output <= 1; 
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
    assign axis_out_0_tdata = ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tdata); 
    assign axis_out_0_tkeep = ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tkeep); 
    assign axis_out_0_tid =   ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tid); 
    assign axis_out_0_tdest = ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tdest); 
    assign axis_out_0_tuser = ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tuser); 
    assign axis_out_0_tlast = ((ENABLE_SECURE_OUTPUT && current_output != 0) ? 0 : reg_tlast); 
    assign axis_out_0_tvalid = (current_output != 0 ? 0 : reg_tvalid); 
 
    assign axis_out_1_tdata = ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tdata); 
    assign axis_out_1_tkeep = ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tkeep); 
    assign axis_out_1_tid =   ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tid); 
    assign axis_out_1_tdest = ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tdest); 
    assign axis_out_1_tuser = ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tuser); 
    assign axis_out_1_tlast = ((ENABLE_SECURE_OUTPUT && current_output != 1) ? 0 : reg_tlast); 
    assign axis_out_1_tvalid = (current_output != 1 ? 0 : reg_tvalid); 


    //Ready signal
    always(*) begin

        if(current_output == 0) begin 
            reg_tready = axis_out_0_tready; 
        end 
        else if(current_output == 1) begin 
            reg_tready = axis_out_1_tready; 
        end 
        else begin
            if(DEFAULT_OUTPUT == 0) reg_tready = axis_out_0_tready 
            if(DEFAULT_OUTPUT == 1) reg_tready = axis_out_1_tready
        end 

    end



endmodule

`default_nettype wire