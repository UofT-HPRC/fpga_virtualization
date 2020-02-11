`timescale 1ns / 1ps
`default_nettype none

/*
Register Slice Module (forward and reverse registering)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   A register slice, with full registering.

Parameters:
   DATA_WIDTH - the data width of the axi stream

Ports:
   in_data - the input data to register
   in_valid - valid signal corresponding to input data
   in_ready - backpressure corrsponding to input signal
   out_data - the output data after registering
   out_valid - valid signal corresponding to output data
   out_ready - backpressure corresponding to output signal
   clk - axi clock signal, all interfaces synchronous to this clock
   resetn - active-low reset, synchronous
*/


module reg_slice_full
#(
	//AXI Stream Params
    parameter DATA_WIDTH = 64
)
(
    //Input data stream
    input wire [DATA_WIDTH-1:0]       in_data,
    input wire                        in_valid,
    output wire                       in_ready,
    
    //Output data stream
    output wire [DATA_WIDTH-1:0]      out_data,
    output wire                       out_valid,
    input wire                        out_ready,

    //Clocking
    input wire  clk,
    input wire  resetn
);

    //--------------------------------------------------------//
    //   Registers                                            //
    //--------------------------------------------------------//

    //The Registers
    reg [DATA_WIDTH-1:0]      reg_data[1:0];
    reg [1:0]                 reg_count;



    //--------------------------------------------------------//
    //   Regster Assignment                                   //
    //--------------------------------------------------------//

    //Counter Update
    always@(posedge clk) begin
        if(~resetn) reg_count <= 0;
        else if(in_valid && in_ready && out_valid && out_ready)
            reg_count <= reg_count;
        else if(in_valid && in_ready)
            reg_count <= reg_count + 1;
        else if(out_valid && out_ready)
            reg_count <= reg_count -1;
    end

    //Shift register for data
    always@(posedge clk) begin
        if(in_valid && in_ready) begin
            //Register new input data
            reg_data[0] <= in_data;

            //If not accepting data at output, shift the data over
            if(!out_ready) reg_data[1] <= reg_data[0];
        end
    end

    //Assign outputs
    assign out_data = (reg_count >= 2 ? reg_data[1] : reg_data[0]);
    assign out_valid = (reg_count > 0);

    //Ready signal
    assign in_ready = (reg_count < 2);



endmodule

`default_nettype wire