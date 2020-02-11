`timescale 1ns / 1ps
`default_nettype none




//IP4 field constants
`define IHL_OFFSET 14
`define PROT_OFFSET 23

`define SA_IP4_OFFSET 26
`define SA_IP4_SIZE 32
`define SA_IP4_LANES (`SA_IP4_SIZE/16)

`define DA_IP4_OFFSET 30
`define DA_IP4_SIZE 32
`define DA_IP4_LANES (`DA_IP4_SIZE/16)

`define LAST_BYTE 33




//The IP4 Parser Module
module ip4_parser
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
    localparam MAX_OFFSET_INTERNAL = 4 + `LAST_BYTE,
    localparam MAX_OFFSET_CBITS = $clog2(MAX_OFFSET_INTERNAL+1),

    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1),
    
    //Features to implement
    parameter bit INCLUDE_IP4_NEXT_ACL = 1,
    parameter bit ALLOW_IP4_OPTIONS = 1,
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

    //Side channel signals from previous stage (arp parser)
    input wire [NUM_AXIS_ID-1:0]        route_mask_in,
    input wire                          poisoned_in,
    input wire                          parsing_done_in,
    input wire                          next_is_config_in,
    input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in,
    input wire                          is_tagged,
    input wire                          next_is_arp,
    input wire                          next_is_ip4,

    //Side channel signals passed to next stage (port parser)
    output wire [NUM_AXIS_ID-1:0]       route_mask_out,
    output wire                         poisoned_out,
    output wire                         parsing_done_out,
    output wire                         next_is_config_out,
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out,
    output wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset,
    output wire                         next_has_ports,
    output wire                         next_can_have_vsid,
    output wire                         next_can_have_udp_check,

    //Configuration register inputs
    output wire [EFF_ID_WIDTH-1:0]      ip4_sel_id,
    output wire [EFF_DEST_WIDTH-1:0]    ip4_sel_dest,

    input wire                          ip4_restrict_to_only_ports,
    input wire [`SA_IP4_SIZE-1:0]       ip4_src_address,
    input wire                          ip4_match_src,
    input wire [`DA_IP4_SIZE-1:0]       ip4_dest_address,
    input wire [`DA_IP4_SIZE-1:0]       ip4_subnet_mask,
    input wire                          ip4_allow_public,
    input wire                          ip4_allow_bc,
    input wire                          ip4_allow_mc,

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

    //Output select signals for configurations registers
    assign ip4_sel_id = axis_in_tid;
    assign ip4_sel_dest = axis_in_tdest;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Current Position Count
    wire [PACKET_LENGTH_CBITS-1:0]   current_position = cur_pos_in;
    
    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+15:j*16];
        end
    endgenerate

    //Params to split offset counters into important parts
    localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
    localparam UPPER_PORTION = PACKET_LENGTH_CBITS; /*(MAX_OFFSET_CBITS <= NUM_BUS_BYTES_LOG2)
                                    ?   NUM_BUS_BYTES_LOG2 + 1
                                    :   MAX_OFFSET_CBITS;*/

    
    
    //--------------------------------------------------------//
    //   IP4 Dest Address Parsing                             //
    //--------------------------------------------------------//

    //IP4 dest lanes
    wire [15:0] dest_adr_lanes [`DA_IP4_LANES-1:0];
    wire        dest_adr_lane_valid [`DA_IP4_LANES-1:0];

    //Extract Dest address lanes
    generate if (INCLUDE_IP4_DEST_ACL || INCLUDE_IP4_DEST_CAM) begin : inc_parse_dest

        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `DA_IP4_OFFSET + (j*2) + (4*is_tagged);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign dest_adr_lanes[j] = lane_data;
            assign dest_adr_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_lanes2
            assign dest_adr_lanes[j] = '0;
            assign dest_adr_lane_valid[j] = 0;
        end

    end
    endgenerate



    //--------------------------------------------------------//
    //   IP4 Source Address Parsing                           //
    //--------------------------------------------------------//

    //IP4 source lanes
    wire [15:0] src_adr_lanes [`SA_IP4_LANES-1:0];
    wire        src_adr_lane_valid [`SA_IP4_LANES-1:0];

    //Extract Dest address lanes
    generate if (INCLUDE_IP4_SRC_ACL) begin : inc_parse_src

        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_lanes
            
            //Address where the byte-pair lane is expected    
            wire [UPPER_PORTION-1:0]                lane_offset = `SA_IP4_OFFSET + (j*2) + (4*is_tagged);
            wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
            wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
            
            //The specific byte-pair lane in the current stream flit
            wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]];
            wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;
                                                                                    
            //Assign parsed values
            assign src_adr_lanes[j] = lane_data;
            assign src_adr_lane_valid[j] = lane_present;
            
        end

    end else begin

        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_lanes2
            assign src_adr_lanes[j] = '0;
            assign src_adr_lane_valid[j] = 0;
        end

    end 
    endgenerate



    //--------------------------------------------------------//
    //   IHL Parsing and Added Offset Calc                    //
    //--------------------------------------------------------//

    //Address where the byte-pair lane is expected    
    wire [UPPER_PORTION-1:0]                ihl_lane_offset = `IHL_OFFSET + (4*is_tagged);
    wire [LOWER_PORTION-1:0]                ihl_lane_lower = ihl_lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  ihl_lane_upper = ihl_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    //The specific byte-pair lane in the current stream flit
    wire [15:0]  ihl_lane = axis_in_tdata_lanes[ihl_lane_lower[LOWER_PORTION-1:1]];
    wire unsigned [3:0] ihl_value = ihl_lane[3:0];
    wire         ihl_lane_valid = (ihl_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;

    //Register to store value for output
    reg [MAX_ADDED_OFFSET_CBITS-1:0]  reg_added_offset;
    wire [MAX_ADDED_OFFSET_CBITS-1:0] cur_added_offset;

    wire has_options;
    reg reg_has_options;
    wire cur_has_options;

    //Value based on current beat
    assign cur_added_offset = ((ihl_value - 5) + is_tagged) * 4;
    assign cur_has_options = (ihl_value != 5);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_added_offset <= 0;
            reg_has_options <= 0;
        end 
        else if(ihl_lane_valid) begin
            reg_added_offset <= cur_added_offset;
            reg_has_options <= cur_has_options;
        end 
    end

    //Assign Output value
    assign added_offset = 
        (ALLOW_IP4_OPTIONS ?
            (ihl_lane_valid ? cur_added_offset : reg_added_offset)
        :
            (4*is_tagged)
        );

    assign has_options = (ihl_lane_valid ? cur_has_options : reg_has_options);
    assign next_can_have_vsid = (!has_options || ALLOW_IP4_OPTIONS);



    //--------------------------------------------------------//
    //   Protocol Parsing                                     //
    //--------------------------------------------------------//

    //Address where the byte-pair lane is expected    
    wire [UPPER_PORTION-1:0]                prot_lane_offset = `PROT_OFFSET + (4*is_tagged);
    wire [LOWER_PORTION-1:0]                prot_lane_lower = prot_lane_offset[LOWER_PORTION-1:0];
    wire [UPPER_PORTION-LOWER_PORTION-1:0]  prot_lane_upper = prot_lane_offset[UPPER_PORTION-1:LOWER_PORTION];
    
    //The specific byte-pair lane in the current stream flit
    wire [15:0]  prot_lane = axis_in_tdata_lanes[prot_lane_lower[LOWER_PORTION-1:1]];
    wire unsigned [7:0] prot_value = prot_lane[15:8];
    wire         prot_lane_valid = (prot_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;



    //--------------------------------------------------------//
    //   Next Header Determination                            //
    //--------------------------------------------------------//

    //Signals
    reg reg_next_has_ports;
    wire cur_next_has_ports;

    //Special reg for UDP
    reg reg_is_udp;

    //Assign current beat's value
    wire cur_is_udp = (prot_value == 8'h11); //UDP
    wire cur_is_tcp = (prot_value == 8'h06); //TCP
    wire cur_is_udpl = (prot_value == 8'h88); //UDPLite
    wire cur_is_dccp = (prot_value == 8'h21); //DCCP
    wire cur_is_sctp = (prot_value == 8'h84); //SCTP

    assign cur_next_has_ports = 
        (cur_is_udp || cur_is_tcp || cur_is_udpl || cur_is_dccp || cur_is_sctp);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_next_has_ports <= 0;
            reg_is_udp <= 0;
        end 
        else if(prot_lane_valid) begin
            reg_next_has_ports <= cur_next_has_ports;
            reg_is_udp <= cur_is_udp;
        end 
    end

    //Assign output values
    assign next_has_ports = 
        ((next_is_ip4 && (!has_options || ALLOW_IP4_OPTIONS)) ?
            (prot_lane_valid ? cur_next_has_ports : reg_next_has_ports)
        :
            0
        );

    assign next_can_have_udp_check = 
        ((next_is_ip4 && (!has_options)) ? //Note, we don't care about ALLOW_IP4_OPTIONS because checksum calc doesn't consider this yet (TODO)
            (prot_lane_valid ? cur_is_udp : reg_is_udp)
        :
            0
        );



    //--------------------------------------------------------//
    //   Next Header ACL                                      //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_next_head_poisoned;

    //Include conditionally
    generate if(INCLUDE_IP4_NEXT_ACL) begin : inc_next

        //Signals for acl
        reg reg_next_head_poisoned;
        wire cur_next_head_poisoned;

        //Assign current beat's value
        wire port_violation = !cur_next_has_ports && ip4_restrict_to_only_ports;
        assign cur_next_head_poisoned = port_violation;

        //Assign Resgistered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_next_head_poisoned <= 0;
            else if(prot_lane_valid) reg_next_head_poisoned <= cur_next_head_poisoned;
        end

        //Assign final value
        assign out_next_head_poisoned = (prot_lane_valid ? cur_next_head_poisoned : reg_next_head_poisoned);

    end else begin

        assign out_next_head_poisoned = 0;

    end
    endgenerate



    //--------------------------------------------------------//
    //   Source Address ACL                                   //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_src_poisoned;

    //Include conditionally
    generate if(INCLUDE_IP4_SRC_ACL) begin : inc_src_acl

        //Signals for acl
        reg reg_src_poisoned;
        wire [`SA_IP4_LANES-1:0] cur_src_poisoned;
        wire [`SA_IP4_LANES-1:0] eff_src_poisoned;

        //Loop over lanes
        for(genvar j = 0; j < `SA_IP4_LANES; j = j + 1) begin : src_acl 

            //Assign current beat's value
            wire src_adr_violation = (src_adr_lanes[j] != ip4_src_address[(j*16)+:16]) && ip4_match_src;
            assign cur_src_poisoned[j] = src_adr_violation;

            //Assign final value for this lane
            assign eff_src_poisoned[j] = src_adr_lane_valid[j] & cur_src_poisoned[j]; 

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
    //   Dest Address ACL                                     //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_dest_poisoned;

    //Include conditionally
    generate if(INCLUDE_IP4_DEST_ACL) begin : inc_dest_acl

        //Registers to hold stored values of status
        reg reg_dest_poisoned;
        reg reg_subnet_match;
        reg reg_dest_is_ones_bc;
        reg reg_dest_is_sub_bc;
        reg reg_dest_is_mc;
        reg reg_dest_is_pri1;
        reg reg_dest_is_pri2;
        reg reg_dest_is_pri3;
        reg reg_dest_is_public;

        //Current beat's values for status
        wire cur_dest_poisoned;
        wire [`DA_IP4_LANES-1:0] cur_subnet_match;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_ones_bc;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_sub_bc;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_mc;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_pri1;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_pri2;
        wire [`DA_IP4_LANES-1:0] cur_dest_is_pri3;

        //Effective values for status
        wire [`DA_IP4_LANES-1:0] eff_subnet_match;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_ones_bc;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_sub_bc;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_mc;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_pri1;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_pri2;
        wire [`DA_IP4_LANES-1:0] eff_dest_is_pri3;

        //Final values for status
        wire out_subnet_match;
        wire out_dest_is_ones_bc;
        wire out_dest_is_sub_bc;
        wire out_dest_is_mc;
        wire out_dest_is_pri1;
        wire out_dest_is_pri2;
        wire out_dest_is_pri3;

        //Constant values to compare to (with don't cares)       |  LSB ||      ||      ||  MSB | //Note - Big Endian
        localparam [`DA_IP4_SIZE-1:0] comp_dest_is_ones_bc = 48'b11111111111111111111111111111111;
        localparam [`DA_IP4_SIZE-1:0] comp_dest_is_mc =      48'bxxxxxxxxxxxxxxxxxxxxxxxx1110xxxx;
        localparam [`DA_IP4_SIZE-1:0] comp_dest_is_pri1 =    48'bxxxxxxxxxxxxxxxxxxxxxxxx00001010; //10.0.0.0-10.255.255.255 (0A:XX:XX:XX)
        localparam [`DA_IP4_SIZE-1:0] comp_dest_is_pri2 =    48'bxxxxxxxxxxxxxxxx0001xxxx10101100; //172.16.0.0-172.21.255.255 (AC:1X:XX:XX)
        localparam [`DA_IP4_SIZE-1:0] comp_dest_is_pri3 =    48'bxxxxxxxxxxxxxxxx1010100011000000; //192.168.0.0-192.168.255.255 (C0:A8:XX:XX)

        //Loop over lanes
        for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_acl 

            //Assign current beat's value
            assign cur_subnet_match[j] = (
                                            (dest_adr_lanes[j] & ip4_subnet_mask[(j*16)+15:j*16]) == 
                                            (ip4_dest_address[(j*16)+:16] & ip4_subnet_mask[(j*16)+:16])
                                         );

            assign cur_dest_is_sub_bc[j] = (
                                              dest_adr_lanes[j]  == 
                                              (ip4_dest_address[(j*16)+:16] | ~ip4_subnet_mask[(j*16)+:16])
                                           );

            assign cur_dest_is_ones_bc[j] = (dest_adr_lanes[j] ==? comp_dest_is_ones_bc[(j*16)+:16]);
            assign cur_dest_is_mc[j] = (dest_adr_lanes[j] ==? comp_dest_is_mc[(j*16)+:16]);
            assign cur_dest_is_pri1[j] = (dest_adr_lanes[j] ==? comp_dest_is_pri1[(j*16)+:16]);
            assign cur_dest_is_pri2[j] = (dest_adr_lanes[j] ==? comp_dest_is_pri2[(j*16)+:16]);
            assign cur_dest_is_pri3[j] = (dest_adr_lanes[j] ==? comp_dest_is_pri3[(j*16)+:16]);

            //Assign final value for this lane
            assign eff_subnet_match[j] = !dest_adr_lane_valid[j] || cur_subnet_match[j];
            assign eff_dest_is_ones_bc[j] = !dest_adr_lane_valid[j] || cur_dest_is_ones_bc[j];
            assign eff_dest_is_sub_bc[j] = !dest_adr_lane_valid[j] || cur_dest_is_sub_bc[j];
            assign eff_dest_is_mc[j] = !dest_adr_lane_valid[j] || cur_dest_is_mc[j];
            assign eff_dest_is_pri1[j] = !dest_adr_lane_valid[j] || cur_dest_is_pri1[j];
            assign eff_dest_is_pri2[j] = !dest_adr_lane_valid[j] || cur_dest_is_pri2[j];
            assign eff_dest_is_pri3[j] = !dest_adr_lane_valid[j] || cur_dest_is_pri3[j];

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) begin
                reg_dest_poisoned <= 0;
                reg_subnet_match <= 1;
                reg_dest_is_ones_bc <= 1;
                reg_dest_is_sub_bc <= 1;
                reg_dest_is_mc <= 1;
                reg_dest_is_pri1 <= 1;
                reg_dest_is_pri2 <= 1;
                reg_dest_is_pri3 <= 1;
            end
            else begin
                if(dest_adr_lane_valid[`DA_IP4_LANES-1])
                    reg_dest_poisoned <= cur_dest_poisoned;

                if(!(&eff_subnet_match)) reg_subnet_match <= 0;
                if(!(&eff_dest_is_ones_bc)) reg_dest_is_ones_bc <= 0;
                if(!(&eff_dest_is_sub_bc)) reg_dest_is_sub_bc <= 0;
                if(!(&eff_dest_is_mc)) reg_dest_is_mc <= 0;
                if(!(&eff_dest_is_pri1)) reg_dest_is_pri1 <= 0;
                if(!(&eff_dest_is_pri2)) reg_dest_is_pri2 <= 0;
                if(!(&eff_dest_is_pri3)) reg_dest_is_pri3 <= 0;
            end
        end

        //Assign final value
        assign out_subnet_match = (&eff_subnet_match) & reg_subnet_match;
        assign out_dest_is_ones_bc = (&eff_dest_is_ones_bc) & reg_dest_is_ones_bc;
        assign out_dest_is_sub_bc = (&eff_dest_is_sub_bc) & reg_dest_is_sub_bc;
        assign out_dest_is_mc = (&eff_dest_is_mc) & reg_dest_is_mc;
        assign out_dest_is_pri1 = (&eff_dest_is_pri1) & reg_dest_is_pri1;
        assign out_dest_is_pri2 = (&eff_dest_is_pri2) & reg_dest_is_pri2;
        assign out_dest_is_pri3 = (&eff_dest_is_pri3) & reg_dest_is_pri3;



        //Determine ACL lagality after DEST address last lane recieved
        //Determine ACL lagality after DEST address last lane recieved
        wire public_exception = ip4_allow_public && !(out_dest_is_pri1 || out_dest_is_pri2 || out_dest_is_pri3);
        wire bc_exception = ip4_allow_bc && (out_dest_is_ones_bc || out_dest_is_sub_bc);
        wire mc_exception = ip4_allow_mc && out_dest_is_mc;
        wire dest_adr_violation = !(out_subnet_match || public_exception || bc_exception || mc_exception);
        assign cur_dest_poisoned = dest_adr_violation;

        //Assign final value
        assign out_dest_poisoned = 
            (dest_adr_lane_valid[`DA_IP4_LANES-1] ? cur_dest_poisoned : reg_dest_poisoned);

    end else begin 

        assign out_dest_poisoned = 0;

    end 
    endgenerate


    //Aggregate of all ACL signals
    assign poisoned_out = 
        (next_is_ip4 ?
            out_next_head_poisoned | out_src_poisoned | out_dest_poisoned | poisoned_in
        :
            poisoned_in
        );



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Include conditionally
    generate if(INCLUDE_IP4_DEST_CAM) begin : inc_cam 

        //Loop over CAM array
        for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: cam_array

            //cam signals
            reg reg_out_route_mask;
            wire [`DA_IP4_LANES-1:0] cur_out_route_mask;
            wire [`DA_IP4_LANES-1:0] eff_out_route_mask;
            
            //Loop over lanes
            for(genvar j = 0; j < `DA_IP4_LANES; j = j + 1) begin : dest_cam 

                //Check current entry match
                wire dest_adr_match = (dest_adr_lanes[j] == ip4_addresses[k][(j*16)+:16]);
                assign cur_out_route_mask[j] = dest_adr_match;
                assign eff_out_route_mask[j] = !dest_adr_lane_valid[j] || cur_out_route_mask[j];

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
    wire [NUM_AXIS_ID-1:0] ip4_cam_must_match_packed = {>>{ip4_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = 
        ~(ip4_cam_must_match_packed) |
            (next_is_ip4 ? out_route_mask : 
                (next_is_arp ? '1 : '0
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
        else if (dest_adr_lane_valid[`DA_IP4_LANES-1]) reg_parsing_done <= 1;
    end
    
    //Assign output value
    wire out_parsing_done = (dest_adr_lane_valid[`DA_IP4_LANES-1] ? 1 : reg_parsing_done);
    assign parsing_done_out = (next_is_ip4 ? out_parsing_done : parsing_done_in);
    



endmodule

`default_nettype wire