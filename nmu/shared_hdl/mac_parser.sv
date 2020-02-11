`timescale 1ns / 1ps
`default_nettype none




//MAC field constants
`define DA_MAC_OFFSET 0
`define DA_MAC_SIZE 48
`define DA_MAC_LANES (`DA_MAC_SIZE/16)

`define SA_MAC_OFFSET 6
`define SA_MAC_SIZE 48
`define SA_MAC_LANES (`SA_MAC_SIZE/16)

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
    localparam MAX_OFFSET_CBITS = $clog2(`LAST_BYTE+1),

    //Features to implement
    parameter bit INGRESS = 0,
    parameter bit INCLUDE_MAC_NEXT_ACL = 1,
    parameter bit INCLUDE_MAC_SRC_ACL = 1,
    parameter bit INCLUDE_MAC_DEST_ACL = 1,
    parameter bit INCLUDE_MAC_DEST_CAM = 1
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]         axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]		  axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]        axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]        axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]	  axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]       axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Side channel signals from previous stage (custom de-tagger)
    input wire [NUM_AXIS_ID-1:0]          route_mask_in,

    //Side channel signals passed to next stage (vlan parser)
    output wire [NUM_AXIS_ID-1:0]         route_mask_out,			//CAM results
    output wire                           poisoned_out,				//ACL results
    output wire                           parsing_done_out,			//Parsing done
    output wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out, 			    //Counter of current packet position (instead of replicating counter in each stage)
    output wire                           next_is_ctag_vlan,		//Next header info
    output wire [`ET_SIZE-1:0]            parsed_etype_out,			//Next header info
    output wire                           parsed_etype_valid_out,	//Next header info
    output wire                           mac_dest_is_bc,			//Used later for etype ACLs
    output wire                           mac_dest_is_mc,			//Used later for etype ACLs
    output wire                           mac_dest_is_ip4_mc,		//Used later for etype ACLs
    output wire                           mac_dest_is_ip6_mc,		//Used later for etype ACLs

    //Configuration register values (used for ACL)
    output wire	[EFF_ID_WIDTH-1:0]		  mac_sel_id,
    output wire	[EFF_DEST_WIDTH-1:0]	  mac_sel_dest,

    input wire							  mac_skip_parsing,
    input wire                            mac_allow_next_ctag,	//Next header ACL config
    input wire [`SA_MAC_SIZE-1:0]         mac_src_address,		//Src ACL config
    input wire                            mac_match_src,		//Src ACL config
    input wire [`DA_MAC_SIZE-1:0]         mac_dest_address,		//Dest ACL config
    input wire                            mac_match_dest,		//Dest ACL config

    //CAM contents
    input wire [`SA_MAC_SIZE-1:0]         mac_addresses [NUM_AXIS_ID-1:0],			//CAM contents
    input wire                            mac_cam_must_match [NUM_AXIS_ID-1:0],		//CAM wild-card

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

    //Output select signals for configurations registers
    assign mac_sel_id = axis_in_tid;
    assign mac_sel_dest = axis_in_tdest;

    //Valid and Ready beat
    wire axis_valid_beat = axis_in_tvalid && axis_out_tready;
    wire axis_last_beat = axis_valid_beat && axis_in_tlast;

    //Skip parsing for egress packets only
    wire skip_parsing = mac_skip_parsing && !INGRESS;
    
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
									?	NUM_BUS_BYTES_LOG2 + 1
									:	MAX_OFFSET_CBITS;*/
    

    
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
	    
    //include conditionally
    generate if(INCLUDE_MAC_DEST_ACL || INCLUDE_MAC_DEST_CAM) begin : inc_parse_dest

	    //Extract Dest address lanes
	    for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_lanes

	        //Address where the byte-pair lane is expected    
	        wire [UPPER_PORTION-1:0]                lane_offset = `DA_MAC_OFFSET + (j*2);
	        wire [LOWER_PORTION-1:0]				lane_lower = lane_offset[LOWER_PORTION-1:0];
	        wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
	        	        
	        //The specific byte-pair lane in the current stream flit
	        wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]]; //Infer Mux, except when lane_lower is a constant
	        wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION])
	        									&& axis_valid_beat && !skip_parsing;

	        //Assign parsed values
	        assign dest_adr_lanes[j] = lane_data;
	        assign dest_adr_lane_valid[j] = lane_present;
	        
	    end

    end else begin
    
        for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_lanes2
            assign dest_adr_lanes[j] = '0;
            assign dest_adr_lane_valid[j] = '0;
        end
    
    end
	endgenerate



    //--------------------------------------------------------//
    //   MAC Source Address Parsing                           //
    //--------------------------------------------------------//

    //MAC source lanes
    wire [15:0] src_adr_lanes [`SA_MAC_LANES-1:0];
    wire        src_adr_lane_valid [`SA_MAC_LANES-1:0];

    //Include conditionally
    generate if (INCLUDE_MAC_SRC_ACL) begin : inc_parse_src

	    //Extract Src address lanes
	    for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_lanes
	        
	        //Address where the byte-pair lane is expected    
	        wire [UPPER_PORTION-1:0]                lane_offset = `SA_MAC_OFFSET + (j*2);
	        wire [LOWER_PORTION-1:0]                lane_lower = lane_offset[LOWER_PORTION-1:0];
	        wire [UPPER_PORTION-LOWER_PORTION-1:0]  lane_upper = lane_offset[UPPER_PORTION-1:LOWER_PORTION];
	        
	        //The specific byte-pair lane in the current stream flit
	        wire [15:0]     lane_data = axis_in_tdata_lanes[lane_lower[LOWER_PORTION-1:1]]; //Infer Mux, except when lane_lower is a constant
	        wire            lane_present = (lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) 
	        									&& axis_valid_beat && !skip_parsing;
	                                                                                
	        //Assign parsed values
	        assign src_adr_lanes[j] = lane_data;
	        assign src_adr_lane_valid[j] = lane_present;
	        
	    end

    end else begin
    
        for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_lanes2
            assign src_adr_lanes[j] = '0;
            assign src_adr_lane_valid[j] = '0;
        end
        
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
    wire         etype_lane_valid = (et_lane_upper == current_position[PACKET_LENGTH_CBITS-1:LOWER_PORTION]) 
    									&& axis_valid_beat && !skip_parsing;



    //--------------------------------------------------------//
    //   Next Header Determination                            //
    //--------------------------------------------------------//

    //Registers to hold stored values of outputs
    reg reg_next_is_ctag_vlan;
    //reg reg_next_is_stag_vlan;

    //Current beat's values for outputs
    wire cur_next_is_ctag_vlan;
    //wire cur_next_is_stag_vlan;

    //Assign current beat's value
    assign cur_next_is_ctag_vlan = (etype_lane == 16'h0081);
    //assign cur_next_is_stag_vlan = (etype_lane == 16'ha888);

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) begin
            reg_next_is_ctag_vlan <= 0;
            //reg_next_is_stag_vlan <= 0;
        end
        else if(etype_lane_valid) begin
            reg_next_is_ctag_vlan <= cur_next_is_ctag_vlan;
            //reg_next_is_stag_vlan <= cur_next_is_stag;
        end
    end

    //Assign output values
    assign next_is_ctag_vlan = (etype_lane_valid ? cur_next_is_ctag_vlan : reg_next_is_ctag_vlan);
    //assign next_is_stag_vlan = (etype_lane_valid ? cur_next_is_stag_vlan : reg_next_is_stag_vlan);
    assign parsed_etype_out = etype_lane;
    assign parsed_etype_valid_out = (skip_parsing ? 1'b0 : etype_lane_valid);



    //--------------------------------------------------------//
    //   Next Header ACL                                      //
    //--------------------------------------------------------//

    //Signal final result of next header ACL
    wire out_next_head_poisoned;

    //Include conditionally
    generate if(INCLUDE_MAC_NEXT_ACL) begin : inc_next_acl 

	    //Signals for acl
	    reg reg_next_head_poisoned;
	    wire cur_next_head_poisoned;

	    //Assign current beat's value
	    wire ctag_violation = cur_next_is_ctag_vlan && !mac_allow_next_ctag;
        //wire stag_violation = cur_next_is_stag_vlan && !mac_allow_next_stag;
	    assign cur_next_head_poisoned = ctag_violation ; // || stag_violation;

	    //Assign Resgistered values
	    always @(posedge aclk) begin
	        if(~aresetn || axis_last_beat) reg_next_head_poisoned <= 0;
	        else if(etype_lane_valid) reg_next_head_poisoned <= cur_next_head_poisoned;
	    end

	    //Assign final value
	    assign out_next_head_poisoned = (etype_lane_valid ? cur_next_head_poisoned : reg_next_head_poisoned);

    end else begin

    	 //Assign final value
	    assign out_next_head_poisoned = 0;

    end 
	endgenerate



    //--------------------------------------------------------//
    //   Source Address ACL                                   //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_src_poisoned;

    //Include conditionally
    generate if(INCLUDE_MAC_SRC_ACL) begin : inc_src_acl 

	    //Signals for acl
	    reg reg_src_poisoned;
	    wire [`SA_MAC_LANES-1:0] cur_src_poisoned;
	    wire [`SA_MAC_LANES-1:0] eff_src_poisoned;

	    //Loop over lanes
	    for(genvar j = 0; j < `SA_MAC_LANES; j = j + 1) begin : src_acl 

	        //Assign current beat's value
	        wire src_adr_violation = (src_adr_lanes[j] != mac_src_address[(j*16)+:16]) && mac_match_src;
	        assign cur_src_poisoned[j] = src_adr_violation;

	        //Assign final value for this lane
	        assign eff_src_poisoned[j] = src_adr_lane_valid[j] && cur_src_poisoned[j]; 

	    end
	    
	    //Assign Registered values
	    always @(posedge aclk) begin
	        if(~aresetn || axis_last_beat) reg_src_poisoned <= 0;
	        else if(|eff_src_poisoned) reg_src_poisoned <= 1;
	    end

	    //Assign final value
	    assign out_src_poisoned = (|eff_src_poisoned) | reg_src_poisoned;

    end else begin

    	//Assign final value
	    assign out_src_poisoned = 0;

    end
    endgenerate



    //--------------------------------------------------------//
    //   Dest Address ACL                                     //
    //--------------------------------------------------------//

    //Signal final result of src addr ACL
    wire out_dest_poisoned;

    //For conditional inclusion
    generate if (INCLUDE_MAC_DEST_ACL) begin : inc_dest_acl

	    //Registers to hold stored values of outputs
	    reg reg_dest_poisoned;
	    reg reg_dest_is_bc;
	    reg reg_dest_is_mc;
	    reg reg_dest_is_ip4_mc;
	    reg reg_dest_is_ip6_mc;

	    //Current beat's values for outputs
	    wire [`DA_MAC_LANES-1:0] cur_dest_poisoned;
	    wire [`DA_MAC_LANES-1:0] cur_dest_is_bc;
	    wire [`DA_MAC_LANES-1:0] cur_dest_is_mc;
	    wire [`DA_MAC_LANES-1:0] cur_dest_is_ip4_mc;
	    wire [`DA_MAC_LANES-1:0] cur_dest_is_ip6_mc;

	    //Effective values for outputs
	    wire [`DA_MAC_LANES-1:0] eff_dest_poisoned;
	    wire [`DA_MAC_LANES-1:0] eff_dest_is_bc;
	    wire [`DA_MAC_LANES-1:0] eff_dest_is_mc;
	    wire [`DA_MAC_LANES-1:0] eff_dest_is_ip4_mc;
	    wire [`DA_MAC_LANES-1:0] eff_dest_is_ip6_mc;

	    //Constant values to compare to (with don't cares)      |  LSB ||      ||      ||      ||      ||  MSB | //Note - Big Endian
	    localparam [`DA_MAC_SIZE-1:0] comp_dest_is_bc =     48'b111111111111111111111111111111111111111111111111;
	    localparam [`DA_MAC_SIZE-1:0] comp_dest_is_mc =     48'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1;
	    localparam [`DA_MAC_SIZE-1:0] comp_dest_is_ip4_mc = 48'bxxxxxxxxxxxxxxxx0xxxxxxx010111100000000000000001;
	    localparam [`DA_MAC_SIZE-1:0] comp_dest_is_ip6_mc = 48'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx0011001100110011;

	    //Loop over lanes
	    for(genvar j = 0; j < `DA_MAC_LANES; j = j + 1) begin : dest_acl

	        //Assign current beat's value
	        wire dest_adr_violation = (dest_adr_lanes[j] != mac_dest_address[(j*16)+:16]) && mac_match_dest;
	        assign cur_dest_poisoned[j] = dest_adr_violation;

	        assign cur_dest_is_bc[j] = (dest_adr_lanes[j] ==? comp_dest_is_bc[(j*16)+:16]);
	        assign cur_dest_is_mc[j] = (dest_adr_lanes[j] ==? comp_dest_is_mc[(j*16)+:16]);
	        assign cur_dest_is_ip4_mc[j] = (dest_adr_lanes[j] ==? comp_dest_is_ip4_mc[(j*16)+:16]);
	        assign cur_dest_is_ip6_mc[j] = (dest_adr_lanes[j] ==? comp_dest_is_ip6_mc[(j*16)+:16]);

	        //Assign final value for this lane
	        assign eff_dest_poisoned[j] = dest_adr_lane_valid[j] && cur_dest_poisoned[j];
	        assign eff_dest_is_bc[j] = !dest_adr_lane_valid[j] || cur_dest_is_bc[j];
	        assign eff_dest_is_mc[j] = !dest_adr_lane_valid[j] || cur_dest_is_mc[j];
	        assign eff_dest_is_ip4_mc[j] = !dest_adr_lane_valid[j] || cur_dest_is_ip4_mc[j];
	        assign eff_dest_is_ip6_mc[j] = !dest_adr_lane_valid[j] || cur_dest_is_ip6_mc[j];

	    end

	    //Assign Registered values
	    always @(posedge aclk) begin
	        if(~aresetn || axis_last_beat) begin
	            reg_dest_poisoned <= 0;
	            reg_dest_is_bc <= 1;
	            reg_dest_is_mc <= 1;
	            reg_dest_is_ip4_mc <= 1;
	            reg_dest_is_ip6_mc <= 1;
	        end
	        else begin
	            if(|eff_dest_poisoned) reg_dest_poisoned <= 1;
	            if(!(&eff_dest_is_bc)) reg_dest_is_bc <= 0;
	            if(!(&eff_dest_is_mc)) reg_dest_is_mc <= 0;
	            if(!(&eff_dest_is_ip4_mc)) reg_dest_is_ip4_mc <= 0;
	            if(!(&eff_dest_is_ip6_mc)) reg_dest_is_ip6_mc <= 0;
	        end
	    end

	    //Assign final value
	    assign out_dest_poisoned = (|eff_dest_poisoned) | reg_dest_poisoned;

	    //Assign output values
	    assign mac_dest_is_bc = (&eff_dest_is_bc) & reg_dest_is_bc;
	    assign mac_dest_is_mc = (&eff_dest_is_mc) & reg_dest_is_mc;
	    assign mac_dest_is_ip4_mc = (&eff_dest_is_ip4_mc) & reg_dest_is_ip4_mc;
	    assign mac_dest_is_ip6_mc = (&eff_dest_is_ip6_mc) & reg_dest_is_ip6_mc;

    end else begin

        //Assign final value
        assign out_dest_poisoned = 0;

        //Assign output values
        assign mac_dest_is_bc = 0;
        assign mac_dest_is_mc = 0;
        assign mac_dest_is_ip4_mc = 0;
        assign mac_dest_is_ip6_mc = 0;

    end
    endgenerate

    //Aggregate of all ACL signals
    assign poisoned_out = out_next_head_poisoned | out_src_poisoned | out_dest_poisoned;



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Include conditionally
    generate if(INCLUDE_MAC_DEST_CAM) begin : inc_cam 

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


    //Assign Output Value
    wire [NUM_AXIS_ID-1:0] mac_cam_must_match_packed = {>>{mac_cam_must_match}};
    wire [NUM_AXIS_ID-1:0] internal_route_mask = out_route_mask | ~(mac_cam_must_match_packed);
    
    assign route_mask_out = internal_route_mask & route_mask_in;



    //--------------------------------------------------------//
    //   End of Processing Indication                         //
    //--------------------------------------------------------//
    
    //Register
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (etype_lane_valid || skip_parsing) reg_parsing_done <= 1;
    end
    
    //Assign output value
    assign parsing_done_out = ((etype_lane_valid || skip_parsing) ? 1 : reg_parsing_done);



endmodule

`default_nettype wire