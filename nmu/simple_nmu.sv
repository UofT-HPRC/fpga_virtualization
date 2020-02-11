`timescale 1ns / 1ps
`default_nettype none

/*
An NMU which uses the LSB of the MAC to detremine the destination

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is a Network Management Unit designed to allow a single
   nework interface to be shared by multiple AXI-Stream ports. All TX
   packets pass through the core, while RX packets are augmented with
   a tdest signal to identify which AXI-Stream port to route to. The
   tdest is set to the LSBs of the destination MAC. Note, zero widths
   for any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction

Ports:
   axis_tx_s_* - the input axi stream for the tx direction
   axis_tx_m_* - the output axi stream for the tx direction
   axis_rx_s_* - the input axi stream for the rx direction
   axis_rx_m_* - the output axi stream for the rx direction
   aclk - clock to which all of the network signals are synchronous
   aresetn - active-low reset corresponding to above clock
*/


module simple_nmu
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
    //   Ingress Path (with tDest determination)              //
    //--------------------------------------------------------//
    
	//Stream passthrough
	assign axis_rx_m_tdata = axis_rx_s_tdata;
	assign axis_rx_m_tkeep = axis_rx_s_tkeep;
	assign axis_rx_m_tlast = axis_rx_s_tlast;
	assign axis_rx_m_tvalid = axis_rx_s_tvalid;

	assign axis_rx_s_tready = axis_rx_m_tready;

	//tDest from Dest MAC address
	reg [AXIS_ID_WIDTH-1:0]		reg_rx_m_tdest;
	reg 						reg_tdest_init;
	
	wire [AXIS_ID_WIDTH-1:0]	cur_rx_m_tdest = 
		{	axis_rx_s_tdata[0+:8],
			axis_rx_s_tdata[8+:8],
			axis_rx_s_tdata[16+:8],
			axis_rx_s_tdata[24+:8],
			axis_rx_s_tdata[32+:8],
			axis_rx_s_tdata[40+:8]
		}; //Assign LSB of Dest MAC to determine AXI ID to route to

	wire valid_beat = axis_rx_s_tvalid && axis_rx_m_tready;
	wire final_beat = valid_beat && axis_rx_s_tlast;

	always @(posedge aclk) begin
		if(~aresetn || final_beat) reg_tdest_init <= 0;
		else if(valid_beat) reg_tdest_init <= 1;
	end

	always @(posedge aclk) begin
		if(~aresetn) reg_rx_m_tdest <= 0;
		else if(valid_beat && !reg_tdest_init) reg_rx_m_tdest <= cur_rx_m_tdest;
	end 

	assign axis_rx_m_tdest = (!reg_tdest_init ? cur_rx_m_tdest : reg_rx_m_tdest);



endmodule

`default_nettype wire