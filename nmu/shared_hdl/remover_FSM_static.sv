`timescale 1ns / 1ps
`default_nettype none


module remover_FSM_static
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_BUS_LANES_LOG2 = NUM_BUS_BYTES_LOG2 - 1,

    //Removed segment parameters
    parameter REMOVE_SIZE_BYTES = 4,
    parameter REMOVE_OFFSET = 12
)
(
    //Inputs from FIFO side
    input wire      input_is_valid,
    input wire      input_is_last,
    
    //Inputs from output side
    input wire      output_is_ready,

    //Outputs driven to output side
    output wire                             axis_lane_write [(NUM_BUS_LANES*2)-2:0],
    output wire [NUM_BUS_LANES_LOG2-1:0]    data_mux_index [NUM_BUS_LANES-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);
   
    //--------------------------------------------------------//
    //   Calauclate Param-based Output Values for FSM         //
    //--------------------------------------------------------// 

    //Parameters
    localparam MAC_PLUS_RMV_BYTES = REMOVE_OFFSET + REMOVE_SIZE_BYTES;
    localparam MAC_PLUS_RMV_BEATS = (MAC_PLUS_RMV_BYTES / NUM_BUS_BYTES) + ((MAC_PLUS_RMV_BYTES % NUM_BUS_BYTES == 0) ?  0 : 1);
    localparam NUM_STATES = MAC_PLUS_RMV_BEATS + 1;

    //Values of outputs for each state
    wire                          axis_lane_write_state [NUM_STATES-1:0][(NUM_BUS_LANES*2)-2:0];
    wire [NUM_BUS_LANES_LOG2-1:0] data_mux_index_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];


    //Calculate the expected output values for all states
    generate
    for(genvar j = 0; j < NUM_STATES; j = j + 1) begin : states
    
        //Parameters to calculate start offset for read FIFO
        localparam TOTAL_LANES_PREVIOUSLY = j * NUM_BUS_LANES;
        localparam RMV_LANES_PREVIOUSLY = 
            (TOTAL_LANES_PREVIOUSLY <= (REMOVE_OFFSET/2) ? 
                0 :
                (TOTAL_LANES_PREVIOUSLY <= (MAC_PLUS_RMV_BYTES/2) ?
                    TOTAL_LANES_PREVIOUSLY - (REMOVE_OFFSET/2) :
                    (REMOVE_SIZE_BYTES/2)
            ));
        localparam BUS_LANES_PREVIOUSLY = TOTAL_LANES_PREVIOUSLY - RMV_LANES_PREVIOUSLY;
        localparam START_OFFSET = BUS_LANES_PREVIOUSLY % NUM_BUS_LANES;
                
        //Parameters to calculate number of lanes to read this beat
        localparam TOTAL_LANES_ACCUM = (j+1) * NUM_BUS_LANES;
        localparam RMV_LANES_ACCUM = 
            (TOTAL_LANES_ACCUM <= (REMOVE_OFFSET/2) ? 
                0 :
                (TOTAL_LANES_ACCUM <= (MAC_PLUS_RMV_BYTES/2) ?
                    TOTAL_LANES_ACCUM - (REMOVE_OFFSET/2) :
                    (REMOVE_SIZE_BYTES/2)
            ));
        localparam RMV_LANES_THIS_BEAT = RMV_LANES_ACCUM - RMV_LANES_PREVIOUSLY;
        localparam NUM_WRITE_LANES = NUM_BUS_LANES - RMV_LANES_THIS_BEAT;

        localparam END_OFFSET = START_OFFSET + NUM_WRITE_LANES;
        


        //Select signals for output muxing
        for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : mux_logic
            localparam LC_INDEX = ((k + (NUM_BUS_LANES - START_OFFSET)) % NUM_BUS_LANES);
            localparam GL_INDEX = BUS_LANES_PREVIOUSLY + LC_INDEX;
            assign data_mux_index_state[j][k] = (GL_INDEX < (REMOVE_OFFSET/2) ? k : (k + (REMOVE_SIZE_BYTES/2)) % NUM_BUS_LANES);
        end



        //Calculate write emable signals
        for(genvar k = 0; k < (NUM_BUS_LANES*2)-1; k = k + 1) begin : write_logic
            assign axis_lane_write_state[j][k] = ( (k >= START_OFFSET) && (k < END_OFFSET) );
        end
              
    end
    endgenerate



    //--------------------------------------------------------//
    //   FSM Implementation                                   //
    //--------------------------------------------------------// 
    
    //Current state register
    localparam NUM_STATES_LOG2 = $clog2(NUM_STATES);
    reg [NUM_STATES_LOG2-1:0]   current_state;
    reg [NUM_STATES_LOG2-1:0]   next_state;
    
    //State transitions
    always@(posedge aclk) begin
        if(~aresetn) current_state <= 0;
        else         current_state <= next_state;
    end
    
    //Next state logic
    wire transition = input_is_valid && output_is_ready; 
    wire transition_last = input_is_last && input_is_valid && output_is_ready;
    
    always@(*) begin
        if(~transition) 
            next_state = current_state;
        else if(transition_last)
            next_state = 0;
        else if(current_state < (NUM_STATES - 1))
            next_state = current_state + 1;
        else
            next_state = (NUM_STATES - 1); //Last state has steady state values for outputs
    end
    
    //Output value logic (Moore outputs)
    assign axis_lane_write = axis_lane_write_state[current_state];
    assign data_mux_index = data_mux_index_state[current_state];

    
    
endmodule

`default_nettype wire