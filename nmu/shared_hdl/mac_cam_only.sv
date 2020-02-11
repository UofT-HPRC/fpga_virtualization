`timescale 1ns / 1ps
`default_nettype none




//MAC field constants
`define DA_MAC_OFFSET 0
`define DA_MAC_SIZE 48
`define DA_MAC_LANES (`DA_MAC_SIZE/16)

`define ET_OFFSET 12
`define ET_SIZE 16

`define LAST_BYTE 13




//The MAC Parser Module
module mac_parser
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
    localparam MAX_OFFSET_CBITS = $clog2(`LAST_BYTE+1)
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]           axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]		    axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]          axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]	    axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Side channel signals passed to next stage (vlan parser)
    output wire [NUM_AXIS_ID-1:0]           route_mask_out,
    output wire                             parsing_done_out,
    output wire [PACKET_LENGTH_CBITS-1:0]   cur_pos_out,
    output wire                             next_is_ctag_vlan,
    output wire [`ET_SIZE-1:0]              parsed_etype_out,
    output wire                             parsed_etype_valid_out,

    //CAM contents
    input wire [`SA_MAC_SIZE-1:0]           mac_addresses [NUM_AXIS_ID-1:0],			//CAM contents
    input wire                              mac_cam_must_match [NUM_AXIS_ID-1:0],		//CAM wild-card

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

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid && axis_out_tready;
    wire axis_last_beat = axis_valid_beat && axis_in_tlast;
    
    //Divide the data bus into 2-byte wide lanes
    wire [15:0] axis_in_tdata_lanes [NUM_BUS_LANES-1:0];
    generate
        for(genvar j = 0; j < NUM_BUS_LANES; j = j + 1) begin : bus_lanes
            assign axis_in_tdata_lanes[j] = axis_in_tdata[(j*16)+:16];
        end
    endgenerate

    //Params to split offset counters into important parts
	localparam LOWER_PORTION = NUM_BUS_BYTES_LOG2;
	localparam UPPER_PORTION = PACKET_LENGTH_CBITS;
    

    
    //--------------------------------------------------------//
    //   Current Position Count                               //
    //--------------------------------------------------------//
    
    //Accouting of current offset within packet
    reg [PACKET_LENGTH_CBITS-1:0] current_position;
    
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) current_position <= 0;
        else if(axis_valid_beat) current_position <= current_position + NUM_BUS_BYTES;
    end

    //Assign output (no need to have counter repeated for every parser, only included for MAC parser)
    assign cur_pos_out = current_position;

    
    
    //--------------------------------------------------------//
    //   MAC Dest Address Parsing                             //
    //--------------------------------------------------------//

    //MAC dest lanes
    wire [15:0] dest_adr_lanes [`DA_MAC_LANES-1:0];
    wire        dest_adr_lane_valid [`DA_MAC_LANES-1:0];
	    
    //Extract Dest address lanes
    for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_lanes

        //Address where the byte-pair lane is expected    
        wire [UPPER_PORTION-1:0]                lane_offset = `DA_MAC_OFFSET + (j*2);
        wire [LOWER_PORTION-1:0]				lane_lower = lane_offset[LOWER_PORTION-1:0];
        wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
                    
        //The specific byte-pair lane in the current stream flit
        wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]]; //Infer Mux, except when lane_lower is a constant
        wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) && axis_valid_beat;

        //Assign parsed values
        assign dest_adr_lanes[j] = lane_data;
        assign dest_adr_lane_valid[j] = lane_present;
        
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
    //   Next Header Determination                            //
    //--------------------------------------------------------//

    //Registers to hold stored values of outputs
    reg reg_next_is_ctag_vlan;

    //Current beat's values for outputs
    wire cur_next_is_ctag_vlan;

    //Assign current beat's value
    assign cur_next_is_ctag_vlan = (etype_lane == 16'h0081);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_next_is_ctag_vlan <= 0;
        end
        else if(etype_lane_valid) begin
            reg_next_is_ctag_vlan <= cur_next_is_ctag_vlan;
        end
    end

    //Assign output values
    assign next_is_ctag_vlan = (etype_lane_valid ? cur_next_is_ctag_vlan : reg_next_is_ctag_vlan);
    assign parsed_etype_out = etype_lane;
    assign parsed_etype_valid_out = etype_lane_valid;



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Loop over CAM array
    for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin: cam_array

        //cam signals
        reg reg_out_route_mask;
        wire [`DA_MAC_LANES-1:0] cur_out_route_mask;
        wire [`DA_MAC_LANES-1:0] eff_out_route_mask;
        
        //Loop over lanes
        for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_cam 

            //Check current entry match
            wire dest_adr_match = (dest_adr_lanes[j] == mac_addresses[k][(j*16)+:16]);
            assign eff_out_route_mask[j] = !dest_adr_lane_valid[j] || dest_adr_match;

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
            else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
        end

        //Assign output values
        assign out_route_mask[k] = (&eff_out_route_mask) & reg_out_route_mask;

    end

    //Assign Output Value
    wire [NUM_AXIS_ID-1:0] mac_cam_must_match_packed = {>>{mac_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = out_route_mask | ~(mac_cam_must_match_packed);
    
    assign route_mask_out = internal_route_mask;



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
    assign parsing_done_out = (etype_lane_valid ? 1 : reg_parsing_done);



endmodule

`default_nettype wire