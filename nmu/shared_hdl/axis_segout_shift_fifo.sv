`timescale 1ns / 1ps
`default_nettype none


module axis_segout_shift_fifo
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_USER_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = (AXIS_BUS_WIDTH/8),

    //Segmentation Params
    parameter NUM_SEGMENTS = 4,
    parameter BUFFER_DEPTH = 3,
    
    //Derived parameters for segmentation
    localparam AXIS_SEG_WIDTH = (AXIS_BUS_WIDTH/NUM_SEGMENTS),
    localparam NUM_SEG_BYTES = (AXIS_SEG_WIDTH/8),
    localparam BUFFER_DEPTH_CBITS = $clog2(BUFFER_DEPTH+1)
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [AXIS_USER_WIDTH-1:0]    axis_in_tuser,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_SEG_WIDTH-1:0]    axis_out_tdata [NUM_SEGMENTS-1:0],
    output wire [AXIS_USER_WIDTH-1:0]   axis_out_tuser,
    output wire [NUM_SEG_BYTES-1:0]     axis_out_tkeep [NUM_SEGMENTS-1:0],
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid [NUM_SEGMENTS-1:0],
    input wire                          axis_out_tready [NUM_SEGMENTS-1:0],
    
    //Output AXI Stream Peek (Next Output)
    output wire [NUM_SEG_BYTES-1:0]     axis_out_next_tkeep [NUM_SEGMENTS-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AXI Stream Buffering                                 //
    //--------------------------------------------------------//
    
    //The buffered data
    reg [AXIS_SEG_WIDTH-1:0]      axis_buff_tdata [BUFFER_DEPTH-1:0][NUM_SEGMENTS-1:0];
    reg [NUM_SEG_BYTES-1:0]       axis_buff_tkeep [BUFFER_DEPTH-1:0][NUM_SEGMENTS-1:0];
    reg [AXIS_USER_WIDTH-1:0]     axis_buff_tuser [BUFFER_DEPTH-1:0];
    reg                           axis_buff_tlast [BUFFER_DEPTH-1:0];
    
    //FIFO signals for the buffer on a byte-pair basis
    reg [BUFFER_DEPTH_CBITS-1:0] axis_lane_count [NUM_SEGMENTS-1:0];
    wire                         axis_lane_rd_en [NUM_SEGMENTS-1:0];
    wire                         axis_lane_n_full [NUM_SEGMENTS-1:0];
    wire                         axis_lane_n_empty [NUM_SEGMENTS-1:0];
    
    //Logic for the FIFO size counters
    assign  axis_in_tready = axis_lane_n_full[NUM_SEGMENTS-1];
    wire    axis_lane_wr_en = axis_in_tvalid && axis_in_tready;
    
    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : fifo_segments
        
            wire axis_lane_incr = axis_lane_wr_en;
            wire axis_lane_decr = axis_lane_rd_en[j] && axis_lane_n_empty[j];
            
            always@(posedge aclk) begin
                if(~aresetn) axis_lane_count[j] <= 0;
                else if(axis_lane_incr && axis_lane_decr) axis_lane_count[j] <= axis_lane_count[j];
                else if(axis_lane_incr) axis_lane_count[j] <= axis_lane_count[j] + 1;
                else if(axis_lane_decr) axis_lane_count[j] <= axis_lane_count[j] - 1;
            end
            
            assign axis_lane_n_full[j] = (axis_lane_count[j] != BUFFER_DEPTH);
            assign axis_lane_n_empty[j] = (axis_lane_count[j] != 0);
        
        end
    endgenerate
    
    //Generate shift register FIFOs per segment
    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : buffer_segments
            for(genvar k = 0; k < BUFFER_DEPTH; k = k + 1) begin : shiftreg_level
            
                wire write_depth_match;
                if(k == (BUFFER_DEPTH-1)) assign write_depth_match = (axis_lane_rd_en[j] ? 0 : axis_lane_count[j] == k);
                else assign write_depth_match = (axis_lane_rd_en[j] ? axis_lane_count[j] == (k+1) : axis_lane_count[j] == k);
            
                always@(posedge aclk) begin
                    if(~aresetn) begin
                        axis_buff_tdata[k][j] <= 0;
                        axis_buff_tkeep[k][j] <= 0;
                        if(j == NUM_SEGMENTS - 1) begin
                            axis_buff_tlast[k] <= 0;
                            axis_buff_tuser[k] <= 0;
                        end
                    end
                    else if(write_depth_match && axis_lane_wr_en) begin
                        axis_buff_tdata[k][j] <= axis_in_tdata[(j*AXIS_SEG_WIDTH)+:AXIS_SEG_WIDTH];
                        axis_buff_tkeep[k][j] <= axis_in_tkeep[(j*NUM_SEG_BYTES)+:NUM_SEG_BYTES];
                        if(j == NUM_SEGMENTS - 1) begin 
                            axis_buff_tlast[k] <= axis_in_tlast;
                            axis_buff_tuser[k] <= axis_in_tuser;
                        end
                    end
                    else if(axis_lane_rd_en[j] && axis_lane_n_empty[j] && k != (BUFFER_DEPTH-1)) begin
                        axis_buff_tdata[k][j] <= axis_buff_tdata[k+1][j];
                        axis_buff_tkeep[k][j] <= axis_buff_tkeep[k+1][j];
                        if(j == NUM_SEGMENTS - 1) begin
                            axis_buff_tlast[k] <= axis_buff_tlast[k+1];
                            axis_buff_tuser[k] <= axis_buff_tuser[k+1];
                        end
                    end
                end
            end
        end
    endgenerate
    
    //Assign output values
    assign axis_out_tdata = axis_buff_tdata[0];
    assign axis_out_tuser = axis_buff_tuser[0];
    assign axis_out_tkeep = axis_buff_tkeep[0];
    assign axis_out_next_tkeep = axis_buff_tkeep[1];
    assign axis_out_tlast = axis_buff_tlast[0];
    
    assign axis_out_tvalid = axis_lane_n_empty;
    assign axis_lane_rd_en = axis_out_tready;
    
endmodule

`default_nettype wire