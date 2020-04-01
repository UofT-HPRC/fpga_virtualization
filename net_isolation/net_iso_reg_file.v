`timescale 1ns / 1ps
`default_nettype none

/*
The Control Registers for the AXI-Stream Interface Isolation Core

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This module is the register file for the AXI-Stream Interface Isolation
   Core. It continas the registers required for the decoupler, the
   protocol verifier, and the bandwidth shaper (optional).

Parameters:
   TOKEN_COUNT_INT_WIDTH - the token count integer component width for the bandwidth shaper (fixed point representation)
   TOKEN_COUNT_FRAC_WIDTH - the token count fractional component width for the bandwidth shaper (fixed point representation)

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
   [aw|w|b|ar|r]* - the AXI-Lite control interface
   decouple - output register, to activate decouplers
   decouple_done - input regster, ack of above when complete
   decouple_status_vector - input register, state of decoupling for both ingress and egress channels
   oversize_error_irq - input register, whether or not an oversize egress packet was sent
   oversize_error_clear - output register, to clear the oversize decouple condition
   timeout_error_irq - input register, whether or not a timeout condition has occured on ingress
   timeout_error_clear - output register, to clear the timeout condition (asserted for a single cycle only)
   rx_packet_dropped - indicates that an RX packet has been dropped in the decoupled state
   *_token - output registers, the token init and update values for the BW Shaper
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/


module net_iso_reg_file
#(
    //Token counter parameters
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8
)
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
    input wire          decouple_done,
    input wire [1:0]    decouple_status_vector,

    //Signals to/from prot_verifier
    input wire          oversize_error_irq,
    output reg          oversize_error_clear,
    input wire          timeout_error_irq,
    output reg          timeout_error_clear,

    //Signals for statistics counters
    input wire          rx_packet_dropped,

    //Signals to bw_shaper
    output reg [TOKEN_COUNT_INT_WIDTH-1:0]  init_token,
    output reg [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token,

    //Clocking
    input wire aclk,
    input wire aresetn
);

  
    //--------------------------------------------------------//
    //  Parameters for register addresses in AXIL space       //
    //--------------------------------------------------------//

    localparam DECOUPLE_REG_ADDR = 0; //{decouple_status_vector, decouple_done, decouple}
    localparam VERIFIER_REG_ADDR = 1; //{timeout_error_irq, oversize_error_irq, timeout_error_clear, oversize_error_clear}
    localparam INIT_REG_ADDR = 2;
    localparam UPD_REG_ADDR = 3;
    localparam RX_PACK_DROP = 4;

    
    
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

    //Indicate resets for stat counters
    reg stat_rx_packets_dropped_reset;

    //Write to the registers
    //NOTE - ignores wstrb 
    always @(posedge aclk) begin

        //clear back to zero (only asserted for a single cycle)
        timeout_error_clear <= 0;
        stat_rx_packets_dropped_reset <= 0;

        if(~aresetn) begin

            decouple <= 0;
            oversize_error_clear <= 0;
            timeout_error_clear <= 0;
            init_token <= 0;
            init_token <= 0;
            stat_rx_packets_dropped_reset <= 0;
        
        end else if(slv_reg_wren) begin

            //Check address for which register to write to
            if(wr_addr == DECOUPLE_REG_ADDR) begin

                decouple <= wdata[0];

            end
            else if(wr_addr == VERIFIER_REG_ADDR) begin

                oversize_error_clear <= wdata[0];
                timeout_error_clear <= wdata[1];

            end
            else if(wr_addr == INIT_REG_ADDR) begin

                init_token <= wdata[0+:TOKEN_COUNT_INT_WIDTH];

            end 
            else if(wr_addr == UPD_REG_ADDR) begin

                upd_token <= wdata[0+:TOKEN_COUNT_FRAC_WIDTH+1];

            end
            else if(wr_addr == RX_PACK_DROP) begin

                //Any write triggers a reset
                stat_rx_packets_dropped_reset <= 1;

            end
           
        end

    end 


    
    //--------------------------------------------------------//
    //  Statistics Counters                                   //
    //--------------------------------------------------------//

    //Registers for stats
    reg [31:0] stat_rx_packets_dropped;

    always @(posedge aclk) begin
        if(~aresetn || stat_rx_packets_dropped_reset) 
            stat_rx_packets_dropped <= 0;
        else if(rx_packet_dropped) 
            stat_rx_packets_dropped <= stat_rx_packets_dropped + 1;
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

            reg_data_out = {decouple_status_vector,decouple_done,decouple};

        end
        else if(rd_addr == VERIFIER_REG_ADDR) begin

            reg_data_out = {timeout_error_irq,oversize_error_irq,timeout_error_clear,oversize_error_clear};

        end
        else if(rd_addr == INIT_REG_ADDR) begin

            reg_data_out = init_token;

        end 
        else if(rd_addr == UPD_REG_ADDR) begin

            reg_data_out = upd_token;

        end
        else if(rd_addr == RX_PACK_DROP) begin

            reg_data_out = stat_rx_packets_dropped;
            
        end

    end 
    


endmodule

`default_nettype wire