`timescale 1ns / 1ps
`default_nettype none


module remover_FSM_dyn
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,

    //Derived params for AXI Stream
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_LANES_LOG2 = $clog2(NUM_BUS_LANES),

    //Removed segment parameters
    parameter MAX_REMOVE_BYTES = 4,
    parameter REMOVE_OFFSET = 12,
    
    //Derived params for removal params
    localparam NUM_RMV_BYTES_CBITS = $clog2(MAX_REMOVE_BYTES+1),
 
    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1)       
)
(
    //Inputs from FIFO side
    input wire      input_is_valid,
    input wire      input_is_last,
    
    //Inputs from output side
    input wire      output_is_ready,
    
    //Input for segment size (shouldn't change before input_is_last asserted)
    input wire [NUM_RMV_BYTES_CBITS-1:0] seg_size,
    
    //Outputs driven to output side
    output wire axis_lane_write [(NUM_BUS_LANES*2)-2:0],
    output wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index [NUM_BUS_LANES-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);
   
    wire transition = input_is_valid && output_is_ready; 
    wire transition_last = input_is_last && input_is_valid && output_is_ready;
   
    //--------------------------------------------------------//
    //   Calauclate Param-based Output Values                 //
    //--------------------------------------------------------// 
    
    //Calculate write offset and num bytes to write
    wire [NUM_BUS_LANES_LOG2-1:0] write_offset;
    reg [NUM_BUS_LANES_LOG2:0] num_write_lanes;
    wire [NUM_BUS_LANES_LOG2:0] num_seg_lanes;
    
    reg [PACKET_LENGTH_CBITS-1:0] acc_write_lanes;
    reg [NUM_RMV_BYTES_CBITS-1:0] acc_seg_lanes;
    reg [PACKET_LENGTH_CBITS-1:0] total_lanes;
    
    always@(posedge aclk) begin
        if(~aresetn || transition_last) begin
            acc_write_lanes <= 0;
            acc_seg_lanes <= 0;
            total_lanes <= NUM_BUS_LANES;
        end
        else if(transition) begin
            acc_write_lanes <= acc_write_lanes + num_write_lanes;
            acc_seg_lanes <= acc_seg_lanes + num_seg_lanes;
            total_lanes <= total_lanes + NUM_BUS_LANES;
        end
    end
    
    wire [NUM_RMV_BYTES_CBITS-1:0] remaining_seg = (seg_size/2) - acc_seg_lanes;
    wire [NUM_BUS_LANES_LOG2:0] max_seg_lanes = (remaining_seg > NUM_BUS_LANES ? NUM_BUS_LANES : remaining_seg);
    
    always@(*) begin
        if(total_lanes <= (REMOVE_OFFSET/2))
            num_write_lanes = NUM_BUS_LANES;
        else if(total_lanes < (REMOVE_OFFSET/2) + NUM_BUS_LANES)
            if(max_seg_lanes < ( NUM_BUS_LANES -  ((REMOVE_OFFSET/2) % NUM_BUS_LANES) ))
                num_write_lanes = NUM_BUS_LANES - max_seg_lanes;
            else
                num_write_lanes = (REMOVE_OFFSET/2) % NUM_BUS_LANES;
        else
            num_write_lanes = NUM_BUS_LANES - max_seg_lanes;
    end
    
    assign num_seg_lanes = NUM_BUS_LANES - num_write_lanes;
    assign write_offset = acc_write_lanes % NUM_BUS_LANES;
    wire [NUM_BUS_LANES_LOG2+1:0] end_offset = write_offset + num_write_lanes;
    



    //Select signals for output muxing
    for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : mux_logic
        wire [NUM_BUS_LANES_LOG2-1:0] lc_index = ((k + (NUM_BUS_LANES - write_offset)) % NUM_BUS_LANES);
        wire [PACKET_LENGTH_CBITS-1:0] gl_index = acc_write_lanes + lc_index;
        assign data_mux_index[k] = (gl_index < (REMOVE_OFFSET/2) ? k : (k + (seg_size/2)) % NUM_BUS_LANES); 
    end




    //Calculate write emable signals
    for(genvar k = 0; k < (NUM_BUS_LANES*2)-1; k = k + 1) begin : write_logic
        assign axis_lane_write[k] = ( (k >= write_offset) && (k < end_offset) );
    end

    
    
endmodule

`default_nettype wire