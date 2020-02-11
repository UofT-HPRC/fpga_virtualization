`timescale 1ns / 1ps
`default_nettype none




//Tag field constants
`define ET_OFFSET 12
`define ET_SIZE 16
`define ET_LANES (`ET_SIZE/16)
`define TAG_OFFSET 14




//The Tag Parser
module cus_tag_parser
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    parameter MAX_TAG_SIZE_BITS = 48, //bits

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_TAG_BYTES = (MAX_TAG_SIZE_BITS/8),
    localparam MAX_TAG_LANES = (MAX_TAG_SIZE_BITS/16),

    localparam LAST_BYTE = `TAG_OFFSET + MAX_TAG_BYTES - 1,
    localparam MAX_OFFSET_INTERNAL = LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2(MAX_OFFSET_INTERNAL+1),

    //Features to Implement
    parameter bit DETAG_ALL_ETYPE_MATCH = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals passed to next stage (de-tagger)
    output wire [NUM_AXIS_ID-1:0]       route_mask,
    output wire                         cus_tag_present,
    output wire                         parsing_done,

    //Configuration register inputs
    input wire [`ET_SIZE-1:0]           expected_etype,

    //CAM contents
    input wire                          has_cus_tag [NUM_AXIS_ID-1:0],
    input wire [MAX_TAG_SIZE_BITS-1:0]  custom_tags [NUM_AXIS_ID-1:0],
    input wire [MAX_TAG_SIZE_BITS-1:0]  custom_tag_masks [NUM_AXIS_ID-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Signals Used Throughout                              //
    //--------------------------------------------------------//

    //Stream passthrough
    assign axis_out_tdata = axis_in_tdata;
    assign axis_out_tkeep = axis_in_tkeep;
    assign axis_out_tlast = axis_in_tlast;
    assign axis_out_tvalid = axis_in_tvalid;
    assign axis_in_tready = axis_out_tready;
    
    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+15:j*16];
        end
    endgenerate

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/



    //--------------------------------------------------------//
    //   Current Position Count                               //
    //--------------------------------------------------------//
    
    //Accouting of current offset within packet
    reg [PACKET_LENGTH_CBITS-1:0]   current_position;
    
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) current_position <= 0;
        else if(axis_valid_beat) current_position <= current_position + NUM_BUS_BYTES;
    end



    //--------------------------------------------------------//
    //   Ethertype Parsing                                    //
    //--------------------------------------------------------//

    //Address where the byte-pair lane is expected    
    wire [UPPER_PORTION-1:0]                et_lane_offset = `ET_OFFSET;
    wire [LOWER_PORTION-1:0]                et_lane_lower = et_lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  et_lane_upper = et_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    //The specific byte-pair lane in the current stream flit
    wire [15:0]  etype_lane = axis_in_tdata_lanes[et_lane_lower[LOWER_PORTION-1:1]];
    wire         etype_lane_valid = (et_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;

    
    
    //--------------------------------------------------------//
    //   Custom Tag Parsing                                   //
    //--------------------------------------------------------//

    //custom tag lanes
    wire [15:0] custom_tag_lanes [MAX_TAG_LANES-1:0];
    wire        custom_tag_lane_valid [MAX_TAG_LANES-1:0];

    //Extract Dest address lanes
    generate
        for(genvar j = 0; j < MAX_TAG_LANES; j = j + 1) begin : tag_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                     lane_offset = `TAG_OFFSET + (j*2);
            wire [LOWER_PORTION-1:0]                     lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]       lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign custom_tag_lanes[j] = lane_data;
            assign custom_tag_lane_valid[j] = lane_present;
            
        end
    endgenerate



    //--------------------------------------------------------//
    //   Etype Check                                          //
    //--------------------------------------------------------//

    //Registers to hold stored values of outputs
    reg reg_etype_match;
    wire cur_etype_match = (etype_lane == expected_etype);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_etype_match <= 0;
        else if(etype_lane_valid) reg_etype_match <= cur_etype_match;
    end

    //Assign output values
    wire etype_match = (etype_lane_valid ? cur_etype_match : reg_etype_match);



    //--------------------------------------------------------//
    //   Tag Routing CAM                                      //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Loop over CAM array
    generate
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: cam_array

            //cam signals
            reg reg_out_route_mask;
            wire [MAX_TAG_LANES-1:0] cur_out_route_mask;
            wire [MAX_TAG_LANES-1:0] eff_out_route_mask;

            //Loop over lanes
            for(genvar j = 0; j < MAX_TAG_LANES; j = j + 1) begin : tag_cam 

                //Check current entry match
                wire tag_match = (  (custom_tag_lanes[j] & custom_tag_masks[k][(j*16)+:16]) ==
                                    (custom_tags[k][(j*16)+:16] & custom_tag_masks[k][(j*16)+:16])
                                  );
                assign cur_out_route_mask[j] = tag_match;
                assign eff_out_route_mask[j] = !custom_tag_lane_valid[j] || cur_out_route_mask[j];

            end

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
                else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
            end

            //Assign output values
            assign out_route_mask[k] =  (&eff_out_route_mask) & reg_out_route_mask;

        end
    endgenerate


    //Assign Output Value
    wire [NUM_AXIS_ID-1:0] has_cus_tag_packed = {>>{has_cus_tag}};
    assign route_mask = (etype_match ? out_route_mask : ~(has_cus_tag_packed));

    //Determine whether a custom tag exisits
    assign cus_tag_present = ( DETAG_ALL_ETYPE_MATCH ? etype_match : ((|route_mask) && etype_match) );



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (custom_tag_lane_valid[MAX_TAG_LANES-1]) reg_parsing_done <= 1;
    end
    
    //Assign output value
    assign parsing_done = (custom_tag_lane_valid[MAX_TAG_LANES-1] ? 1 : reg_parsing_done);



endmodule

`default_nettype wire