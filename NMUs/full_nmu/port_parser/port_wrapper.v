`timescale 1ns / 1ps
`default_nettype none




//Port field constants
`define SPORT_SIZE 16
`define DPORT_SIZE 16




//The Port Parser
module port_wrapper
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



    port_wrap_sv
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

        .port_config_sel (port_config_sel),
        .port_config_regs (port_config_regs),
        .port_cam_values (port_cam_values),

        .aclk (aclk),
        .aresetn (aresetn)
    );    



endmodule

`default_nettype wire