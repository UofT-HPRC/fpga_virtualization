`timescale 1ns / 1ps
`default_nettype none




//Constants
`define PROT_OFFSET 23

`define IP4_OFFSET 26
`define IP4_SIZE 64
`define IP4_BYTES (`IP4_SIZE/8)

`define UDP_OFFSET 34
`define UDP_SIZE 64
`define UDP_BYTES (`UDP_SIZE/8)

`define LEN_OFFSET 38

`define LAST_BYTE 41





//Calculate pseduo header checksum
module pseudo_udp_header_check
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TUSER_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_OFFSET_INTERNAL = 4 + `LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2(MAX_OFFSET_INTERNAL+1) 
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire [AXIS_TUSER_WIDTH-1:0]   axis_in_tuser,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire [AXIS_TUSER_WIDTH-1:0]  axis_out_tuser,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals from previous stages
    input wire                          is_tagged,

    //Checksum calculation output
    output wire [15:0]                  pseudo_udp_checksum,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Signals Used Throughout                              //
    //--------------------------------------------------------//

    //Modified tkeep values used to indicate bytes to include in clac
    wire [NUM_BUS_BYTES-1:0] prot_tkeep;
    wire [NUM_BUS_BYTES-1:0] ip4_tkeep;
    wire [NUM_BUS_BYTES-1:0] udp_tkeep;
    wire [NUM_BUS_BYTES-1:0] axis_pseudo_tkeep = prot_tkeep | ip4_tkeep | udp_tkeep;

    //Modified output data to use for calculation
    wire [AXIS_BUS_WIDTH-1:0] axis_pseudo_tdata;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid && axis_out_tready;
    wire axis_last_beat = axis_valid_beat && axis_in_tlast;

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/



    //--------------------------------------------------------//
    //   Current Position Count                               //
    //--------------------------------------------------------//
    
    //Accouting of current offset within packet
    reg [PACKET_LENGTH_CBITS-1:0] current_position;
    
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) current_position <= 0;
        else if(axis_valid_beat) current_position <= current_position + NUM_BUS_BYTES;
    end
   


    //--------------------------------------------------------//
    //   Protocol tkeep values                                //
    //--------------------------------------------------------//

    //Tkeep values depending on tagged status
    wire [NUM_BUS_BYTES-1:0] prot_tkeep_tag;
    wire [NUM_BUS_BYTES-1:0] prot_tkeep_notag;
    assign prot_tkeep = (is_tagged ? prot_tkeep_tag : prot_tkeep_notag);

    //No tag calculation
    localparam PROT_OFFSET_NT = `PROT_OFFSET;
    localparam PROT_LOWER_NT = PROT_OFFSET_NT[LOWER_PORTION-1:0];
    localparam PROT_UPPER_NT = PROT_OFFSET_NT[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : prot_tkeep_calc
            assign prot_tkeep_notag[j] = 
                (j == PROT_LOWER_NT) && 
                (current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION] == PROT_UPPER_NT);
        end 
    endgenerate

    //With Tag calculation
    localparam PROT_OFFSET_TAG = `PROT_OFFSET + 4;
    localparam PROT_LOWER_TAG = PROT_OFFSET_TAG[LOWER_PORTION-1:0];
    localparam PROT_UPPER_TAG = PROT_OFFSET_TAG[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : prot_tkeep_calc2
            assign prot_tkeep_tag[j] = 
                (j == PROT_LOWER_TAG) && 
                (current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION] == PROT_UPPER_TAG);
        end 
    endgenerate

    //Old way
    /*
    wire [UPPER_PORTION-1:0]                lane_offset = `PROT_OFFSET + (4*is_tagged);
    wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin :prot_tkeep_calc
            assign prot_tkeep_notag[j] = 
                (j == lane_lower) && 
                (current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION] == lane_upper);
        end 
    endgenerate
    */



    //--------------------------------------------------------//
    //   IP4 Pseudo Header tkeep values                       //
    //--------------------------------------------------------//

    //Tkeep values depending on tagged status
    wire [NUM_BUS_BYTES-1:0] ip4_tkeep_tag;
    wire [NUM_BUS_BYTES-1:0] ip4_tkeep_notag;
    assign ip4_tkeep = (is_tagged ? ip4_tkeep_tag : ip4_tkeep_notag);

    //No tag calculation
    localparam IP4_BEGIN_NT = `IP4_OFFSET;
    localparam IP4_BEGIN_NT_LOWER = IP4_BEGIN_NT[LOWER_PORTION-1:0];
    localparam IP4_BEGIN_NT_UPPER = IP4_BEGIN_NT[UPPER_PORTION-1:LOWER_PORTION];

    localparam IP4_END_NT = `IP4_OFFSET + `IP4_BYTES - 1;
    localparam IP4_END_NT_LOWER = IP4_END_NT[LOWER_PORTION-1:0];
    localparam IP4_END_NT_UPPER = IP4_END_NT[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : ip4_tkeep_calc

            wire [PACKET_LENGTH_CBITS-LOWER_PORTION-1:0] cur_pos_up =
                current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION];

            assign ip4_tkeep_notag[j] = 
                ((cur_pos_up == IP4_BEGIN_NT_UPPER && cur_pos_up == IP4_END_NT_UPPER) ?
                    (j >= IP4_BEGIN_NT_LOWER) && (j <= IP4_END_NT_LOWER) :
                (cur_pos_up == IP4_BEGIN_NT_UPPER ? 
                    (j >= IP4_BEGIN_NT_LOWER) :
                (cur_pos_up == IP4_END_NT_UPPER ? 
                    (j <= IP4_END_NT_LOWER) :
                ((cur_pos_up >= (IP4_BEGIN_NT_UPPER+1) && cur_pos_up < IP4_END_NT_UPPER) ? 
                    1'b1 : 1'b0
                )))); //TODO - check
        end
    endgenerate

    //With Tag calculation
    localparam IP4_BEGIN_TAG = `IP4_OFFSET + 4;
    localparam IP4_BEGIN_TAG_LOWER = IP4_BEGIN_TAG[LOWER_PORTION-1:0];
    localparam IP4_BEGIN_TAG_UPPER = IP4_BEGIN_NT[UPPER_PORTION-1:LOWER_PORTION];

    localparam IP4_END_TAG = `IP4_OFFSET + `IP4_BYTES + 3;
    localparam IP4_END_TAG_LOWER = IP4_END_TAG[LOWER_PORTION-1:0];
    localparam IP4_END_TAG_UPPER = IP4_END_TAG[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : ip4_tkeep_calc2

            wire [PACKET_LENGTH_CBITS-LOWER_PORTION-1:0] cur_pos_up =
                current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION];

            assign ip4_tkeep_tag[j] = 
                ((cur_pos_up == IP4_BEGIN_TAG_UPPER && cur_pos_up == IP4_END_TAG_UPPER) ?
                    (j >= IP4_BEGIN_TAG_LOWER) && (j <= IP4_END_TAG_LOWER) :
                (cur_pos_up == IP4_BEGIN_TAG_UPPER ? 
                    (j >= IP4_BEGIN_TAG_LOWER) :
                (cur_pos_up == IP4_END_TAG_UPPER ? 
                    (j <= IP4_END_TAG_LOWER) :
                ((cur_pos_up >= (IP4_BEGIN_TAG_UPPER+1) && cur_pos_up < IP4_END_TAG_UPPER) ? 
                    1'b1 : 1'b0
                ))));
        end
    endgenerate



    //--------------------------------------------------------//
    //   UDP Header tkeep values                              //
    //--------------------------------------------------------//

    //Note - UDP header's inclusion in checksum only correct if IPv4 and no IP Options included

    //Tkeep values depending on tagged status
    wire [NUM_BUS_BYTES-1:0] udp_tkeep_tag;
    wire [NUM_BUS_BYTES-1:0] udp_tkeep_notag;
    assign udp_tkeep = (is_tagged ? udp_tkeep_tag : udp_tkeep_notag);

    //No tag calculation
    localparam UDP_BEGIN_NT = `UDP_OFFSET;
    localparam UDP_BEGIN_NT_LOWER = UDP_BEGIN_NT[LOWER_PORTION-1:0];
    localparam UDP_BEGIN_NT_UPPER = UDP_BEGIN_NT[UPPER_PORTION-1:LOWER_PORTION];

    localparam UDP_END_NT = `UDP_OFFSET + `UDP_BYTES - 1;
    localparam UDP_END_NT_LOWER = UDP_END_NT[LOWER_PORTION-1:0];
    localparam UDP_END_NT_UPPER = UDP_END_NT[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : udp_tkeep_calc

            wire [PACKET_LENGTH_CBITS-LOWER_PORTION-1:0] cur_pos_up =
                current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION];

            assign udp_tkeep_notag[j] = 
                ((cur_pos_up == UDP_BEGIN_NT_UPPER && cur_pos_up == UDP_END_NT_UPPER) ?
                    (j >= UDP_BEGIN_NT_LOWER) && (j <= UDP_END_NT_LOWER) :
                (cur_pos_up == UDP_BEGIN_NT_UPPER ? 
                    (j >= UDP_BEGIN_NT_LOWER) :
                (cur_pos_up == UDP_END_NT_UPPER ? 
                    (j <= UDP_END_NT_LOWER) :
                ((cur_pos_up >= (UDP_BEGIN_NT_UPPER+1) && cur_pos_up < UDP_END_NT_UPPER) ? 
                    1'b1 : 1'b0
                ))));
        end
    endgenerate

    //With Tag calculation
    localparam UDP_BEGIN_TAG = `UDP_OFFSET + 4;
    localparam UDP_BEGIN_TAG_LOWER = UDP_BEGIN_TAG[LOWER_PORTION-1:0];
    localparam UDP_BEGIN_TAG_UPPER = UDP_BEGIN_NT[UPPER_PORTION-1:LOWER_PORTION];

    localparam UDP_END_TAG = `UDP_OFFSET + `UDP_BYTES + 3;
    localparam UDP_END_TAG_LOWER = UDP_END_TAG[LOWER_PORTION-1:0];
    localparam UDP_END_TAG_UPPER = UDP_END_TAG[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_BYTES; j = j + 1) begin : udp_tkeep_calc2

            wire [PACKET_LENGTH_CBITS-LOWER_PORTION-1:0] cur_pos_up =
                current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION];

            assign udp_tkeep_tag[j] = 
                ((cur_pos_up == UDP_BEGIN_TAG_UPPER && cur_pos_up == UDP_END_TAG_UPPER) ?
                    (j >= UDP_BEGIN_TAG_LOWER) && (j <= UDP_END_TAG_LOWER) :
                (cur_pos_up == UDP_BEGIN_TAG_UPPER ? 
                    (j >= UDP_BEGIN_TAG_LOWER) :
                (cur_pos_up == UDP_END_TAG_UPPER ? 
                    (j <= UDP_END_TAG_LOWER) :
                ((cur_pos_up >= (UDP_BEGIN_TAG_UPPER+1) && cur_pos_up < UDP_END_TAG_UPPER) ? 
                    1'b1 : 1'b0
                ))));
        end
    endgenerate



    //--------------------------------------------------------//
    //   Modify tdata so length field counted twice           //
    //--------------------------------------------------------//

    //Tkeep values depending on tagged status
    wire [NUM_BUS_LANES-1:0] is_length_tag;
    wire [NUM_BUS_LANES-1:0] is_length_notag;

    //No tag calculation
    localparam LEN_OFFSET_NT = `LEN_OFFSET;
    localparam LEN_LOWER_NT = LEN_OFFSET_NT[LOWER_PORTION-1:0];
    localparam LEN_UPPER_NT = LEN_OFFSET_NT[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : is_len
            assign is_length_notag[j] = 
                (j == LEN_LOWER_NT[LOWER_PORTION-1:1]) && 
                (current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION] == LEN_UPPER_NT);
        end 
    endgenerate

    //With Tag calculation
    localparam LEN_OFFSET_TAG = `LEN_OFFSET + 4;
    localparam LEN_LOWER_TAG = LEN_OFFSET_TAG[LOWER_PORTION-1:0];
    localparam LEN_UPPER_TAG = LEN_OFFSET_TAG[UPPER_PORTION-1:LOWER_PORTION];

    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : is_len2
            assign is_length_tag[j] = 
                (j == LEN_LOWER_TAG[LOWER_PORTION-1:1]) && 
                (current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION] == LEN_UPPER_TAG);
        end 
    endgenerate

    //Assign tdata based on current position
    //Note - below only works for UDP size < 32k. but our system doesn't support IPFrag anyway
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : pseduo_data_asg
            wire [15:0] cur_lane = axis_in_tdata[(j*16)+:16];
            wire [15:0] cur_lane_le = {cur_lane[7:0],cur_lane[15:8]};
            wire [15:0] double = cur_lane_le * 2;
            wire [15:0] double_be = {double[7:0],double[15:8]};

            assign axis_pseudo_tdata[(j*16)+:16] = 
                ( ((is_tagged && is_length_tag[j]) || (!is_tagged && is_length_notag[j])) ? double_be : cur_lane );
        end 
    endgenerate



    //--------------------------------------------------------//
    //   Calculation of checksum                              //
    //--------------------------------------------------------//

    //Checksum calculation
    length_checksum_calc
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_TUSER_WIDTH   (AXIS_TUSER_WIDTH + NUM_BUS_BYTES + AXIS_BUS_WIDTH),
        .COUNT_LENGTH       (0),
        .CALC_CHECKSUM      (1)
    )
    len_check
    (
        .axis_in_tdata          (axis_pseudo_tdata),
        .axis_in_tuser          ({axis_in_tuser,axis_in_tkeep,axis_in_tdata}),
        .axis_in_tkeep          (axis_pseudo_tkeep),
        .axis_in_tlast          (axis_in_tlast),
        .axis_in_tvalid         (axis_in_tvalid),
        .axis_in_tready         (axis_in_tready),

        .axis_out_tdata         (),
        .axis_out_tuser         ({axis_out_tuser,axis_out_tkeep,axis_out_tdata}),
        .axis_out_tkeep         (),
        .axis_out_tlast         (axis_out_tlast),
        .axis_out_tvalid        (axis_out_tvalid),
        .axis_out_tready        (axis_out_tready),

        .length_count           (),
        .accumalted_checksum    (pseudo_udp_checksum),        
        
        .aclk       (aclk),
        .aresetn    (aresetn)
    );



endmodule

`default_nettype wire