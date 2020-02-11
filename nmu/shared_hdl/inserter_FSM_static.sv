`timescale 1ns / 1ps
`default_nettype none


module inserter_FSM_static
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_BUS_LANES_LOG2 = NUM_BUS_BYTES_LOG2 - 1,

    //Inserted segment parameters
    parameter INSERT_SIZE_BYTES = 4,
    parameter SEG_MUX_INDEX_BITS = $clog2(INSERT_SIZE_BYTES/2),
    parameter INSERT_OFFSET = 12
)
(
    //Inputs from FIFO side
    input wire      input_is_regular_valid,
    input wire      input_is_last_valid,
    input wire      input_last_tkeep [NUM_BUS_LANES-1:0],
    
    //Inputs from output side
    input wire      output_is_ready,

    //Whether or not the last lane is read (useful in parrallel FSMs)
    input wire      read_last_lane,
    
    //Outputs driven to FIFO side
    output wire     axis_lane_rd_en [NUM_BUS_LANES-1:0],
    
    //Outputs driven to output side
    output wire                             drive_lane_from_input [NUM_BUS_LANES-1:0],
    output wire                             drive_lane_to_zero [NUM_BUS_LANES-1:0],
    output wire [NUM_BUS_LANES_LOG2-1:0]    data_mux_index [NUM_BUS_LANES-1:0],
    output wire [SEG_MUX_INDEX_BITS-1:0]    seg_mux_index [NUM_BUS_LANES-1:0],
    
    //Outputs to determine tkeep value of next beat
    output wire [NUM_BUS_LANES_LOG2-1:0]    tkeep_test_index,
    output wire                             tkeep_test_valid,
    output wire                             tkeep_test_from_next,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);
   
    //--------------------------------------------------------//
    //   Calauclate Param-based Output Values for FSM         //
    //--------------------------------------------------------// 
    
    //Parameters
    localparam MAC_PLUS_INSRT_BYTES = INSERT_OFFSET + INSERT_SIZE_BYTES;
    localparam MAC_PLUS_INSRT_BEATS = (MAC_PLUS_INSRT_BYTES / NUM_BUS_BYTES) + ((MAC_PLUS_INSRT_BYTES % NUM_BUS_BYTES == 0) ?  0 : 1);
    localparam NUM_STATES = MAC_PLUS_INSRT_BEATS + 1;
    
    //Values of outputs for each state
    wire                             axis_lane_rd_en_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire                             drive_lane_from_input_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire                             drive_lane_to_zero_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire [NUM_BUS_LANES_LOG2-1:0]    data_mux_index_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire [SEG_MUX_INDEX_BITS-1:0]    seg_mux_index_state [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire [NUM_BUS_LANES_LOG2-1:0]    tkeep_test_index_state [NUM_STATES-1:0];
    wire                             tkeep_test_valid_state [NUM_STATES-1:0];
    wire                             tkeep_test_from_next_state [NUM_STATES-1:0];
    
    //Values of outputs for each state on last beat
    wire                             axis_lane_rd_en_last [NUM_STATES-1:0][NUM_BUS_LANES-1:0];
    wire                             drive_lane_to_zero_last [NUM_STATES-1:0][NUM_BUS_LANES-1:0];    
    
    //Calculate the expected output values for all states
    generate
    for(genvar j = 0; j < NUM_STATES; j = j + 1) begin : states
    
        //Parameters to calculate start offset for read FIFO
        localparam TOTAL_LANES_PREVIOUSLY = j * NUM_BUS_LANES;
        localparam INSRT_LANES_PREVIOUSLY = 
            (TOTAL_LANES_PREVIOUSLY <= (INSERT_OFFSET/2) ? 
                0 :
                (TOTAL_LANES_PREVIOUSLY <= (MAC_PLUS_INSRT_BYTES/2) ?
                    TOTAL_LANES_PREVIOUSLY - (INSERT_OFFSET/2) :
                    (INSERT_SIZE_BYTES/2)
            ));
        localparam BUS_LANES_PREVIOUSLY = TOTAL_LANES_PREVIOUSLY - INSRT_LANES_PREVIOUSLY;
        localparam START_OFFSET = BUS_LANES_PREVIOUSLY % NUM_BUS_LANES;
                
        //Parameters to calculate number of lanes to read this beat
        localparam TOTAL_LANES_ACCUM = (j+1) * NUM_BUS_LANES;
        localparam INSRT_LANES_ACCUM = 
            (TOTAL_LANES_ACCUM <= (INSERT_OFFSET/2) ? 
                0 :
                (TOTAL_LANES_ACCUM <= (MAC_PLUS_INSRT_BYTES/2) ?
                    TOTAL_LANES_ACCUM - (INSERT_OFFSET/2) :
                    (INSERT_SIZE_BYTES/2)
            ));
        localparam INSRT_LANES_THIS_BEAT = INSRT_LANES_ACCUM - INSRT_LANES_PREVIOUSLY;
        localparam NUM_READ_LANES = NUM_BUS_LANES - INSRT_LANES_THIS_BEAT;
        
        //tkeep of lane immediately before segment inserted (track premature ending before inserted)
        localparam INSRT_STARTS_MID_BEAT = (TOTAL_LANES_ACCUM > (INSERT_OFFSET/2) && TOTAL_LANES_ACCUM < (INSERT_OFFSET/2 + NUM_BUS_LANES));
        localparam INDEX_BEFORE_INSRT = (INSERT_OFFSET != 0 ? (INSERT_OFFSET/2 - 1) % NUM_BUS_LANES : NUM_BUS_LANES-1);
        wire input_last_tkeep_before_insrt = (INSRT_STARTS_MID_BEAT ? input_last_tkeep[INDEX_BEFORE_INSRT] : 1'b1);
        
        
        //Signals for FIFO Read Enables
        for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : lanes1
            localparam OFFSET_INDEX = (k + START_OFFSET) % NUM_BUS_LANES;
            
            //For regular reads
            if(k < NUM_READ_LANES)  assign axis_lane_rd_en_state[j][OFFSET_INDEX] = 1'b1;
            else                    assign axis_lane_rd_en_state[j][OFFSET_INDEX] = 1'b0;
        
            //For reads with tlast
            if(OFFSET_INDEX >= START_OFFSET)    assign axis_lane_rd_en_last[j][OFFSET_INDEX] = (k < NUM_READ_LANES) || !input_last_tkeep_before_insrt;
            else                                assign axis_lane_rd_en_last[j][OFFSET_INDEX] = 1'b0;
        end
        
        
        //Select signals for output Muxing
        for(genvar k = 0; k < NUM_BUS_LANES; k = k + 1) begin : lanes2
        
            localparam INDEX = (j*NUM_BUS_LANES + k);
        
            //Check the index value range
            if(INDEX < (INSERT_OFFSET/2)) begin
                //Non last values
                assign drive_lane_from_input_state[j][k] = 1'b1;
                assign drive_lane_to_zero_state[j][k] = 1'b0;
                assign data_mux_index_state[j][k] = k;
                
                //Last values
                assign drive_lane_to_zero_last[j][k] = 1'b0;
            end
            else if(INDEX < (MAC_PLUS_INSRT_BYTES/2)) begin
                //Non last values
                assign drive_lane_from_input_state[j][k] = 1'b0;
                assign drive_lane_to_zero_state[j][k] = 1'b0;
                assign data_mux_index_state[j][k] = k;
                
                //Last values
                assign drive_lane_to_zero_last[j][k] = ~input_last_tkeep_before_insrt;
            end
            else begin
                //Non last values
                assign drive_lane_from_input_state[j][k] = 1'b1;
                assign drive_lane_to_zero_state[j][k] = 1'b0;
                assign data_mux_index_state[j][k] = (INDEX - (INSERT_SIZE_BYTES/2)) % NUM_BUS_LANES;
                
                //Last values
                assign drive_lane_to_zero_last[j][k] = (k >= (NUM_BUS_LANES - START_OFFSET) ? 1'b1 : 1'b0);
            end

            assign seg_mux_index_state[j][k] = (INDEX - (INSERT_OFFSET/2));
        end
        
        
        //Signals for checking tkeep of next beat
        if(j != NUM_STATES - 1) begin
            //Not last values
            assign tkeep_test_index_state[j] = data_mux_index_state[j+1][0];
            assign tkeep_test_valid_state[j] = drive_lane_from_input_state[j+1][0];
        end
        else begin
            //Not last values
            assign tkeep_test_index_state[j] = data_mux_index_state[j][0];
            assign tkeep_test_valid_state[j] = drive_lane_from_input_state[j][0];
        end
        
        assign tkeep_test_from_next_state[j] = (NUM_READ_LANES == NUM_BUS_LANES);        
        
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
    wire input_is_valid = input_is_regular_valid || input_is_last_valid;
    wire transition = input_is_valid && output_is_ready;
    wire transition_last = input_is_last_valid && read_last_lane && output_is_ready;
    
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
    
    //Output value logic (Mealy outputs for tlast, tready, and tvalid input signals)
    generate
    for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : lanes3
        assign axis_lane_rd_en[j] =
            (~transition ?
                1'b0 :
                (input_is_last_valid ?
                    axis_lane_rd_en_last[current_state][j] :
                    axis_lane_rd_en_state[current_state][j]
            ));
    end         
    endgenerate
    
    //Output value logic (Mealy outputs for tlast input signal)
    assign drive_lane_to_zero =
        (input_is_last_valid ?
            drive_lane_to_zero_last[current_state] :
            drive_lane_to_zero_state[current_state]
        );
                
    //Output value logic (Moore outputs)
    assign drive_lane_from_input = drive_lane_from_input_state[current_state];
    assign data_mux_index = data_mux_index_state[current_state];
    assign seg_mux_index = seg_mux_index_state[current_state];
    assign tkeep_test_index = tkeep_test_index_state[current_state];
    assign tkeep_test_valid = tkeep_test_valid_state[current_state];
    assign tkeep_test_from_next = tkeep_test_from_next_state[current_state];



endmodule

`default_nettype wire