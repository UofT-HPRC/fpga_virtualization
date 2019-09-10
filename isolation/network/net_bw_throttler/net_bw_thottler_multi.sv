`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module net_bw_throttler_multi
#(
    //AXIS Interface Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    parameter NUM_MASTERS = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8
)
(
    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in_all_tdata [NUM_MASTERS-1:0],
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in_all_tid [NUM_MASTERS-1:0],
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in_all_tdest [NUM_MASTERS-1:0],                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in_all_tkeep [NUM_MASTERS-1:0],
    input wire                                                  axis_egr_in_all_tlast [NUM_MASTERS-1:0],
    input wire                                                  axis_egr_in_all_tvalid [NUM_MASTERS-1:0],
    output wire                                                 axis_egr_in_all_tready [NUM_MASTERS-1:0],

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out_all_tdata [NUM_MASTERS-1:0],
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out_all_tid [NUM_MASTERS-1:0],
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out_all_tdest [NUM_MASTERS-1:0],                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out_all_tkeep [NUM_MASTERS-1:0],
    output wire                                                 axis_egr_out_all_tlast [NUM_MASTERS-1:0],
    output wire                                                 axis_egr_out_all_tvalid [NUM_MASTERS-1:0],
    input wire                                                  axis_egr_out_all_tready [NUM_MASTERS-1:0],

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in_all_tdata [NUM_MASTERS-1:0],
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in_all_tdest [NUM_MASTERS-1:0],
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in_all_tkeep [NUM_MASTERS-1:0],
    input wire                                                  axis_ingr_in_all_tlast [NUM_MASTERS-1:0],
    input wire                                                  axis_ingr_in_all_tvalid [NUM_MASTERS-1:0],
    output wire                                                 axis_ingr_in_all_tready [NUM_MASTERS-1:0],

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out_all_tdata [NUM_MASTERS-1:0],
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out_all_tdest [NUM_MASTERS-1:0],
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out_all_tkeep [NUM_MASTERS-1:0],
    output wire                                                 axis_ingr_out_all_tlast [NUM_MASTERS-1:0],
    output wire                                                 axis_ingr_out_all_tvalid [NUM_MASTERS-1:0],
    input wire                                                  axis_ingr_out_all_tready [NUM_MASTERS-1:0],

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  init_token [NUM_MASTERS-1:0],
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token [NUM_MASTERS-1:0],

    //Clocking
    input wire  aclk,
    input wire  aresetn
);



    //--------------------------------------------------------//
    //   Individual Throttlers Instantiated                   //
    //--------------------------------------------------------//

generate for(genvar j = 0; j < NUM_MASTERS; j = j + 1) begin : throttlers

    net_bw_throttler
    #(
        .AXIS_BUS_WIDTH         (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH          (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH        (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH      (MAX_PACKET_LENGTH),
        .TOKEN_COUNT_INT_WIDTH  (TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH (TOKEN_COUNT_FRAC_WIDTH)
    )
    bw
    (
        .axis_egr_in_tdata      (axis_egr_in_all_tdata[j]),
        .axis_egr_in_tid        (axis_egr_in_all_tid[j]),
        .axis_egr_in_tdest      (axis_egr_in_all_tdest[j]),                                          
        .axis_egr_in_tkeep      (axis_egr_in_all_tkeep[j]),
        .axis_egr_in_tlast      (axis_egr_in_all_tlast[j]),
        .axis_egr_in_tvalid     (axis_egr_in_all_tvalid[j]),
        .axis_egr_in_tready     (axis_egr_in_all_tready[j]),

        .axis_egr_out_tdata     (axis_egr_out_all_tdata[j]),
        .axis_egr_out_tid       (axis_egr_out_all_tid[j]),
        .axis_egr_out_tdest     (axis_egr_out_all_tdest[j]),                                           
        .axis_egr_out_tkeep     (axis_egr_out_all_tkeep[j]),
        .axis_egr_out_tlast     (axis_egr_out_all_tlast[j]),
        .axis_egr_out_tvalid    (axis_egr_out_all_tvalid[j]),
        .axis_egr_out_tready    (axis_egr_out_all_tready[j]),

        .axis_ingr_in_tdata     (axis_ingr_in_all_tdata[j]),
        .axis_ingr_in_tdest     (axis_ingr_in_all_tdest[j]),
        .axis_ingr_in_tkeep     (axis_ingr_in_all_tkeep[j]),
        .axis_ingr_in_tlast     (axis_ingr_in_all_tlast[j]),
        .axis_ingr_in_tvalid    (axis_ingr_in_all_tvalid[j]),
        .axis_ingr_in_tready    (axis_ingr_in_all_tready[j]),

        .axis_ingr_out_tdata    (axis_ingr_out_all_tdata[j]),
        .axis_ingr_out_tdest    (axis_ingr_out_all_tdest[j]),
        .axis_ingr_out_tkeep    (axis_ingr_out_all_tkeep[j]),
        .axis_ingr_out_tlast    (axis_ingr_out_all_tlast[j]),
        .axis_ingr_out_tvalid   (axis_ingr_out_all_tvalid[j]),
        .axis_ingr_out_tready   (axis_ingr_out_all_tready[j]),

        .init_token             (init_token[j]),
        .upd_token              (upd_token[j]),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );

end endgenerate



endmodule

`default_nettype wire