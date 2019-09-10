`timescale 1ns / 1ps
`default_nettype none




//The MAC Parser Module
module simple_nmu
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4
)
(
    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_egr_in_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_egr_in_tkeep,
    input wire                            axis_egr_in_tlast,
    input wire                            axis_egr_in_tvalid,
    output wire                           axis_egr_in_tready,
    
    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_egr_out_tdata,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_egr_out_tkeep,
    output wire                           axis_egr_out_tlast,
    output wire                           axis_egr_out_tvalid,
    input wire                            axis_egr_out_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_ingr_in_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_ingr_in_tkeep,
    input wire                            axis_ingr_in_tlast,
    input wire                            axis_ingr_in_tvalid,
    output wire                           axis_ingr_in_tready,
    
    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_ingr_out_tdata,
    output wire [AXIS_ID_WIDTH-1:0]		  axis_ingr_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_ingr_out_tkeep,
    output wire                           axis_ingr_out_tlast,
    output wire                           axis_ingr_out_tvalid,
    input wire                            axis_ingr_out_tready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Egress Path                                          //
    //--------------------------------------------------------//

    //Stream passthrough
	assign axis_egr_out_tdata = axis_egr_in_tdata;
	assign axis_egr_out_tkeep = axis_egr_in_tkeep;
	assign axis_egr_out_tlast = axis_egr_in_tlast;
	assign axis_egr_out_tvalid = axis_egr_in_tvalid;

	assign axis_egr_in_tready = axis_egr_out_tready;
    

    
    //--------------------------------------------------------//
    //   Ingress Path (with tDest determination)              //
    //--------------------------------------------------------//
    
	//Stream passthrough
	assign axis_ingr_out_tdata = axis_ingr_in_tdata;
	assign axis_ingr_out_tkeep = axis_ingr_in_tkeep;
	assign axis_ingr_out_tlast = axis_ingr_in_tlast;
	assign axis_ingr_out_tvalid = axis_ingr_in_tvalid;

	assign axis_ingr_in_tready = axis_ingr_out_tready;

	//tDest from Dest MAC address
	reg [AXIS_ID_WIDTH-1:0]		reg_ingr_out_tdest;
	reg 						reg_tdest_init;
	
	wire [AXIS_ID_WIDTH-1:0]	cur_ingr_out_tdest = 
		{	axis_ingr_in_tdata[0+:8],
			axis_ingr_in_tdata[8+:8],
			axis_ingr_in_tdata[16+:8],
			axis_ingr_in_tdata[24+:8],
			axis_ingr_in_tdata[32+:8],
			axis_ingr_in_tdata[40+:8]
		}; //Assign LSB of Dest MAC to determine AXI ID to route to

	wire valid_beat = axis_ingr_in_tvalid && axis_ingr_out_tready;
	wire final_beat = valid_beat && axis_ingr_in_tlast;

	always @(posedge aclk) begin
		if(~aresetn || final_beat) reg_tdest_init <= 0;
		else if(valid_beat) reg_tdest_init <= 1;
	end

	always @(posedge aclk) begin
		if(~aresetn) reg_ingr_out_tdest <= 0;
		else if(valid_beat && !reg_tdest_init) reg_ingr_out_tdest <= cur_ingr_out_tdest;
	end 

	assign axis_ingr_out_tdest = (!reg_tdest_init) ? cur_ingr_out_tdest : reg_ingr_out_tdest;



endmodule

`default_nettype wire