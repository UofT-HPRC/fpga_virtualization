`timescale 1ns / 1ps
`default_nettype none




//VSID field constants
`define L4_OFFSET 34
`define EXTRA_OFFSET_VX 8

`define VSID_OFFSET 4
`define VSID_SIZE 32
`define VSID_MASK {32'h00FFFFFF} //Actually 24 bit value
`define VSID_LANES (`VSID_SIZE/16)

`define DA_MAC_OFFSET 8
`define DA_MAC_SIZE 48
`define DA_MAC_BYTES (`DA_MAC_SIZE/8)
`define DA_MAC_LANES (`DA_MAC_SIZE/16)

`define LAST_BYTE `L4_OFFSET + `EXTRA_OFFSET_VX + `DA_MAC_OFFSET + `DA_MAC_BYTES - 1




//The VSID Parser
module vsid_parser
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

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_OFFSET_INTERNAL = MAX_ADDED_OFFSET + `LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2(MAX_OFFSET_INTERNAL+1),
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1)   
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

    //Side channel signals from previous stage (port parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire                          next_is_config_in,
    input wire                          has_udp_checksum_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos,
    input wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset,
    input wire                          next_can_have_vsid,

    //Side channel signals passed to next stage (filtering)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire                         next_is_config_out,
    output wire                         has_udp_checksum_out,
    output wire                         parsing_vsid_done,

    //Configuration register inputs
    input wire                          is_vxlan,

    //CAM contents
    input wire [`VSID_SIZE-1:0]         vsids [NUM_AXIS_ID-1:0],
    input wire                          vsid_cam_must_match [NUM_AXIS_ID-1:0],
    input wire [`DA_MAC_SIZE-1:0]       mac_encap_addresses [NUM_AXIS_ID-1:0],
    input wire                          mac_encap_cam_must_match [NUM_AXIS_ID-1:0],
    
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

    //Other passthrough
    assign next_is_config_out = next_is_config_in;
    assign poisoned_out = poisoned_in;
    assign parsing_done_out = parsing_done_in;
    assign has_udp_checksum_out = has_udp_checksum_in;
    
    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+:16];
        end
    endgenerate

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Current Position Count
    wire [PACKET_LENGTH_CBITS-1:0]   current_position = cur_pos;

    //Added offset internal
    wire [MAX_ADDED_OFFSET_CBITS:0] added_offset_int = added_offset + (is_vxlan ? `EXTRA_OFFSET_VX : 0);

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/

    
    
    //--------------------------------------------------------//
    //   VSID Field Parsing                                   //
    //--------------------------------------------------------//

    //custom field lanes
    wire [15:0] vsid_lanes [`VSID_LANES-1:0];
    wire        vsid_lane_valid [`VSID_LANES-1:0];

    //Extract Dest port lanes
    generate
        for(genvar j = 0; j < `VSID_LANES; j = j + 1) begin : vsid_lanes_loop
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `L4_OFFSET + `VSID_OFFSET + (j*2) + added_offset_int;

            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign vsid_lanes[j] = lane_data;
            assign vsid_lane_valid[j] = lane_present;
            
        end
    endgenerate



    //--------------------------------------------------------//
    //   Encap MAC Field Parsing                              //
    //--------------------------------------------------------//

    //custom field lanes
    wire [15:0] dest_mac_lanes [`DA_MAC_LANES-1:0];
    wire        dest_mac_lane_valid [`DA_MAC_LANES-1:0];

    //Extract Dest port lanes
    generate
        for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `L4_OFFSET + `DA_MAC_OFFSET + (j*2) + added_offset_int;
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign dest_mac_lanes[j] = lane_data;
            assign dest_mac_lane_valid[j] = lane_present;
            
        end
    endgenerate



    //--------------------------------------------------------//
    //   VSID Routing CAM                                     //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] vsid_out_route_mask;
    wire [`VSID_SIZE-1:0] vsid_match_mask = `VSID_MASK;

    //Loop over CAM array
    generate
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: vsid_cam_array

            //cam signals
            reg  reg_out_route_mask;
            wire [`VSID_LANES-1:0] cur_out_route_mask;
            wire [`VSID_LANES-1:0] eff_out_route_mask;
            
            //Loop over lanes
            for(genvar j = 0; j < `VSID_LANES; j = j + 1) begin : vsid_cam 

                //Check current entry match
                wire tag_match = (vsid_lanes[j] & vsid_match_mask[(j*16)+:16]) ==
                                 (vsids[k][(j*16)+:16] & vsid_match_mask[(j*16)+:16]);

                assign cur_out_route_mask[j] = tag_match;
                assign eff_out_route_mask[j] = !vsid_lane_valid[j] || cur_out_route_mask[j];

            end

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
                else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
            end

            //Assign output values
            assign vsid_out_route_mask[k] =  (&eff_out_route_mask) & reg_out_route_mask;

        end
    endgenerate



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] mac_out_route_mask;

    //Loop over CAM array
    generate
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: mac_cam_array

            //cam signals
            reg reg_out_route_mask;
            wire [`DA_MAC_LANES-1:0] cur_out_route_mask;
            wire [`DA_MAC_LANES-1:0] eff_out_route_mask;
            
            //Loop over lanes
            for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_cam 

                //Check current entry match
                wire dest_adr_match = (dest_mac_lanes[j] == mac_encap_addresses[k][(j*16)+:16]);
                assign cur_out_route_mask[j] = dest_adr_match;
                assign eff_out_route_mask[j] = !dest_mac_lane_valid[j] || cur_out_route_mask[j];

            end

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
                else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
            end

            //Assign output values
            assign mac_out_route_mask[k] = (&eff_out_route_mask) & reg_out_route_mask;

        end
    endgenerate

    //Assign Output Value
    wire [NUM_AXIS_ID-1:0] mac_encap_cam_must_match_packed = {>>{mac_encap_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_mac_route_mask = 
        mac_out_route_mask | ~(mac_encap_cam_must_match_packed);

    wire [NUM_AXIS_ID-1:0] vsid_cam_must_match_packed = {>>{vsid_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_vsid_route_mask =
        ~(vsid_cam_must_match_packed) |
            ((parsing_vsid_done && next_can_have_vsid) ? vsid_out_route_mask : '0);

    assign route_mask_out = internal_mac_route_mask & internal_vsid_route_mask & route_mask_in;



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (dest_mac_lane_valid[`DA_MAC_LANES-1]) reg_parsing_done <= 1;
    end
    
    //Assign output value
    assign parsing_vsid_done = (dest_mac_lane_valid[`DA_MAC_LANES-1] ? 1 : reg_parsing_done);
    


endmodule

`default_nettype wire