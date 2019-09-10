`timescale 1ns / 1ps
`default_nettype none


//The memory decoupler
module mem_util_monitor
#(
    //Additional Params to determine particular capabilities
    parameter UTIL_COUNT_WIDTH = 10
)
(
    //Write Data Channel
    input wire                              w_valid,
    input wire                              w_ready,
    //Read Data Response Channel
    input wire                              r_valid,
    input wire                              r_ready,

    //Output monitoring result
    output wire [UTIL_COUNT_WIDTH:0]        utilization,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Monitor data channels for frequency of response      //
    //--------------------------------------------------------//

    //Valid data beats
    wire valid_write_data = w_valid && w_ready;
    wire valid_read_data = r_valid && r_ready;
    
    //Utilization counter
    reg [(2*UTIL_COUNT_WIDTH):0] util_counter;

    always@(posedge aclk) begin
        if(~aresetn) util_counter <= { 1'b1,{(2*UTIL_COUNT_WIDTH){1'b0}} };
        else begin
            util_counter <= util_counter
                + (valid_write_data << UTIL_COUNT_WIDTH)
                + (valid_read_data << UTIL_COUNT_WIDTH)
                - (util_counter >> UTIL_COUNT_WIDTH);
        end
    end

    //Assign output
    assign utilization = util_counter[UTIL_COUNT_WIDTH+:UTIL_COUNT_WIDTH+1];



endmodule

`default_nettype wire
