`timescale 1ns / 1ps
`default_nettype none

/*
Register Slice Module (forward and reverse registering, with bubble cycle inserted)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   A register slice, with full registering and an inserted bubble cycle

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


module reg_slice_full_light
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
    reg [DATA_WIDTH-1:0]      reg_data;
    reg                       reg_valid;



    //--------------------------------------------------------//
    //   Regster Assignment                                   //
    //--------------------------------------------------------//

    //Registers instantiated
    always@(posedge clk) begin
        if(~resetn) begin

            reg_valid <= 0;

        end 
        else if(!reg_valid) begin

            reg_data <= in_data;
            reg_valid <= in_valid;

        end
        else if(out_ready) begin

            reg_valid <= 0;

        end
    end

    //Assign outputs
    assign out_data = reg_data;
    assign out_valid = reg_valid;
    assign in_ready = !reg_valid;



endmodule

`default_nettype wire