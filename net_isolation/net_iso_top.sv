`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Stream Interface Isolation Core Wrapper (Both TX and RX signals)

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module wraps all of the AXI-Stream isolation cores into a single
   module, connecting them together and adding an AXI-Lite control
   interface to control the various cores. This includes a decoupler,
   an AXI-Stream protocol verifier, and a bandwidth shaper. These cores
   are included for TX and RX directions (except bw shaping is only 
   applied to TX direction).

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction
   AXIS_DEST_WIDTH - the width of all AXI DEST sigals (zero is supported)
   MAX_PACKET_LENGTH - the maximum packet length to support (for forced tlast)
   INCLUDE_BW_SHAPER - binary, whether or not to include a bandwidth shaper for tx packets
   DISALLOW_INGR_BACKPRESSURE - binary, whether the rx port is allowed to assert backpressure (the rx_tready overrided if enabled)
   DISALLOW_INVALID_MID_PACKET_EGR - binary, whether to expect (and enforce) a continuous stream of flits for tx
   INCLUDE_TIMEOUT_ERROR_INGR - binary, whether to check for timeouts on rx (useless if rx channel cannot assert backpressure)
   INGR_TIMEOUT_CYCLES - total numner of cycles to wait after tvalid is asserted before indicating an rx timeout
   TOKEN_COUNT_INT_WIDTH - the token count integer component width (fixed point representation)
   TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width (fixed point representation)

AXI-Lite Control Interface Register Space
   We have the following mapping (byte addressable, /4 for word addressable systems)
     [0] Decoupler registers 
          - bit 0 - decouple output register
          - bit 1 - decouple_done input register
          - bits 3..2 - decouple_status_vector input register
     [4] Protocol Verifier Registers
          - bit 0 - oversize_error_clear output register
          - bit 1 - timeout_error_clear output register
          - bit 2 - oversize_error_irq input register
          - bit 3 - timeout_error_irq input register
     [8] Egress Channel Init Token Register
     [12] Egress Channel Update Token Register
     [16] Statistic - number of RX packets dropped while decoupled

Ports:
   axis_tx_s_* - the input axi stream for the tx direction
   axis_tx_m_* - the output axi stream for the tx direction
   axis_rx_s_* - the input axi stream for the rx direction
   axis_rx_m_* - the output axi stream for the rx direction
   ctrl_* - the AXI-Lite control interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module net_iso_top
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Core Options
    parameter INCLUDE_BW_SHAPER = 1,
    parameter DISALLOW_INGR_BACKPRESSURE = 1,
    parameter DISALLOW_INVALID_MID_PACKET_EGR = 1,
    parameter INCLUDE_TIMEOUT_ERROR_INGR = 0,

    //Core Params
    parameter INGR_TIMEOUT_CYCLES = 15,

    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8
)
(
    //Egress Input AXI stream (the master interface to isolate connects to this)
    input wire [AXIS_BUS_WIDTH-1:0]         axis_tx_s_tdata,
    input wire [AXIS_ID_WIDTH-1:0]          axis_tx_s_tid,
    input wire [AXIS_DEST_WIDTH-1:0]        axis_tx_s_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_tx_s_tkeep,
    input wire                              axis_tx_s_tlast,
    input wire                              axis_tx_s_tvalid,
    output wire                             axis_tx_s_tready,

    //Egress Output AXI stream (connects to the slave expecting the isolated signal)
    output wire [AXIS_BUS_WIDTH-1:0]        axis_tx_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]         axis_tx_m_tid,
    output wire [AXIS_DEST_WIDTH-1:0]       axis_tx_m_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_tx_m_tkeep,
    output wire                             axis_tx_m_tlast,
    output wire                             axis_tx_m_tvalid,
    input wire                              axis_tx_m_tready,

    //Ingress Input AXI stream (connects to the master expecting the isolated signal)
    input wire [AXIS_BUS_WIDTH-1:0]         axis_rx_s_tdata,
    input wire [AXIS_ID_WIDTH-1:0]          axis_rx_s_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_rx_s_tkeep,
    input wire                              axis_rx_s_tlast,
    input wire                              axis_rx_s_tvalid,
    output wire                             axis_rx_s_tready,

    //Ingress Output AXI stream (the slave interface to isolate connects to this)
    output wire [AXIS_BUS_WIDTH-1:0]        axis_rx_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]         axis_rx_m_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_rx_m_tkeep,
    output wire                             axis_rx_m_tlast,
    output wire                             axis_rx_m_tvalid,
    input wire                              axis_rx_m_tready,
    
    //The AXI-Lite Control Interface
    //Write Address Channel  
    input wire [31:0]                       ctrl_awaddr,
    input wire                              ctrl_awvalid,
    output reg                              ctrl_awready,
    //Write Data Channel
    input wire [31:0]                       ctrl_wdata,
    //input wire [3:0]                        ctrl_wstrb,
    input wire                              ctrl_wvalid,
    output reg                              ctrl_wready,
    //Write Response Channel
    output reg [1:0]                        ctrl_bresp,
    output reg                              ctrl_bvalid,
    input wire                              ctrl_bready,
    //Read Address Channel 
    input wire [31:0]                       ctrl_araddr,
    input wire                              ctrl_arvalid,
    output reg                              ctrl_arready,
    //Read Data Response Channel
    output reg [31:0]                       ctrl_rdata,
    output reg [1:0]                        ctrl_rresp,
    output reg                              ctrl_rvalid,
    input wire                              ctrl_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   TX Datapath                                          //
    //--------------------------------------------------------//

    //--------------------------------------------------------//
    //   Master Decoupler                                     //
    //--------------------------------------------------------//

    //Axi-stream interface on output of decoupler
    wire [AXIS_BUS_WIDTH-1:0]       axis_tx_decoupled_tdata;
    wire [AXIS_ID_WIDTH-1:0]        axis_tx_decoupled_tid;
    wire [AXIS_DEST_WIDTH-1:0]      axis_tx_decoupled_tdest;
    wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_tx_decoupled_tkeep;
    wire                            axis_tx_decoupled_tlast;
    wire                            axis_tx_decoupled_tvalid;
    wire                            axis_tx_decoupled_tready;

    //Other decoupler signals
    wire decouple;
    wire decouple_force_tx;
    wire decouple_done_tx;
    wire [1:0] decouple_status_vector;
    wire axis_tlast_forced;

    //Decoupler Instantiated
    axi_stream_master_decoupler
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH)
    )
    decoupler_mast_inst
    (
        //Egress Input AXI stream
        .axis_s_tdata      (axis_tx_s_tdata),
        .axis_s_tid        (axis_tx_s_tid),
        .axis_s_tdest      (axis_tx_s_tdest),
        .axis_s_tkeep      (axis_tx_s_tkeep),
        .axis_s_tlast      (axis_tx_s_tlast),
        .axis_s_tvalid     (axis_tx_s_tvalid),
        .axis_s_tready     (axis_tx_s_tready),

        //Egress Output AXI stream
        .axis_m_tdata      (axis_tx_decoupled_tdata),
        .axis_m_tid        (axis_tx_decoupled_tid),
        .axis_m_tdest      (axis_tx_decoupled_tdest),
        .axis_m_tkeep      (axis_tx_decoupled_tkeep),
        .axis_m_tlast      (axis_tx_decoupled_tlast),
        .axis_m_tvalid     (axis_tx_decoupled_tvalid),
        .axis_m_tready     (axis_tx_decoupled_tready),

        //Indicate tlast asserted by protocol corrector
        .axis_tlast_forced      (axis_tlast_forced),

        //Decoupler signals
        .decouple               (decouple),
        .decouple_force         (decouple_force_tx),
        .decouple_done          (decouple_done_tx),
        .decoupled              (decouple_status_vector[0]),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );



    //--------------------------------------------------------//
    //   Master Protocol Verifier                             //
    //--------------------------------------------------------//

    //Axi-stream interface on output of verifier
    wire [AXIS_BUS_WIDTH-1:0]       axis_tx_verified_tdata;
    wire [AXIS_ID_WIDTH-1:0]        axis_tx_verified_tid;
    wire [AXIS_DEST_WIDTH-1:0]      axis_tx_verified_tdest;
    wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_tx_verified_tkeep;
    wire                            axis_tx_verified_tlast;
    wire                            axis_tx_verified_tvalid;
    wire                            axis_tx_verified_tready;

    //Other Verifier Signals
    wire         oversize_error_irq;
    wire         oversize_error_clear;

    //Verifier Instantiated
    axi_stream_master_verifier
    #(
        .AXIS_BUS_WIDTH                     (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH                      (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH                    (AXIS_DEST_WIDTH),
        .MAX_PACKET_LENGTH                  (MAX_PACKET_LENGTH),
        .DISALLOW_INVALID_MID_PACKET        (DISALLOW_INVALID_MID_PACKET_EGR)
    )
    verifier_mast_inst
    (
        //Egress Input AXI stream
        .axis_s_tdata      (axis_tx_decoupled_tdata),
        .axis_s_tid        (axis_tx_decoupled_tid),
        .axis_s_tdest      (axis_tx_decoupled_tdest),
        .axis_s_tkeep      (axis_tx_decoupled_tkeep),
        .axis_s_tlast      (axis_tx_decoupled_tlast),
        .axis_s_tvalid     (axis_tx_decoupled_tvalid),
        .axis_s_tready     (axis_tx_decoupled_tready),

        //Egress Output AXI stream
        .axis_m_tdata      (axis_tx_verified_tdata),
        .axis_m_tid        (axis_tx_verified_tid),
        .axis_m_tdest      (axis_tx_verified_tdest),
        .axis_m_tkeep      (axis_tx_verified_tkeep),
        .axis_m_tlast      (axis_tx_verified_tlast),
        .axis_m_tvalid     (axis_tx_verified_tvalid),
        .axis_m_tready     (axis_tx_verified_tready),

        //Indicate tlast asserted
        .axis_tlast_forced      (axis_tlast_forced),

        //Protocol error indicators
        .oversize_error_irq     (oversize_error_irq),
        .oversize_error_clear   (oversize_error_clear),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

    //Feedback connections to decoupler
    assign decouple_force_tx = oversize_error_irq;



    //--------------------------------------------------------//
    //   Bandwidth Shaper                                     //
    //--------------------------------------------------------//

    //Axi-stream interface on output of BW shaper
    wire [AXIS_BUS_WIDTH-1:0]       axis_tx_shaped_tdata;
    wire [AXIS_ID_WIDTH-1:0]        axis_tx_shaped_tid;
    wire [AXIS_DEST_WIDTH-1:0]      axis_tx_shaped_tdest;
    wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_tx_shaped_tkeep;
    wire                            axis_tx_shaped_tlast;
    wire                            axis_tx_shaped_tvalid;
    wire                            axis_tx_shaped_tready;

    //Other BW shaping signals
    wire [TOKEN_COUNT_INT_WIDTH-1:0]  init_token;
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token;

    generate if(INCLUDE_BW_SHAPER) begin : bw_shaper_if

        //BW shaper instantiated
        axi_stream_bw_shaper
        #(
            .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
            .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
            .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH),
            .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
            .TOKEN_COUNT_INT_WIDTH      (TOKEN_COUNT_INT_WIDTH),
            .TOKEN_COUNT_FRAC_WIDTH     (TOKEN_COUNT_FRAC_WIDTH)
        )
        shaper_inst
        (
            //Egress Input AXI stream
            .axis_s_tdata      (axis_tx_verified_tdata),
            .axis_s_tid        (axis_tx_verified_tid),
            .axis_s_tdest      (axis_tx_verified_tdest),                                          
            .axis_s_tkeep      (axis_tx_verified_tkeep),
            .axis_s_tlast      (axis_tx_verified_tlast),
            .axis_s_tvalid     (axis_tx_verified_tvalid),
            .axis_s_tready     (axis_tx_verified_tready),

            //Egress Output AXI stream
            .axis_m_tdata      (axis_tx_shaped_tdata),
            .axis_m_tid        (axis_tx_shaped_tid),
            .axis_m_tdest      (axis_tx_shaped_tdest),                                           
            .axis_m_tkeep      (axis_tx_shaped_tkeep),
            .axis_m_tlast      (axis_tx_shaped_tlast),
            .axis_m_tvalid     (axis_tx_shaped_tvalid),
            .axis_m_tready     (axis_tx_shaped_tready),

            //Token counter parameters
            .init_token     (init_token),
            .upd_token      (upd_token),

            //Clocking
            .aclk           (aclk),
            .aresetn        (aresetn)
        );

    end else begin

        assign axis_tx_shaped_tdata = axis_tx_verified_tdata;
        assign axis_tx_shaped_tid = axis_tx_verified_tid;
        assign axis_tx_shaped_tdest = axis_tx_verified_tdest;                                           
        assign axis_tx_shaped_tkeep = axis_tx_verified_tkeep;
        assign axis_tx_shaped_tlast = axis_tx_verified_tlast;
        assign axis_tx_shaped_tvalid = axis_tx_verified_tvalid;
        assign axis_tx_verified_tready = axis_tx_shaped_tready;

    end endgenerate



    //--------------------------------------------------------//
    //   Output Assignment (with register slice               //
    //--------------------------------------------------------//

    //TX register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXIS_BUS_WIDTH + AXIS_ID_WIDTH + AXIS_DEST_WIDTH + (AXIS_BUS_WIDTH/8) + 1)
    )
    tx_reg_slice
    (
        .in_data    ( { axis_tx_shaped_tdata,
                        axis_tx_shaped_tid,
                        axis_tx_shaped_tdest,
                        axis_tx_shaped_tkeep,
                        axis_tx_shaped_tlast}),
        .in_valid   (axis_tx_shaped_tvalid),
        .in_ready   (axis_tx_shaped_tready),

        .out_data   ( { axis_tx_m_tdata,
                        axis_tx_m_tid,
                        axis_tx_m_tdest,
                        axis_tx_m_tkeep,
                        axis_tx_m_tlast}),
        .out_valid  (axis_tx_m_tvalid),
        .out_ready  (axis_tx_m_tready),
        
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //Axi-stream output assignment
    /*assign axis_tx_m_tdata = axis_tx_shaped_tdata;
    assign axis_tx_m_tid = axis_tx_shaped_tid;
    assign axis_tx_m_tdest = axis_tx_shaped_tdest;                                           
    assign axis_tx_m_tkeep = axis_tx_shaped_tkeep;
    assign axis_tx_m_tlast = axis_tx_shaped_tlast;
    assign axis_tx_m_tvalid = axis_tx_shaped_tvalid;
    assign axis_tx_shaped_tready = axis_tx_m_tready;*/



    //--------------------------------------------------------//
    //   RX Datapath                                          //
    //--------------------------------------------------------//

    //--------------------------------------------------------//
    //   Slave Decoupler                                      //
    //--------------------------------------------------------//

    //Axi-stream interface on input of decoupler
    wire [AXIS_BUS_WIDTH-1:0]       axis_rx_decoupled_tdata;
    wire [AXIS_ID_WIDTH-1:0]        axis_rx_decoupled_tdest;
    wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_rx_decoupled_tkeep;
    wire                            axis_rx_decoupled_tlast;
    wire                            axis_rx_decoupled_tvalid;
    wire                            axis_rx_decoupled_tready;
    wire                            axis_rx_packet_dropped;

    //Other decoupler signals
    wire decouple_force_rx;
    wire decouple_done_rx;

    //Decoupler Instantiated
    axi_stream_slave_decoupler
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_ID_WIDTH),
        .DISALLOW_BACKPRESSURE      (DISALLOW_INGR_BACKPRESSURE)
    )
    decoupler_slave_inst
    (
        //Ingress Input AXI stream
        .axis_s_tdata     (axis_rx_decoupled_tdata),
        .axis_s_tdest     (axis_rx_decoupled_tdest),
        .axis_s_tkeep     (axis_rx_decoupled_tkeep),
        .axis_s_tlast     (axis_rx_decoupled_tlast),
        .axis_s_tvalid    (axis_rx_decoupled_tvalid),
        .axis_s_tready    (axis_rx_decoupled_tready),

        //Ingress Output AXI stream
        .axis_m_tdata     (axis_rx_m_tdata),
        .axis_m_tdest     (axis_rx_m_tdest),
        .axis_m_tkeep     (axis_rx_m_tkeep),
        .axis_m_tlast     (axis_rx_m_tlast),
        .axis_m_tvalid    (axis_rx_m_tvalid),
        .axis_m_tready    (axis_rx_m_tready),

        //Decoupler signals
        .decouple               (decouple),
        .decouple_force         (decouple_force_rx),
        .decouple_done          (decouple_done_rx),
        .decoupled              (decouple_status_vector[1]),

        //Dropped Packet Signal
        .packet_dropped         (axis_rx_packet_dropped),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );



    //--------------------------------------------------------//
    //   Slave Protocol Verifier                              //
    //--------------------------------------------------------//

    //Axi-stream interface on input of verifier
    wire [AXIS_BUS_WIDTH-1:0]       axis_rx_verified_tdata;
    wire [AXIS_ID_WIDTH-1:0]        axis_rx_verified_tdest;
    wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_rx_verified_tkeep;
    wire                            axis_rx_verified_tlast;
    wire                            axis_rx_verified_tvalid;
    wire                            axis_rx_verified_tready;

    //Other Verifier Signals
    wire         timeout_error_irq;
    wire         timeout_error_clear;

    //Verifier Instantiated
    axi_stream_slave_verifier
    #(
        .AXIS_BUS_WIDTH                     (AXIS_BUS_WIDTH),
        .AXIS_DEST_WIDTH                    (AXIS_ID_WIDTH),
        .INCLUDE_TIMEOUT_ERROR              (INCLUDE_TIMEOUT_ERROR_INGR),
        .TIMEOUT_CYCLES                     (INGR_TIMEOUT_CYCLES)
    )
    verifier_slave_inst
    (
        //Ingress Input AXI stream
        .axis_s_tdata     (axis_rx_verified_tdata),
        .axis_s_tdest     (axis_rx_verified_tdest),
        .axis_s_tkeep     (axis_rx_verified_tkeep),
        .axis_s_tlast     (axis_rx_verified_tlast),
        .axis_s_tvalid    (axis_rx_verified_tvalid),
        .axis_s_tready    (axis_rx_verified_tready),

        //Ingress Output AXI stream
        .axis_m_tdata     (axis_rx_decoupled_tdata),
        .axis_m_tdest     (axis_rx_decoupled_tdest),
        .axis_m_tkeep     (axis_rx_decoupled_tkeep),
        .axis_m_tlast     (axis_rx_decoupled_tlast),
        .axis_m_tvalid    (axis_rx_decoupled_tvalid),
        .axis_m_tready    (axis_rx_decoupled_tready),

        //Protocol error indicators
        .timeout_error_irq      (timeout_error_irq),
        .timeout_error_clear    (timeout_error_clear),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

    //Feedback connections to decoupler
    assign decouple_force_rx = timeout_error_irq;


    //--------------------------------------------------------//
    //   Final Input Assignment (with Reg Slice)              //
    //--------------------------------------------------------//

    //TX register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXIS_BUS_WIDTH + AXIS_ID_WIDTH + (AXIS_BUS_WIDTH/8) + 1)
    )
    rx_reg_slice
    (
        .in_data    ( { axis_rx_s_tdata,
                        axis_rx_s_tdest,
                        axis_rx_s_tkeep,
                        axis_rx_s_tlast}),
        .in_valid   (axis_rx_s_tvalid),
        .in_ready   (axis_rx_s_tready),

        .out_data   ( { axis_rx_verified_tdata,
                        axis_rx_verified_tdest,
                        axis_rx_verified_tkeep,
                        axis_rx_verified_tlast}),
        .out_valid  (axis_rx_verified_tvalid),
        .out_ready  (axis_rx_verified_tready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //Axi-stream input assignment
    /*assign axis_rx_verified_tdata = axis_rx_s_tdata;
    assign axis_rx_verified_tdest = axis_rx_s_tdest;
    assign axis_rx_verified_tkeep = axis_rx_s_tkeep;
    assign axis_rx_verified_tlast = axis_rx_s_tlast;
    assign axis_rx_verified_tvalid = axis_rx_s_tvalid;
    assign axis_rx_s_tready = axis_rx_verified_tready;*/



    //--------------------------------------------------------//
    //   Control Path                                         //
    //--------------------------------------------------------//

    //Instantiate Register File
    net_iso_reg_file
    #(
        .TOKEN_COUNT_INT_WIDTH  (TOKEN_COUNT_INT_WIDTH),
        .TOKEN_COUNT_FRAC_WIDTH (TOKEN_COUNT_FRAC_WIDTH)
    )
    reg_file_inst
    (
        //AXI-Lite Control Interface
        //Write Address Channel
        .awaddr        (ctrl_awaddr),
        .awvalid       (ctrl_awvalid),
        .awready       (ctrl_awready),
        //Write Data Channel
        .wdata         (ctrl_wdata),
        .wvalid        (ctrl_wvalid),
        .wready        (ctrl_wready),
        //Write Response Channel
        .bresp         (ctrl_bresp),
        .bvalid        (ctrl_bvalid),
        .bready        (ctrl_bready),
        //Read Address Channel 
        .araddr        (ctrl_araddr),
        .arvalid       (ctrl_arvalid),
        .arready       (ctrl_arready),
        //Read Data Response Channel
        .rdata         (ctrl_rdata),
        .rresp         (ctrl_rresp),
        .rvalid        (ctrl_rvalid),
        .rready        (ctrl_rready),

        //Register Outputs
        .decouple               (decouple),
        .oversize_error_clear   (oversize_error_clear),
        .timeout_error_clear    (timeout_error_clear),
        .init_token             (init_token),
        .upd_token              (upd_token),

        //Register Inputs
        .decouple_done          (decouple_done_tx & decouple_done_rx),
        .decouple_status_vector (decouple_status_vector),
        .oversize_error_irq     (oversize_error_irq),
        .timeout_error_irq      (timeout_error_irq),

        //Signals for statistics counters
        .rx_packet_dropped      (axis_rx_packet_dropped),

        //Clocking
        .aclk               (aclk),
        .aresetn            (aresetn)
    );
 



endmodule

`default_nettype wire