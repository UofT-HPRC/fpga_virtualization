`timescale 1ns / 1ps
`default_nettype none

/*
AXIL Register Slice Module

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   An AXI-Lite register slice for all channels, inserting bubble cycles
   for full valid and ready signal registering

Parameters:
   AXI_ADDR_WIDTH - the address width of the AXIL interface

Ports:
   axi_lite_s_* - the input memory mapped AXI interface
   axi_lite_m_* - the output memory mapped AXI interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module axil_reg_slice
#(
	//AXI Stream Params
    parameter AXI_ADDR_WIDTH = 32
)
(
    //AXI-Lite slave connection
    //Write Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         axi_lite_s_awaddr,
    input wire                              axi_lite_s_awvalid,
    output wire                             axi_lite_s_awready,
    //Write Data Channel
    input wire [(32))-1:0]                  axi_lite_s_wdata,
    input wire [(32/8)-1:0]                 axi_lite_s_wstrb,
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
    output wire [(32)-1:0]                  axi_lite_s_rdata,
    output wire [1:0]                       axi_lite_s_rresp,
    output wire                             axi_lite_s_rvalid,
    input wire                              axi_lite_s_rready,

    //AXI-Lite master connection
    //Write Address Channel     
    output wire [AXI_ADDR_WIDTH-1:0]        axi_lite_m_awaddr,
    output wire                             axi_lite_m_awvalid,
    input wire                              axi_lite_m_awready,
    //Write Data Channel
    output wire [(32))-1:0]                 axi_lite_m_wdata,
    output wire [(32/8)-1:0]                axi_lite_m_wstrb,
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
    input wire [(32)-1:0]                   axi_lite_m_rdata,
    input wire [1:0]                        axi_lite_m_rresp,
    input wire                              axi_lite_m_rvalid,
    output wire                             axi_lite_m_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   AW Channel                                           //
    //--------------------------------------------------------//

    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_ADDR_WIDTH)
    )
    aw_reg_slice
    (
        .in_data    (axi_lite_s_awaddr),
        .in_valid   (axi_lite_s_awvalid),
        .in_ready   (axi_lite_s_awready),

        .out_data   (axi_lite_m_awaddr),
        .out_valid  (axi_lite_m_awvalid),
        .out_ready  (axi_lite_m_awready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );



    //--------------------------------------------------------//
    //   W Channel                                            //
    //--------------------------------------------------------//

    reg_slice_full_light
    #(
        .DATA_WIDTH( 32 + (32/8) )
    )
    aw_reg_slice
    (
        .in_data    ( { axi_lite_s_wdata, 
                        axi_lite_s_wstrb } ),
        .in_valid   (axi_lite_s_wvalid),
        .in_ready   (axi_lite_s_wready),

        .out_data   ( { axi_lite_m_wdata, 
                        axi_lite_m_wstrb } ),
        .out_valid  (axi_lite_m_wvalid),
        .out_ready  (axi_lite_m_wready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );



    //--------------------------------------------------------//
    //   B Channel                                            //
    //--------------------------------------------------------//

    reg_slice_full_light
    #(
        .DATA_WIDTH(2)
    )
    aw_reg_slice
    (
        .in_data    (axi_lite_m_bresp),
        .in_valid   (axi_lite_m_bvalid),
        .in_ready   (axi_lite_m_bready),

        .out_data   (axi_lite_s_bresp),
        .out_valid  (axi_lite_s_bvalid),
        .out_ready  (axi_lite_s_bready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );



    //--------------------------------------------------------//
    //   AR Channel                                           //
    //--------------------------------------------------------//

    reg_slice_full_light
    #(
        .DATA_WIDTH(AXI_ADDR_WIDTH)
    )
    aw_reg_slice
    (
        .in_data    (axi_lite_s_araddr),
        .in_valid   (axi_lite_s_arvalid),
        .in_ready   (axi_lite_s_arready),

        .out_data   (axi_lite_m_araddr),
        .out_valid  (axi_lite_m_arvalid),
        .out_ready  (axi_lite_m_arready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );



    //--------------------------------------------------------//
    //   R Channel                                            //
    //--------------------------------------------------------//

    reg_slice_full_light
    #(
        .DATA_WIDTH( 32 + 2 )
    )
    aw_reg_slice
    (
        .in_data    ( { axi_lite_m_rresp,
                        axi_lite_m_rdata  } ),
        .in_valid   (axi_lite_m_rvalid),
        .in_ready   (axi_lite_m_rready),

        .out_data   ( { axi_lite_s_rresp,
                        axi_lite_s_rdata  } ),
        .out_valid  (axi_lite_s_rvalid),
        .out_ready  (axi_lite_s_rready),
                
        .clk        (aclk),
        .resetn     (aresetn)
    );
    



endmodule

`default_nettype wire