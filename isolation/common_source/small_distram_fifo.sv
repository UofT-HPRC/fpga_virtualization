`timescale 1ns / 1ps
`default_nettype none


module small_distram_fifo
#(
    //AXI Stream Params
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
        
    //Derived parameters
    localparam BUFFER_DEPTH = 2 ** ADDR_WIDTH,
    localparam BUFFER_DEPTH_LOG2 = $clog2(BUFFER_DEPTH),
    localparam BUFFER_DEPTH_CBITS = $clog2(BUFFER_DEPTH + 1)
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

    //--------------------------------------------------------//
    //   Primary Stream FIFO                                  //
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

    //Assign values for read port (first word fall-through)
    assign dout = fifo_data[fifo_rd_pointer];

    //Infer write port
    always@(posedge clk) begin
        if(fifo_wr_en) begin
            fifo_data[fifo_wr_pointer] <= din;
        end
    end


   
endmodule

`default_nettype wire