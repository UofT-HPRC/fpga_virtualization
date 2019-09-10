`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module mem_bw_throttler_multi
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 4,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter AXI_AX_USER_WIDTH = 1,

    parameter NUM_MASTERS = 4,
    
    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,

    //Timeout limits
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,

    //Retiming for adders
    parameter AW_RETIMING_STAGES = 0,
    parameter AR_RETIMING_STAGES = 0,

    //Features to Implement
    parameter bit ALLOW_OVERRIDE = 1,
    parameter bit INCLUDE_BACKPRESSURE = 0
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel
    input wire [AXI_ID_WIDTH-1:0]           in_all_awid [NUM_MASTERS-1:0],
    input wire [AXI_ADDR_WIDTH-1:0]         in_all_awaddr [NUM_MASTERS-1:0],
    input wire [7:0]                        in_all_awlen [NUM_MASTERS-1:0],
    input wire [2:0]                        in_all_awsize [NUM_MASTERS-1:0],
    input wire [1:0]                        in_all_awburst [NUM_MASTERS-1:0],
    input wire [AXI_AX_USER_WIDTH-1:0]      in_all_awuser [NUM_MASTERS-1:0],
    input wire                              in_all_awvalid [NUM_MASTERS-1:0],
    output wire                             in_all_awready [NUM_MASTERS-1:0],
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         in_all_wdata [NUM_MASTERS-1:0],
    input wire [(AXI_DATA_WIDTH/8)-1:0]     in_all_wstrb [NUM_MASTERS-1:0],
    input wire                              in_all_wlast [NUM_MASTERS-1:0],
    input wire                              in_all_wvalid [NUM_MASTERS-1:0],
    output wire                             in_all_wready [NUM_MASTERS-1:0],
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in_all_bid [NUM_MASTERS-1:0],
    output wire [1:0]                       in_all_bresp [NUM_MASTERS-1:0],
    output wire                             in_all_bvalid [NUM_MASTERS-1:0],
    input wire                              in_all_bready [NUM_MASTERS-1:0],
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           in_all_arid [NUM_MASTERS-1:0],
    input wire [AXI_ADDR_WIDTH-1:0]         in_all_araddr [NUM_MASTERS-1:0],
    input wire [7:0]                        in_all_arlen [NUM_MASTERS-1:0],
    input wire [2:0]                        in_all_arsize [NUM_MASTERS-1:0],
    input wire [1:0]                        in_all_arburst [NUM_MASTERS-1:0],
    input wire [AXI_AX_USER_WIDTH-1:0]      in_all_aruser [NUM_MASTERS-1:0],
    input wire                              in_all_arvalid [NUM_MASTERS-1:0],
    output wire                             in_all_arready [NUM_MASTERS-1:0],
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          in_all_rid [NUM_MASTERS-1:0],
    output wire [AXI_DATA_WIDTH-1:0]        in_all_rdata [NUM_MASTERS-1:0],
    output wire [1:0]                       in_all_rresp [NUM_MASTERS-1:0],
    output wire                             in_all_rlast [NUM_MASTERS-1:0],
    output wire                             in_all_rvalid [NUM_MASTERS-1:0],
    input wire                              in_all_rready [NUM_MASTERS-1:0],

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out_all_awid [NUM_MASTERS-1:0],
    output wire [AXI_ADDR_WIDTH-1:0]        out_all_awaddr [NUM_MASTERS-1:0],
    output wire [7:0]                       out_all_awlen [NUM_MASTERS-1:0],
    output wire [2:0]                       out_all_awsize [NUM_MASTERS-1:0],
    output wire [1:0]                       out_all_awburst [NUM_MASTERS-1:0],
    output wire [AXI_AX_USER_WIDTH-1:0]     out_all_awuser [NUM_MASTERS-1:0],
    output wire                             out_all_awvalid [NUM_MASTERS-1:0],
    input wire                              out_all_awready [NUM_MASTERS-1:0],
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        out_all_wdata [NUM_MASTERS-1:0],
    output wire [(AXI_DATA_WIDTH/8)-1:0]    out_all_wstrb [NUM_MASTERS-1:0],
    output wire                             out_all_wlast [NUM_MASTERS-1:0],
    output wire                             out_all_wvalid [NUM_MASTERS-1:0],
    input wire                              out_all_wready [NUM_MASTERS-1:0],
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out_all_bid [NUM_MASTERS-1:0],
    input wire [1:0]                        out_all_bresp [NUM_MASTERS-1:0],
    input wire                              out_all_bvalid [NUM_MASTERS-1:0],
    output wire                             out_all_bready [NUM_MASTERS-1:0],
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          out_all_arid [NUM_MASTERS-1:0],
    output wire [AXI_ADDR_WIDTH-1:0]        out_all_araddr [NUM_MASTERS-1:0],
    output wire [7:0]                       out_all_arlen [NUM_MASTERS-1:0],
    output wire [2:0]                       out_all_arsize [NUM_MASTERS-1:0],
    output wire [1:0]                       out_all_arburst [NUM_MASTERS-1:0],
    output wire [AXI_AX_USER_WIDTH-1:0]     out_all_aruser [NUM_MASTERS-1:0],
    output wire                             out_all_arvalid [NUM_MASTERS-1:0],
    input wire                              out_all_arready [NUM_MASTERS-1:0],
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           out_all_rid [NUM_MASTERS-1:0],
    input wire [AXI_DATA_WIDTH-1:0]         out_all_rdata [NUM_MASTERS-1:0],
    input wire [1:0]                        out_all_rresp [NUM_MASTERS-1:0],
    input wire                              out_all_rlast [NUM_MASTERS-1:0],
    input wire                              out_all_rvalid [NUM_MASTERS-1:0],
    output wire                             out_all_rready [NUM_MASTERS-1:0],

    //Token counter parameters
    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  aw_init_token [NUM_MASTERS-1:0],
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   aw_upd_token [NUM_MASTERS-1:0],

    input wire [TOKEN_COUNT_INT_WIDTH-1:0]  ar_init_token [NUM_MASTERS-1:0],
    input wire [TOKEN_COUNT_FRAC_WIDTH:0]   ar_upd_token [NUM_MASTERS-1:0],

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Override token decoupling
    wire [NUM_MASTERS-1:0] aw_overrides;
    wire [NUM_MASTERS-1:0] ar_overrides;

    wire [NUM_MASTERS-1:0] aw_has_outstanding;
    wire [NUM_MASTERS-1:0] aw_can_override;
    wire [NUM_MASTERS-1:0] ar_has_outstanding;
    wire [NUM_MASTERS-1:0] ar_can_override;



    //--------------------------------------------------------//
    //   Individual Throttlers Instantiated                   //
    //--------------------------------------------------------//

generate for(genvar j = 0; j < NUM_MASTERS; j = j + 1) begin : throttlers

    mem_bw_throttler
    #(
        .AXI_ID_WIDTH           (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .AXI_AX_USER_WIDTH      (AXI_AX_USER_WIDTH),
        .TOKEN_COUNT_INT_WIDTH  (TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH (TOKEN_COUNT_FRAC_WIDTH),
        .WTIMEOUT_CYCLES        (WTIMEOUT_CYCLES),
        .BTIMEOUT_CYCLES        (BTIMEOUT_CYCLES),
        .RTIMEOUT_CYCLES        (RTIMEOUT_CYCLES),
        .OUTSTANDING_WREQ       (OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ       (OUTSTANDING_RREQ),
        .AW_RETIMING_STAGES     (AW_RETIMING_STAGES),
        .AR_RETIMING_STAGES     (AR_RETIMING_STAGES),
        .ALLOW_OVERRIDE         (ALLOW_OVERRIDE),
        .INCLUDE_BACKPRESSURE   (INCLUDE_BACKPRESSURE)
    )
    bw
    (
        .mem_in_awid        (in_all_awid[j]),
        .mem_in_awaddr      (in_all_awaddr[j]),
        .mem_in_awlen       (in_all_awlen[j]),
        .mem_in_awsize      (in_all_awsize[j]),
        .mem_in_awburst     (in_all_awburst[j]),
        .mem_in_awuser      (in_all_awuser[j]),
        .mem_in_awvalid     (in_all_awvalid[j]),
        .mem_in_awready     (in_all_awready[j]),
        
        .mem_in_wdata       (in_all_wdata[j]),
        .mem_in_wstrb       (in_all_wstrb[j]),
        .mem_in_wlast       (in_all_wlast[j]),
        .mem_in_wvalid      (in_all_wvalid[j]),
        .mem_in_wready      (in_all_wready[j]),
        
        .mem_in_bid         (in_all_bid[j]),
        .mem_in_bresp       (in_all_bresp[j]),
        .mem_in_bvalid      (in_all_bvalid[j]),
        .mem_in_bready      (in_all_bready[j]),
             
        .mem_in_arid        (in_all_arid[j]),
        .mem_in_araddr      (in_all_araddr[j]),
        .mem_in_arlen       (in_all_arlen[j]),
        .mem_in_arsize      (in_all_arsize[j]),
        .mem_in_arburst     (in_all_arburst[j]),
        .mem_in_aruser      (in_all_aruser[j]),
        .mem_in_arvalid     (in_all_arvalid[j]),
        .mem_in_arready     (in_all_arready[j]),
        
        .mem_in_rid         (in_all_rid[j]),
        .mem_in_rdata       (in_all_rdata[j]),
        .mem_in_rresp       (in_all_rresp[j]),
        .mem_in_rlast       (in_all_rlast[j]),
        .mem_in_rvalid      (in_all_rvalid[j]),
        .mem_in_rready      (in_all_rready[j]),

   
        .mem_out_awid       (out_all_awid[j]),
        .mem_out_awaddr     (out_all_awaddr[j]),
        .mem_out_awlen      (out_all_awlen[j]),
        .mem_out_awsize     (out_all_awsize[j]),
        .mem_out_awburst    (out_all_awburst[j]),
        .mem_out_awuser     (out_all_awuser[j]),
        .mem_out_awvalid    (out_all_awvalid[j]),
        .mem_out_awready    (out_all_awready[j]),

        .mem_out_wdata      (out_all_wdata[j]),
        .mem_out_wstrb      (out_all_wstrb[j]),
        .mem_out_wlast      (out_all_wlast[j]),
        .mem_out_wvalid     (out_all_wvalid[j]),
        .mem_out_wready     (out_all_wready[j]),

        .mem_out_bid        (out_all_bid[j]),
        .mem_out_bresp      (out_all_bresp[j]),
        .mem_out_bvalid     (out_all_bvalid[j]),
        .mem_out_bready     (out_all_bready[j]),

        .mem_out_arid       (out_all_arid[j]),
        .mem_out_araddr     (out_all_araddr[j]),
        .mem_out_arlen      (out_all_arlen[j]),
        .mem_out_arsize     (out_all_arsize[j]),
        .mem_out_arburst    (out_all_arburst[j]),
        .mem_out_aruser     (out_all_aruser[j]),
        .mem_out_arvalid    (out_all_arvalid[j]),
        .mem_out_arready    (out_all_arready[j]),

        .mem_out_rid        (out_all_rid[j]),
        .mem_out_rdata      (out_all_rdata[j]),
        .mem_out_rresp      (out_all_rresp[j]),
        .mem_out_rlast      (out_all_rlast[j]),
        .mem_out_rvalid     (out_all_rvalid[j]),
        .mem_out_rready     (out_all_rready[j]),

        .aw_init_token  (aw_init_token[j]),
        .aw_upd_token   (aw_upd_token[j]),
        .ar_init_token  (ar_init_token[j]),
        .ar_upd_token   (ar_upd_token[j]),

        .aw_override        (aw_overrides[j]),
        .ar_override        (ar_overrides[j]),
        .aw_has_outstanding (aw_has_outstanding[j]),
        .aw_can_override    (aw_can_override[j]),
        .ar_has_outstanding (ar_has_outstanding[j]),
        .ar_can_override    (ar_can_override[j]),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );

end endgenerate



    //--------------------------------------------------------//
    //   Overriding Engine Instantiated                       //
    //--------------------------------------------------------//

generate if(ALLOW_OVERRIDE) begin : overrides

    mem_bw_override
    #(
        .NUM_MASTERS (NUM_MASTERS)
    )
    ovr
    (
        .aw_overrides           (aw_overrides),
        .ar_overrides           (ar_overrides),
        .aw_has_outstanding     (aw_has_outstanding),
        .aw_can_override        (aw_can_override),
        .ar_has_outstanding     (ar_has_outstanding),
        .ar_can_override        (ar_can_override),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );

end else begin : overrides_else

    assign aw_overrides = '0;
    assign ar_overrides = '0;
    
end endgenerate



endmodule

`default_nettype wire