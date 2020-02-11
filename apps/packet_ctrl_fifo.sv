`timescale 1ns / 1ps
`default_nettype none

/*
Simple network packet sender and receiver tester app

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This application connects a FIFO to the TX interface of a 
   network connection and another FIFO to the RX interface of
   the network connection. The FIFOs are writable and readable
   respectively from the control interface. This allows for the
   sending and receiving of packet data to/from the network
   using AXI-lite.

Parameters:
   AXIS_BUS_WIDTH - the data width of the axi-streams (must be multiple of 8)
   AXIS_ID_WIDTH - the width of the AXI ID signals in the TX direction and TDEST signals in the RX direction
   AXIS_DEST_WIDTH - the width of all network stream AXI DEST sigals
   MAX_FIFO_DEPTH - maximum fifo size (make large enough to prevent dropped beats)

Ports:
   axis_out_* - the output network interface, to send packets
   axis_in_* - the input network interface, to receive packets
   ctrl_* - the input AXI-Lite control interface
   aclk - clock to which all signala are synchronous
   aresetn - active-low reset corresponding to above clock
*/



module packet_ctrl_fifo
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Features
    parameter MAX_FIFO_DEPTH = 256 //Must be power of 2, greater than MTU/AXIS_BUS_WIDTH
)
(
    //Egress Output AXI stream
    output reg [AXIS_BUS_WIDTH-1:0]     axis_out_tdata,
    output reg [AXIS_ID_WIDTH-1:0]      axis_out_tid,
    output reg [AXIS_DEST_WIDTH-1:0]    axis_out_tdest,
    output reg [(AXIS_BUS_WIDTH/8)-1:0] axis_out_tkeep,
    output reg                          axis_out_tlast,
    output reg                          axis_out_tvalid,
    input wire                          axis_out_tready,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [AXIS_ID_WIDTH-1:0]      axis_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0] axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,

    //The AXI-Lite Control Interface
    //Write Address Channel
    input wire  [31:0]      ctrl_awaddr,
    input wire              ctrl_awvalid,
    output reg              ctrl_awready,
    //Write Data Channel
    input wire  [31:0]      ctrl_wdata,
    //input wire  [3:0]       ctrl_wstrb,
    input wire              ctrl_wvalid,
    output reg              ctrl_wready,
    //Write Response Channel
    output reg [1:0]        ctrl_bresp,
    output reg              ctrl_bvalid,
    input wire              ctrl_bready,
    //Read Address Channel
    input wire  [31:0]      ctrl_araddr,
    input wire              ctrl_arvalid,
    output reg              ctrl_arready,
    //Read Data Response Channel
    output reg [31:0]       ctrl_rdata,
    output reg [1:0]        ctrl_rresp,
    output reg              ctrl_rvalid,
    input wire              ctrl_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   FIFO to drive output                                 //
    //--------------------------------------------------------//

    //Seperate FIFOs for each signal
    reg [AXIS_BUS_WIDTH-1:0]        reg_out_tdata [MAX_FIFO_DEPTH-1:0];
    reg [AXIS_ID_WIDTH-1:0]         reg_out_tid [MAX_FIFO_DEPTH-1:0];
    reg [AXIS_DEST_WIDTH-1:0]       reg_out_tdest [MAX_FIFO_DEPTH-1:0];
    reg [(AXIS_BUS_WIDTH/8)-1:0]    reg_out_tkeep [MAX_FIFO_DEPTH-1:0];
    reg                             reg_out_tlast [MAX_FIFO_DEPTH-1:0];

    //FIFO signals
    localparam FIFO_IDX_WIDTH = $clog2(MAX_FIFO_DEPTH);
    localparam FIFO_CNT_WIDTH = $clog2(MAX_FIFO_DEPTH+1);

    reg [FIFO_CNT_WIDTH-1:0] out_fifo_count;
    reg [FIFO_IDX_WIDTH-1:0] out_fifo_rd_pointer;
    reg [FIFO_IDX_WIDTH-1:0] out_fifo_wr_pointer;
    wire out_fifo_full = (out_fifo_count == MAX_FIFO_DEPTH);
    wire out_fifo_empty = (out_fifo_count == 0);
    wire out_fifo_rden;
    reg out_fifo_wren;
    wire out_fifo_do_read = out_fifo_rden && !out_fifo_empty;
    wire out_fifo_do_write = out_fifo_wren && !out_fifo_full;

    always@(posedge aclk) begin
        if(~aresetn) begin
            out_fifo_count <= 0;
            out_fifo_rd_pointer <= 0;
            out_fifo_wr_pointer <= 0; 
        end else if(out_fifo_do_read && out_fifo_do_write) begin
            out_fifo_rd_pointer <= out_fifo_rd_pointer + 1;
            out_fifo_wr_pointer <= out_fifo_wr_pointer + 1;
        end else if(out_fifo_do_read) begin
            out_fifo_count <= out_fifo_count - 1;
            out_fifo_rd_pointer <= out_fifo_rd_pointer + 1;
        end else if(out_fifo_do_write) begin
            out_fifo_count <= out_fifo_count + 1;
            out_fifo_wr_pointer <= out_fifo_wr_pointer + 1;
        end 
    end 

    //Input Register
    localparam OUT_FIFO_WIDTH = AXIS_BUS_WIDTH + AXIS_ID_WIDTH + AXIS_DEST_WIDTH + (AXIS_BUS_WIDTH/8) + 1;
    reg [OUT_FIFO_WIDTH-1:0] out_fifo_din;

    //Write port to FIFO (infered)
    always@(posedge aclk) begin
        if(out_fifo_do_write) begin
            reg_out_tdata[out_fifo_wr_pointer] 
                <= out_fifo_din[0+:AXIS_BUS_WIDTH];
            reg_out_tid[out_fifo_wr_pointer] 
                <= out_fifo_din[AXIS_BUS_WIDTH+:AXIS_ID_WIDTH];
            reg_out_tdest[out_fifo_wr_pointer] 
                <= out_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+:AXIS_DEST_WIDTH];
            reg_out_tkeep[out_fifo_wr_pointer] 
                <= out_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+AXIS_DEST_WIDTH+:(AXIS_BUS_WIDTH/8)];
            reg_out_tlast[out_fifo_wr_pointer] 
                <= out_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+AXIS_DEST_WIDTH+(AXIS_BUS_WIDTH/8)];            
        end 
    end 

    //Read port to output (infered)
    always@(posedge aclk) begin
        if(~aresetn) begin
            axis_out_tvalid <= 0;
        end else if(out_fifo_do_read) begin
            axis_out_tdata <= reg_out_tdata[out_fifo_rd_pointer];
            axis_out_tid <= reg_out_tid[out_fifo_rd_pointer];
            axis_out_tdest <= reg_out_tdest[out_fifo_rd_pointer];
            axis_out_tkeep <= reg_out_tkeep[out_fifo_rd_pointer];
            axis_out_tlast <= reg_out_tlast[out_fifo_rd_pointer];
            axis_out_tvalid <= 1;
        end else if(axis_out_tready) begin
            axis_out_tvalid <= 0;
        end 
    end 

    //Read port enable
    reg output_enabled;
    assign out_fifo_rden = output_enabled && (axis_out_tready || !axis_out_tvalid);



    //--------------------------------------------------------//
    //   FIFO to store input                                  //
    //--------------------------------------------------------//

    //Seperate FIFOs for each signal
    reg [AXIS_BUS_WIDTH-1:0]        reg_in_tdata [MAX_FIFO_DEPTH-1:0];
    reg [AXIS_ID_WIDTH-1:0]         reg_in_tdest [MAX_FIFO_DEPTH-1:0];
    reg [(AXIS_BUS_WIDTH/8)-1:0]    reg_in_tkeep [MAX_FIFO_DEPTH-1:0];
    reg                             reg_in_tlast [MAX_FIFO_DEPTH-1:0];
    reg [9:0]                       reg_in_count [MAX_FIFO_DEPTH-1:0];

    //FIFO Signals
    reg [FIFO_CNT_WIDTH-1:0] in_fifo_count;
    reg [FIFO_IDX_WIDTH-1:0] in_fifo_rd_pointer;
    reg [FIFO_IDX_WIDTH-1:0] in_fifo_wr_pointer;
    wire in_fifo_full = (in_fifo_count == MAX_FIFO_DEPTH);
    wire in_fifo_empty = (in_fifo_count == 0);
    reg in_fifo_rden;
    wire in_fifo_wren;
    wire in_fifo_do_read = in_fifo_rden && !in_fifo_empty;
    wire in_fifo_do_write = in_fifo_wren && !in_fifo_full;

    always@(posedge aclk) begin
        if(~aresetn) begin
            in_fifo_count <= 0;
            in_fifo_rd_pointer <= 0;
            in_fifo_wr_pointer <= 0;
        end else if(in_fifo_do_read && in_fifo_do_write) begin
            in_fifo_rd_pointer <= in_fifo_rd_pointer + 1;
            in_fifo_wr_pointer <= in_fifo_wr_pointer + 1;
        end else if(in_fifo_do_read) begin
            in_fifo_count <= in_fifo_count - 1;
            in_fifo_rd_pointer <= in_fifo_rd_pointer + 1;
        end else if(in_fifo_do_write) begin
            in_fifo_count <= in_fifo_count + 1;
            in_fifo_wr_pointer <= in_fifo_wr_pointer + 1;
        end 
    end 

    //Counter to indicate beats dropped
    reg [9:0] counter;

    always@(posedge aclk) begin
        if(~aresetn) counter <= 0;
        else if(in_fifo_wren) counter <= counter +1;
    end 

    //Write port to FIFO (infered)
    always@(posedge aclk) begin
        if(in_fifo_do_write) begin
            reg_in_tdata[in_fifo_wr_pointer] <= axis_in_tdata; 
            reg_in_tdest[in_fifo_wr_pointer] <= axis_in_tdest; 
            reg_in_tkeep[in_fifo_wr_pointer] <= axis_in_tkeep; 
            reg_in_tlast[in_fifo_wr_pointer] <= axis_in_tlast; 
            reg_in_count[in_fifo_wr_pointer] <= counter;
        end 
    end 

    //Write port enable
    reg input_enabled;
    assign in_fifo_wren = input_enabled && axis_in_tvalid && axis_in_tready;
    assign axis_in_tready = 1'b1; //Never apply backpressure

    //Input Register
    localparam IN_FIFO_WIDTH = AXIS_BUS_WIDTH + AXIS_ID_WIDTH + (AXIS_BUS_WIDTH/8) + 1 + 10 + 1; //1 extra bit to indicate valid
    reg [IN_FIFO_WIDTH-1:0] in_fifo_din;

    //Read port from FIFO (infered)
    always@(posedge aclk) begin
        if(~aresetn) begin
            in_fifo_din <= 0;
        end else if(in_fifo_do_read) begin
            in_fifo_din[0+:AXIS_BUS_WIDTH] 
                <= reg_in_tdata[in_fifo_rd_pointer];
            in_fifo_din[AXIS_BUS_WIDTH+:AXIS_ID_WIDTH] 
                <= reg_in_tdest[in_fifo_rd_pointer];
            in_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+:(AXIS_BUS_WIDTH/8)] 
                <= reg_in_tkeep[in_fifo_rd_pointer];
            in_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+(AXIS_BUS_WIDTH/8)] 
                <= reg_in_tlast[in_fifo_rd_pointer];
            in_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+(AXIS_BUS_WIDTH/8)+1+:10] 
                <= reg_in_count[in_fifo_rd_pointer];
            in_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+(AXIS_BUS_WIDTH/8)+1+10] <= 1;
        end else if(in_fifo_rden && in_fifo_empty) begin
            in_fifo_din[AXIS_BUS_WIDTH+AXIS_ID_WIDTH+(AXIS_BUS_WIDTH/8)+1+10] <= 0;
        end 
    end 



    //--------------------------------------------------------//
    //   AXIL Ctrl Implementation                             //
    //--------------------------------------------------------//
    
    //Align reg files to power of 2 boundaries
    localparam OUT_FIFO_REGS = (OUT_FIFO_WIDTH/32) + ((OUT_FIFO_WIDTH%32 == 0) ? 0 : 1);
    localparam OUT_FINAL_BITS = (OUT_FIFO_WIDTH%32 == 0) ? 32 : OUT_FIFO_WIDTH%32;
    localparam OUT_FIFO_IDX_WIDTH = $clog2(OUT_FIFO_REGS);
    localparam OUT_FIFO_REGS_ALIGN = 2 ** OUT_FIFO_IDX_WIDTH;

    localparam IN_FIFO_REGS = (IN_FIFO_WIDTH/32) + ((IN_FIFO_WIDTH%32 == 0) ? 0 : 1);
    localparam IN_FINAL_BITS = (IN_FIFO_WIDTH%32 == 0) ? 32 : IN_FIFO_WIDTH%32;
    localparam IN_FIFO_IDX_WIDTH = $clog2(IN_FIFO_REGS);
    localparam IN_FIFO_REGS_ALIGN = 2 ** IN_FIFO_IDX_WIDTH;

    //Address Ranges
    localparam OUT_FIFO_WR_FIRST_WORD = 0;
    localparam OUT_FIFO_WR_LAST_WORD = OUT_FIFO_WR_FIRST_WORD + OUT_FIFO_REGS_ALIGN;

    localparam IN_FIFO_WR_FIRST_WORD = OUT_FIFO_WR_LAST_WORD;
    localparam IN_FIFO_WR_LAST_WORD = IN_FIFO_WR_FIRST_WORD + IN_FIFO_REGS_ALIGN;

    localparam OUT_FIFO_STATUS_ADDR = IN_FIFO_WR_LAST_WORD;
    localparam IN_FIFO_STATUS_ADDR = OUT_FIFO_STATUS_ADDR + 1;

    //AXI-LITE registered signals
    reg [31:0]   ctrl_awaddr_reg;
    reg [31:0]   ctrl_araddr_reg;
    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_awready <= 1'b0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awready <= 1'b1;
        else ctrl_awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge aclk) begin
        if (~aresetn) ctrl_awaddr_reg <= 0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awaddr_reg <= ctrl_awaddr; 
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

    //Register araddr value
    always @(posedge aclk) begin
        if (~aresetn) ctrl_araddr_reg  <= 32'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_araddr_reg  <= ctrl_araddr;
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

    //Segment address signal
    localparam ADDR_LSB = 2;
    localparam ADDR_WIDTH_ALIGNED = 32 - ADDR_LSB;

    wire [ADDR_WIDTH_ALIGNED-1:0] wr_addr = ctrl_awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [OUT_FIFO_IDX_WIDTH-1:0] wr_out_idx = ctrl_awaddr_reg[ADDR_LSB+:OUT_FIFO_IDX_WIDTH];

    wire [ADDR_WIDTH_ALIGNED-1:0] rd_addr = ctrl_araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [OUT_FIFO_IDX_WIDTH-1:0] rd_out_idx = ctrl_araddr_reg[ADDR_LSB+:OUT_FIFO_IDX_WIDTH];
    wire [IN_FIFO_IDX_WIDTH-1:0] rd_in_idx = ctrl_araddr_reg[ADDR_LSB+:IN_FIFO_IDX_WIDTH];

    //Loop vars
    integer i;

    //Write (infer write port)
    always @(posedge aclk) begin

        //Default assigment
        out_fifo_wren <= 0;

        if(~aresetn) begin
            out_fifo_din <= 0;
            output_enabled <= 0;
            input_enabled <= 0;
        end else if(slv_reg_wren) begin
            if(wr_addr >= OUT_FIFO_WR_FIRST_WORD && wr_addr < OUT_FIFO_WR_LAST_WORD) begin

                for(i = 0; i < OUT_FIFO_REGS; i = i + 1) begin
                    if(wr_out_idx == i) begin
                        if(i == OUT_FIFO_REGS-1) begin
                            out_fifo_din[OUT_FIFO_WIDTH-1-:OUT_FINAL_BITS] <= ctrl_wdata;
                            out_fifo_wren <= 1;
                        end else begin
                            out_fifo_din[(i*32)+:32] <= ctrl_wdata;
                        end 
                    end 
                end 

            end 
            /*else if(wr_addr >= IN_FIFO_WR_FIRST_WORD && wr_addr < IN_FIFO_WR_LAST_WORD) begin

                for(integer i = 0; i < IN_FIFO_REGS; i = i + 1) begin
                    if(wr_in_idx == i) begin
                        if(i == IN_FIFO_REGS-1) begin
                            in_fifo_din[IN_FIFO_WIDTH-1-:IN_FINAL_BITS] <= ctrl_wdata;
                        end else begin
                            in_fifo_din[(i*32)+:32] <= ctrl_wdata;
                        end 
                    end 
                end 

            end*/ //Not writable 
            else if(wr_addr == OUT_FIFO_STATUS_ADDR) begin
                output_enabled <= ctrl_wdata[FIFO_CNT_WIDTH];
            end 
            else if(wr_addr == IN_FIFO_STATUS_ADDR) begin
                input_enabled <= ctrl_wdata[FIFO_CNT_WIDTH];
            end 
        end 
    end 

    //Read (infer read ports)
    always @(posedge aclk) begin

        //Default assignment
        in_fifo_rden <= 0;

        if(~aresetn) ctrl_rdata <= 0;
        else if(slv_reg_rden) begin

            if(rd_addr >= OUT_FIFO_WR_FIRST_WORD && rd_addr < OUT_FIFO_WR_LAST_WORD) begin

                for(i = 0; i < OUT_FIFO_REGS; i = i + 1) begin
                    if(rd_out_idx == i) begin
                        if(i == OUT_FIFO_REGS-1) begin
                            ctrl_rdata <= out_fifo_din[OUT_FIFO_WIDTH-1-:OUT_FINAL_BITS];
                        end else begin
                            ctrl_rdata <= out_fifo_din[(i*32)+:32];
                        end 
                    end 
                end 

            end 
            else if(rd_addr >= IN_FIFO_WR_FIRST_WORD && rd_addr < IN_FIFO_WR_LAST_WORD) begin

                for(i = 0; i < IN_FIFO_REGS; i = i + 1) begin
                    if(rd_in_idx == i) begin
                        if(i == IN_FIFO_REGS-1) begin
                            ctrl_rdata <= in_fifo_din[IN_FIFO_WIDTH-1-:IN_FINAL_BITS];
                            in_fifo_rden <= 1;
                        end else begin
                            ctrl_rdata <= in_fifo_din[(i*32)+:32];
                        end 
                    end 
                end 

            end
            else if(rd_addr == OUT_FIFO_STATUS_ADDR) begin
                ctrl_rdata <= {output_enabled,out_fifo_count};
            end 
            else if(rd_addr == IN_FIFO_STATUS_ADDR) begin
                ctrl_rdata <= {input_enabled,in_fifo_count};
            end

        end 
    end 



endmodule

`default_nettype wire