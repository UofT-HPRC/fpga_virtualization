`timescale 1ns / 1ps
`default_nettype none

/*
AXI4-MM Interface Isolation Core Wrapper

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module wraps all of the AXI4-MM isolation cores into a single
   module, connecting them together and adding an AXI-Lite control
   interface to control the various cores. This includes a decoupler,
   an AXI4 protocol verifier, and a bandwidth shaper. This core isolates
   an untrusted Master interface from a trusted Slave interface. Note, 
   zero widths for any of the signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path
   INCLUDE_BW_SHAPER_SEP - binary, whether or not to include a bandwidth shaper with seperate tokens for read and write (takes precedence over next parameter)
   INCLUDE_BW_SHAPER_UNI - binary, whether or not to include a bandwidth shaper with a single token count for read and write
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_RREQ - the maximum allowed outstanding read requests
   WTIMEOUT_CYCLES - total number of cycles to wait after receiving the AW request or the previous W beat before indicating a W-channel timeout (should be one less than a power of 2 for implementation efficiency)
   BTIMEOUT_CYCLES - total numner of cycles to wait after bready is asserted before indicating a B-channel timeout
   RTIMEOUT_CYCLES - total number of cycles to wait after rready is asserted before indicating an R-channel timeout (should be one less than a power of 2 for implementation efficiency)
   TOKEN_COUNT_INT_WIDTH - the token count integer component width for the bandwidth shaper (fixed point representation)
   TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width  for the bandwidth shaper (fixed point representation)
   SUM_RETIMING_STAGES - retiming registers to insert into token summing to meet timing for the bandwidth shaper

AXI-Lite Control Interface Register Space
   We have the following mapping (byte addressable, /4 for word addressable systems)
     [0] Decoupler registers 
          - bit 0 - decouple output register
          - bit 1 - decouple_done input register
          - bits 6..2 - decouple_status_vector input register
     [4] Protocol Verifier Registers
          - bit 0 - timeout_error_clear output register
          - bit 1 - timeout_error_irq input register
          - bits 4..2 - timeout_status_vector input register
     [8] AW Channel Init Token Register (Also used for unified BW Shaper)
     [12] AW Channel Update Token Register (Also used for unified BW Shaper)
     [16] AR Channel Init Token Register
     [20] AR Channel Update Token Register

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface
   ctrl_* - the AXI-Lite control interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module mem_iso_top
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 5,
    parameter AXI_ADDR_WIDTH = 33,
    parameter AXI_DATA_WIDTH = 128,

    //Core Options
    parameter INCLUDE_BW_SHAPER_SEP = 1,
    parameter INCLUDE_BW_SHAPER_UNI = 0,

    //Core Params
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 15,

    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,

    //Retiming for adders in BW shaper
    parameter SUM_RETIMING_STAGES = 1
)
(
    //AXI4 slave connection (master to isolate connects to this)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_awaddr,
    input wire [7:0]                        axi_s_awlen,
    input wire [2:0]                        axi_s_awsize,
    input wire [1:0]                        axi_s_awburst,
    input wire                              axi_s_awvalid,
    output wire                             axi_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_s_wstrb,
    input wire                              axi_s_wlast,
    input wire                              axi_s_wvalid,
    output wire                             axi_s_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_bid,
    output wire [1:0]                       axi_s_bresp,
    output wire                             axi_s_bvalid,
    input wire                              axi_s_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_arid,
    input wire [AXI_ADDR_WIDTH-1:0]         axi_s_araddr,
    input wire [7:0]                        axi_s_arlen,
    input wire [2:0]                        axi_s_arsize,
    input wire [1:0]                        axi_s_arburst,
    input wire                              axi_s_arvalid,
    output wire                             axi_s_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_rid,
    output wire [AXI_DATA_WIDTH-1:0]        axi_s_rdata,
    output wire [1:0]                       axi_s_rresp,
    output wire                             axi_s_rlast,
    output wire                             axi_s_rvalid,
    input wire                              axi_s_rready,

    //AXI4 master connection (connects to slave expecting isolated signal)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output wire [2:0]                       axi_m_awsize,
    output wire [1:0]                       axi_m_awburst,
    output wire                             axi_m_awuser, //error indicator
    output wire                             axi_m_awvalid,
    input wire                              axi_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_m_wstrb,
    output wire                             axi_m_wlast,
    output wire                             axi_m_wvalid,
    input wire                              axi_m_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_bid,
    input wire [1:0]                        axi_m_bresp,
    input wire                              axi_m_bvalid,
    output wire                             axi_m_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_arid,
    output wire [AXI_ADDR_WIDTH-1:0]        axi_m_araddr,
    output wire [7:0]                       axi_m_arlen,
    output wire [2:0]                       axi_m_arsize,
    output wire [1:0]                       axi_m_arburst,
    output wire                             axi_m_aruser,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,
    
    //The AXI-Lite Control Interface
    //Write Address Channel  
    input wire  [31:0]                      ctrl_awaddr,
    input wire                              ctrl_awvalid,
    output reg                              ctrl_awready,
    //Write Data Channel
    input wire  [31:0]                      ctrl_wdata,
    //input wire  [3:0]                       ctrl_wstrb,
    input wire                              ctrl_wvalid,
    output reg                              ctrl_wready,
    //Write Response Channel
    output reg [1:0]                        ctrl_bresp,
    output reg                              ctrl_bvalid,
    input wire                              ctrl_bready,
    //Read Address Channel 
    input wire  [31:0]                      ctrl_araddr,
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
    //   Decoupler                                            //
    //--------------------------------------------------------//

    //Axi interface on output of decoupler
    //Write Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_decoupled_awid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_decoupled_awaddr;
    wire [7:0]                       axi_decoupled_awlen;
    wire [2:0]                       axi_decoupled_awsize;
    wire [1:0]                       axi_decoupled_awburst;
    wire                             axi_decoupled_awvalid;
    wire                             axi_decoupled_awready;
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_decoupled_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0]    axi_decoupled_wstrb;
    wire                             axi_decoupled_wlast;
    wire                             axi_decoupled_wvalid;
    wire                             axi_decoupled_wready;
    //Write Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_decoupled_bid;
    wire [1:0]                       axi_decoupled_bresp;
    wire                             axi_decoupled_bvalid;
    wire                             axi_decoupled_bready;
    //Read Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_decoupled_arid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_decoupled_araddr;
    wire [7:0]                       axi_decoupled_arlen;
    wire [2:0]                       axi_decoupled_arsize;
    wire [1:0]                       axi_decoupled_arburst;
    wire                             axi_decoupled_arvalid;
    wire                             axi_decoupled_arready;
    //Read Data Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_decoupled_rid;
    wire [AXI_DATA_WIDTH-1:0]        axi_decoupled_rdata;
    wire [1:0]                       axi_decoupled_rresp;
    wire                             axi_decoupled_rlast;
    wire                             axi_decoupled_rvalid;
    wire                             axi_decoupled_rready;

    //Other decoupler signals
    wire             decouple;
    wire             decouple_force;
    wire             decouple_done;
    wire [4:0]       decouple_status_vector;

    //Decoupler Instantiated
    axi4_master_decoupler
    #(
        .AXI_ID_WIDTH            (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH          (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH          (AXI_DATA_WIDTH),
        .OUTSTANDING_WREQ        (OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ        (OUTSTANDING_RREQ),
        .INCLUDE_BACKPRESSURE    (1),
        .W_BEFORE_AW_CAPABLE     (0) //The Verifier doesn't accept W beats before AW requests
    )
    decoupler_inst
    (
        //AXI4 slave connection (input of requests)
        //Write Address Channel     
        .axi_s_awid             (axi_s_awid),
        .axi_s_awaddr           (axi_s_awaddr),
        .axi_s_awlen            (axi_s_awlen),
        .axi_s_awsize           (axi_s_awsize),
        .axi_s_awburst          (axi_s_awburst),
        .axi_s_awvalid          (axi_s_awvalid),
        .axi_s_awready          (axi_s_awready),
        //Write Data Channel
        .axi_s_wdata            (axi_s_wdata),
        .axi_s_wstrb            (axi_s_wstrb),
        .axi_s_wlast            (axi_s_wlast),
        .axi_s_wvalid           (axi_s_wvalid),
        .axi_s_wready           (axi_s_wready),
        //Write Response Channel
        .axi_s_bid              (axi_s_bid),
        .axi_s_bresp            (axi_s_bresp),
        .axi_s_bvalid           (axi_s_bvalid),
        .axi_s_bready           (axi_s_bready),
        //Read Address Channel     
        .axi_s_arid             (axi_s_arid),
        .axi_s_araddr           (axi_s_araddr),
        .axi_s_arlen            (axi_s_arlen),
        .axi_s_arsize           (axi_s_arsize),
        .axi_s_arburst          (axi_s_arburst),
        .axi_s_arvalid          (axi_s_arvalid),
        .axi_s_arready          (axi_s_arready),
        //Read Data Response Channel
        .axi_s_rid              (axi_s_rid),
        .axi_s_rdata            (axi_s_rdata),
        .axi_s_rresp            (axi_s_rresp),
        .axi_s_rlast            (axi_s_rlast),
        .axi_s_rvalid           (axi_s_rvalid),
        .axi_s_rready           (axi_s_rready),

        //AXI4 master connection (output of requests)
        //Write Address Channel     
        .axi_m_awid           (axi_decoupled_awid),
        .axi_m_awaddr         (axi_decoupled_awaddr),
        .axi_m_awlen          (axi_decoupled_awlen),
        .axi_m_awsize         (axi_decoupled_awsize),
        .axi_m_awburst        (axi_decoupled_awburst),
        .axi_m_awvalid        (axi_decoupled_awvalid),
        .axi_m_awready        (axi_decoupled_awready),
        //Write Data Channel
        .axi_m_wdata          (axi_decoupled_wdata),
        .axi_m_wstrb          (axi_decoupled_wstrb),
        .axi_m_wlast          (axi_decoupled_wlast),
        .axi_m_wvalid         (axi_decoupled_wvalid),
        .axi_m_wready         (axi_decoupled_wready),
        //Write Response Channel
        .axi_m_bid            (axi_decoupled_bid),
        .axi_m_bresp          (axi_decoupled_bresp),
        .axi_m_bvalid         (axi_decoupled_bvalid),
        .axi_m_bready         (axi_decoupled_bready),
        //Read Address Channel     
        .axi_m_arid           (axi_decoupled_arid),
        .axi_m_araddr         (axi_decoupled_araddr),
        .axi_m_arlen          (axi_decoupled_arlen),
        .axi_m_arsize         (axi_decoupled_arsize),
        .axi_m_arburst        (axi_decoupled_arburst),
        .axi_m_arvalid        (axi_decoupled_arvalid),
        .axi_m_arready        (axi_decoupled_arready),
        //Read Data Response Channel
        .axi_m_rid            (axi_decoupled_rid),
        .axi_m_rdata          (axi_decoupled_rdata),
        .axi_m_rresp          (axi_decoupled_rresp),
        .axi_m_rlast          (axi_decoupled_rlast),
        .axi_m_rvalid         (axi_decoupled_rvalid),
        .axi_m_rready         (axi_decoupled_rready),

        //Decoupler signals
        .decouple               (decouple),
        .decouple_force         (decouple_force),
        .decouple_done          (decouple_done),
        .decouple_status_vector (decouple_status_vector),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );



    //--------------------------------------------------------//
    //   Protocol Verifier                                    //
    //--------------------------------------------------------//

    //Axi interface on output of verifier
    //Write Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_verified_awid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_verified_awaddr;
    wire [7:0]                       axi_verified_awlen;
    wire [2:0]                       axi_verified_awsize;
    wire [1:0]                       axi_verified_awburst;
    wire                             axi_verified_awuser; //added error signal (handled my MMU)
    wire                             axi_verified_awvalid;
    wire                             axi_verified_awready;
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_verified_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0]    axi_verified_wstrb;
    wire                             axi_verified_wlast;
    wire                             axi_verified_wvalid;
    wire                             axi_verified_wready;
    //Write Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_verified_bid;
    wire [1:0]                       axi_verified_bresp;
    wire                             axi_verified_bvalid;
    wire                             axi_verified_bready;
    //Read Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_verified_arid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_verified_araddr;
    wire [7:0]                       axi_verified_arlen;
    wire [2:0]                       axi_verified_arsize;
    wire [1:0]                       axi_verified_arburst;
    wire                             axi_verified_aruser; //added error signal (handled by MMU)
    wire                             axi_verified_arvalid;
    wire                             axi_verified_arready;
    //Read Data Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_verified_rid;
    wire [AXI_DATA_WIDTH-1:0]        axi_verified_rdata;
    wire [1:0]                       axi_verified_rresp;
    wire                             axi_verified_rlast;
    wire                             axi_verified_rvalid;
    wire                             axi_verified_rready;

    //Other Verifier Signals
    wire          timeout_error_irq;
    wire [2:0]    timeout_status_vector;
    wire          timeout_error_clear;

    //Verifier Instantiated
    axi4_master_verifier
    #(
        .AXI_ID_WIDTH           (AXI_ID_WIDTH),
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .WTIMEOUT_CYCLES        (WTIMEOUT_CYCLES),
        .BTIMEOUT_CYCLES        (BTIMEOUT_CYCLES),
        .RTIMEOUT_CYCLES        (RTIMEOUT_CYCLES),
        .OUTSTANDING_WREQ       (OUTSTANDING_WREQ)
    )
    verifier_inst
    (
        //AXI4 slave connection (input of requests)
        //Write Address Channel     
        .axi_s_awid            (axi_decoupled_awid),
        .axi_s_awaddr          (axi_decoupled_awaddr),
        .axi_s_awlen           (axi_decoupled_awlen),
        .axi_s_awsize          (axi_decoupled_awsize),
        .axi_s_awburst         (axi_decoupled_awburst),
        .axi_s_awvalid         (axi_decoupled_awvalid),
        .axi_s_awready         (axi_decoupled_awready),
        //Write Data Channel
        .axi_s_wdata           (axi_decoupled_wdata),
        .axi_s_wstrb           (axi_decoupled_wstrb),
        .axi_s_wlast           (axi_decoupled_wlast),
        .axi_s_wvalid          (axi_decoupled_wvalid),
        .axi_s_wready          (axi_decoupled_wready),
        //Write Response Channel
        .axi_s_bid             (axi_decoupled_bid),
        .axi_s_bresp           (axi_decoupled_bresp),
        .axi_s_bvalid          (axi_decoupled_bvalid),
        .axi_s_bready          (axi_decoupled_bready),
        //Read Address Channel     
        .axi_s_arid            (axi_decoupled_arid),
        .axi_s_araddr          (axi_decoupled_araddr),
        .axi_s_arlen           (axi_decoupled_arlen),
        .axi_s_arsize          (axi_decoupled_arsize),
        .axi_s_arburst         (axi_decoupled_arburst),
        .axi_s_arvalid         (axi_decoupled_arvalid),
        .axi_s_arready         (axi_decoupled_arready),
        //Read Data Response Channel
        .axi_s_rid             (axi_decoupled_rid),
        .axi_s_rdata           (axi_decoupled_rdata),
        .axi_s_rresp           (axi_decoupled_rresp),
        .axi_s_rlast           (axi_decoupled_rlast),
        .axi_s_rvalid          (axi_decoupled_rvalid),
        .axi_s_rready          (axi_decoupled_rready),

        //AXI4 master connection (output of requests)
        //Write Address Channel     
        .axi_m_awid           (axi_verified_awid),
        .axi_m_awaddr         (axi_verified_awaddr),
        .axi_m_awlen          (axi_verified_awlen),
        .axi_m_awsize         (axi_verified_awsize),
        .axi_m_awburst        (axi_verified_awburst),
        .axi_m_awuser         (axi_verified_awuser),
        .axi_m_awvalid        (axi_verified_awvalid),
        .axi_m_awready        (axi_verified_awready),
        //Write Data Channel
        .axi_m_wdata          (axi_verified_wdata),
        .axi_m_wstrb          (axi_verified_wstrb),
        .axi_m_wlast          (axi_verified_wlast),
        .axi_m_wvalid         (axi_verified_wvalid),
        .axi_m_wready         (axi_verified_wready),
        //Write Response Channel
        .axi_m_bid            (axi_verified_bid),
        .axi_m_bresp          (axi_verified_bresp),
        .axi_m_bvalid         (axi_verified_bvalid),
        .axi_m_bready         (axi_verified_bready),
        //Read Address Channel     
        .axi_m_arid           (axi_verified_arid),
        .axi_m_araddr         (axi_verified_araddr),
        .axi_m_arlen          (axi_verified_arlen),
        .axi_m_arsize         (axi_verified_arsize),
        .axi_m_arburst        (axi_verified_arburst),
        .axi_m_aruser         (axi_verified_aruser),
        .axi_m_arvalid        (axi_verified_arvalid),
        .axi_m_arready        (axi_verified_arready),
        //Read Data Response Channel
        .axi_m_rid            (axi_verified_rid),
        .axi_m_rdata          (axi_verified_rdata),
        .axi_m_rresp          (axi_verified_rresp),
        .axi_m_rlast          (axi_verified_rlast),
        .axi_m_rvalid         (axi_verified_rvalid),
        .axi_m_rready         (axi_verified_rready),

        //Protocol error indicators
        .timeout_error_irq      (timeout_error_irq),
        .timeout_status_vector  (timeout_status_vector),
        .timeout_error_clear    (timeout_error_clear),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

    //Feedback connections to decoupler
    assign decouple_force = timeout_error_irq;



    //--------------------------------------------------------//
    //   Bandwidth Shaper                                     //
    //--------------------------------------------------------//

    //Axi interface on output of BW shaper
    //Write Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_shaped_awid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_shaped_awaddr;
    wire [7:0]                       axi_shaped_awlen;
    wire [2:0]                       axi_shaped_awsize;
    wire [1:0]                       axi_shaped_awburst;
    wire                             axi_shaped_awuser;
    wire                             axi_shaped_awvalid;
    wire                             axi_shaped_awready;
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_shaped_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0]    axi_shaped_wstrb;
    wire                             axi_shaped_wlast;
    wire                             axi_shaped_wvalid;
    wire                             axi_shaped_wready;
    //Write Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_shaped_bid;
    wire [1:0]                       axi_shaped_bresp;
    wire                             axi_shaped_bvalid;
    wire                             axi_shaped_bready;
    //Read Address Channel     
    wire [AXI_ID_WIDTH-1:0]          axi_shaped_arid;
    wire [AXI_ADDR_WIDTH-1:0]        axi_shaped_araddr;
    wire [7:0]                       axi_shaped_arlen;
    wire [2:0]                       axi_shaped_arsize;
    wire [1:0]                       axi_shaped_arburst;
    wire                             axi_shaped_aruser;
    wire                             axi_shaped_arvalid;
    wire                             axi_shaped_arready;
    //Read Data Response Channel
    wire [AXI_ID_WIDTH-1:0]          axi_shaped_rid;
    wire [AXI_DATA_WIDTH-1:0]        axi_shaped_rdata;
    wire [1:0]                       axi_shaped_rresp;
    wire                             axi_shaped_rlast;
    wire                             axi_shaped_rvalid;
    wire                             axi_shaped_rready;

    //Other BW shaping signals
    wire [TOKEN_COUNT_INT_WIDTH-1:0]  aw_init_token;
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   aw_upd_token;
    wire [TOKEN_COUNT_INT_WIDTH-1:0]  ar_init_token;
    wire [TOKEN_COUNT_FRAC_WIDTH:0]   ar_upd_token;

    //Check which type of BW shaper to insert
    generate if(INCLUDE_BW_SHAPER_SEP) begin : bw_shaper_sep_gen

        //BW shaper instantiated
        axi4_bw_shaper
        #(
            .AXI_ID_WIDTH               (AXI_ID_WIDTH),
            .AXI_ADDR_WIDTH             (AXI_ADDR_WIDTH),
            .AXI_DATA_WIDTH             (AXI_DATA_WIDTH),
            .AXI_AX_USER_WIDTH          (1),
            .TOKEN_COUNT_INT_WIDTH      (TOKEN_COUNT_INT_WIDTH),
            .TOKEN_COUNT_FRAC_WIDTH     (TOKEN_COUNT_FRAC_WIDTH),
            .WTIMEOUT_CYCLES            (WTIMEOUT_CYCLES),
            .BTIMEOUT_CYCLES            (BTIMEOUT_CYCLES),
            .RTIMEOUT_CYCLES            (RTIMEOUT_CYCLES),
            .OUTSTANDING_WREQ           (OUTSTANDING_WREQ),
            .AW_RETIMING_STAGES         (SUM_RETIMING_STAGES),
            .AR_RETIMING_STAGES         (SUM_RETIMING_STAGES)
        )
        bw_shaper_sep_inst
        (
            //AXI4 slave connection (input of requests)
            //Write Address Channel
            .axi_s_awid            (axi_verified_awid),
            .axi_s_awaddr          (axi_verified_awaddr),
            .axi_s_awlen           (axi_verified_awlen),
            .axi_s_awsize          (axi_verified_awsize),
            .axi_s_awburst         (axi_verified_awburst),
            .axi_s_awuser          (axi_verified_awuser),
            .axi_s_awvalid         (axi_verified_awvalid),
            .axi_s_awready         (axi_verified_awready),
            //Write Data Channel
            .axi_s_wdata           (axi_verified_wdata),
            .axi_s_wstrb           (axi_verified_wstrb),
            .axi_s_wlast           (axi_verified_wlast),
            .axi_s_wvalid          (axi_verified_wvalid),
            .axi_s_wready          (axi_verified_wready),
            //Write Response Channel
            .axi_s_bid             (axi_verified_bid),
            .axi_s_bresp           (axi_verified_bresp),
            .axi_s_bvalid          (axi_verified_bvalid),
            .axi_s_bready          (axi_verified_bready),
            //Read Address Channel     
            .axi_s_arid            (axi_verified_arid),
            .axi_s_araddr          (axi_verified_araddr),
            .axi_s_arlen           (axi_verified_arlen),
            .axi_s_arsize          (axi_verified_arsize),
            .axi_s_arburst         (axi_verified_arburst),
            .axi_s_aruser          (axi_verified_aruser),
            .axi_s_arvalid         (axi_verified_arvalid),
            .axi_s_arready         (axi_verified_arready),
            //Read Data Response Channel
            .axi_s_rid             (axi_verified_rid),
            .axi_s_rdata           (axi_verified_rdata),
            .axi_s_rresp           (axi_verified_rresp),
            .axi_s_rlast           (axi_verified_rlast),
            .axi_s_rvalid          (axi_verified_rvalid),
            .axi_s_rready          (axi_verified_rready),

            //AXI4 master connection (output of requests)
            //Write Address Channel     
            .axi_m_awid           (axi_shaped_awid),
            .axi_m_awaddr         (axi_shaped_awaddr),
            .axi_m_awlen          (axi_shaped_awlen),
            .axi_m_awsize         (axi_shaped_awsize),
            .axi_m_awburst        (axi_shaped_awburst),
            .axi_m_awuser         (axi_shaped_awuser),
            .axi_m_awvalid        (axi_shaped_awvalid),
            .axi_m_awready        (axi_shaped_awready),
            //Write Data Channel
            .axi_m_wdata          (axi_shaped_wdata),
            .axi_m_wstrb          (axi_shaped_wstrb),
            .axi_m_wlast          (axi_shaped_wlast),
            .axi_m_wvalid         (axi_shaped_wvalid),
            .axi_m_wready         (axi_shaped_wready),
            //Write Response Channel
            .axi_m_bid            (axi_shaped_bid),
            .axi_m_bresp          (axi_shaped_bresp),
            .axi_m_bvalid         (axi_shaped_bvalid),
            .axi_m_bready         (axi_shaped_bready),
            //Read Address Channel     
            .axi_m_arid           (axi_shaped_arid),
            .axi_m_araddr         (axi_shaped_araddr),
            .axi_m_arlen          (axi_shaped_arlen),
            .axi_m_arsize         (axi_shaped_arsize),
            .axi_m_arburst        (axi_shaped_arburst),
            .axi_m_aruser         (axi_shaped_aruser),
            .axi_m_arvalid        (axi_shaped_arvalid),
            .axi_m_arready        (axi_shaped_arready),
            //Read Data Response Channel
            .axi_m_rid            (axi_shaped_rid),
            .axi_m_rdata          (axi_shaped_rdata),
            .axi_m_rresp          (axi_shaped_rresp),
            .axi_m_rlast          (axi_shaped_rlast),
            .axi_m_rvalid         (axi_shaped_rvalid),
            .axi_m_rready         (axi_shaped_rready),

            //Token counter parameters
            .aw_init_token          (aw_init_token),
            .aw_upd_token           (aw_upd_token),
            .ar_init_token          (ar_init_token),
            .ar_upd_token           (ar_upd_token),

            //Clocking
            .aclk                   (aclk),
            .aresetn                (aresetn)
        );

    end else if(INCLUDE_BW_SHAPER_UNI) begin : bw_shaper_uni_gen

        //BW shaper instantiated
        axi4_bw_shaper_unified
        #(
            .AXI_ID_WIDTH               (AXI_ID_WIDTH),
            .AXI_ADDR_WIDTH             (AXI_ADDR_WIDTH),
            .AXI_DATA_WIDTH             (AXI_DATA_WIDTH),
            .AXI_AX_USER_WIDTH          (1),
            .TOKEN_COUNT_INT_WIDTH      (TOKEN_COUNT_INT_WIDTH),
            .TOKEN_COUNT_FRAC_WIDTH     (TOKEN_COUNT_FRAC_WIDTH),
            .WTIMEOUT_CYCLES            (WTIMEOUT_CYCLES),
            .BTIMEOUT_CYCLES            (BTIMEOUT_CYCLES),
            .RTIMEOUT_CYCLES            (RTIMEOUT_CYCLES),
            .OUTSTANDING_WREQ           (OUTSTANDING_WREQ),
            .SUM_RETIMING_STAGES        (SUM_RETIMING_STAGES),
            .ALLOW_RD_WR_SAME_TIME      (1)
        )
        bw_shaper_uni_inst
        (
            //AXI4 slave connection (input of requests)
            //Write Address Channel
            .axi_s_awid            (axi_verified_awid),
            .axi_s_awaddr          (axi_verified_awaddr),
            .axi_s_awlen           (axi_verified_awlen),
            .axi_s_awsize          (axi_verified_awsize),
            .axi_s_awburst         (axi_verified_awburst),
            .axi_s_awuser          (axi_verified_awuser),
            .axi_s_awvalid         (axi_verified_awvalid),
            .axi_s_awready         (axi_verified_awready),
            //Write Data Channel
            .axi_s_wdata           (axi_verified_wdata),
            .axi_s_wstrb           (axi_verified_wstrb),
            .axi_s_wlast           (axi_verified_wlast),
            .axi_s_wvalid          (axi_verified_wvalid),
            .axi_s_wready          (axi_verified_wready),
            //Write Response Channel
            .axi_s_bid             (axi_verified_bid),
            .axi_s_bresp           (axi_verified_bresp),
            .axi_s_bvalid          (axi_verified_bvalid),
            .axi_s_bready          (axi_verified_bready),
            //Read Address Channel     
            .axi_s_arid            (axi_verified_arid),
            .axi_s_araddr          (axi_verified_araddr),
            .axi_s_arlen           (axi_verified_arlen),
            .axi_s_arsize          (axi_verified_arsize),
            .axi_s_arburst         (axi_verified_arburst),
            .axi_s_aruser          (axi_verified_aruser),
            .axi_s_arvalid         (axi_verified_arvalid),
            .axi_s_arready         (axi_verified_arready),
            //Read Data Response Channel
            .axi_s_rid             (axi_verified_rid),
            .axi_s_rdata           (axi_verified_rdata),
            .axi_s_rresp           (axi_verified_rresp),
            .axi_s_rlast           (axi_verified_rlast),
            .axi_s_rvalid          (axi_verified_rvalid),
            .axi_s_rready          (axi_verified_rready),

            //AXI4 master connection (output of requests)
            //Write Address Channel     
            .axi_m_awid           (axi_shaped_awid),
            .axi_m_awaddr         (axi_shaped_awaddr),
            .axi_m_awlen          (axi_shaped_awlen),
            .axi_m_awsize         (axi_shaped_awsize),
            .axi_m_awburst        (axi_shaped_awburst),
            .axi_m_awuser         (axi_shaped_awuser),
            .axi_m_awvalid        (axi_shaped_awvalid),
            .axi_m_awready        (axi_shaped_awready),
            //Write Data Channel
            .axi_m_wdata          (axi_shaped_wdata),
            .axi_m_wstrb          (axi_shaped_wstrb),
            .axi_m_wlast          (axi_shaped_wlast),
            .axi_m_wvalid         (axi_shaped_wvalid),
            .axi_m_wready         (axi_shaped_wready),
            //Write Response Channel
            .axi_m_bid            (axi_shaped_bid),
            .axi_m_bresp          (axi_shaped_bresp),
            .axi_m_bvalid         (axi_shaped_bvalid),
            .axi_m_bready         (axi_shaped_bready),
            //Read Address Channel     
            .axi_m_arid           (axi_shaped_arid),
            .axi_m_araddr         (axi_shaped_araddr),
            .axi_m_arlen          (axi_shaped_arlen),
            .axi_m_arsize         (axi_shaped_arsize),
            .axi_m_arburst        (axi_shaped_arburst),
            .axi_m_aruser         (axi_shaped_aruser),
            .axi_m_arvalid        (axi_shaped_arvalid),
            .axi_m_arready        (axi_shaped_arready),
            //Read Data Response Channel
            .axi_m_rid            (axi_shaped_rid),
            .axi_m_rdata          (axi_shaped_rdata),
            .axi_m_rresp          (axi_shaped_rresp),
            .axi_m_rlast          (axi_shaped_rlast),
            .axi_m_rvalid         (axi_shaped_rvalid),
            .axi_m_rready         (axi_shaped_rready),

            //Token counter parameters
            .init_token             (aw_init_token),
            .upd_token              (aw_upd_token),

            //Clocking
            .aclk                   (aclk),
            .aresetn                (aresetn)
        );

    end else begin : no_nw_shaper_gen

        assign axi_shaped_awid = axi_verified_awid;
        assign axi_shaped_awaddr = axi_verified_awaddr;
        assign axi_shaped_awlen = axi_verified_awlen;
        assign axi_shaped_awsize = axi_verified_awsize;
        assign axi_shaped_awburst = axi_verified_awburst;
        assign axi_shaped_awuser = axi_verified_awuser;
        assign axi_shaped_awvalid = axi_verified_awvalid;
        assign axi_verified_awready = axi_shaped_awready;

        assign axi_shaped_wdata = axi_verified_wdata;
        assign axi_shaped_wstrb = axi_verified_wstrb;
        assign axi_shaped_wlast = axi_verified_wlast;
        assign axi_shaped_wvalid = axi_verified_wvalid;
        assign axi_verified_wready = axi_shaped_wready;
        
        assign axi_verified_bid = axi_shaped_bid;
        assign axi_verified_bresp = axi_shaped_bresp;
        assign axi_verified_bvalid = axi_shaped_bvalid;
        assign axi_shaped_bready = axi_verified_bready;
             
        assign axi_shaped_arid = axi_verified_arid;
        assign axi_shaped_araddr = axi_verified_araddr;
        assign axi_shaped_arlen = axi_verified_arlen;
        assign axi_shaped_arsize = axi_verified_arsize;
        assign axi_shaped_arburst = axi_verified_arburst;
        assign axi_shaped_aruser = axi_verified_aruser;
        assign axi_shaped_arvalid = axi_verified_arvalid;
        assign axi_verified_arready = axi_shaped_arready;
        
        assign axi_verified_rid = axi_shaped_rid;
        assign axi_verified_rdata = axi_shaped_rdata;
        assign axi_verified_rresp = axi_shaped_rresp;
        assign axi_verified_rlast = axi_shaped_rlast;
        assign axi_verified_rvalid = axi_shaped_rvalid;
        assign axi_shaped_rready = axi_verified_rready;

    end endgenerate



    //--------------------------------------------------------//
    //   Output Assignment (w Reg Slice)                      //
    //--------------------------------------------------------//

    //AXI AW register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXI_ID_WIDTH + AXI_ADDR_WIDTH + 8 + 3 + 2 + 1)
    )
    aw_reg_slice
    (
        .in_data    ( { axi_shaped_awid,
                        axi_shaped_awaddr,
                        axi_shaped_awlen,
                        axi_shaped_awsize,
                        axi_shaped_awburst,
                        axi_shaped_awuser} ),
        .in_valid   (axi_shaped_awvalid),
        .in_ready   (axi_shaped_awready),

        .out_data   ( { axi_m_awid,
                        axi_m_awaddr,
                        axi_m_awlen,
                        axi_m_awsize,
                        axi_m_awburst,
                        axi_m_awuser} ),
        .out_valid  (axi_m_awvalid),
        .out_ready  (axi_m_awready),
        
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AXI W register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXI_DATA_WIDTH + (AXI_DATA_WIDTH/8) + 1)
    )
    w_reg_slice
    (
        .in_data    ( { axi_shaped_wdata,
                        axi_shaped_wstrb,
                        axi_shaped_wlast} ),
        .in_valid   (axi_shaped_wvalid),
        .in_ready   (axi_shaped_wready),

        .out_data   ( { axi_m_wdata,
                        axi_m_wstrb,
                        axi_m_wlast} ),
        .out_valid  (axi_m_wvalid),
        .out_ready  (axi_m_wready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AXI B register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXI_ID_WIDTH + 2)
    )
    b_reg_slice
    (
        .in_data    ( { axi_m_bid,
                        axi_m_bresp}),
        .in_valid   (axi_m_bvalid),
        .in_ready   (axi_m_bready),

        .out_data   ( { axi_shaped_bid,
                        axi_shaped_bresp}),
        .out_valid  (axi_shaped_bvalid),
        .out_ready  (axi_shaped_bready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AXI AR register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXI_ID_WIDTH + AXI_ADDR_WIDTH + 8 + 3 + 2 + 1)
    )
    ar_reg_slice
    (
        .in_data    ( { axi_shaped_arid,
                        axi_shaped_araddr,
                        axi_shaped_arlen,
                        axi_shaped_arsize,
                        axi_shaped_arburst,
                        axi_shaped_aruser} ),
        .in_valid   (axi_shaped_arvalid),
        .in_ready   (axi_shaped_arready),

        .out_data   ( { axi_m_arid,
                        axi_m_araddr,
                        axi_m_arlen,
                        axi_m_arsize,
                        axi_m_arburst,
                        axi_m_aruser} ),
        .out_valid  (axi_m_arvalid),
        .out_ready  (axi_m_arready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AXI R register slice
    reg_slice_full
    #(
        .DATA_WIDTH(AXI_ID_WIDTH + AXI_DATA_WIDTH + 2 + 1)
    )
    r_reg_slice
    (
        .in_data    ( { axi_m_rid,
                        axi_m_rdata,
                        axi_m_rresp,
                        axi_m_rlast}),
        .in_valid   (axi_m_rvalid),
        .in_ready   (axi_m_rready),

        .out_data   ( { axi_shaped_rid,
                        axi_shaped_rdata,
                        axi_shaped_rresp,
                        axi_shaped_rlast}),
        .out_valid  (axi_shaped_rvalid),
        .out_ready  (axi_shaped_rready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //Old plain assignments
    /*assign axi_m_awid = axi_shaped_awid;
    assign axi_m_awaddr = axi_shaped_awaddr;
    assign axi_m_awlen = axi_shaped_awlen;
    assign axi_m_awsize = axi_shaped_awsize;
    assign axi_m_awburst = axi_shaped_awburst;
    assign axi_m_awuser = axi_shaped_awuser;
    assign axi_m_awvalid = axi_shaped_awvalid;
    assign axi_shaped_awready = axi_m_awready;

    assign axi_m_wdata = axi_shaped_wdata;
    assign axi_m_wstrb = axi_shaped_wstrb;
    assign axi_m_wlast = axi_shaped_wlast;
    assign axi_m_wvalid = axi_shaped_wvalid;
    assign axi_shaped_wready = axi_m_wready;
    
    assign axi_shaped_bid = axi_m_bid;
    assign axi_shaped_bresp = axi_m_bresp;
    assign axi_shaped_bvalid = axi_m_bvalid;
    assign axi_m_bready = axi_shaped_bready;
            
    assign axi_m_arid = axi_shaped_arid;
    assign axi_m_araddr = axi_shaped_araddr;
    assign axi_m_arlen = axi_shaped_arlen;
    assign axi_m_arsize = axi_shaped_arsize;
    assign axi_m_arburst = axi_shaped_arburst;
    assign axi_m_arusuer = axi_shaped_aruser;
    assign axi_m_arvalid = axi_shaped_arvalid;
    assign axi_shaped_arready = axi_m_arready;
    
    assign axi_shaped_rid = axi_m_rid;
    assign axi_shaped_rdata = axi_m_rdata;
    assign axi_shaped_rresp = axi_m_rresp;
    assign axi_shaped_rlast = axi_m_rlast;
    assign axi_shaped_rvalid = axi_m_rvalid;
    assign axi_m_rready = axi_shaped_rready;*/



    //--------------------------------------------------------//
    //   Control Path                                         //
    //--------------------------------------------------------//

    //Instantiate Register File
    mem_iso_reg_file
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
        .timeout_error_clear    (timeout_error_clear),
        .aw_init_token          (aw_init_token),
        .aw_upd_token           (aw_upd_token),
        .ar_init_token          (ar_init_token),
        .ar_upd_token           (ar_upd_token),

        //Register Inputs
        .decouple_done          (decouple_done),
        .decouple_status_vector (decouple_status_vector),
        .timeout_error_irq      (timeout_error_irq),
        .timeout_status_vector  (timeout_status_vector),

        //Clocking
        .aclk               (aclk),
        .aresetn            (aresetn)
    );



endmodule

`default_nettype wire