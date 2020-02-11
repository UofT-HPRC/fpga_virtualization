`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream Aribiter Module (2 to 1)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   An AXI Stream Aribiter, with 2 inputs and 1 output. Arbitration
   based on priority specifed by parameters. Re-arbitration after
   tlast transmitted (rather than per flit). One cycle of latency
   added with single register stage. The output TID signal is the
   concatentation of the stream number selected by the abiter to the 
   MSB of the input TID signal. Note, zero widths for any of the 
   signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi streams
   AXIS_IN_TID_WIDTH - the width of the tid signal on the input stream
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   IN_PRIORITY_# - priority of input #, lower is better
   AXIS_OUT_TID_WIDTH - the width of the tid signal on the output stream (should leave as default value)

Ports:
   axis_in_#_* - input axi stream corresponding to interface #
   axis_out_* - output axi stream
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous

Notes:
   - This module registers all inputs, so the total number of registers
   needed can be large with wide interfaces or large # of inputs
   - The tready signals for each of the inputs is a combinational 
   function of the registered version of tvalid for all of the inputs,
   some internal state registers, and the output tready signal, which 
   can lead to large combinational paths with large # of inputs
*/


module axi_stream_2_to_1_arbiter
#(
	//AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_IN_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //Priority for inputs (lower is better)
    parameter IN_PRIORITY_0 = 1,
    parameter IN_PRIORITY_1 = 2,

    //Derived parameters, shouldn't be modified
    parameter AXIS_OUT_TID_WIDTH = AXIS_IN_TID_WIDTH + 1
)
(
	//Input AXI streams
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_0_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_0_tkeep,
    input wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_0_tid,
    input wire [AXIS_TDEST_WDITH-1:0]       axis_in_0_tdest,
    input wire [AXIS_TUSER_WIDTH-1:0]       axis_in_0_tuser,
    input wire                              axis_in_0_tlast,
    input wire                              axis_in_0_tvalid,
    output wire                             axis_in_0_tready,

    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_1_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_1_tkeep,
    input wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_1_tid,
    input wire [AXIS_TDEST_WDITH-1:0]       axis_in_1_tdest,
    input wire [AXIS_TUSER_WIDTH-1:0]       axis_in_1_tuser,
    input wire                              axis_in_1_tlast,
    input wire                              axis_in_1_tvalid,
    output wire                             axis_in_1_tready,

    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_tkeep,
    output wire [AXIS_OUT_TID_WIDTH-1:0]    axis_out_tid,
    output wire [AXIS_TDEST_WDITH-1:0]      axis_out_tdest,
    output wire [AXIS_TUSER_WIDTH-1:0]      axis_out_tuser,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Input signals in order of priorty (lowest number to highest)
    wire [AXIS_BUS_WIDTH-1:0]         axis_in_ordered_tdata [1:0];
    wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_ordered_tkeep [1:0];
    wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_ordered_tid [1:0];
    wire [AXIS_TDEST_WDITH-1:0]       axis_in_ordered_tdest [1:0];
    wire [AXIS_TUSER_WIDTH-1:0]       axis_in_ordered_tuser [1:0];
    wire                              axis_in_ordered_tlast [1:0];
    wire                              axis_in_ordered_tvalid [1:0];
    wire                              axis_in_ordered_tready [1:0];
    wire                              axis_in_ordered_actual_num [1:0];

    generate if(IN_PRIORITY_0 <= IN_PRIORITY_1) begin: priorty_compare

        assign axis_in_ordered_tdata[0] = axis_in_0_tdata;
        assign axis_in_ordered_tkeep[0] = axis_in_0_tkeep;
        assign axis_in_ordered_tid[0] = axis_in_0_tid;
        assign axis_in_ordered_tdest[0] = axis_in_0_tdest;
        assign axis_in_ordered_tuser[0] = axis_in_0_tuser;
        assign axis_in_ordered_tlast[0] = axis_in_0_tlast;
        assign axis_in_ordered_tvalid[0] = axis_in_0_tvalid;
        assign axis_in_0_tready = axis_in_ordered_tready[0];
        assign axis_in_ordered_actual_num[0] = 0;

        assign axis_in_ordered_tdata[1] = axis_in_1_tdata;
        assign axis_in_ordered_tkeep[1] = axis_in_1_tkeep;
        assign axis_in_ordered_tid[1] = axis_in_1_tid;
        assign axis_in_ordered_tdest[1] = axis_in_1_tdest;
        assign axis_in_ordered_tuser[1] = axis_in_1_tuser;
        assign axis_in_ordered_tlast[1] = axis_in_1_tlast;
        assign axis_in_ordered_tvalid[1] = axis_in_1_tvalid;
        assign axis_in_1_tready = axis_in_ordered_tready[1];
        assign axis_in_ordered_actual_num[1] = 1;

    end else begin

        assign axis_in_ordered_tdata[0] = axis_in_1_tdata;
        assign axis_in_ordered_tkeep[0] = axis_in_1_tkeep;
        assign axis_in_ordered_tid[0] = axis_in_1_tid;
        assign axis_in_ordered_tdest[0] = axis_in_1_tdest;
        assign axis_in_ordered_tuser[0] = axis_in_1_tuser;
        assign axis_in_ordered_tlast[0] = axis_in_1_tlast;
        assign axis_in_ordered_tvalid[0] = axis_in_1_tvalid;
        assign axis_in_1_tready = axis_in_ordered_tready[0];
        assign axis_in_ordered_actual_num[0] = 1;

        assign axis_in_ordered_tdata[1] = axis_in_0_tdata;
        assign axis_in_ordered_tkeep[1] = axis_in_0_tkeep;
        assign axis_in_ordered_tid[1] = axis_in_0_tid;
        assign axis_in_ordered_tdest[1] = axis_in_0_tdest;
        assign axis_in_ordered_tuser[1] = axis_in_0_tuser;
        assign axis_in_ordered_tlast[1] = axis_in_0_tlast;
        assign axis_in_ordered_tvalid[1] = axis_in_0_tvalid;
        assign axis_in_0_tready = axis_in_ordered_tready[1];
        assign axis_in_ordered_actual_num[1] = 0;

    end endgenerate



    //Register all inputs (tvalid signal cannot form cobinational loop with tready)
    reg [AXIS_BUS_WIDTH-1:0]         axis_in_reg_tdata[1:0];
    reg [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_reg_tkeep[1:0];
    reg [AXIS_IN_TID_WIDTH-1:0]      axis_in_reg_tid[1:0];
    reg [AXIS_TDEST_WDITH-1:0]       axis_in_reg_tdest[1:0];
    reg [AXIS_TUSER_WIDTH-1:0]       axis_in_reg_tuser[1:0];
    reg                              axis_in_reg_tlast[1:0];
    reg                              axis_in_reg_tvalid[1:0];
    wire                             axis_in_reg_tready[1:0];

    genvar i;
    generate for(i = 0; i < 2; i++) begin: in_register_loop

        always@(posedge aclk) begin
            if(~aresten) begin
                axis_in_reg_tdata[i] <= 0;
                axis_in_reg_tkeep[i] <-0;
                axis_in_reg_tid[i] <= 0;
                axis_in_reg_tdest[i] <= 0;
                axis_in_reg_tuser[i] <= 0;
                axis_in_reg_tlast[i] <= 0;
                axis_in_reg_tvalid[i] <= 0;
            end
            else if(!axis_in_reg_tvalid[i] || axis_in_reg_tready[i]) begin
                axis_in_reg_tdata[i] <= axis_in_ordered_tdata[i];
                axis_in_reg_tkeep[i] <-axis_in_ordered_tkeep[i];
                axis_in_reg_tid[i] <= axis_in_ordered_tid[i];
                axis_in_reg_tdest[i] <= axis_in_ordered_tdest[i];
                axis_in_reg_tuser[i] <= axis_in_ordered_tuser[i];
                axis_in_reg_tlast[i] <= axis_in_ordered_tlast[i];
                axis_in_reg_tvalid[i] <= axis_in_ordered_tvalid[i];
            end 
        end

        assign axis_in_ordered_tready[i] = !axis_in_reg_tvalid[i] || axis_in_reg_tready[i];

    end endgenerate



    //Detrmine arbitration based on available inputs
    reg input_to_send;
    reg nothing_to_send;
    reg current_input_selected;
    reg last_beat_sent;

    always@(*) begin
        if(!last_beat_sent) begin
            input_to_send = current_input_selected;
            nothing_to_send = 0;
        end else begin
            //default assignment
            input_to_send = 0;
            nothing_to_send = 1;

            //loop from lowest priority to highest
            integer j;
            for(j = 1; j >= 0; j--) begin
                if(axis_in_reg_tvalid[j]) begin
                    input_to_send = j;
                    nothing_to_send = 0;
                end 
            end 

        end
    end 

    always@(posedge aclk) begin
        if(~aresten) current_input_selected <= 0;
        else if(last_beat_sent) current_input_selected <= input_to_send;
    end 

    always@(posedge aclk) begin
        if(~aresten) 
            last_beat_sent <= 1;
        else if(axis_in_reg_tvalid[input_to_send] && axis_in_reg_tlast[input_to_send] && axis_out_tready)
            last_beat_sent <= 1;
        else if(!nothing_to_send)
            last_beat_sent <= 0;
    end



    //Assign Output values
    assign axis_out_tdata = axis_in_reg_tdata[input_to_send];
    assign axis_out_tkeep = axis_in_reg_tkeep[input_to_send];
    assign axis_out_tid = {axis_in_ordered_actual_num[input_to_send],axis_in_reg_tid[input_to_send]};
    assign axis_out_tdest = axis_in_reg_tdest[input_to_send];
    assign axis_out_tuser = axis_in_reg_tuser[input_to_send];
    assign axis_out_tlast = axis_in_reg_tlast[input_to_send];
    assign axis_out_tvalid = axis_in_reg_tvalid[input_to_send];



    //Assign tready signals
    generate for(i = 0; i < 2; i++) begin: tready_assign_loop
    
        assign axis_in_reg_tready[i] = ((input_to_send != i || nothing_to_send) ? 0 : axis_out_tready);

    end endgenerate



endmodule

`default_nettype wire