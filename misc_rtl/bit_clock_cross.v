`timescale 1ns / 1ps
`default_nettype none

/*
Bit Clock Cross

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   Clock crossing for a single bit, to use in Xlnx Block Diagrams

*/


module bit_clock_cross
(
    //Single Bit wire to cross clock
    input wire      bit_in,
    output wire     bit_out,

    //Clocks for input and output side
    input wire      clk_in,
    output wire     clk_out
);

    xpm_cdc_array_single
    #(
        .DEST_SYNC_FF(3),   //DECIMAL; range:2-10
        .INIT_SYNC_FF(0),   //DECIMAL; integer; 0=disable simulation init values, 1=enable simulation init values
        .SIM_ASSERT_CHK(0), //DECIMAL; integer; 0=disable simulation messages, 1=enable simulation messages
        .SRC_INPUT_REG(1),  //DECIMAL; 0=do not register input, 1=register input
        .WIDTH(1)           //DECIMAL; range:1-1024
    )
    sync_net_decoup_inst
    (
        .src_in     (bit_in),
        .dest_out   (bit_out),

        .src_clk    (clk_in),
        .dest_clk   (clk_out)        
    );


endmodule

`default_nettype wire