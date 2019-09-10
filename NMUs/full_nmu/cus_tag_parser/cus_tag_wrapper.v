`timescale 1ns / 1ps
`default_nettype none




//Tag field constants
`define ET_SIZE 16
`define TAG_OFFSET 14




//The Tag Parser
module cus_tag_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    parameter MAX_TAG_SIZE_BITS = 64, //bits

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_TAG_BYTES = (MAX_TAG_SIZE_BITS/8),
    localparam LAST_BYTE = `TAG_OFFSET + MAX_TAG_BYTES - 1,

    //Packed input signals size
    localparam CUS_TUSER_OUT_WDITH = NUM_AXIS_ID + 1,
    localparam CUS_TAG_CONFIG_REG_WIDTH = `ET_SIZE,
    localparam CUS_TAG_CAM_WIDTH = ((MAX_TAG_SIZE_BITS*2) + 1) * NUM_AXIS_ID,

    //Features to Implement
    parameter DETAG_ALL_ETYPE_MATCH = 0,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((2**AXIS_ID_WIDTH)+1)-1:0]  axis_out_tuser,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    input wire [(`ET_SIZE)-1:0]            cus_tag_config_regs,
    input wire [(((MAX_TAG_SIZE_BITS*2)+1)*(2**AXIS_ID_WIDTH))-1:0] 
                                          cus_tag_cam_values,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);



    cus_tag_wrap_sv
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        .MAX_TAG_SIZE_BITS          (MAX_TAG_SIZE_BITS),
        .DETAG_ALL_ETYPE_MATCH      (DETAG_ALL_ETYPE_MATCH)
    )
    parse
    (
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),

        .axis_out_tdata (axis_out_tdata),
        .axis_out_tuser (axis_out_tuser),
        .axis_out_tkeep (axis_out_tkeep),
        .axis_out_tlast (axis_out_tlast),
        .axis_out_tvalid (axis_out_tvalid),
        .axis_out_tready (axis_out_tready),

        .cus_tag_config_regs (cus_tag_config_regs),
        .cus_tag_cam_values (cus_tag_cam_values),

        .aclk (aclk),
        .aresetn (aresetn)
    );



endmodule

`default_nettype wire