`timescale 1ns / 1ps
`default_nettype none

/*
AXI Reg Slice Pack Module

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   An AXI Stream register pack, typically used to insert a pack of registers
   into an AXI Stream in order to facilitate retiming. Note, zero widths for 
   any of the signals is not supported.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi stream
   AXIS_TID_WIDTH - the width of the tid signal
   AXIS_TDEST_WIDTH - the width of the tdest signal
   AXIS_TUSER_WIDTH - the width of the tuser signal
   REG_STAGES - the number of register stages to include (zero creates a pass-through)

Ports:
   axis_in_* - input axi stream to be routed
   axis_out_#_* - output axi stream corresponding to interface #
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axi_stream_reg_slice_pack
#(
	//AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_TID_WIDTH = 1,
    parameter AXIS_TDEST_WDITH = 1,
    parameter AXIS_TUSER_WIDTH = 1,

    //Register Stage Number
    parameter REG_STAGES = 2
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [AXIS_TUSER_WIDTH-1:0]     axis_in_tuser,
    input wire [AXIS_TID_WIDTH-1:0]       axis_in_tid,
    input wire [AXIS_TDEST_WDITH-1:0]     axis_in_tdest,                                       
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [AXIS_TUSER_WIDTH-1:0]    axis_out_tuser,
    output wire [AXIS_TID_WIDTH-1:0]      axis_out_tid,
    output wire [AXIS_TDEST_WDITH-1:0]    axis_out_tdest,                                        
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

	//Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,



    //--------------------------------------------------------//
    //   Register Signals                                     //
    //--------------------------------------------------------//

    //The Registers
    reg [AXIS_BUS_WIDTH-1:0]      axis_reg_out_tdata [REG_STAGES:0];
    reg [AXIS_TUSER_WIDTH-1:0]    axis_reg_out_tuser [REG_STAGES:0];
    reg [AXIS_TID_WIDTH-1:0]      axis_reg_out_tid [REG_STAGES:0];
    reg [AXIS_TDEST_WDITH-1:0]    axis_reg_out_tdest [REG_STAGES:0];
    reg [NUM_BUS_BYTES-1:0]       axis_reg_out_tkeep [REG_STAGES:0];
    reg                           axis_reg_out_tlast [REG_STAGES:0];
    reg                           axis_reg_out_tvalid [REG_STAGES:0];

    //Input assignment
    assign axis_reg_out_tdata[0] = axis_in_tdata;
    assign axis_reg_out_tuser[0] = axis_in_tuser;
    assign axis_reg_out_tid[0] = axis_in_tid;
    assign axis_reg_out_tdest[0] = axis_in_tdest;
    assign axis_reg_out_tkeep[0] = axis_in_tkeep;
    assign axis_reg_out_tlast[0] = axis_in_tlast;
    assign axis_reg_out_tvalid[0] = axis_in_tvalid;

    assign axis_in_tready = axis_out_tready;



    //--------------------------------------------------------//
    //   Regster Assignment                                   //
    //--------------------------------------------------------//

    //Retiming registers instantiated
    generate 
        for(genvar j = 1; j <= REG_STAGES; j = j + 1) begin : retime_reg_pack 
            always@(posedge aclk) begin
                if(~aresetn) begin

                    axis_reg_out_tvalid[j] <= 0;

                end 
                else if(axis_out_tready) begin

                    axis_reg_out_tdata[j] <= axis_reg_out_tdata[j-1];
                    axis_reg_out_tuser[j] <= axis_reg_out_tuser[j-1];
                    axis_reg_out_tid[j] <= axis_reg_out_tid[j-1];
                    axis_reg_out_tdest[j] <= axis_reg_out_tdest[j-1];
                    axis_reg_out_tkeep[j] <= axis_reg_out_tkeep[j-1];
                    axis_reg_out_tlast[j] <= axis_reg_out_tlast[j-1];
                    axis_reg_out_tvalid[j] <= axis_reg_out_tvalid[j-1];

                end
            end
        end
    endgenerate

    //Assign outputs
    assign axis_out_tdata = axis_reg_out_tdata[REG_STAGES];
    assign axis_out_tuser = axis_reg_out_tuser[REG_STAGES];
    assign axis_out_tid = axis_reg_out_tid[REG_STAGES];
    assign axis_out_tdest = axis_reg_out_tdest[REG_STAGES];
    assign axis_out_tkeep = axis_reg_out_tkeep[REG_STAGES];
    assign axis_out_tlast = axis_reg_out_tlast[REG_STAGES];
    assign axis_out_tvalid = axis_reg_out_tvalid[REG_STAGES];



endmodule

`default_nettype wire