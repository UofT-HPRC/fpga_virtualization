`timescale 1ns / 1ps
`default_nettype none

/*
An NMU which forwards all received packets to a specific AXI ID always

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is a Network Management Unit designed to allow a single
   nework interface to be shared by multiple AXI-Stream ports. All TX
   packets pass through the core, while RX packets are augmented with
   a tdest signal to identify which AXI-Stream port to route to. The
   tdest signal is set to a single AXI-Stream port, set through the
   AXI-Lite control interface. Note, zero widths for any of the signals
   is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction

AXI-Lite Control Interface Register Space
   There is only a single register, all reads and writes map to this register
     [0] - The ID of the interface to route RX packets to

Ports:
   axis_tx_s_* - the input axi stream for the tx direction
   axis_tx_m_* - the output axi stream for the tx direction
   axis_rx_s_* - the input axi stream for the rx direction
   axis_rx_m_* - the output axi stream for the rx direction
   ctrl_* - the axi-lite control interface to set the register value
   aclk - clock to which all of the network signals are synchronous
   aresetn - active-low reset corresponding to above clock
*/


module exclusive_nmu
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4
)
(
    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_tx_s_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_tx_s_tkeep,
    input wire                            axis_tx_s_tlast,
    input wire                            axis_tx_s_tvalid,
    output wire                           axis_tx_s_tready,
    
    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_tx_m_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_tx_m_tkeep,
    output wire                           axis_tx_m_tlast,
    output wire                           axis_tx_m_tvalid,
    input wire                            axis_tx_m_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_rx_s_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_rx_s_tkeep,
    input wire                            axis_rx_s_tlast,
    input wire                            axis_rx_s_tvalid,
    output wire                           axis_rx_s_tready,
    
    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]     axis_rx_m_tdata,
    output wire [AXIS_ID_WIDTH-1:0]      axis_rx_m_tdest, 
    output wire [(AXIS_BUS_WIDTH/8)-1:0] axis_rx_m_tkeep,
    output wire                          axis_rx_m_tlast,
    output wire                          axis_rx_m_tvalid,
    input wire                           axis_rx_m_tready,

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
    //   Egress Path                                          //
    //--------------------------------------------------------//

    //Stream passthrough
	assign axis_tx_m_tdata = axis_tx_s_tdata;
	assign axis_tx_m_tkeep = axis_tx_s_tkeep;
	assign axis_tx_m_tlast = axis_tx_s_tlast;
	assign axis_tx_m_tvalid = axis_tx_s_tvalid;

	assign axis_tx_s_tready = axis_tx_m_tready;
    

    
    //--------------------------------------------------------//
    //   Ingress Path (with tdest determination)              //
    //--------------------------------------------------------//
    
	//Stream passthrough
	assign axis_rx_m_tdata = axis_rx_s_tdata;
	assign axis_rx_m_tkeep = axis_rx_s_tkeep;
	assign axis_rx_m_tlast = axis_rx_s_tlast;
	assign axis_rx_m_tvalid = axis_rx_s_tvalid;

	assign axis_rx_s_tready = axis_rx_m_tready;

	//tDest value stored in register
	reg [AXIS_ID_WIDTH-1:0] reg_rx_out_tdest;
	assign axis_rx_m_tdest = reg_rx_out_tdest;



    //--------------------------------------------------------//
    //   AXI-Lite Implementation                              //
    //--------------------------------------------------------//

    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_awready <= 1'b0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awready <= 1'b1;
        else ctrl_awready <= 1'b0;
    end 
    
    //wready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_wready <= 1'b0;
        else if (~ctrl_wready && ctrl_wvalid && ctrl_awvalid) ctrl_wready <= 1'b1;
        else ctrl_wready <= 1'b0;
    end

    //write response logic
    always @(posedge aclk) begin
        if (~aresetn) begin
            ctrl_bvalid  <= 1'b0;
            ctrl_bresp   <= 2'b0;
        end else if (ctrl_awready && ctrl_awvalid && ~ctrl_bvalid && ctrl_wready && ctrl_wvalid) begin
            ctrl_bvalid <= 1'b1;
            ctrl_bresp  <= 2'b0; // 'OKAY' response 
        end else if (ctrl_bready && ctrl_bvalid)  begin
            ctrl_bvalid <= 1'b0; 
            ctrl_bresp  <= 2'b0;
        end  
    end
    
    //arready asserted once valid read request available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_arready <= 1'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_arready <= 1'b1;
        else ctrl_arready <= 1'b0;
    end
    
    //Read response logic  
    always @(posedge aclk) begin
        if (~aresetn) begin
            ctrl_rvalid <= 1'b0;
            ctrl_rresp  <= 1'b0;
        end else if (ctrl_arready && ctrl_arvalid && ~ctrl_rvalid) begin
            ctrl_rvalid <= 1'b1;
            ctrl_rresp  <= 2'b0; // 'OKAY' response
        end else if (ctrl_rvalid && ctrl_rready) begin
            ctrl_rvalid <= 1'b0;
            ctrl_rresp  <= 2'b0;
        end                
    end

    //Read and write enables
    wire slv_reg_wren = ctrl_wready && ctrl_wvalid && ctrl_awready && ctrl_awvalid;
    wire slv_reg_rden = ctrl_arready & ctrl_arvalid & ~ctrl_rvalid;


    //Write to the Register
    always @(posedge aclk) begin
        if(~aresetn) reg_rx_out_tdest  <= 0;
        else if(slv_reg_wren) reg_rx_out_tdest <= ctrl_wdata;
    end 

    //Read from Register
    always @(posedge aclk) begin
        if(~aresetn) ctrl_rdata <= 0;
        else if(slv_reg_rden) ctrl_rdata <= reg_rx_out_tdest;
    end



endmodule

`default_nettype wire