`timescale 1ns / 1ps
`default_nettype none




//VSID field constants
`define VSID_SIZE 32
`define DA_MAC_SIZE 48




//The VSID Parser
module vsid_wrap_sv
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),
    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET+1),

    //Packed input signals size
    localparam VSID_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 5,
    localparam VSID_TUSER_OUT_WIDTH = NUM_AXIS_ID + 5,
    localparam VSID_CONFIG_REG_WIDTH = 1,
    localparam VSID_CAM_WIDTH = (`VSID_SIZE + `DA_MAC_SIZE + 2) * NUM_AXIS_ID,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+5)-1:0] // [VSID_TUSER_IN_WIDTH-1:0]
                                          axis_in_tuser,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((2**AXIS_ID_WIDTH)+5)-1:0] // [VSID_TUSER_OUT_WIDTH-1:0] 
                                          axis_out_tuser,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    input wire [(1)-1:0]                  vsid_config_regs,
    input wire [((`VSID_SIZE+`DA_MAC_SIZE+2)*(2**AXIS_ID_WIDTH))-1:0]
                                          vsid_cam_values,

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
    wire                          has_udp_checksum_in;
    wire [PACKET_LENGTH_CBITS-1:0]  cur_pos;
    wire [MAX_ADDED_OFFSET_CBITS-1:0]  added_offset;
    wire                          next_can_have_vsid;

    assign {next_can_have_vsid,added_offset,cur_pos,has_udp_checksum_in,
            next_is_config_in,parsing_done_in,poisoned_in,route_mask_in}
    = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask_out;
    wire                         poisoned_out;
    wire                         parsing_done_out;
    wire                         next_is_config_out;
    wire                         has_udp_checksum_out;
    wire                         parsing_vsid_done;

    wire [VSID_TUSER_OUT_WIDTH-1:0] axis_pack_out_tuser = 
        {parsing_vsid_done,has_udp_checksum_out,next_is_config_out,
         parsing_done_out,poisoned_out,route_mask_out};

    //Configuration signal declarations
    wire                          is_vxlan = vsid_config_regs;

    //Unpack Cam contents
    wire [`VSID_SIZE-1:0]         vsids [NUM_AXIS_ID-1:0];
    wire                          vsid_cam_must_match [NUM_AXIS_ID-1:0];
    wire [`DA_MAC_SIZE-1:0]       mac_encap_addresses [NUM_AXIS_ID-1:0];
    wire                          mac_encap_cam_must_match [NUM_AXIS_ID-1:0];

    localparam PER_ID = (`VSID_SIZE + `DA_MAC_SIZE + 2);

    genvar j;
    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : config0 

            assign {mac_encap_cam_must_match[j],mac_encap_addresses[j],vsid_cam_must_match[j],vsids[j]}    
            = vsid_cam_values[(PER_ID*j)+:PER_ID];

        end
    endgenerate



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    vsid_parser
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH)
    )
    parse
    (
        .axis_out_tdata     (axis_buff_tdata),
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
        .AXIS_USER_WIDTH    (VSID_TUSER_OUT_WIDTH),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      (axis_pack_out_tuser),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     (axis_out_tuser),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );
    
    


endmodule

`default_nettype wire