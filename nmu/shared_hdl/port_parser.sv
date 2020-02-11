`timescale 1ns / 1ps
`default_nettype none




//Port field constants
`define SPORT_OFFSET 34
`define SPORT_SIZE 16
`define SPORT_LANES (`SPORT_SIZE/16)

`define DPORT_OFFSET 36
`define DPORT_SIZE 16
`define DPORT_LANES (`DPORT_SIZE/16)

`define CHECK_OFFSET 40
`define CHECK_SIZE 16
`define CHECK_LANES (`CHECK_SIZE/16)

`define LAST_BYTE 41




//The Port Parser
module port_parser
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

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_ADDED_OFFSET = 64,  
    localparam MAX_OFFSET_INTERNAL = MAX_ADDED_OFFSET + `LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2(MAX_OFFSET_INTERNAL+1),
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1),

    //Features to implement
    parameter bit INCLUDE_SRC_PORT_ACL = 1,
    parameter bit INCLUDE_DEST_PORT_ACL = 1,
    parameter bit INCLUDE_DEST_PORT_CAM = 1    
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

    //Side channel signals from previous stage (ip4 parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire                          next_is_config_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in,
    input wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset_in,
    input wire                          next_has_ports,
    input wire                          next_can_have_vsid_in,
    input wire                          next_can_have_udp_check,

    //Side channel signals passed to next stage (vsid parser/filtering)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire                         next_is_config_out,
    output wire                         has_udp_checksum,
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out,
    output wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset_out,
    output wire                         next_can_have_vsid_out,

    //Configuration register inputs
    output wire [EFF_ID_WIDTH-1:0]      port_sel_id,
    output wire [EFF_DEST_WIDTH-1:0]    port_sel_dest,

    input wire [`SPORT_SIZE-1:0]        src_port,
    input wire                          match_src_port,
    input wire [`DPORT_SIZE-1:0]        dest_port,
    input wire                          match_dest_port,
    
    //CAM contents
    input wire [`SPORT_SIZE-1:0]        ports [NUM_AXIS_ID-1:0],
    input wire                          port_cam_must_match [NUM_AXIS_ID-1:0],

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
    assign next_is_config_out = next_is_config_in;
    assign cur_pos_out = cur_pos_in;
    assign added_offset_out = added_offset_in;
    assign next_can_have_vsid_out = next_can_have_vsid_in;
    
    //Output select signals for configurations registers
    assign port_sel_id = axis_in_tid;
    assign port_sel_dest = axis_in_tdest;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Current Position Count
    wire [PACKET_LENGTH_CBITS-1:0]   current_position = cur_pos_in;

    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+:16];
        end
    endgenerate

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/

    
    
    //--------------------------------------------------------//
    //   Dest Port Parsing                                    //
    //--------------------------------------------------------//

    //Dest Port lanes
    wire [15:0] dest_port_lanes [`DPORT_LANES-1:0];
    wire        dest_port_lane_valid [`DPORT_LANES-1:0];

    //Extract Dest port lanes
    generate if (INCLUDE_DEST_PORT_ACL || INCLUDE_DEST_PORT_CAM) begin : inc_parse_dest

        for(genvar j = 0; j < `DPORT_LANES; j = j + 1) begin : dest_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `DPORT_OFFSET + (j*2) + added_offset_in;
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign dest_port_lanes[j] = lane_data;
            assign dest_port_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `DPORT_LANES; j = j + 1) begin : dest_lanes2
            assign dest_port_lanes[j] = '0;
            assign dest_port_lane_valid[j] = 0;
        end

    end
    endgenerate



    //--------------------------------------------------------//
    //   Source Port Parsing                                  //
    //--------------------------------------------------------//

    //Source Port lanes
    wire [15:0] src_port_lanes [`SPORT_LANES-1:0];
    wire        src_port_lane_valid [`SPORT_LANES-1:0];

    //Extract Dest Port lanes
    generate if (INCLUDE_SRC_PORT_ACL) begin : inc_parse_src

        for(genvar j = 0; j < `SPORT_LANES; j = j + 1) begin : src_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `SPORT_OFFSET + (j*2) + added_offset_in;
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign src_port_lanes[j] = lane_data;
            assign src_port_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `SPORT_LANES; j = j + 1) begin : src_lanes2
            assign src_port_lanes[j] = '0;
            assign src_port_lane_valid[j] = 0;
        end

    end
    endgenerate



    //--------------------------------------------------------//
    //   Checksum Parsing and Detection                       //
    //--------------------------------------------------------//

    //Address where the byte-pair lane is expected    
    wire [UPPER_PORTION-1:0]                check_lane_offset = `CHECK_OFFSET;
    wire [LOWER_PORTION-1:0]                check_lane_lower = check_lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  check_lane_upper = check_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    //The specific byte-pair lane in the current stream flit
    wire [15:0]  check_lane = axis_in_tdata_lanes[check_lane_lower[LOWER_PORTION-1:1]];
    wire         check_lane_valid = (check_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;

    //Signal final result of whether checksum is present
    wire out_check_present;
    wire cur_check_present;
    reg reg_check_present;

    //Assign current beat's value
    assign cur_check_present = (check_lane != 0);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_check_present <= 0;
        else if(check_lane_valid) reg_check_present <= cur_check_present;
    end

    //Assign output vlue
    assign out_check_present = (check_lane_valid ? cur_check_present : reg_check_present);

    //Assign final value
    assign has_udp_checksum = (next_can_have_udp_check ? out_check_present : 1'b0);



    //--------------------------------------------------------//
    //   Source Port ACL                                      //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_src_poisoned;

    //Include conditionally
    generate if(INCLUDE_SRC_PORT_ACL) begin : inc_src_acl

        //Signals for acl
        reg reg_src_poisoned;
        wire [`SPORT_LANES-1:0] cur_src_poisoned;
        wire [`SPORT_LANES-1:0] eff_src_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `SPORT_LANES; j = j + 1) begin : src_acl 

            //Assign current beat's value
            wire src_port_violation = (src_port_lanes[j] != src_port[(j*16)+:16]) && match_src_port;
            assign cur_src_poisoned[j] = src_port_violation;

            //Assign final value for this lane
            assign eff_src_poisoned[j] = src_port_lane_valid[j] && cur_src_poisoned[j]; 

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_src_poisoned <= 0;
            else if(|eff_src_poisoned) reg_src_poisoned <= 1;
        end

        //Assign final value
        assign out_src_poisoned = (|eff_src_poisoned) | reg_src_poisoned;

    end else begin

        assign out_src_poisoned = 0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Dest Port ACL                                        //
    //--------------------------------------------------------//
    //Signal final result of src addr ACL
    wire out_dest_poisoned;

    //Include conditionally
    generate if(INCLUDE_DEST_PORT_ACL) begin : inc_dest_acl

        //Signals for acl
        reg reg_dest_poisoned;
        wire [`DPORT_LANES-1:0] cur_dest_poisoned;
        wire [`DPORT_LANES-1:0] eff_dest_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `DPORT_LANES; j = j + 1) begin : dest_acl 

            //Assign current beat's value
            wire dest_port_violation = (dest_port_lanes[j] != dest_port[(j*16)+:16]) && match_dest_port;
            assign cur_dest_poisoned[j] = dest_port_violation;

            //Assign final value for this lane
            assign eff_dest_poisoned[j] = dest_port_lane_valid[j] && cur_dest_poisoned[j]; 

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_dest_poisoned <= 0;
            else if (|eff_dest_poisoned) reg_dest_poisoned <= 1;
        end

        //Assign final value
        assign out_dest_poisoned = (|eff_dest_poisoned) | reg_dest_poisoned;

    end else begin

        assign out_dest_poisoned = 0;

    end 
    endgenerate


    //Aggregate of all ACL signals
    assign poisoned_out = 
        (next_has_ports ? 
            out_src_poisoned | out_dest_poisoned | poisoned_in
        :
            poisoned_in
        );



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Include conditionally
    generate if(INCLUDE_DEST_PORT_CAM) begin : inc_cam 

        //Loop over CAM array
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin : cam_array

            //cam signals
            reg reg_out_route_mask;
            wire [`DPORT_LANES-1:0] cur_out_route_mask;
            wire [`DPORT_LANES-1:0] eff_out_route_mask;
            
            //Loop over lanes
            for(genvar j = 0; j < `DPORT_LANES; j = j + 1) begin : dest_cam

                //Check current entry match
                wire dest_port_match = (dest_port_lanes[j] == ports[k][(j*16)+:16]);
                assign cur_out_route_mask[j] = dest_port_match;
                assign eff_out_route_mask[j] = !dest_port_lane_valid[j] || cur_out_route_mask[j];

            end

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
                else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
            end

            //Assign output values
            assign out_route_mask[k] = (&eff_out_route_mask) & reg_out_route_mask;

        end

    end else begin

        assign out_route_mask = '1;

    end 
    endgenerate

    //Assign Final output
    wire [NUM_AXIS_ID-1:0] port_cam_must_match_packed = {>>{port_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = 
        ~(port_cam_must_match_packed) |
            (next_has_ports ? out_route_mask : '0);

    assign route_mask_out = internal_route_mask & route_mask_in;



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (dest_port_lane_valid[`DPORT_LANES-1]) reg_parsing_done <= 1;
    end
    
    //Assign output value
    wire out_parsing_done = (dest_port_lane_valid[`DPORT_LANES-1] ? 1 : reg_parsing_done);
    assign parsing_done_out = (next_has_ports ? out_parsing_done : parsing_done_in);
    



endmodule

`default_nettype wire