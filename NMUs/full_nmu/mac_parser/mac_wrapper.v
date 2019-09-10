`timescale 1ns / 1ps
`default_nettype none




//MAC field constants
`define DA_MAC_SIZE 48
`define SA_MAC_SIZE 48
`define ET_SIZE 16




//The MAC Parser Module
module mac_wrapper
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

    //Packed input signals size
    localparam MAC_TUSER_IN_WIDTH = NUM_AXIS_ID,
    localparam MAC_TUSER_OUT_WDITH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + `ET_SIZE + 8,
    localparam MAC_CONFIG_SEL_WIDTH = EFF_ID_WIDTH + EFF_DEST_WIDTH,
    localparam MAC_CONFIG_REG_WIDTH = `SA_MAC_SIZE + `DA_MAC_SIZE + 4,
    localparam MAC_CAM_WIDTH = (`SA_MAC_SIZE + 1) * NUM_AXIS_ID,

    //Features to implement
    parameter INGRESS = 0,
    parameter INCLUDE_MAC_NEXT_ACL = 1,
    parameter INCLUDE_MAC_SRC_ACL = 1,
    parameter INCLUDE_MAC_DEST_ACL = 1,
    parameter INCLUDE_MAC_DEST_CAM = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [(2**AXIS_ID_WIDTH)-1:0]   axis_in_tuser, // [MAC_TUSER_IN_WIDTH-1:0]
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
    output wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+`ET_SIZE+8)-1:0] // [MAC_TUSER_OUT_WDITH-1:0]
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
                                            mac_config_sel,
    input wire [(`SA_MAC_SIZE+`DA_MAC_SIZE+4)-1:0]   
                                            mac_config_regs,
    input wire [((`SA_MAC_SIZE+1)*(2**AXIS_ID_WIDTH))-1:0]          
                                            mac_cam_values,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);



    mac_wrap_sv
    #(
        .AXIS_BUS_WIDTH          (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH           (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH         (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH       (MAX_PACKET_LENGTH),
        .INGRESS                 (INGRESS),
        .INCLUDE_MAC_NEXT_ACL    (INCLUDE_MAC_NEXT_ACL),
        .INCLUDE_MAC_SRC_ACL     (INCLUDE_MAC_SRC_ACL),
        .INCLUDE_MAC_DEST_ACL    (INCLUDE_MAC_DEST_ACL),
        .INCLUDE_MAC_DEST_CAM    (INCLUDE_MAC_DEST_CAM)    
    )
    parse
    (
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tuser (axis_in_tuser),
        .axis_in_tid (axis_in_tid),
        .axis_in_tdest (axis_in_tdest),                                          
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),
        
        .axis_out_tdata (axis_out_tdata),
        .axis_out_tuser (axis_out_tuser),
        .axis_out_tid (axis_out_tid),
        .axis_out_tdest (axis_out_tdest),                                           
        .axis_out_tkeep (axis_out_tkeep),
        .axis_out_tlast (axis_out_tlast),
        .axis_out_tvalid (axis_out_tvalid),
        .axis_out_tready (axis_out_tready),

        .mac_config_sel (mac_config_sel),
        .mac_config_regs (mac_config_regs),
        .mac_cam_values (mac_cam_values),

        .aclk (aclk),
        .aresetn (aresetn)
    );




endmodule

`default_nettype wire