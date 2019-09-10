`timescale 1ns / 1ps
`default_nettype none


//Number of masters
`define NUM_MASTERS 4
`define INC_M1
`define INC_M2
`define INC_M3
`define INC_M4
//`define INC_M5
//`define INC_M6
//`define INC_M7
//`define INC_M8

//The memory prtocol checker/corrector
module net_bw_throttler_multi_wrap_sv
#(
    //AXIS Interface Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam BW_THROT_BITS_PER_MAST = (TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH + 1),
    localparam BW_THROT_REG_WIDTH =  BW_THROT_BITS_PER_MAST * `NUM_MASTERS
)
(

`ifdef INC_M1

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in1_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in1_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in1_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in1_tkeep,
    input wire                                                  axis_egr_in1_tlast,
    input wire                                                  axis_egr_in1_tvalid,
    output wire                                                 axis_egr_in1_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out1_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out1_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out1_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out1_tkeep,
    output wire                                                 axis_egr_out1_tlast,
    output wire                                                 axis_egr_out1_tvalid,
    input wire                                                  axis_egr_out1_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in1_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in1_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in1_tkeep,
    input wire                                                  axis_ingr_in1_tlast,
    input wire                                                  axis_ingr_in1_tvalid,
    output wire                                                 axis_ingr_in1_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out1_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out1_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out1_tkeep,
    output wire                                                 axis_ingr_out1_tlast,
    output wire                                                 axis_ingr_out1_tvalid,
    input wire                                                  axis_ingr_out1_tready,

`endif

`ifdef INC_M2

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in2_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in2_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in2_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in2_tkeep,
    input wire                                                  axis_egr_in2_tlast,
    input wire                                                  axis_egr_in2_tvalid,
    output wire                                                 axis_egr_in2_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out2_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out2_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out2_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out2_tkeep,
    output wire                                                 axis_egr_out2_tlast,
    output wire                                                 axis_egr_out2_tvalid,
    input wire                                                  axis_egr_out2_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in2_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in2_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in2_tkeep,
    input wire                                                  axis_ingr_in2_tlast,
    input wire                                                  axis_ingr_in2_tvalid,
    output wire                                                 axis_ingr_in2_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out2_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out2_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out2_tkeep,
    output wire                                                 axis_ingr_out2_tlast,
    output wire                                                 axis_ingr_out2_tvalid,
    input wire                                                  axis_ingr_out2_tready,

`endif

`ifdef INC_M3

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in3_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in3_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in3_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in3_tkeep,
    input wire                                                  axis_egr_in3_tlast,
    input wire                                                  axis_egr_in3_tvalid,
    output wire                                                 axis_egr_in3_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out3_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out3_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out3_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out3_tkeep,
    output wire                                                 axis_egr_out3_tlast,
    output wire                                                 axis_egr_out3_tvalid,
    input wire                                                  axis_egr_out3_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in3_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in3_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in3_tkeep,
    input wire                                                  axis_ingr_in3_tlast,
    input wire                                                  axis_ingr_in3_tvalid,
    output wire                                                 axis_ingr_in3_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out3_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out3_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out3_tkeep,
    output wire                                                 axis_ingr_out3_tlast,
    output wire                                                 axis_ingr_out3_tvalid,
    input wire                                                  axis_ingr_out3_tready,

`endif

`ifdef INC_M4

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in4_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in4_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in4_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in4_tkeep,
    input wire                                                  axis_egr_in4_tlast,
    input wire                                                  axis_egr_in4_tvalid,
    output wire                                                 axis_egr_in4_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out4_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out4_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out4_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out4_tkeep,
    output wire                                                 axis_egr_out4_tlast,
    output wire                                                 axis_egr_out4_tvalid,
    input wire                                                  axis_egr_out4_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in4_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in4_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in4_tkeep,
    input wire                                                  axis_ingr_in4_tlast,
    input wire                                                  axis_ingr_in4_tvalid,
    output wire                                                 axis_ingr_in4_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out4_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out4_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out4_tkeep,
    output wire                                                 axis_ingr_out4_tlast,
    output wire                                                 axis_ingr_out4_tvalid,
    input wire                                                  axis_ingr_out4_tready,

`endif

`ifdef INC_M5

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in5_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in5_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in5_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in5_tkeep,
    input wire                                                  axis_egr_in5_tlast,
    input wire                                                  axis_egr_in5_tvalid,
    output wire                                                 axis_egr_in5_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out5_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out5_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out5_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out5_tkeep,
    output wire                                                 axis_egr_out5_tlast,
    output wire                                                 axis_egr_out5_tvalid,
    input wire                                                  axis_egr_out5_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in5_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in5_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in5_tkeep,
    input wire                                                  axis_ingr_in5_tlast,
    input wire                                                  axis_ingr_in5_tvalid,
    output wire                                                 axis_ingr_in5_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out5_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out5_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out5_tkeep,
    output wire                                                 axis_ingr_out5_tlast,
    output wire                                                 axis_ingr_out5_tvalid,
    input wire                                                  axis_ingr_out5_tready,

`endif

`ifdef INC_M6

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in6_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in6_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in6_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in6_tkeep,
    input wire                                                  axis_egr_in6_tlast,
    input wire                                                  axis_egr_in6_tvalid,
    output wire                                                 axis_egr_in6_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out6_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out6_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out6_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out6_tkeep,
    output wire                                                 axis_egr_out6_tlast,
    output wire                                                 axis_egr_out6_tvalid,
    input wire                                                  axis_egr_out6_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in6_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in6_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in6_tkeep,
    input wire                                                  axis_ingr_in6_tlast,
    input wire                                                  axis_ingr_in6_tvalid,
    output wire                                                 axis_ingr_in6_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out6_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out6_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out6_tkeep,
    output wire                                                 axis_ingr_out6_tlast,
    output wire                                                 axis_ingr_out6_tvalid,
    input wire                                                  axis_ingr_out6_tready,

`endif

`ifdef INC_M7

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in7_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in7_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in7_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in7_tkeep,
    input wire                                                  axis_egr_in7_tlast,
    input wire                                                  axis_egr_in7_tvalid,
    output wire                                                 axis_egr_in7_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out7_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out7_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out7_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out7_tkeep,
    output wire                                                 axis_egr_out7_tlast,
    output wire                                                 axis_egr_out7_tvalid,
    input wire                                                  axis_egr_out7_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in7_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in7_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in7_tkeep,
    input wire                                                  axis_ingr_in7_tlast,
    input wire                                                  axis_ingr_in7_tvalid,
    output wire                                                 axis_ingr_in7_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out7_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out7_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out7_tkeep,
    output wire                                                 axis_ingr_out7_tlast,
    output wire                                                 axis_ingr_out7_tvalid,
    input wire                                                  axis_ingr_out7_tready,

`endif

`ifdef INC_M8

    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in8_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in8_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in8_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in8_tkeep,
    input wire                                                  axis_egr_in8_tlast,
    input wire                                                  axis_egr_in8_tvalid,
    output wire                                                 axis_egr_in8_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out8_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out8_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out8_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out8_tkeep,
    output wire                                                 axis_egr_out8_tlast,
    output wire                                                 axis_egr_out8_tvalid,
    input wire                                                  axis_egr_out8_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in8_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in8_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in8_tkeep,
    input wire                                                  axis_ingr_in8_tlast,
    input wire                                                  axis_ingr_in8_tvalid,
    output wire                                                 axis_ingr_in8_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out8_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out8_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out8_tkeep,
    output wire                                                 axis_ingr_out8_tlast,
    output wire                                                 axis_ingr_out8_tvalid,
    input wire                                                  axis_ingr_out8_tready,

`endif

    //Packed Register signals
    input wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*`NUM_MASTERS)-1:0]     
                                            bw_throt_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Input signal declarations                            //
    //--------------------------------------------------------//
    
    //Egress Input AXI stream
    wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_in_all_tdata [`NUM_MASTERS-1:0];
    wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_in_all_tid [`NUM_MASTERS-1:0];
    wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_in_all_tdest [`NUM_MASTERS-1:0];                                          
    wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_in_all_tkeep [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_in_all_tlast [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_in_all_tvalid [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_in_all_tready [`NUM_MASTERS-1:0];

    //Egress Output AXI stream
    wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out_all_tdata [`NUM_MASTERS-1:0];
    wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out_all_tid [`NUM_MASTERS-1:0];
    wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out_all_tdest [`NUM_MASTERS-1:0];                                           
    wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out_all_tkeep [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_out_all_tlast [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_out_all_tvalid [`NUM_MASTERS-1:0];
    wire                                                 axis_egr_out_all_tready [`NUM_MASTERS-1:0];

    //Ingress Input AXI stream
    wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_in_all_tdata [`NUM_MASTERS-1:0];
    wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_in_all_tdest [`NUM_MASTERS-1:0];
    wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_in_all_tkeep [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_in_all_tlast [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_in_all_tvalid [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_in_all_tready [`NUM_MASTERS-1:0];

    //Ingress Output AXI stream
    wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out_all_tdata [`NUM_MASTERS-1:0];
    wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out_all_tdest [`NUM_MASTERS-1:0];
    wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out_all_tkeep [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_out_all_tlast [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_out_all_tvalid [`NUM_MASTERS-1:0];
    wire                                                 axis_ingr_out_all_tready [`NUM_MASTERS-1:0];



    //--------------------------------------------------------//
    //   AXI Input Assignments                                //
    //--------------------------------------------------------//    

`ifdef INC_M1

    assign axis_egr_in_all_tdata[0] = axis_egr_in1_tdata;
    assign axis_egr_in_all_tid[0] = axis_egr_in1_tid;
    assign axis_egr_in_all_tdest[0] = axis_egr_in1_tdest;
    assign axis_egr_in_all_tkeep[0] = axis_egr_in1_tkeep;
    assign axis_egr_in_all_tlast[0] = axis_egr_in1_tlast;
    assign axis_egr_in_all_tvalid[0] = axis_egr_in1_tvalid;
    assign axis_egr_in1_tready = axis_egr_in_all_tready[0];

    assign axis_egr_out1_tdata = axis_egr_out_all_tdata[0];
    assign axis_egr_out1_tid = axis_egr_out_all_tid[0];
    assign axis_egr_out1_tdest = axis_egr_out_all_tdest[0];
    assign axis_egr_out1_tkeep = axis_egr_out_all_tkeep[0];
    assign axis_egr_out1_tlast = axis_egr_out_all_tlast[0];
    assign axis_egr_out1_tvalid = axis_egr_out_all_tvalid[0];
    assign axis_egr_out_all_tready[0] = axis_egr_out1_tready;

    assign axis_ingr_in_all_tdata[0] = axis_ingr_in1_tdata;
    assign axis_ingr_in_all_tdest[0] = axis_ingr_in1_tdest;
    assign axis_ingr_in_all_tkeep[0] = axis_ingr_in1_tkeep;
    assign axis_ingr_in_all_tlast[0] = axis_ingr_in1_tlast;
    assign axis_ingr_in_all_tvalid[0] = axis_ingr_in1_tvalid;
    assign axis_ingr_in1_tready = axis_ingr_in_all_tready[0];

    assign axis_ingr_out1_tdata = axis_ingr_out_all_tdata[0];
    assign axis_ingr_out1_tdest = axis_ingr_out_all_tdest[0];
    assign axis_ingr_out1_tkeep = axis_ingr_out_all_tkeep[0];
    assign axis_ingr_out1_tlast = axis_ingr_out_all_tlast[0];
    assign axis_ingr_out1_tvalid = axis_ingr_out_all_tvalid[0];
    assign axis_ingr_out_all_tready[0] = axis_ingr_out1_tready;

`endif

`ifdef INC_M2

    assign axis_egr_in_all_tdata[1] = axis_egr_in2_tdata;
    assign axis_egr_in_all_tid[1] = axis_egr_in2_tid;
    assign axis_egr_in_all_tdest[1] = axis_egr_in2_tdest;
    assign axis_egr_in_all_tkeep[1] = axis_egr_in2_tkeep;
    assign axis_egr_in_all_tlast[1] = axis_egr_in2_tlast;
    assign axis_egr_in_all_tvalid[1] = axis_egr_in2_tvalid;
    assign axis_egr_in2_tready = axis_egr_in_all_tready[1];

    assign axis_egr_out2_tdata = axis_egr_out_all_tdata[1];
    assign axis_egr_out2_tid = axis_egr_out_all_tid[1];
    assign axis_egr_out2_tdest = axis_egr_out_all_tdest[1];
    assign axis_egr_out2_tkeep = axis_egr_out_all_tkeep[1];
    assign axis_egr_out2_tlast = axis_egr_out_all_tlast[1];
    assign axis_egr_out2_tvalid = axis_egr_out_all_tvalid[1];
    assign axis_egr_out_all_tready[1] = axis_egr_out2_tready;

    assign axis_ingr_in_all_tdata[1] = axis_ingr_in2_tdata;
    assign axis_ingr_in_all_tdest[1] = axis_ingr_in2_tdest;
    assign axis_ingr_in_all_tkeep[1] = axis_ingr_in2_tkeep;
    assign axis_ingr_in_all_tlast[1] = axis_ingr_in2_tlast;
    assign axis_ingr_in_all_tvalid[1] = axis_ingr_in2_tvalid;
    assign axis_ingr_in2_tready = axis_ingr_in_all_tready[1];

    assign axis_ingr_out2_tdata = axis_ingr_out_all_tdata[1];
    assign axis_ingr_out2_tdest = axis_ingr_out_all_tdest[1];
    assign axis_ingr_out2_tkeep = axis_ingr_out_all_tkeep[1];
    assign axis_ingr_out2_tlast = axis_ingr_out_all_tlast[1];
    assign axis_ingr_out2_tvalid = axis_ingr_out_all_tvalid[1];
    assign axis_ingr_out_all_tready[1] = axis_ingr_out2_tready;

`endif 

`ifdef INC_M3

    assign axis_egr_in_all_tdata[2] = axis_egr_in3_tdata;
    assign axis_egr_in_all_tid[2] = axis_egr_in3_tid;
    assign axis_egr_in_all_tdest[2] = axis_egr_in3_tdest;
    assign axis_egr_in_all_tkeep[2] = axis_egr_in3_tkeep;
    assign axis_egr_in_all_tlast[2] = axis_egr_in3_tlast;
    assign axis_egr_in_all_tvalid[2] = axis_egr_in3_tvalid;
    assign axis_egr_in3_tready = axis_egr_in_all_tready[2];

    assign axis_egr_out3_tdata = axis_egr_out_all_tdata[2];
    assign axis_egr_out3_tid = axis_egr_out_all_tid[2];
    assign axis_egr_out3_tdest = axis_egr_out_all_tdest[2];
    assign axis_egr_out3_tkeep = axis_egr_out_all_tkeep[2];
    assign axis_egr_out3_tlast = axis_egr_out_all_tlast[2];
    assign axis_egr_out3_tvalid = axis_egr_out_all_tvalid[2];
    assign axis_egr_out_all_tready[2] = axis_egr_out3_tready;

    assign axis_ingr_in_all_tdata[2] = axis_ingr_in3_tdata;
    assign axis_ingr_in_all_tdest[2] = axis_ingr_in3_tdest;
    assign axis_ingr_in_all_tkeep[2] = axis_ingr_in3_tkeep;
    assign axis_ingr_in_all_tlast[2] = axis_ingr_in3_tlast;
    assign axis_ingr_in_all_tvalid[2] = axis_ingr_in3_tvalid;
    assign axis_ingr_in3_tready = axis_ingr_in_all_tready[2];

    assign axis_ingr_out3_tdata = axis_ingr_out_all_tdata[2];
    assign axis_ingr_out3_tdest = axis_ingr_out_all_tdest[2];
    assign axis_ingr_out3_tkeep = axis_ingr_out_all_tkeep[2];
    assign axis_ingr_out3_tlast = axis_ingr_out_all_tlast[2];
    assign axis_ingr_out3_tvalid = axis_ingr_out_all_tvalid[2];
    assign axis_ingr_out_all_tready[2] = axis_ingr_out3_tready;

`endif 

`ifdef INC_M4

   assign axis_egr_in_all_tdata[3] = axis_egr_in4_tdata;
    assign axis_egr_in_all_tid[3] = axis_egr_in4_tid;
    assign axis_egr_in_all_tdest[3] = axis_egr_in4_tdest;
    assign axis_egr_in_all_tkeep[3] = axis_egr_in4_tkeep;
    assign axis_egr_in_all_tlast[3] = axis_egr_in4_tlast;
    assign axis_egr_in_all_tvalid[3] = axis_egr_in4_tvalid;
    assign axis_egr_in4_tready = axis_egr_in_all_tready[3];

    assign axis_egr_out4_tdata = axis_egr_out_all_tdata[3];
    assign axis_egr_out4_tid = axis_egr_out_all_tid[3];
    assign axis_egr_out4_tdest = axis_egr_out_all_tdest[3];
    assign axis_egr_out4_tkeep = axis_egr_out_all_tkeep[3];
    assign axis_egr_out4_tlast = axis_egr_out_all_tlast[3];
    assign axis_egr_out4_tvalid = axis_egr_out_all_tvalid[3];
    assign axis_egr_out_all_tready[3] = axis_egr_out4_tready;

    assign axis_ingr_in_all_tdata[3] = axis_ingr_in4_tdata;
    assign axis_ingr_in_all_tdest[3] = axis_ingr_in4_tdest;
    assign axis_ingr_in_all_tkeep[3] = axis_ingr_in4_tkeep;
    assign axis_ingr_in_all_tlast[3] = axis_ingr_in4_tlast;
    assign axis_ingr_in_all_tvalid[3] = axis_ingr_in4_tvalid;
    assign axis_ingr_in4_tready = axis_ingr_in_all_tready[3];

    assign axis_ingr_out4_tdata = axis_ingr_out_all_tdata[3];
    assign axis_ingr_out4_tdest = axis_ingr_out_all_tdest[3];
    assign axis_ingr_out4_tkeep = axis_ingr_out_all_tkeep[3];
    assign axis_ingr_out4_tlast = axis_ingr_out_all_tlast[3];
    assign axis_ingr_out4_tvalid = axis_ingr_out_all_tvalid[3];
    assign axis_ingr_out_all_tready[3] = axis_ingr_out4_tready;

`endif 

`ifdef INC_M5

    assign axis_egr_in_all_tdata[4] = axis_egr_in5_tdata;
    assign axis_egr_in_all_tid[4] = axis_egr_in5_tid;
    assign axis_egr_in_all_tdest[4] = axis_egr_in5_tdest;
    assign axis_egr_in_all_tkeep[4] = axis_egr_in5_tkeep;
    assign axis_egr_in_all_tlast[4] = axis_egr_in5_tlast;
    assign axis_egr_in_all_tvalid[4] = axis_egr_in5_tvalid;
    assign axis_egr_in5_tready = axis_egr_in_all_tready[4];

    assign axis_egr_out5_tdata = axis_egr_out_all_tdata[4];
    assign axis_egr_out5_tid = axis_egr_out_all_tid[4];
    assign axis_egr_out5_tdest = axis_egr_out_all_tdest[4];
    assign axis_egr_out5_tkeep = axis_egr_out_all_tkeep[4];
    assign axis_egr_out5_tlast = axis_egr_out_all_tlast[4];
    assign axis_egr_out5_tvalid = axis_egr_out_all_tvalid[4];
    assign axis_egr_out_all_tready[4] = axis_egr_out5_tready;

    assign axis_ingr_in_all_tdata[4] = axis_ingr_in5_tdata;
    assign axis_ingr_in_all_tdest[4] = axis_ingr_in5_tdest;
    assign axis_ingr_in_all_tkeep[4] = axis_ingr_in5_tkeep;
    assign axis_ingr_in_all_tlast[4] = axis_ingr_in5_tlast;
    assign axis_ingr_in_all_tvalid[4] = axis_ingr_in5_tvalid;
    assign axis_ingr_in5_tready = axis_ingr_in_all_tready[4];

    assign axis_ingr_out5_tdata = axis_ingr_out_all_tdata[4];
    assign axis_ingr_out5_tdest = axis_ingr_out_all_tdest[4];
    assign axis_ingr_out5_tkeep = axis_ingr_out_all_tkeep[4];
    assign axis_ingr_out5_tlast = axis_ingr_out_all_tlast[4];
    assign axis_ingr_out5_tvalid = axis_ingr_out_all_tvalid[4];
    assign axis_ingr_out_all_tready[4] = axis_ingr_out5_tready;

`endif 

`ifdef INC_M6

   assign axis_egr_in_all_tdata[5] = axis_egr_in6_tdata;
    assign axis_egr_in_all_tid[5] = axis_egr_in6_tid;
    assign axis_egr_in_all_tdest[5] = axis_egr_in6_tdest;
    assign axis_egr_in_all_tkeep[5] = axis_egr_in6_tkeep;
    assign axis_egr_in_all_tlast[5] = axis_egr_in6_tlast;
    assign axis_egr_in_all_tvalid[5] = axis_egr_in6_tvalid;
    assign axis_egr_in6_tready = axis_egr_in_all_tready[5];

    assign axis_egr_out6_tdata = axis_egr_out_all_tdata[5];
    assign axis_egr_out6_tid = axis_egr_out_all_tid[5];
    assign axis_egr_out6_tdest = axis_egr_out_all_tdest[5];
    assign axis_egr_out6_tkeep = axis_egr_out_all_tkeep[5];
    assign axis_egr_out6_tlast = axis_egr_out_all_tlast[5];
    assign axis_egr_out6_tvalid = axis_egr_out_all_tvalid[5];
    assign axis_egr_out_all_tready[5] = axis_egr_out6_tready;

    assign axis_ingr_in_all_tdata[5] = axis_ingr_in6_tdata;
    assign axis_ingr_in_all_tdest[5] = axis_ingr_in6_tdest;
    assign axis_ingr_in_all_tkeep[5] = axis_ingr_in6_tkeep;
    assign axis_ingr_in_all_tlast[5] = axis_ingr_in6_tlast;
    assign axis_ingr_in_all_tvalid[5] = axis_ingr_in6_tvalid;
    assign axis_ingr_in6_tready = axis_ingr_in_all_tready[5];

    assign axis_ingr_out6_tdata = axis_ingr_out_all_tdata[5];
    assign axis_ingr_out6_tdest = axis_ingr_out_all_tdest[5];
    assign axis_ingr_out6_tkeep = axis_ingr_out_all_tkeep[5];
    assign axis_ingr_out6_tlast = axis_ingr_out_all_tlast[5];
    assign axis_ingr_out6_tvalid = axis_ingr_out_all_tvalid[5];
    assign axis_ingr_out_all_tready[5] = axis_ingr_out6_tready;

`endif 

`ifdef INC_M7

    assign axis_egr_in_all_tdata[6] = axis_egr_in7_tdata;
    assign axis_egr_in_all_tid[6] = axis_egr_in7_tid;
    assign axis_egr_in_all_tdest[6] = axis_egr_in7_tdest;
    assign axis_egr_in_all_tkeep[6] = axis_egr_in7_tkeep;
    assign axis_egr_in_all_tlast[6] = axis_egr_in7_tlast;
    assign axis_egr_in_all_tvalid[6] = axis_egr_in7_tvalid;
    assign axis_egr_in7_tready = axis_egr_in_all_tready[6];

    assign axis_egr_out7_tdata = axis_egr_out_all_tdata[6];
    assign axis_egr_out7_tid = axis_egr_out_all_tid[6];
    assign axis_egr_out7_tdest = axis_egr_out_all_tdest[6];
    assign axis_egr_out7_tkeep = axis_egr_out_all_tkeep[6];
    assign axis_egr_out7_tlast = axis_egr_out_all_tlast[6];
    assign axis_egr_out7_tvalid = axis_egr_out_all_tvalid[6];
    assign axis_egr_out_all_tready[6] = axis_egr_out7_tready;

    assign axis_ingr_in_all_tdata[6] = axis_ingr_in7_tdata;
    assign axis_ingr_in_all_tdest[6] = axis_ingr_in7_tdest;
    assign axis_ingr_in_all_tkeep[6] = axis_ingr_in7_tkeep;
    assign axis_ingr_in_all_tlast[6] = axis_ingr_in7_tlast;
    assign axis_ingr_in_all_tvalid[6] = axis_ingr_in7_tvalid;
    assign axis_ingr_in7_tready = axis_ingr_in_all_tready[6];

    assign axis_ingr_out7_tdata = axis_ingr_out_all_tdata[6];
    assign axis_ingr_out7_tdest = axis_ingr_out_all_tdest[6];
    assign axis_ingr_out7_tkeep = axis_ingr_out_all_tkeep[6];
    assign axis_ingr_out7_tlast = axis_ingr_out_all_tlast[6];
    assign axis_ingr_out7_tvalid = axis_ingr_out_all_tvalid[6];
    assign axis_ingr_out_all_tready[6] = axis_ingr_out7_tready;

`endif 

`ifdef INC_M8

    assign axis_egr_in_all_tdata[7] = axis_egr_in8_tdata;
    assign axis_egr_in_all_tid[7] = axis_egr_in8_tid;
    assign axis_egr_in_all_tdest[7] = axis_egr_in8_tdest;
    assign axis_egr_in_all_tkeep[7] = axis_egr_in8_tkeep;
    assign axis_egr_in_all_tlast[7] = axis_egr_in8_tlast;
    assign axis_egr_in_all_tvalid[7] = axis_egr_in8_tvalid;
    assign axis_egr_in8_tready = axis_egr_in_all_tready[7];

    assign axis_egr_out8_tdata = axis_egr_out_all_tdata[7];
    assign axis_egr_out8_tid = axis_egr_out_all_tid[7];
    assign axis_egr_out8_tdest = axis_egr_out_all_tdest[7];
    assign axis_egr_out8_tkeep = axis_egr_out_all_tkeep[7];
    assign axis_egr_out8_tlast = axis_egr_out_all_tlast[7];
    assign axis_egr_out8_tvalid = axis_egr_out_all_tvalid[7];
    assign axis_egr_out_all_tready[7] = axis_egr_out8_tready;

    assign axis_ingr_in_all_tdata[7] = axis_ingr_in8_tdata;
    assign axis_ingr_in_all_tdest[7] = axis_ingr_in8_tdest;
    assign axis_ingr_in_all_tkeep[7] = axis_ingr_in8_tkeep;
    assign axis_ingr_in_all_tlast[7] = axis_ingr_in8_tlast;
    assign axis_ingr_in_all_tvalid[7] = axis_ingr_in8_tvalid;
    assign axis_ingr_in8_tready = axis_ingr_in_all_tready[7];

    assign axis_ingr_out8_tdata = axis_ingr_out_all_tdata[7];
    assign axis_ingr_out8_tdest = axis_ingr_out_all_tdest[7];
    assign axis_ingr_out8_tkeep = axis_ingr_out_all_tkeep[7];
    assign axis_ingr_out8_tlast = axis_ingr_out_all_tlast[7];
    assign axis_ingr_out8_tvalid = axis_ingr_out_all_tvalid[7];
    assign axis_ingr_out_all_tready[7] = axis_ingr_out8_tready;

`endif



    //--------------------------------------------------------//
    //   Unpack Register values                               //
    //--------------------------------------------------------// 

    wire [TOKEN_COUNT_INT_WIDTH-1:0]  init_token [`NUM_MASTERS-1:0];
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token [`NUM_MASTERS-1:0];

    genvar j;
    generate for(j = 0; j < `NUM_MASTERS; j = j + 1) begin : reg_unpack

        assign {upd_token[j],init_token[j]}
            = bw_throt_regs[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST];

    end endgenerate



    //--------------------------------------------------------//
    //   Instantiate throttlers                               //
    //--------------------------------------------------------// 

    net_bw_throttler_multi
    #(
        .AXIS_BUS_WIDTH         (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH          (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH        (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH      (MAX_PACKET_LENGTH),
        .NUM_MASTERS            (`NUM_MASTERS),
        .TOKEN_COUNT_INT_WIDTH  (TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH (TOKEN_COUNT_FRAC_WIDTH)
    )
    thottles 
    (
        .*
    );



endmodule

`default_nettype wire