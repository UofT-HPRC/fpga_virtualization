`timescale 1ns / 1ps
`default_nettype none



//NMU
module exclusive_nmu
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    parameter CTRL_AXIL_ADDR_WIDTH = 2
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

    //The AXI-Lite Control Interface
    //Write Address Channel  
    input wire  [CTRL_AXIL_ADDR_WIDTH-1:0]  ctrl_awaddr,
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
    input wire  [CTRL_AXIL_ADDR_WIDTH-1:0]  ctrl_araddr,
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

	//tDest value stored in register
	reg [AXIS_ID_WIDTH-1:0] reg_ingr_out_tdest;
	assign axis_ingr_out_tdest = reg_ingr_out_tdest;



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
        if(~aresetn) reg_ingr_out_tdest  <= 0;
        else if(slv_reg_wren) reg_ingr_out_tdest <= ctrl_wdata;
    end 

    //Read from Register
    always @(posedge aclk) begin
        if(~aresetn) ctrl_rdata <= 0;
        else if(slv_reg_rden) ctrl_rdata <= reg_ingr_out_tdest;
    end



endmodule

`default_nettype wire