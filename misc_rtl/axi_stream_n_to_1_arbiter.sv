`timescale 1ns / 1ps
`default_nettype none

/*
AXI Stream Aribiter Module (N to 1)

Author: Daniel Rozhko, PhD Candidate University of Toronto

***Read Notes (module not complete, may not work)
***Note - This core has not been fully tested and may not work correctly

Description:
   An AXI Stream Aribiter, with N inputs and 1 output. Arbitration
   based on priority specifed by parameters. Re-arbitration after
   tlast transmitted (rather than per flit). One cycle of latency
   added with single register stage. The output TID signal is the
   concatentation of the stream number selected by the abiter to the 
   MSB of the input TID signal. Note, zero widths for any of the 
   signals is not supported.

Defines:
   MAX_NUM_INPUTS - the maximum number of inputs supported

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi streams
   AXIS_IN_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   IN_PRIORITY_# - priority of input #, lower is better
   NUM_INPUTS - number of inputs actually used, defaults to max
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
   - This module includes a function wich hasn't been tested yet, and
   as such cannot be considered working (and may not synthesize)
*/

//Max number of outputs (less than or equal to 128 supported)
`define MAX_NUM_INPUTS 32

//Preprocessor functions
`include "preproc_repeat.vh"



module axi_stream_n_to_1_arbiter
#(
	//AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_IN_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //Priority for inputs (lower is better)
    `define PARAM_PRIORITY_DEF(n,d) \
    parameter IN_PRIORITY_``n = 0,\

    `PP_REPEAT(`MAX_NUM_OUTPUTS,PARAM_PRIORITY_DEF,0)

    //Additional params
    parameter NUM_INPUTS = `MAX_NUM_INPUTS, //Actual number of inputs in use (for parameterizability)
    
    //Derived parameters, shouldn't be modified
    parameter AXIS_OUT_TID_WIDTH = AXIS_IN_TID_WIDTH + $clog2(NUM_INPUTS)
)
(
	//Input AXI streams
	`define INPUT_PORTS_DEF(n,d) \
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_``n``_tdata,\
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_``n``_tkeep,\
    input wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_``n``_tid,\
    input wire [AXIS_TDEST_WDITH-1:0]       axis_in_``n``_tdest,\
    input wire [AXIS_TUSER_WIDTH-1:0]       axis_in_``n``_tuser,\
    input wire                              axis_in_``n``_tlast,\
    input wire                              axis_in_``n``_tvalid,\
    output wire                             axis_in_``n``_tready,\

    `PP_REPEAT(`MAX_NUM_OUTPUTS,INPUT_PORTS_DEF,0)

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

	//Assign input signals to arrays to deal with more easily
	wire [AXIS_BUS_WIDTH-1:0]         axis_in_array_tdata [`MAX_NUM_INPUTS-1:0];
    wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_array_tkeep [`MAX_NUM_INPUTS-1:0];
    wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_array_tid [`MAX_NUM_INPUTS-1:0];
    wire [AXIS_TDEST_WDITH-1:0]       axis_in_array_tdest [`MAX_NUM_INPUTS-1:0];
    wire [AXIS_TUSER_WIDTH-1:0]       axis_in_array_tuser [`MAX_NUM_INPUTS-1:0];
    wire                              axis_in_array_tlast [`MAX_NUM_INPUTS-1:0];
    wire                              axis_in_array_tvalid [`MAX_NUM_INPUTS-1:0];
    wire                              axis_in_array_tready [`MAX_NUM_INPUTS-1:0];

    `define INPUT_TO_ARRAY(n,d) \
	assign axis_in_array_tdata[n] = axis_in_``n``_tdata;\
	assign axis_in_array_tkeep[n] = axis_in_``n``_tkeep;\
	assign axis_in_array_tid[n] = axis_in_``n``_tid;\
	assign axis_in_array_tdest[n] = axis_in_``n``_tdest;\
	assign axis_in_array_tuser[n] = axis_in_``n``_tuser;\
	assign axis_in_array_tlast[n] = axis_in_``n``_tlast;\
	assign axis_in_array_tvalid[n] = axis_in_``n``_tvalid;\
	assign axis_in_``n``_tready = axis_in_array_tready[n];\

	`PP_REPEAT(`MAX_NUM_OUTPUTS,INPUT_TO_ARRAY,0)



	//Input signals in order of priorty (lowest number to highest)
    localparam NUM_IN_LOG2 = $clog2(NUM_INPUTS);
    wire [AXIS_BUS_WIDTH-1:0]         axis_in_ordered_tdata [NUM_INPUTS-1:0];
    wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_ordered_tkeep [NUM_INPUTS-1:0];
    wire [AXIS_IN_TID_WIDTH-1:0]      axis_in_ordered_tid [NUM_INPUTS-1:0];
    wire [AXIS_TDEST_WDITH-1:0]       axis_in_ordered_tdest [NUM_INPUTS-1:0];
    wire [AXIS_TUSER_WIDTH-1:0]       axis_in_ordered_tuser [NUM_INPUTS-1:0];
    wire                              axis_in_ordered_tlast [NUM_INPUTS-1:0];
    wire                              axis_in_ordered_tvalid [NUM_INPUTS-1:0];
    wire                              axis_in_ordered_tready [NUM_INPUTS-1:0];
    wire [NUM_IN_LOG2-1:0]            axis_in_ordered_actual_num [NUM_INPUTS-1:0];

    typedef integer ret_array [NUM_INPUTS-1:0];
    function ret_array determine_priority_list (); //function compares all priorities and returns the priority order
    begin

    	//The priority parameters
    	automatic integer input_priorities[`MAX_NUM_INPUTS-1:0];

    	`define ASSIGN_TO_INT(n,d) \
    	input_priorities[n] = IN_PRIORITY_``n;

    	`PP_REPEAT(`MAX_NUM_INPUTS,ASSIGN_TO_INT,0)

    	//Initialize fist entry in list;
    	determine_priority_list[0] = 0;

    	//Loop through remaining priorities
    	for(integer i = 1; i < NUM_INPUTS; i++) begin

    		//Determine position to insert new priority in list
    		integer insert;
    		for(insert = 0; insert < i; insert++) begin
    			if(input_priorities[ determine_priority_list[insert] ] > input_priorities[i]) break; //Not sure if synthesizable
    		end 

    		//Shift all entries above insert position
    		for(integer j = i; j > insert; j--) begin
    			determine_priority_list[j] = determine_priority_list[j-1];
    		end 

    		//Insert the priority value
    		determine_priority_list[insert] = i;

    	end 

    	//TODO - test if this function actually works, haven't tested this yet

    end
    endfunction

    localparam integer priority_list [NUM_INPUTS-1:0] = determine_priority_list(); //The input numbers in order of priority

    genvar i;
    generate for(i = 0; i < NUM_INPUTS; i++) begin: priority_assign_loop

    	assign axis_in_ordered_tdata[i] = axis_in_array_tdata [ priority_list[i] ];
    	assign axis_in_ordered_tkeep[i] = axis_in_array_tkeep [ priority_list[i] ];
    	assign axis_in_ordered_tid[i] = axis_in_array_tid [ priority_list[i] ];
    	assign axis_in_ordered_tdest[i] = axis_in_array_tdest [ priority_list[i] ];
    	assign axis_in_ordered_tuser[i] = axis_in_array_tuser [ priority_list[i] ];
    	assign axis_in_ordered_tlast[i] = axis_in_array_tlast [ priority_list[i] ];
    	assign axis_in_ordered_tvalid[i] = axis_in_array_tvalid [ priority_list[i] ];
    	assign axis_in_array_tready [ priority_list[i] ] = axis_in_ordered_tready[i];
        assign axis_in_ordered_actual_num[i] = priority_list[i];

    end endgenerate

    generate for(i = NUM_INPUTS; i < 'MAX_NUM_INPUTS; i++) begin: tready_unused_tie_off

        assign axis_in_array_tready[i] = 0

    end endgenerate



    //Register all inputs (tvalid signal cannot form cobinational loop with tready)
    reg [AXIS_BUS_WIDTH-1:0]         axis_in_reg_tdata[NUM_INPUTS-1:0];
    reg [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_reg_tkeep[NUM_INPUTS-1:0];
    reg [AXIS_IN_TID_WIDTH-1:0]      axis_in_reg_tid[NUM_INPUTS-1:0];
    reg [AXIS_TDEST_WDITH-1:0]       axis_in_reg_tdest[NUM_INPUTS-1:0];
    reg [AXIS_TUSER_WIDTH-1:0]       axis_in_reg_tuser[NUM_INPUTS-1:0];
    reg                              axis_in_reg_tlast[NUM_INPUTS-1:0];
    reg                              axis_in_reg_tvalid[NUM_INPUTS-1:0];
    wire                             axis_in_reg_tready[NUM_INPUTS-1:0];

    generate for(i = 0; i < NUM_INPUTS; i++) begin: in_register_loop

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
    wire [NUM_IN_LOG2-1:0] input_to_send;
    wire nothing_to_send;
    reg [NUM_IN_LOG2-1:0] current_input_selected;
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
            for(j = NUM_INPUTS-1; j >= 0; j--) begin
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
    generate for(i = 0; i < NUM_INPUTS; i++) begin: tready_assign_loop
    
        assign axis_in_reg_tready[i] = ((input_to_send != i || nothing_to_send) ? 0 : axis_out_tready);

    end endgenerate



endmodule

`undefineall
`default_nettype wire