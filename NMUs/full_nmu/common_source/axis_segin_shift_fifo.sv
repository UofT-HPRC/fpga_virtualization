`timescale 1ns / 1ps
`default_nettype none


module axis_segin_shift_fifo
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TUSER_WIDTH = 4,

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
    input wire [AXIS_SEG_WIDTH-1:0]     axis_in_tdata [NUM_SEGMENTS-1:0],
    input wire [NUM_SEG_BYTES-1:0]      axis_in_tkeep [NUM_SEGMENTS-1:0],
    input wire [AXIS_TUSER_WIDTH-1:0]   axis_in_tuser,
    input wire                          axis_in_tvalid,
    input wire                          axis_in_tlast,
    output wire                         axis_in_tready,

    //When to write to the segments
    input wire                          axis_in_write [(NUM_SEGMENTS*2)-2:0],
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire [AXIS_TUSER_WIDTH-1:0]  axis_out_tuser,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Determine what to do per segment                     //
    //--------------------------------------------------------//

    //Whether or not each segment is written to
    wire axis_tdata_wr [NUM_SEGMENTS-1:0];

    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : tdata_wr 
            if(j == NUM_SEGMENTS-1) assign axis_tdata_wr[j] = axis_in_tvalid && axis_in_tready && axis_in_write[j]; 
            else assign axis_tdata_wr[j] = axis_in_tvalid && axis_in_tready && (axis_in_write[j] || axis_in_write[j+NUM_SEGMENTS]); 
        end
    endgenerate

    //Determine whether to insert empty data
    reg [(NUM_SEGMENTS*2)-2:0] axis_in_write_packed = {>>{axis_in_write}};

    wire axis_tdata_insrt1 [NUM_SEGMENTS-1:0];
    wire axis_tdata_insrt2 [NUM_SEGMENTS-1:0];
    wire axis_tdata_insrt [NUM_SEGMENTS-1:0];

    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : tlast_incr1
            if(j == 0) assign axis_tdata_insrt1[j] = 1'b0;
            else assign axis_tdata_insrt1[j] = (|axis_in_write_packed[j-1:0]) && !axis_in_write_packed[j];

            if(j == 0) assign axis_tdata_insrt2[j] = 1'b0;
            else if(j == NUM_SEGMENTS-1) assign axis_tdata_insrt2[j] = |axis_in_write_packed[j+NUM_SEGMENTS-1:NUM_SEGMENTS];
            else assign axis_tdata_insrt2[j] = (|axis_in_write_packed[j+NUM_SEGMENTS-1:NUM_SEGMENTS]) && !axis_in_write_packed[j+NUM_SEGMENTS];

            assign axis_tdata_insrt[j] = axis_in_tvalid && axis_in_tready && axis_in_tlast && (axis_tdata_insrt1[j] || axis_tdata_insrt2[j]);
        end
    endgenerate

    //Determine whether to overwrite prev tlast value
    wire axis_tlast_overwrite = axis_in_tvalid && axis_in_tready && axis_in_tlast && !(|axis_in_write_packed);



    //--------------------------------------------------------//
    //   AXI Segmented Buffering                              //
    //--------------------------------------------------------//
    
    //The buffered data
    reg [AXIS_SEG_WIDTH-1:0]      axis_buff_tdata [BUFFER_DEPTH-1:0][NUM_SEGMENTS-1:0];
    reg [NUM_SEG_BYTES-1:0]       axis_buff_tkeep [BUFFER_DEPTH-1:0][NUM_SEGMENTS-1:0];
    reg [AXIS_TUSER_WIDTH-1:0]    axis_buff_tuser [BUFFER_DEPTH-1:0];
    reg                           axis_buff_tlast [BUFFER_DEPTH-1:0];
    
    //FIFO signals for the buffer segments
    reg [BUFFER_DEPTH_CBITS-1:0] axis_lane_count [NUM_SEGMENTS-1:0];
    wire                         axis_lane_rd_en = axis_out_tvalid && axis_out_tready;
    wire                         axis_lane_n_full [NUM_SEGMENTS-1:0];
    wire                         axis_lane_n_empty [NUM_SEGMENTS-1:0];
    wire                         axis_lane_gt_empty [NUM_SEGMENTS-1:0];
        
    //Logic for the FIFO size counters
    assign  axis_in_tready = axis_lane_n_full[0];
    
    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : fifo_segments
        
            wire axis_lane_incr1 = axis_tdata_wr[j];
            wire axis_lane_incr2 = axis_tdata_insrt[j];
            wire axis_lane_decr = axis_lane_rd_en;
            
            always@(posedge aclk) begin
                if(~aresetn) axis_lane_count[j] <= 0;
                else axis_lane_count[j] <= axis_lane_count[j] + axis_lane_incr1 + axis_lane_incr2 - axis_lane_decr;
            end
            
            assign axis_lane_n_full[j] = (axis_lane_count[j] != BUFFER_DEPTH);
            assign axis_lane_n_empty[j] = (axis_lane_count[j] != 0);
            assign axis_lane_gt_empty[j] = (axis_lane_count[j] > 1);
        
        end
    endgenerate
    
    //Generate shift register FIFOs per segment
    generate
        for(genvar j = 0; j < NUM_SEGMENTS; j = j + 1) begin : buffer_segments
            for(genvar k = 0; k < BUFFER_DEPTH; k = k + 1) begin : shiftreg_level
            
                always@(posedge aclk) begin
                    if(~aresetn) begin
                        axis_buff_tdata[k][j] <= 0;
                        axis_buff_tkeep[k][j] <= 0;
                        if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= 0;
                    end
                    //Test if writing and inserting
                    else if(axis_tdata_wr[j] && axis_tdata_insrt[j]) begin
                        if(k == 0) begin
                            axis_buff_tdata[k][j] <= axis_in_tdata[j]; //Don't Care
                            axis_buff_tkeep[k][j] <= 2'b00;
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_in_tlast;
                            if(j == 0) axis_buff_tuser[k] <= axis_in_tuser;
                        end
                        else if(k == 1) begin
                            axis_buff_tdata[k][j] <= axis_in_tdata[j];
                            axis_buff_tkeep[k][j] <= axis_in_tkeep[j];
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= 1'b0;
                            if(j == 0) axis_buff_tuser[k] <= axis_in_tuser;
                        end
                        else begin
                            axis_buff_tdata[k][j] <= axis_buff_tdata[k-2][j];
                            axis_buff_tkeep[k][j] <= axis_buff_tkeep[k-2][j];
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_buff_tlast[k-2];
                            if(j == 0) axis_buff_tuser[k] <= axis_buff_tuser[k-2];
                        end
                    end
                    //Test if writing only
                    else if(axis_tdata_wr[j]) begin
                        if(k == 0) begin
                            axis_buff_tdata[k][j] <= axis_in_tdata[j];
                            axis_buff_tkeep[k][j] <= axis_in_tkeep[j];
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_in_tlast;
                            if(j == 0) axis_buff_tuser[k] <= axis_in_tuser;
                        end
                        else begin
                            axis_buff_tdata[k][j] <= axis_buff_tdata[k-1][j];
                            axis_buff_tkeep[k][j] <= axis_buff_tkeep[k-1][j];
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_buff_tlast[k-1];
                            if(j == 0) axis_buff_tuser[k] <= axis_buff_tuser[k-1];
                        end
                    end
                    //Test if inserting only
                    else if(axis_tdata_insrt[j]) begin
                        if(k == 0) begin
                            axis_buff_tdata[k][j] <= axis_in_tdata[j]; //Don't Care
                            axis_buff_tkeep[k][j] <= 2'b00;
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_in_tlast;
                            if(j == 0) axis_buff_tuser[k] <= axis_in_tuser;
                        end
                        else begin
                            axis_buff_tdata[k][j] <= axis_buff_tdata[k-1][j];
                            axis_buff_tkeep[k][j] <= axis_buff_tkeep[k-1][j];
                            if(j == NUM_SEGMENTS - 1) axis_buff_tlast[k] <= axis_buff_tlast[k-1];
                            if(j == 0) axis_buff_tuser[k] <= axis_buff_tuser[k-1];
                        end
                    end
                    //For tlast, check if need to overwrite
                    else if(axis_tlast_overwrite && j == NUM_SEGMENTS-1 && k == 0) begin
                        axis_buff_tlast[k] <= axis_in_tlast;
                    end
                end
            end
            
            //Assign output values
            wire [BUFFER_DEPTH_CBITS-1:0] rd_index = axis_lane_count[j] - 1;

            assign axis_out_tdata[(j*AXIS_SEG_WIDTH)+:AXIS_SEG_WIDTH] = axis_buff_tdata[rd_index][j];
            assign axis_out_tkeep[(j*NUM_SEG_BYTES)+:NUM_SEG_BYTES] = axis_buff_tkeep[rd_index][j];
            if(j == NUM_SEGMENTS - 1) assign axis_out_tlast = axis_buff_tlast[rd_index];
            if(j == 0) assign axis_out_tuser = axis_buff_tuser[rd_index];
            
        end
    endgenerate
    
    //Assign tvalid value (more than 1 in FIFO, or tlast)
    assign axis_out_tvalid = axis_lane_gt_empty[0] || (axis_out_tlast && axis_lane_n_empty[NUM_SEGMENTS-1]);

    
endmodule

`default_nettype wire