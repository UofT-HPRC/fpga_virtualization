`timescale 1ns / 1ps
`default_nettype none

/*
Simple FIFO

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   A simple FIFO implementation, using non-registered output value so the
   memory can only be inferred as a LUTRAM

Parameters:
   DATA_WIDTH - the data width of the FIFO
   BUFFER_DEPTH_LOG2 - the FIFO depth, in LOG2 (only powers of 2 supported)

Ports:
   din - the input data port
   wr_en - indicates that the data is to be pushed to the FIFO
   full - indicates when the FIFO is full (cannot push)
   dout - the output data port
   rd_en - indicates that the data is to be popped from the FIFO
   empty - indicates when the FIFO is empty (cannot pop)
   clk - the clock, all interfaces synchronous to this clock
   rst - active-high reset, synchronous
*/


module simple_fifo
#(
    //FIFO Params
    parameter DATA_WIDTH = 8,
    parameter BUFFER_DEPTH_LOG2 = 8
)
(
    //Input interface
    input wire [DATA_WIDTH-1:0]     din,
    input wire                      wr_en,
    output wire                     full,

    //Output Interface
    output wire [DATA_WIDTH-1:0]    dout,
    input wire                      rd_en,
    output wire                     empty,
    
    //Clocking
    input wire  clk,
    input wire  rst
);

	//Derived parameters
    localparam BUFFER_DEPTH = 2 ** BUFFER_DEPTH_LOG2;
    localparam BUFFER_DEPTH_CBITS = BUFFER_DEPTH_LOG2 + 1;



    //--------------------------------------------------------//
    //   The FIFO Impl.                                       //
    //--------------------------------------------------------//

    //FIFO data
    reg [DATA_WIDTH-1:0]   fifo_data [BUFFER_DEPTH-1:0];

    //Signals for the FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]   fifo_count;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo_rd_pointer;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo_wr_pointer;

    assign empty = (fifo_count == 0);
    assign full = (fifo_count == BUFFER_DEPTH);

    wire fifo_wr_en = (wr_en && !full);
    wire fifo_rd_en = (rd_en && !empty);

    //Counter updates
    always@(posedge clk) begin
        if(rst) begin
            fifo_count <= 0;
            fifo_rd_pointer <= 0;
            fifo_wr_pointer <= 0;
        end
        else if(fifo_rd_en && fifo_wr_en) begin
            fifo_rd_pointer <= fifo_rd_pointer + 1;
            fifo_wr_pointer <= fifo_wr_pointer + 1;
        end
        else if(fifo_rd_en) begin
            fifo_count <= fifo_count - 1;
            fifo_rd_pointer <= fifo_rd_pointer + 1;
        end
        else if(fifo_wr_en) begin
            fifo_count <= fifo_count + 1;
            fifo_wr_pointer <= fifo_wr_pointer + 1;
        end
    end

    //Assign values for read port (first word fall-through, LUTRAM only impl.)
    assign dout = fifo_data[fifo_rd_pointer];

    //Infer write port
    always@(posedge clk) begin
        if(fifo_wr_en) begin
            fifo_data[fifo_wr_pointer] <= din;
        end
    end


   
endmodule

`default_nettype wire