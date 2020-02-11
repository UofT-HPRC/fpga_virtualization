`timescale 1ns / 1ps
`default_nettype none




//ARP field constants
`define BOILER_PLATE_OFFSET 14
`define BOILER_PLATE_SIZE 48
`define BOILER_PLATE_LANES (`BOILER_PLATE_SIZE/16)

`define OPCODE_OFFSET 20
`define OPCODE_SIZE 16
`define OPCODE_LANES (`OPCODE_SIZE/16)

`define SA_MAC_OFFSET 22
`define SA_MAC_SIZE 48
`define SA_MAC_LANES (`SA_MAC_SIZE/16)

`define SA_IP4_OFFSET 28
`define SA_IP4_SIZE 32
`define SA_IP4_LANES (`SA_IP4_SIZE/16)

`define DA_IP4_OFFSET 38
`define DA_IP4_SIZE 32
`define DA_IP4_LANES (`DA_IP4_SIZE/16)

`define LAST_BYTE 41




//The ARP Parser Module
module arp_parser
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
    localparam MAX_OFFSET_INTERNAL = 4 + `LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2((MAX_OFFSET_INTERNAL)+1),

    //Features to implement
    parameter bit INCLUDE_BOILER_PLATE_ACL = 1,
    parameter bit INCLUDE_MAC_SRC_ACL = 1,
    parameter bit INCLUDE_IP4_SRC_ACL = 1,
    parameter bit INCLUDE_IP4_DEST_ACL = 1,
    parameter bit INCLUDE_IP4_DEST_CAM = 1  
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

    //Side channel signals from previous stage (etype parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire                          next_is_config_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in,
    input wire                          is_tagged_in,
    input wire                          next_is_arp_in,
    input wire                          next_is_ip4_in,

    //Side channel signals passed to next stage (ip4 parser)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire                         next_is_config_out,
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out,
    output wire                         is_tagged_out,
    output wire                         next_is_arp_out,
    output wire                         next_is_ip4_out,
    
    //Configuration register values (used for ACL)
    output wire [EFF_ID_WIDTH-1:0]      arp_sel_id,
    output wire [EFF_DEST_WIDTH-1:0]    arp_sel_dest,

    input wire [`SA_MAC_SIZE-1:0]       mac_src_address,
    input wire                          mac_match_src,
    input wire [`SA_IP4_SIZE-1:0]       ip4_src_address,
    input wire                          ip4_match_src,
    input wire [`DA_IP4_SIZE-1:0]       ip4_dest_address,
    input wire [`DA_IP4_SIZE-1:0]       ip4_subnet_mask,
    
    //CAM contents
    input wire [`SA_IP4_SIZE-1:0]       ip4_addresses [NUM_AXIS_ID-1:0],
    input wire                          ip4_cam_must_match [NUM_AXIS_ID-1:0],

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
    assign next_is_config_out = next_is_config_in;
    assign next_is_arp_out = next_is_arp_in;
    assign next_is_ip4_out = next_is_ip4_in;
    assign is_tagged_out = is_tagged_in;

    //Output select signals for configurations registers
    assign arp_sel_id = axis_in_tid;
    assign arp_sel_dest = axis_in_tdest;

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
    //   MAC Source Address Parsing                           //
    //--------------------------------------------------------//

    //MAC source lanes
    wire [15:0] src_mac_adr_lanes [`SA_MAC_LANES-1:0];
    wire        src_mac_adr_lane_valid [`SA_MAC_LANES-1:0];

    //Extract Source address lanes
    generate if (INCLUDE_MAC_SRC_ACL) begin : inc_parse_mac_src

        for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_mac_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `SA_MAC_OFFSET + (j*2) + (4*is_tagged_in);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign src_mac_adr_lanes[j] = lane_data;
            assign src_mac_adr_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_mac_lanes2
            assign src_mac_adr_lanes[j] = '0;
            assign src_mac_adr_lane_valid[j] = '0;
        end

    end 
    endgenerate

    
    
    //--------------------------------------------------------//
    //   IP4 Dest Address Parsing                             //
    //--------------------------------------------------------//

    //IP4 dest lanes
    wire [15:0] dest_ip4_adr_lanes [`DA_IP4_LANES-1:0];
    wire        dest_ip4_adr_lane_valid [`DA_IP4_LANES-1:0];

    //Extract Dest address lanes
    generate if (INCLUDE_IP4_DEST_ACL || INCLUDE_IP4_DEST_CAM) begin : inc_parse_ip_dest

        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_ip4_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `DA_IP4_OFFSET + (j*2) + (4*is_tagged_in);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign dest_ip4_adr_lanes[j] = lane_data;
            assign dest_ip4_adr_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_ip4_lanes2
            assign dest_ip4_adr_lanes[j] = '0;
            assign dest_ip4_adr_lane_valid[j] = '0;
        end

    end
    endgenerate



    //--------------------------------------------------------//
    //   IP4 Source Address Parsing                           //
    //--------------------------------------------------------//

    //IP4 source lanes
    wire [15:0] src_ip4_adr_lanes [`SA_IP4_LANES-1:0];
    wire        src_ip4_adr_lane_valid [`SA_IP4_LANES-1:0];

    //Extract Source address lanes
    generate if (INCLUDE_IP4_SRC_ACL) begin : inc_parse_ip_src

        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_ip4_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `SA_IP4_OFFSET + (j*2) + (4*is_tagged_in);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign src_ip4_adr_lanes[j] = lane_data;
            assign src_ip4_adr_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_ip4_lanes2
            assign src_ip4_adr_lanes[j] = '0;
            assign src_ip4_adr_lane_valid[j] = '0;
        end

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Boiler Plate and ACL                                 //
    //--------------------------------------------------------//

    //Signal final result of boiler plate ACL
    wire out_bp_poisoned;

    //Include conditionally
    generate if(INCLUDE_BOILER_PLATE_ACL) begin : inc_boil_acl

        //bp source lanes
        wire [15:0] bp_lanes [`BOILER_PLATE_LANES-1:0];
        wire        bp_lane_valid [`BOILER_PLATE_LANES-1:0];

        //Extract BP address lanes
        for(genvar j = 0; j < `BOILER_PLATE_LANES; j = j + 1) begin : boil_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `BOILER_PLATE_OFFSET + (j*2) + (4*is_tagged_in);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign bp_lanes[j] = lane_data;
            assign bp_lane_valid[j] = lane_present;
            
        end




        //Ensure correct boiler plate
        localparam [`BOILER_PLATE_SIZE-1:0] bp_expected = 48'h040600080100;

        //Signals for ACL
        reg reg_bp_poisoned;
        wire [`BOILER_PLATE_LANES-1:0] cur_bp_poisoned;
        wire [`BOILER_PLATE_LANES-1:0] eff_bp_poisoned;

        for(genvar j = 0; j < `BOILER_PLATE_LANES; j = j + 1) begin : bp_acl

            //Assign curren beat's value
            assign cur_bp_poisoned[j] = (bp_lanes[j] != bp_expected[(j*16)+:16]);

            //Effective value
            assign eff_bp_poisoned[j] = bp_lane_valid[j] && cur_bp_poisoned[j];

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_bp_poisoned <= 0;
            else if(|eff_bp_poisoned) reg_bp_poisoned <= 1;
        end

        //Assign final value
        assign out_bp_poisoned = (|eff_bp_poisoned) | reg_bp_poisoned;

    end else begin

        assign out_bp_poisoned = '0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   OpCode Parsing and ACL                               //
    //--------------------------------------------------------//

    //Address where the byte-pair lane is expected    
    wire [UPPER_PORTION-1:0]                op_lane_offset = `OPCODE_OFFSET + (4*is_tagged_in);
    wire [LOWER_PORTION-1:0]                op_lane_lower = op_lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  op_lane_upper = op_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    //The specific byte-pair lane in the current stream flit
    wire [15:0]  op_lane = axis_in_tdata_lanes[op_lane_lower[LOWER_PORTION-1:1]];
    wire         op_lane_valid = (op_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;




    //Register values
    reg reg_op_poisoned;
    reg reg_is_req;
    reg reg_is_reply;

    //Values based on current beat
    wire cur_op_poisoned;
    wire cur_is_req;
    wire cur_is_reply;

    //FInal values for outputs
    wire out_op_poisoned;
    wire out_is_req;   //TODO - use (limit broadcast to requests)
    wire out_is_reply;

    //Assign curren beat's value
    assign cur_is_req = (op_lane == 16'h0100);
    assign cur_is_reply = (op_lane == 16'h0200);
    assign cur_op_poisoned = !(cur_is_req || cur_is_reply);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_op_poisoned <= 0;
            reg_is_req <= 0;
            reg_is_reply <= 0;
        end
        else if (op_lane_valid) begin
            reg_op_poisoned <= cur_op_poisoned;
            reg_is_req <= cur_is_req;
            reg_is_reply <= cur_is_reply;
        end
    end

    //Assign final value
    assign out_is_req = (op_lane_valid ? cur_is_req : reg_is_req);
    assign out_is_reply = (op_lane_valid ? cur_is_reply : reg_is_reply);

    assign out_op_poisoned = 
        (INCLUDE_BOILER_PLATE_ACL ?
            (op_lane_valid ? cur_op_poisoned : reg_op_poisoned)
        :
            0
        );



    //--------------------------------------------------------//
    //   Source MAC Address ACL                               //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_mac_src_poisoned;

    //Include conditionally
    generate if(INCLUDE_MAC_SRC_ACL) begin : inc_src_mac_acl 

        //Signals for acl
        reg reg_mac_src_poisoned;
        wire [`SA_MAC_LANES-1:0] cur_mac_src_poisoned;
        wire [`SA_MAC_LANES-1:0] eff_mac_src_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_mac_acl 

            //Assign current beat's value
            wire src_mac_adr_violation = (src_mac_adr_lanes[j] != mac_src_address[(j*16)+:16]) && mac_match_src;
            assign cur_mac_src_poisoned[j] = src_mac_adr_violation;

            //Assign final value for this lane
            assign eff_mac_src_poisoned[j] = src_mac_adr_lane_valid[j] && cur_mac_src_poisoned[j]; 

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_mac_src_poisoned <= 0;
            else if(|eff_mac_src_poisoned) reg_mac_src_poisoned <= 1;
        end

        //Assign final value
        assign out_mac_src_poisoned = (|eff_mac_src_poisoned) | reg_mac_src_poisoned;

    end else begin

        assign out_mac_src_poisoned = 0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Source IP4 Address ACL                               //
    //--------------------------------------------------------//

    //Signal final result of ACL
    wire out_ip4_src_poisoned;

    //Include conditionally
    generate if(INCLUDE_IP4_SRC_ACL) begin : inc_src_ip4_acl 

        //Signals for acl
        reg reg_ip4_src_poisoned;
        wire [`SA_IP4_LANES-1:0] cur_ip4_src_poisoned;
        wire [`SA_IP4_LANES-1:0] eff_ip4_src_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_ip4_acl 

            //Assign current beat's value
            wire src_ip4_adr_violation = (src_ip4_adr_lanes[j] != ip4_src_address[(j*16)+:16]) && ip4_match_src;
            assign cur_ip4_src_poisoned[j] = src_ip4_adr_violation;

            //Assign final value for this lane
            assign eff_ip4_src_poisoned[j] = src_ip4_adr_lane_valid[j] && cur_ip4_src_poisoned[j]; 

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_ip4_src_poisoned <= 0;
            else if(|eff_ip4_src_poisoned) reg_ip4_src_poisoned <= 1;
        end

        //Assign final value
        assign out_ip4_src_poisoned = (|eff_ip4_src_poisoned) | reg_ip4_src_poisoned;

    end else begin

        assign out_ip4_src_poisoned = 0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Dest IP4 Address ACL                                 //
    //--------------------------------------------------------//

    //Signal final result of ACL
    wire out_ip4_dest_poisoned;

    //Include conditionally
    generate if(INCLUDE_IP4_DEST_ACL) begin : inc_dest_ip4_acl 

        //Signals to hold stored values of outputs
        reg reg_ip4_dest_poisoned;
        wire [`DA_IP4_LANES-1:0] cur_ip4_dest_poisoned;
        wire [`DA_IP4_LANES-1:0] eff_ip4_dest_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_ip4_acl 

            //Assign current beat's value
            wire subnet_violation = (
                                        (dest_ip4_adr_lanes[j] & ip4_subnet_mask[(j*16)+:16]) != 
                                        (ip4_dest_address[(j*16)+:16] & ip4_subnet_mask[(j*16)+:16])
                                    );
            assign cur_ip4_dest_poisoned[j] = subnet_violation;

            //Assign final value for this lane
            assign eff_ip4_dest_poisoned[j] = dest_ip4_adr_lane_valid[j] && cur_ip4_dest_poisoned[j];

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_ip4_dest_poisoned <= 0;
            else if(|eff_ip4_dest_poisoned) reg_ip4_dest_poisoned <= 1;
        end

        //Assign final value
        assign out_ip4_dest_poisoned = (|eff_ip4_dest_poisoned) | reg_ip4_dest_poisoned;

    end else begin

        assign out_ip4_dest_poisoned = 0;

    end 
    endgenerate


    //Aggregate of all ACL signals
    assign poisoned_out = 
        (next_is_arp_in ?
            out_bp_poisoned | out_op_poisoned | out_mac_src_poisoned | 
            out_ip4_src_poisoned | out_ip4_dest_poisoned | poisoned_in
        :
            poisoned_in
        );



    //--------------------------------------------------------//
    //   Dest IP4 Address Routing CAM                         //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] ip4_out_route_mask;

    //Include conditionally
    generate if(INCLUDE_IP4_DEST_CAM) begin : inc_cam

        //Loop over CAM array
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: cam_array_ip4

            //cam signals
            reg reg_ip4_out_route_mask;
            wire [`DA_IP4_LANES-1:0] cur_ip4_out_route_mask;
            wire [`DA_IP4_LANES-1:0] eff_ip4_out_route_mask;
            
            //Loop over lanes
            for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_cam_ip4

                //Check current entry match
                wire dest_ip4_adr_match = (dest_ip4_adr_lanes[j] == ip4_addresses[k][(j*16)+:16]);
                assign cur_ip4_out_route_mask[j] = dest_ip4_adr_match;
                assign eff_ip4_out_route_mask[j] = !dest_ip4_adr_lane_valid[j] || cur_ip4_out_route_mask[j];

            end

            //Assign Registered values
            always @(posedge aclk) begin
                if(~aresetn || axis_last_beat) reg_ip4_out_route_mask <= 1;
                else if(!(&eff_ip4_out_route_mask)) reg_ip4_out_route_mask <= 0;
            end

            //Assign output values
            assign ip4_out_route_mask[k] = (&eff_ip4_out_route_mask) & reg_ip4_out_route_mask;

        end

    end else begin

        assign ip4_out_route_mask = '1;

    end 
    endgenerate


    //Assign Final output from CAM
    wire [NUM_AXIS_ID-1:0] ip4_cam_must_match_packed = {>>{ip4_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = 
    	~(ip4_cam_must_match_packed) | 
    		(next_is_arp_in ? ip4_out_route_mask : 
    			(next_is_ip4_in ? '1: '0
            ));

    assign route_mask_out = internal_route_mask & route_mask_in;



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (dest_ip4_adr_lane_valid[`DA_IP4_LANES-1]) reg_parsing_done <= 1;
    end
    
    //Assign output value
    wire out_parsing_done = (dest_ip4_adr_lane_valid[`DA_IP4_LANES-1] ? 1 : reg_parsing_done);
    assign parsing_done_out = (next_is_arp_in ? out_parsing_done : parsing_done_in);
    


endmodule

`default_nettype wire