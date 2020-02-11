`timescale 1ns / 1ps
`default_nettype none


module parse_wait_buffer
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    //Parsing Limit Params
    parameter SIDE_CHAN_WIDTH = 10,
    parameter LAST_BYTE = 1522,
        
    //Derived parameters for parsing limit
    localparam LAST_BEAT = (LAST_BYTE / NUM_BUS_BYTES) + ((LAST_BYTE % NUM_BUS_BYTES == 0) ? 0 : 1) + 1,
    localparam BUFFER_DEPTH_LOG2 = $clog2(LAST_BEAT),
    localparam BUFFER_DEPTH = 2 ** BUFFER_DEPTH_LOG2,
    localparam BUFFER_DEPTH_CBITS = $clog2(BUFFER_DEPTH + 1)
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,

    //Input side channel
    input wire [SIDE_CHAN_WIDTH-1:0]        chan_in_data,
    input wire                              chan_in_error,
    input wire                              chan_in_done_opt, 
    input wire                              chan_in_done_req, 
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Output side channel
    output wire [SIDE_CHAN_WIDTH-1:0]       chan_out_data,
    output wire                             chan_out_error,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Primary Stream FIFO                                  //
    //--------------------------------------------------------//

    //FIFO data
    reg [AXIS_BUS_WIDTH-1:0]   fifo_tdata [BUFFER_DEPTH-1:0];
    reg [NUM_BUS_BYTES-1:0]    fifo_tkeep [BUFFER_DEPTH-1:0];
    reg                        fifo_tlast [BUFFER_DEPTH-1:0];

    //Signals for the FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]   fifo_count;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo_rd_pointer;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo_wr_pointer;
    wire                           fifo_n_empty = (fifo_count != 0);
    wire                           fifo_n_full = (fifo_count != BUFFER_DEPTH);
    wire                           fifo_wr_en;
    wire                           fifo_rd_en;

    //Counter updates
    always@(posedge aclk) begin
        if(~aresetn) begin
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

    //Assign values for read ports (first word fall-through)
    assign axis_out_tdata = fifo_tdata[fifo_rd_pointer];
    assign axis_out_tkeep = fifo_tkeep[fifo_rd_pointer];
    assign axis_out_tlast = fifo_tlast[fifo_rd_pointer];

    //Infer write port
    always@(posedge aclk) begin
        if(fifo_wr_en && fifo_n_full) begin
            fifo_tdata[fifo_wr_pointer] <= axis_in_tdata;
            fifo_tkeep[fifo_wr_pointer] <= axis_in_tkeep;
            fifo_tlast[fifo_wr_pointer] <= axis_in_tlast;
        end
    end



    //--------------------------------------------------------//
    //   Side Channel FIFO                                    //
    //--------------------------------------------------------//

    //FIFO data
    reg [SIDE_CHAN_WIDTH-1:0]  fifo_chan_data [BUFFER_DEPTH-1:0];
    reg                        fifo_chan_error [BUFFER_DEPTH-1:0];
    wire                       eff_chan_error;

    //Signals for the FIFO
    reg [BUFFER_DEPTH_CBITS-1:0]   fifo2_count;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo2_rd_pointer;
    reg [BUFFER_DEPTH_LOG2-1:0]    fifo2_wr_pointer;
    wire                           fifo2_n_empty = (fifo2_count != 0);
    wire                           fifo2_n_full = (fifo2_count != BUFFER_DEPTH);
    wire                           fifo2_wr_en;
    wire                           fifo2_rd_en;

    //Counter updates
    always@(posedge aclk) begin
        if(~aresetn) begin
            fifo2_count <= 0;
            fifo2_rd_pointer <= 0;
            fifo2_wr_pointer <= 0;
        end
        else if(fifo2_rd_en && fifo2_wr_en) begin
            fifo2_rd_pointer <= fifo2_rd_pointer + 1;
            fifo2_wr_pointer <= fifo2_wr_pointer + 1;
        end
        else if(fifo2_rd_en) begin
            fifo2_count <= fifo2_count - 1;
            fifo2_rd_pointer <= fifo2_rd_pointer + 1;
        end
        else if(fifo2_wr_en) begin
            fifo2_count <= fifo2_count + 1;
            fifo2_wr_pointer <= fifo2_wr_pointer + 1;
        end
    end

    //Assign values for read ports
    assign chan_out_data = fifo_chan_data[fifo2_rd_pointer];
    assign chan_out_error = fifo_chan_error[fifo2_rd_pointer];

    //Infer write port
    always@(posedge aclk) begin
        if(fifo2_wr_en && fifo2_n_full) begin
            fifo_chan_data[fifo2_wr_pointer] <= chan_in_data;
            fifo_chan_error[fifo2_wr_pointer] <= eff_chan_error;
        end
    end



    //--------------------------------------------------------//
    //   Control the FIFOs                                    //
    //--------------------------------------------------------//

    //Reading from fifo logic
    assign axis_out_tvalid = fifo2_n_empty && fifo_n_empty;
    assign fifo_rd_en = axis_out_tready && axis_out_tvalid;
    assign fifo2_rd_en = fifo_rd_en && axis_out_tlast;
    
    //Writing to fifo logic
    assign axis_in_tready = fifo_n_full && fifo2_n_full;
    assign fifo_wr_en = axis_in_tvalid && axis_in_tready;

    reg side_chan_done;
    always@(posedge aclk) begin
        if(~aresetn || (fifo_wr_en && axis_in_tlast) ) side_chan_done <= 0;
        else if (fifo_wr_en && chan_in_done_opt) side_chan_done <= 1;
    end

    assign fifo2_wr_en = fifo_wr_en && ((chan_in_done_opt && !side_chan_done) || (axis_in_tlast && !side_chan_done));
    assign eff_chan_error = chan_in_error || (axis_in_tlast && !side_chan_done && !chan_in_done_req);

    
   
endmodule

`default_nettype wire