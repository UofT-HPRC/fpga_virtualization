`timescale 1ns / 1ps
`default_nettype none

/*
The Control Registers for Clock and Reset decoupling

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is the register file for the decouple signal
   sent to the clock decoupler and is used to generate a reset
   to the application region

AXI-Lite Control Interface Register Space
   We have the following mapping (byte addressable, /4 for word addressable systems)
     [0] Decoupler registers 
          - bit 0 - decouple output register
     [4] Reset registers
          - bit 0 - assert_reset output resgiter (active_high)

Ports:
   [aw|w|b|ar|r]* - the AXI-Lite control interface
   decouple - output register, to activate clock decoupler
   asert_reset - output register, to assert reset for the application region
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module clock_reset_decouple_controller
(
    //The AXI-Lite interface
    input wire  [31:0]                 awaddr,
    input wire                         awvalid,
    output reg                         awready,
    
    input wire  [31:0]                 wdata,
    //input wire  [3:0]                  wstrb,
    input wire                         wvalid,
    output reg                         wready,

    output reg [1:0]                   bresp,
    output reg                         bvalid,
    input wire                         bready,
    
    input wire  [31:0]                 araddr,
    input wire                         arvalid,
    output reg                         arready,

    output reg [31:0]                  rdata,
    output reg [1:0]                   rresp,
    output reg                         rvalid,
    input wire                         rready,
    
    //Signals to/from decoupler
    output reg          decouple,

    //Signals to/from reset
    output reg          assert_reset,

    //Clocking
    input wire aclk,
    input wire aresetn
);

  
    //--------------------------------------------------------//
    //  Parameters for register addresses in AXIL space       //
    //--------------------------------------------------------//

    localparam DECOUPLE_REG_ADDR = 0;
    localparam RESET_REG_ADDR = 1;

    
    
    //--------------------------------------------------------//
    //  AXI-Lite protocol implementation                      //
    //--------------------------------------------------------//
    
    //AXI-LITE registered signals
    reg [31:0]         awaddr_reg;
    reg [31:0]         araddr_reg;
    reg [31:0]         reg_data_out;
    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) awready <= 1'b0;
        else if (~awready && awvalid && wvalid) awready <= 1'b1;
        else awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge aclk) begin
        if (~aresetn) awaddr_reg <= 0;
        else if (~awready && awvalid && wvalid) awaddr_reg <= awaddr; 
    end
    
    //wready asserted once valid write request and data availavle
    always @(posedge aclk) begin
        if (~aresetn) wready <= 1'b0;
        else if (~wready && wvalid && awvalid) wready <= 1'b1;
        else wready <= 1'b0;
    end

    //write response logic
    always @(posedge aclk) begin
        if (~aresetn) begin
            bvalid  <= 1'b0;
            bresp   <= 2'b0;
        end else if (awready && awvalid && ~bvalid && wready && wvalid) begin
            bvalid <= 1'b1;
            bresp  <= 2'b0; // 'OKAY' response 
        end else if (bready && bvalid)  begin
            bvalid <= 1'b0; 
            bresp  <= 2'b0;
        end  
    end
    
    //arready asserted once valid read request available
    always @(posedge aclk) begin
        if (~aresetn) arready <= 1'b0;
        else if (~arready && arvalid) arready <= 1'b1;
        else arready <= 1'b0;
    end

    //Register araddr value
    always @(posedge aclk) begin
        if (~aresetn) araddr_reg  <= 32'b0;
        else if (~arready && arvalid) araddr_reg  <= araddr;
    end
    
    //Read response logic  
    always @(posedge aclk) begin
        if (~aresetn) begin
            rvalid <= 1'b0;
            rresp  <= 1'b0;
        end else if (arready && arvalid && ~rvalid) begin
            rvalid <= 1'b1;
            rresp  <= 2'b0; // 'OKAY' response
        end else if (rvalid && rready) begin
            rvalid <= 1'b0;
            rresp  <= 2'b0;
        end                
    end

    //Read and write enables
    wire slv_reg_wren = wready && wvalid && awready && awvalid;
    wire slv_reg_rden = arready & arvalid & ~rvalid;

    //register the output rdata
    always @(posedge aclk) begin
        if (~aresetn) rdata  <= 0;
        else if (slv_reg_rden) rdata <= reg_data_out;
    end



    //--------------------------------------------------------//
    //  Write Functionality                                   //
    //--------------------------------------------------------//
    
    //Segment address signal
    localparam ADDR_LSB = 2;
    localparam ADDR_WIDTH_ALIGNED = 12 - ADDR_LSB;

    wire [ADDR_WIDTH_ALIGNED-1:0]   wr_addr = awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];

    //Write to the registers
    //NOTE - ignores wstrb 
    always @(posedge aclk) begin


        if(~aresetn) begin

            decouple <= 0;
            assert_reset <= 0;
        
        end else if(slv_reg_wren) begin

            //Check address for which register to write to
            if(wr_addr == DECOUPLE_REG_ADDR) begin

                decouple <= wdata[0];

            end
            else if(wr_addr == RESET_REG_ADDR) begin

                assert_reset <= wdata[0];

            end
           
        end

    end 


    
    //--------------------------------------------------------//
    //  Read Functionality                                    //
    //--------------------------------------------------------//

    //Segment address signal
    wire [ADDR_WIDTH_ALIGNED-1:0]   rd_addr = araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];

    //Read from the registers
    always @(*) begin

        //Defualt assignment
        reg_data_out = 0;

        //Check address for register to read from
        if(rd_addr == DECOUPLE_REG_ADDR) begin

            reg_data_out = decouple;

        end
        else if(rd_addr == RESET_REG_ADDR) begin

            reg_data_out = assert_reset;

        end

    end
    


endmodule

`default_nettype wire