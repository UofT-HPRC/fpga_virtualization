`timescale 1ns / 1ps
`default_nettype none


module length_checksum_calc
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TUSER_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_BUS_LANES_LOG2 = NUM_BUS_BYTES_LOG2 - 1,
    localparam NUM_BUS_BYTES_CBITS = $clog2(NUM_BUS_BYTES+1),

    //Features to Implement
    parameter bit COUNT_LENGTH = 1,
    parameter bit CALC_CHECKSUM = 1
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [AXIS_TUSER_WIDTH-1:0]   axis_in_tuser,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [AXIS_TUSER_WIDTH-1:0]  axis_out_tuser,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals passed to next stage (encap)
    output wire [15:0]                  length_count,
    output wire [15:0]                  accumalted_checksum,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Parameters and stream passthrough                    //
    //--------------------------------------------------------//

    //STream passthrough
    assign axis_out_tdata = axis_in_tdata;
    assign axis_out_tuser = axis_in_tuser;
    assign axis_out_tkeep = axis_in_tkeep;
    assign axis_out_tlast = axis_in_tlast;
    assign axis_out_tvalid = axis_in_tvalid;
    assign axis_in_tready = axis_out_tready;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid && axis_out_tready;
    wire axis_last_beat = axis_valid_beat && axis_in_tlast;


    //--------------------------------------------------------//
    //   Calculation of length                                //
    //--------------------------------------------------------//

    generate if(COUNT_LENGTH) begin : gen_counter

        //Length counter
        reg [15:0] current_length;
        always@(posedge aclk) begin
            if(~aresetn || axis_last_beat) current_length <= 0;
            else if(axis_valid_beat) current_length <= length_count;
        end

        reg [NUM_BUS_BYTES_CBITS-1:0] current_beat_length;
        always@(*) begin
            current_beat_length = NUM_BUS_BYTES;
            if(axis_in_tlast) begin
                for(integer i = NUM_BUS_BYTES-1; i >= 0; i = i - 1) begin
                    if(axis_in_tkeep[i] == 1'b0) current_beat_length = i;
                end
            end
        end

        assign length_count = current_length + current_beat_length;

    end else begin

        assign length_count = 0;

    end endgenerate



    //--------------------------------------------------------//
    //   Calculation of checksum                              //
    //--------------------------------------------------------//

    //Checksum calculation
    generate if(CALC_CHECKSUM) begin : gen_checksum

        //Tree adder for checksum calculation
        wire [15:0] intermediate_add [NUM_BUS_BYTES_LOG2-1:0][NUM_BUS_LANES-1:0];

        for(genvar j = 0; j <= NUM_BUS_LANES_LOG2; j = j + 1) begin : adder_tree1

            localparam INDEX2 = 2 ** (NUM_BUS_LANES_LOG2 - j);

            for(genvar k = 0; k < INDEX2; k = k + 1) begin : adder_tree2
                if(j == 0) begin

                    assign intermediate_add[j][k][15:8] = (axis_in_tkeep[k*2]  ? axis_in_tdata[(k*16)+:8] : 0);

                    assign intermediate_add[j][k][7:0] = (axis_in_tkeep[(k*2)+1]  ? axis_in_tdata[((k*16)+8)+:8] : 0);

                end else begin

                    wire [16:0] intermediate_add_im = intermediate_add[j-1][k*2] + intermediate_add[j-1][(k*2)+1];
                    assign intermediate_add[j][k] = intermediate_add_im[15:0] + intermediate_add_im[16];

                end
            end
        end

        //Register accumulated checksum
        reg [15:0] current_check;
        always@(posedge aclk) begin
            if(~aresetn || axis_last_beat) current_check <= 0;
            else if(axis_valid_beat) current_check <= accumalted_checksum;
        end

        wire[16:0] final_add_im = intermediate_add[NUM_BUS_BYTES_LOG2-1][0] + current_check;
        assign accumalted_checksum = final_add_im[15:0] + final_add_im[16];

    end else begin

        assign accumalted_checksum = 0;

    end endgenerate



endmodule

`default_nettype wire