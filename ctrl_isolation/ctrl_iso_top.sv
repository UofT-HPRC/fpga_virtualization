`timescale 1ns / 1ps
`default_nettype none

/*
AXI-Lite Slave Interface Isolation Core Wrapper 

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module wraps all of the AXI-Liteisolation cores into a single
   module, connecting them together and adding an AXI-Lite control
   interface to control the various cores. This includes a decoupler,
   and an AXI-Lite protocol verifier.

Parameters:
   AXI_ADDR_WIDTH - the width of the address field
   AXI_DATA_WIDTH - the width of the data path (must be 32 or 64)
   AWTIMEOUT_CYCLES - total number of cycles to wait after awvalid is asserted before indicating an AW-channel timeout
   WTIMEOUT_CYCLES - total number of cycles to wait after wvalid is asserted before indicating a W-channel timeout
   BTIMEOUT_CYCLES - total numner of cycles to wait after valid AW and W data have been received for a response before indicating a B-channel timeout
   ARTIMEOUT_CYCLES - total number of cycles to wait after arvalid is asserted before indicating an AR-channel timeout
   RTIMEOUT_CYCLES - total numner of cycles to wait after a valid AR request has been received for a response before indicating a B-channel timeout
   OUTSTANDING_WREQ - the maximum allowed oustanding write requests
   OUTSTANDING_RREQ - the maximum allowed outstanding read requests
   INCLUDE_BACKPRESSURE - binary, whether or not to assert backpressure when OUTSTANDING limits reached (recommended)
   W_BEFORE_AW_CAPABLE - binary, whether or not the module can expect W-channel beats before the corresponding AW request has been accepted

AXI-Lite Control Interface Register Space
   We have the following mapping (byte addressable, /4 for word addressable systems)
     [0] Decoupler registers 
          - bit 0 - decouple output register
          - bit 1 - decouple_done input register
          - bits 6..2 - decouple_status_vector input register
     [4] Protocol Verifier Registers
          - bit 0 - timeout_error_clear output register
          - bit 1 - timeout_error_irq input register
          - bits 6..2 - timeout_status_vector input register

Ports:
   axi_lite_s_* - the input memory mapped AXI interface
   axi_lite_m_* the output memory mapped AXI interface
   ctrl_* - the AXI-Lite control interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module ctrl_iso_top
#(
    //AXI-Lite Interface Params
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    
    //Timeout limits
    parameter AWTIMEOUT_CYCLES = 15,
    parameter WTIMEOUT_CYCLES = 15,
    parameter BTIMEOUT_CYCLES = 127,
    parameter ARTIMEOUT_CYCLES = 15,
    parameter RTIMEOUT_CYCLES = 127,
    
    //Additional Params to determine particular capabilities
    parameter OUTSTANDING_WREQ = 8,
    parameter OUTSTANDING_RREQ = 8,
    parameter INCLUDE_BACKPRESSURE = 1,
    parameter W_BEFORE_AW_CAPABLE = 1
)
(
    //AXI-Lite slave connection (connects to the master interface expecting a isolated signal)
    //Write Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_awaddr,
    input wire                              axi_lite_s_awvalid,
    output wire                             axi_lite_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_lite_s_wstrb,
    input wire                              axi_lite_s_wvalid,
    output wire                             axi_lite_s_wready,
    //Write Response Channel
    output wire [1:0]                       axi_lite_s_bresp,
    output wire                             axi_lite_s_bvalid,
    input wire                              axi_lite_s_bready,
    //Read Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_araddr,
    input wire                              axi_lite_s_arvalid,
    output wire                             axi_lite_s_arready,
    //Read Data Response Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_lite_s_rdata,
    output wire [1:0]                       axi_lite_s_rresp,
    output wire                             axi_lite_s_rvalid,
    input wire                              axi_lite_s_rready,

    //AXI4 master connection (the slave interface to isolate connects to this)
    //Write Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_awaddr,
    output wire                             axi_lite_m_awvalid,
    input wire                              axi_lite_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_lite_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_lite_m_wstrb,
    output wire                             axi_lite_m_wvalid,
    input wire                              axi_lite_m_wready,
    //Write Response Channel
    input wire [1:0]                        axi_lite_m_bresp,
    input wire                              axi_lite_m_bvalid,
    output wire                             axi_lite_m_bready,
    //Read Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_araddr,
    output wire                             axi_lite_m_arvalid,
    input wire                              axi_lite_m_arready,
    //Read Data Response Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_lite_m_rdata,
    input wire [1:0]                        axi_lite_m_rresp,
    input wire                              axi_lite_m_rvalid,
    output wire                             axi_lite_m_rready,

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

    //Axi-Lite interface on input of decoupler
    //Write Address Channel     
    wire [AXI_ADDR_WIDTH-1:0]        axi_lite_decoupled_awaddr;
    wire                             axi_lite_decoupled_awvalid;
    wire                             axi_lite_decoupled_awready;
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_lite_decoupled_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0]    axi_lite_decoupled_wstrb;
    wire                             axi_lite_decoupled_wvalid;
    wire                             axi_lite_decoupled_wready;
    //Write Response Channel
    wire [1:0]                       axi_lite_decoupled_bresp;
    wire                             axi_lite_decoupled_bvalid;
    wire                             axi_lite_decoupled_bready;
    //Read Address Channel     
    wire [AXI_ADDR_WIDTH-1:0]        axi_lite_decoupled_araddr;
    wire                             axi_lite_decoupled_arvalid;
    wire                             axi_lite_decoupled_arready;
    //Read Data Response Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_lite_decoupled_rdata;
    wire [1:0]                       axi_lite_decoupled_rresp;
    wire                             axi_lite_decoupled_rvalid;
    wire                             axi_lite_decoupled_rready;

    //Other decoupler signals
    wire        decouple;
    wire        decouple_force;
    wire        decouple_done;
    wire [4:0]  decouple_status_vector;
    wire        bresp_expected;
    wire        rresp_expected;

    //Decoupler instantiated
    axi_lite_slave_decoupler
    #(
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .OUTSTANDING_WREQ       (OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ       (OUTSTANDING_RREQ),
        .INCLUDE_BACKPRESSURE   (INCLUDE_BACKPRESSURE),
        .W_BEFORE_AW_CAPABLE    (W_BEFORE_AW_CAPABLE)
    )
    decoupler_inst
    (
        //AXI-Lite slave connection (connects to the master interface expecting a decoupled signal)
        .axi_lite_s_awaddr      (axi_lite_decoupled_awaddr),
        .axi_lite_s_awvalid     (axi_lite_decoupled_awvalid),
        .axi_lite_s_awready     (axi_lite_decoupled_awready),
        .axi_lite_s_wdata       (axi_lite_decoupled_wdata),
        .axi_lite_s_wstrb       (axi_lite_decoupled_wstrb),
        .axi_lite_s_wvalid      (axi_lite_decoupled_wvalid),
        .axi_lite_s_wready      (axi_lite_decoupled_wready),
        .axi_lite_s_bresp       (axi_lite_decoupled_bresp),
        .axi_lite_s_bvalid      (axi_lite_decoupled_bvalid),
        .axi_lite_s_bready      (axi_lite_decoupled_bready),
        .axi_lite_s_araddr      (axi_lite_decoupled_araddr),
        .axi_lite_s_arvalid     (axi_lite_decoupled_arvalid),
        .axi_lite_s_arready     (axi_lite_decoupled_arready),
        .axi_lite_s_rdata       (axi_lite_decoupled_rdata),
        .axi_lite_s_rresp       (axi_lite_decoupled_rresp),
        .axi_lite_s_rvalid      (axi_lite_decoupled_rvalid),
        .axi_lite_s_rready      (axi_lite_decoupled_rready),

        //AXI4 master connection (the slave interface to decouple connects to this)
        .axi_lite_m_awaddr      (axi_lite_m_awaddr),
        .axi_lite_m_awvalid     (axi_lite_m_awvalid),
        .axi_lite_m_awready     (axi_lite_m_awready),
        .axi_lite_m_wdata       (axi_lite_m_wdata),
        .axi_lite_m_wstrb       (axi_lite_m_wstrb),
        .axi_lite_m_wvalid      (axi_lite_m_wvalid),
        .axi_lite_m_wready      (axi_lite_m_wready),
        .axi_lite_m_bresp       (axi_lite_m_bresp),
        .axi_lite_m_bvalid      (axi_lite_m_bvalid),
        .axi_lite_m_bready      (axi_lite_m_bready),
        .axi_lite_m_araddr      (axi_lite_m_araddr),
        .axi_lite_m_arvalid     (axi_lite_m_arvalid),
        .axi_lite_m_arready     (axi_lite_m_arready),
        .axi_lite_m_rdata       (axi_lite_m_rdata),
        .axi_lite_m_rresp       (axi_lite_m_rresp),
        .axi_lite_m_rvalid      (axi_lite_m_rvalid),
        .axi_lite_m_rready      (axi_lite_m_rready),

        //Decoupler signals
        .decouple               (decouple),
        .decouple_force         (decouple_force),
        .decouple_done          (decouple_done),
        .decouple_status_vector (decouple_status_vector),

        //Signal to Verifier to indicate responses expected (Rather than duplicate logic there)
        .bresp_expected         (bresp_expected),
        .rresp_expected         (rresp_expected),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );



    //--------------------------------------------------------//
    //   Verifier                                             //
    //--------------------------------------------------------//

    //Axi-Lite interface on input of verifier
    //Write Address Channel     
    wire [AXI_ADDR_WIDTH-1:0]        axi_lite_verified_awaddr;
    wire                             axi_lite_verified_awvalid;
    wire                             axi_lite_verified_awready;
    //Write Data Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_lite_verified_wdata;
    wire [(AXI_DATA_WIDTH/8)-1:0]    axi_lite_verified_wstrb;
    wire                             axi_lite_verified_wvalid;
    wire                             axi_lite_verified_wready;
    //Write Response Channel
    wire [1:0]                       axi_lite_verified_bresp;
    wire                             axi_lite_verified_bvalid;
    wire                             axi_lite_verified_bready;
    //Read Address Channel     
    wire [AXI_ADDR_WIDTH-1:0]        axi_lite_verified_araddr;
    wire                             axi_lite_verified_arvalid;
    wire                             axi_lite_verified_arready;
    //Read Data Response Channel
    wire [AXI_DATA_WIDTH-1:0]        axi_lite_verified_rdata;
    wire [1:0]                       axi_lite_verified_rresp;
    wire                             axi_lite_verified_rvalid;
    wire                             axi_lite_verified_rready;

    //Other verifier signals
    wire         timeout_error_irq;
    wire [4:0]   timeout_status_vector;
    wire         timeout_error_clear;

    //Verifer instantiated
    axi_lite_slave_verifier
    #(
        .AXI_ADDR_WIDTH         (AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH         (AXI_DATA_WIDTH),
        .AWTIMEOUT_CYCLES       (AWTIMEOUT_CYCLES),
        .WTIMEOUT_CYCLES        (WTIMEOUT_CYCLES),
        .BTIMEOUT_CYCLES        (BTIMEOUT_CYCLES),
        .ARTIMEOUT_CYCLES       (ARTIMEOUT_CYCLES),
        .RTIMEOUT_CYCLES        (RTIMEOUT_CYCLES),
        .OUTSTANDING_WREQ       (OUTSTANDING_WREQ),
        .OUTSTANDING_RREQ       (OUTSTANDING_RREQ)
    )
    verify_inst
    (
        //AXI-Lite slave connection (connects to the master interface expecting a verified signal)
        .axi_lite_s_awaddr      (axi_lite_verified_awaddr),
        .axi_lite_s_awvalid     (axi_lite_verified_awvalid),
        .axi_lite_s_awready     (axi_lite_verified_awready),
        .axi_lite_s_wdata       (axi_lite_verified_wdata),
        .axi_lite_s_wstrb       (axi_lite_verified_wstrb),
        .axi_lite_s_wvalid      (axi_lite_verified_wvalid),
        .axi_lite_s_wready      (axi_lite_verified_wready),
        .axi_lite_s_bresp       (axi_lite_verified_bresp),
        .axi_lite_s_bvalid      (axi_lite_verified_bvalid),
        .axi_lite_s_bready      (axi_lite_verified_bready),
        .axi_lite_s_araddr      (axi_lite_verified_araddr),
        .axi_lite_s_arvalid     (axi_lite_verified_arvalid),
        .axi_lite_s_arready     (axi_lite_verified_arready),
        .axi_lite_s_rdata       (axi_lite_verified_rdata),
        .axi_lite_s_rresp       (axi_lite_verified_rresp),
        .axi_lite_s_rvalid      (axi_lite_verified_rvalid),
        .axi_lite_s_rready      (axi_lite_verified_rready),

        //AXI4 master connection (the slave interface to verify connects to this)
        .axi_lite_m_awaddr      (axi_lite_decoupled_awaddr),
        .axi_lite_m_awvalid     (axi_lite_decoupled_awvalid),
        .axi_lite_m_awready     (axi_lite_decoupled_awready),
        .axi_lite_m_wdata       (axi_lite_decoupled_wdata),
        .axi_lite_m_wstrb       (axi_lite_decoupled_wstrb),
        .axi_lite_m_wvalid      (axi_lite_decoupled_wvalid),
        .axi_lite_m_wready      (axi_lite_decoupled_wready),
        .axi_lite_m_bresp       (axi_lite_decoupled_bresp),
        .axi_lite_m_bvalid      (axi_lite_decoupled_bvalid),
        .axi_lite_m_bready      (axi_lite_decoupled_bready),
        .axi_lite_m_araddr      (axi_lite_decoupled_araddr),
        .axi_lite_m_arvalid     (axi_lite_decoupled_arvalid),
        .axi_lite_m_arready     (axi_lite_decoupled_arready),
        .axi_lite_m_rdata       (axi_lite_decoupled_rdata),
        .axi_lite_m_rresp       (axi_lite_decoupled_rresp),
        .axi_lite_m_rvalid      (axi_lite_decoupled_rvalid),
        .axi_lite_m_rready      (axi_lite_decoupled_rready),

        //Protocol error indicators
        .timeout_error_irq      (timeout_error_irq),
        .timeout_status_vector  (timeout_status_vector),
        .timeout_error_clear    (timeout_error_clear),

        //Inputs from Decoupler indicating if responses expected (rather than duplicating logic here)
        .bresp_expected         (bresp_expected),
        .rresp_expected         (rresp_expected),

        //Clocking
        .aclk                   (aclk),
        .aresetn                (aresetn)
    );

    //Feedback connections to decoupler
    assign decouple_force = timeout_error_irq;



    //--------------------------------------------------------//
    //   Final Input Assignment (wiht Reg Slice)              //
    //--------------------------------------------------------//

    //AW register slice
    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_ADDR_WIDTH)
    )
    aw_reg_slice
    (
        .in_data    (axi_lite_s_awaddr),
        .in_valid   (axi_lite_s_awvalid),
        .in_ready   (axi_lite_s_awready),

        .out_data   (axi_lite_verified_awaddr),
        .out_valid  (axi_lite_verified_awvalid),
        .out_ready  (axi_lite_verified_awready),
        
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //W register slice
    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_DATA_WIDTH + (AXI_DATA_WIDTH/8) )
    )
    w_reg_slice
    (
        .in_data    ({axi_lite_s_wdata,axi_lite_s_wstrb}),
        .in_valid   (axi_lite_s_wvalid),
        .in_ready   (axi_lite_s_wready),

        .out_data   ({axi_lite_verified_wdata,axi_lite_verified_wstrb}),
        .out_valid  (axi_lite_verified_wvalid),
        .out_ready  (axi_lite_verified_wready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //B register slice
    reg_slice_full_light
    #(
        .DATA_WIDTH(2)
    )
    b_reg_slice
    (
        .in_data    (axi_lite_verified_bresp),
        .in_valid   (axi_lite_verified_bvalid),
        .in_ready   (axi_lite_verified_bready),

        .out_data   (axi_lite_s_bresp),
        .out_valid  (axi_lite_s_bvalid),
        .out_ready  (axi_lite_s_bready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AR register slice
    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_ADDR_WIDTH)
    )
    ar_reg_slice
    (
        .in_data    (axi_lite_s_araddr),
        .in_valid   (axi_lite_s_arvalid),
        .in_ready   (axi_lite_s_arready),

        .out_data   (axi_lite_verified_araddr),
        .out_valid  (axi_lite_verified_arvalid),
        .out_ready  (axi_lite_verified_arready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //R register slice
    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_DATA_WIDTH + 2)
    )
    r_reg_slice
    (
        .in_data    ({axi_lite_verified_rdata,axi_lite_verified_rresp}),
        .in_valid   (axi_lite_verified_rvalid),
        .in_ready   (axi_lite_verified_rready),

        .out_data   ({axi_lite_s_rdata,axi_lite_s_rresp}),
        .out_valid  (axi_lite_s_rvalid),
        .out_ready  (axi_lite_s_rready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );

    //AXI input assignment
    /*assign axi_lite_verified_awaddr = axi_lite_s_awaddr;
    assign axi_lite_verified_awvalid = axi_lite_s_awvalid;
    assign axi_lite_s_awready = axi_lite_verified_awready;

    assign axi_lite_verified_wdata = axi_lite_s_wdata;
    assign axi_lite_verified_wstrb = axi_lite_s_wstrb;
    assign axi_lite_verified_wvalid = axi_lite_s_wvalid;
    assign axi_lite_s_wready = axi_lite_verified_wready;
    
    assign axi_lite_s_bresp = axi_lite_verified_bresp;
    assign axi_lite_s_bvalid = axi_lite_verified_bvalid;
    assign axi_lite_verified_bready = axi_lite_s_bready;
            
    assign axi_lite_verified_araddr = axi_lite_s_araddr;
    assign axi_lite_verified_arvalid = axi_lite_s_arvalid;
    assign axi_lite_s_arready = axi_lite_verified_arready;
    
    assign axi_lite_s_rdata = axi_lite_verified_rdata;
    assign axi_lite_s_rresp = axi_lite_verified_rresp;
    assign axi_lite_s_rvalid = axi_lite_verified_rvalid;
    assign axi_lite_verified_rready = axi_lite_s_rready;*/



    //--------------------------------------------------------//
    //   Control Path                                         //
    //--------------------------------------------------------//

    //Instantiate Register File
    ctrl_iso_reg_file reg_file_inst
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