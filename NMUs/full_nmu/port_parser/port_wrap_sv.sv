`timescale 1ns / 1ps
`default_nettype none




//Port field constants
`define SPORT_SIZE 16
`define DPORT_SIZE 16




//The Port Parser
module port_wrap_sv
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),
    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1),

    //Packed input signals size
    localparam PORT_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 6,
    localparam PORT_TUSER_OUT_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 5,
    localparam PORT_CONFIG_SEL_WIDTH = EFF_ID_WIDTH + EFF_DEST_WIDTH,
    localparam PORT_CONFIG_REG_WIDTH = `SPORT_SIZE + `DPORT_SIZE + 2,
    localparam PORT_CAM_WIDTH = (`SPORT_SIZE + 1) * NUM_AXIS_ID,

    //Features to implement
    parameter INCLUDE_SRC_PORT_ACL = 1,
    parameter INCLUDE_DEST_PORT_ACL = 1,
    parameter INCLUDE_DEST_PORT_CAM = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+6)-1:0] // [PORT_TUSER_IN_WIDTH-1:0]
                                          axis_in_tuser,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        
                                          axis_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+5)-1:0] // [PORT_TUSER_OUT_WIDTH-1:0] 
                                          axis_out_tuser,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       
                                          axis_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_out_tdest, 
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    output wire [(((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)+((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH))-1:0]  
                                          port_config_sel,
    input wire [(`SPORT_SIZE+`DPORT_SIZE+2)-1:0]
                                          port_config_regs,
    input wire [((`SPORT_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]          
                                          port_cam_values,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//

    //Input signal declarations
    wire [NUM_AXIS_ID-1:0]        route_mask_in;
    wire                          poisoned_in;
    wire                          parsing_done_in;
    wire                          next_is_config_in;
    wire [PACKET_LENGTH_CBITS-1:0]  cur_pos_in;
    wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset_in;
    wire                          next_has_ports;
    wire                          next_can_have_vsid_in;
    wire                          next_can_have_udp_check;

    assign {next_can_have_udp_check,next_can_have_vsid_in,next_has_ports,added_offset_in,
            cur_pos_in,next_is_config_in,parsing_done_in,poisoned_in,route_mask_in}
    = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask_out;
    wire                         poisoned_out;
    wire                         parsing_done_out;
    wire                         next_is_config_out;
    wire                         has_udp_checksum;
    wire [PACKET_LENGTH_CBITS-1:0] cur_pos_out;
    wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset_out;
    wire                         next_can_have_vsid_out;

    wire [PORT_TUSER_OUT_WIDTH-1:0] axis_pack_out_tuser = 
        {next_can_have_vsid_out,added_offset_out,cur_pos_out,has_udp_checksum,
         next_is_config_out,parsing_done_out,poisoned_out,route_mask_out};

    //Configuration select signals
    wire [EFF_ID_WIDTH-1:0]        port_sel_id;
    wire [EFF_DEST_WIDTH-1:0]      port_sel_dest;

    assign port_config_sel = {port_sel_id,port_sel_dest};

    //Configuration signal declarations
    wire [`SPORT_SIZE-1:0]        src_port;
    wire                          match_src_port;
    wire [`DPORT_SIZE-1:0]        dest_port;
    wire                          match_dest_port;
    
    assign {match_dest_port,dest_port,match_src_port,src_port} = port_config_regs;

    //CAM contents
    wire [`SPORT_SIZE-1:0]        ports [NUM_AXIS_ID-1:0];
    wire                          port_cam_must_match [NUM_AXIS_ID-1:0];

    localparam PER_ID = (`SPORT_SIZE + 1);

    genvar j;
    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : config0 

            assign {port_cam_must_match[j],ports[j]}    
            = port_cam_values[(PER_ID*j)+:PER_ID];

        end
    endgenerate



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_buff_tid;
    wire [EFF_DEST_WIDTH-1:0]      axis_buff_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    port_parser
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        .INCLUDE_SRC_PORT_ACL       (INCLUDE_SRC_PORT_ACL),
        .INCLUDE_DEST_PORT_ACL      (INCLUDE_DEST_PORT_ACL),
        .INCLUDE_DEST_PORT_CAM      (INCLUDE_DEST_PORT_CAM)
    )
    parse
    (
        .axis_out_tdata     (axis_buff_tdata),
        .axis_out_tid       (axis_buff_tid),
        .axis_out_tdest     (axis_buff_tdest),
        .axis_out_tkeep     (axis_buff_tkeep),
        .axis_out_tlast     (axis_buff_tlast),
        .axis_out_tvalid    (axis_buff_tvalid),
        .axis_out_tready    (axis_buff_tready),
        .*
    );



    //--------------------------------------------------------//
    //   Retiming registers                                   //
    //--------------------------------------------------------//

    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (PORT_TUSER_OUT_WIDTH+EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      ({axis_pack_out_tuser,axis_buff_tid,axis_buff_tdest}),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tuser,axis_out_tid,axis_out_tdest}),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );
    



endmodule

`default_nettype wire