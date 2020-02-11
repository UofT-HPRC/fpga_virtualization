`timescale 1ns / 1ps
`default_nettype none




//VLAN field constants
`define VID_OFFSET 14
`define VID_SIZE 16
`define VID_LANES (`VID_SIZE/16)

`define ET_OFFSET 16
`define ET_SIZE 16
`define ET_LANES (`ET_SIZE/16)

`define LAST_BYTE 17




//The VLAN Parser Module
module vlan_parser
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_BUS_LANES = AXIS_BUS_WIDTH/16,
    localparam NUM_BUS_BYTES_LOG2 = $clog2(NUM_BUS_BYTES),
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Bits required for internal counters
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),
    localparam MAX_OFFSET_CBITS = $clog2(`LAST_BYTE+1),

    //Features to implement
    parameter bit INCLUDE_VLAN_ACL = 1,
    parameter bit INCLUDE_VLAN_CAM = 1   
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]       axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]     axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]      axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]    axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals from previous stage (mac parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in,
    input wire                          next_is_ctag_vlan,
    input wire [`ET_SIZE-1:0]           parsed_etype_in,
    input wire                          parsed_etype_valid_in,
    input wire                          mac_dest_is_bc_in,
    input wire                          mac_dest_is_mc_in,
    input wire                          mac_dest_is_ip4_mc_in,
    input wire                          mac_dest_is_ip6_mc_in,

    //Side channel signals passed to next stage (etype parser)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out,
    output wire                         is_tagged,
    output wire [`ET_SIZE-1:0]          parsed_etype_out,
    output wire                         parsed_etype_valid_out,
    output wire                         mac_dest_is_bc_out,
    output wire                         mac_dest_is_mc_out,
    output wire                         mac_dest_is_ip4_mc_out,
    output wire                         mac_dest_is_ip6_mc_out,
    
    //Configuration register values (used for ACL)
    output wire [EFF_ID_WIDTH-1:0]      vlan_sel_id,

    input wire [`VID_SIZE-1:0]          vlan_field_expected,
    input wire                          vlan_match_tag,
    input wire                          vlan_match_pri,

    //CAM contents
    input wire [`VID_SIZE-1:0]          vlan_fields [NUM_AXIS_ID-1:0],
    input wire                          vlan_cam_must_match[NUM_AXIS_ID-1:0],
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Signals Used Throughout                              //
    //--------------------------------------------------------//

    //Stream passthrough
    assign axis_out_tdata = axis_in_tdata;
    assign axis_out_tid = axis_in_tid;
    assign axis_out_tdest = axis_in_tdest;
    assign axis_out_tkeep = axis_in_tkeep;
    assign axis_out_tlast = axis_in_tlast;
    assign axis_out_tvalid = axis_in_tvalid;
    assign axis_in_tready = axis_out_tready;

    //Other passthrough
    assign cur_pos_out = cur_pos_in;
    assign mac_dest_is_bc_out = mac_dest_is_bc_in;
    assign mac_dest_is_mc_out = mac_dest_is_mc_in;
    assign mac_dest_is_ip4_mc_out = mac_dest_is_ip4_mc_in;
    assign mac_dest_is_ip6_mc_out = mac_dest_is_ip6_mc_in;
    assign is_tagged = next_is_ctag_vlan;

    //Output select signals for configurations registers
    assign vlan_sel_id = axis_in_tid;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Current position within packet
    wire [PACKET_LENGTH_CBITS-1:0]   current_position = cur_pos_in;
    
    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+15:j*16];
        end
    endgenerate
    
    //Split VLAN field into relevant segments
    wire [`VID_SIZE-1:0] expected_vid_tag = {vlan_field_expected[15:8],4'h0,vlan_field_expected[3:0]};
    wire [2:0]          expected_vid_pri = vlan_field_expected[7:5];

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/

    
    
    //--------------------------------------------------------//
    //   VLAN Tag and Priority Parsing                        //
    //--------------------------------------------------------//

    //VLAN value to analyze
    wire [15:0]  vlan_lane;
    wire         vlan_lane_valid;

    //Effective data to analyse
    wire [`VID_SIZE-1:0] eff_vlan_lane = (next_is_ctag_vlan ? vlan_lane : 16'h0000);
    wire                 eff_vlan_valid = (next_is_ctag_vlan ? vlan_lane_valid : parsed_etype_valid_in);
    wire [`VID_SIZE-1:0] vid_tag_lane = {eff_vlan_lane[15:8],4'h0,eff_vlan_lane[3:0]};
    wire [2:0]           vid_pri_lane = eff_vlan_lane[7:5];


    //Include conditionally
    generate if (INCLUDE_VLAN_ACL || INCLUDE_VLAN_CAM) begin : inc_parse

        //Address where the byte-pair lane is expected    
        wire [UPPER_PORTION-1:0]                vlan_lane_offset = `VID_OFFSET;
        wire [LOWER_PORTION-1:0]                vlan_lane_lower = vlan_lane_offset[LOWER_PORTION-1:0];
        wire [UPPER_PORTION-LOWER_PORTION-1:0]  vlan_lane_upper = vlan_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
        
        //The specific byte-pair lane in the current stream flit
        assign vlan_lane = axis_in_tdata_lanes[vlan_lane_lower[LOWER_PORTION-1:1]];
        assign vlan_lane_valid = (vlan_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;

    end else begin

        assign vlan_lane = 0;
        assign vlan_lane_valid = 0;

    end
    endgenerate



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
    //   Next Header Determination                            //
    //--------------------------------------------------------//

    //Assign output values
    assign parsed_etype_out = (next_is_ctag_vlan ? etype_lane : parsed_etype_in);
    assign parsed_etype_valid_out = (next_is_ctag_vlan ? etype_lane_valid : parsed_etype_valid_in);



    //--------------------------------------------------------//
    //   VLAN ACL                                             //
    //--------------------------------------------------------//

    //Signal final result of ACL
    wire out_vlan_poisoned;

    //Include conditionally
    generate if(INCLUDE_VLAN_ACL) begin : inc_vlan_acl 

        //Signals for acl
        reg reg_vlan_poisoned;
        wire cur_vlan_poisoned;

        //Assign current beat's value
        wire tag_violation = (vid_tag_lane != expected_vid_tag) && vlan_match_tag;
        wire pri_violation = (vid_pri_lane != expected_vid_pri) && vlan_match_pri;
        assign cur_vlan_poisoned = tag_violation || pri_violation;

        //Assign Resgistered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_vlan_poisoned <= 0;
            else if(eff_vlan_valid) reg_vlan_poisoned <= cur_vlan_poisoned;
        end

        //Assign final value
        assign out_vlan_poisoned = (eff_vlan_valid ? cur_vlan_poisoned : reg_vlan_poisoned);

    end else begin

        //Assign final value
        assign out_vlan_poisoned = 0;

    end 
    endgenerate

    //Aggregate of all ACL signals
    assign poisoned_out = out_vlan_poisoned || poisoned_in;



    //--------------------------------------------------------//
    //   VLAN Routing CAM                                     //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Include conditionally
    generate if(INCLUDE_VLAN_CAM) begin : inc_cam 

        //Loop over CAM array
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: cam_array

            //cam signals
            reg reg_out_route;
            wire cur_out_route;
            
            //Check current entry match
            wire vlan_match = (vid_tag_lane == {vlan_fields[k][15:8],4'h0,vlan_fields[k][3:0]});
            assign cur_out_route = vlan_match;

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_out_route <= 1;
                else if(eff_vlan_valid) reg_out_route <= cur_out_route;
            end

            //Assign output values
            assign out_route_mask[k] = (eff_vlan_valid ? cur_out_route : reg_out_route);

        end

    end else begin

        assign out_route_mask = '1;

    end 
    endgenerate

    //Assign Output Value
    wire [NUM_AXIS_ID-1:0] vlan_cam_must_match_packed = {>>{vlan_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = out_route_mask | ~(vlan_cam_must_match_packed);
    assign route_mask_out = internal_route_mask & route_mask_in;



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (etype_lane_valid) reg_parsing_done <= 1;
    end
    
    //Assign output value
    wire out_parsing_done = (etype_lane_valid ? 1 : reg_parsing_done);
    assign parsing_done_out = (next_is_ctag_vlan ? out_parsing_done : parsing_done_in);
    


endmodule

`default_nettype wire