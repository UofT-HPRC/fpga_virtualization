`timescale 1ns / 1ps
`default_nettype none




//Port field constants
`define DPORT_OFFSET 36
`define DPORT_SIZE 16
`define DPORT_LANES (`DPORT_SIZE/16)

`define LAST_BYTE 41



//The Port Parser
module port_cam_only
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
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1)  
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]           axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]         axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]          axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]        axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Side channel signals from previous stage (ip4 parser)
    input wire [NUM_AXIS_ID-1:0]            route_mask_in,
    input wire                              parsing_done_in,
    input wire [PACKET_LENGTH_CBITS-1:0]    cur_pos_in,
    input wire [MAX_ADDED_OFFSET_CBITS-1:0] added_offset_in,
    input wire                              next_has_ports,

    //Side channel signals passed to next stage (vsid parser/filtering)
    output wire [NUM_AXIS_ID-1:0]           route_mask_out,
    output wire                             parsing_done_out,
    
    //CAM contents
    input wire [`SPORT_SIZE-1:0]            ports [NUM_AXIS_ID-1:0],
    input wire                              port_cam_must_match [NUM_AXIS_ID-1:0],

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
    wire axis_valid_beat = axis_in_tvalid & axis_out_tready;
    wire axis_last_beat = axis_valid_beat & axis_in_tlast;

    //Current Position Count
    wire [PACKET_LENGTH_CBITS-1:0] current_position = cur_pos_in;

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
    //   Dest Port Parsing                                    //
    //--------------------------------------------------------//

    //Dest Port lanes
    wire [15:0] dest_port_lanes [`DPORT_LANES-1:0];
    wire        dest_port_lane_valid [`DPORT_LANES-1:0];

    //Extract Dest port lanes
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



    //--------------------------------------------------------//
    //   Dest Address Routing CAM                             //
    //--------------------------------------------------------//

    //Signal final result of CAM
    wire [NUM_AXIS_ID-1:0] out_route_mask;

    //Loop over CAM array
    for(genvar k = 0; k < NUM_AXIS_ID; k = k + 1) begin : cam_array

        //cam signals
        reg reg_out_route_mask;
        wire [`DPORT_LANES-1:0] eff_out_route_mask;
        
        //Loop over lanes
        for(genvar j = 0; j < `DPORT_LANES; j = j + 1) begin : dest_cam

            //Check current entry match
            wire dest_port_match = (dest_port_lanes[j] == ports[k][(j*16)+:16]);
            assign eff_out_route_mask[j] = !dest_port_lane_valid[j] || dest_port_match;

        end

        //Assign Registered values
        always @(posedge aclk) begin
            if(~aresetn || axis_last_beat) reg_out_route_mask <= 1;
            else if(!(&eff_out_route_mask)) reg_out_route_mask <= 0;
        end

        //Assign output values
        assign out_route_mask[k] = (&eff_out_route_mask) & reg_out_route_mask;

    end

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
    wire cur_parsing_done = dest_port_lane_valid[`DPORT_LANES-1];
    reg reg_parsing_done;

    //Assign Registered values
    always @(posedge aclk) begin
        if(~aresetn || axis_last_beat) reg_parsing_done <= 0;
        else if (cur_parsing_done) reg_parsing_done <= 1;
    end
    
    //Assign output value
    wire out_parsing_done = (cur_parsing_done ? 1 : reg_parsing_done);
    assign parsing_done_out = (next_has_ports ? out_parsing_done : parsing_done_in);
    


endmodule

`default_nettype wire