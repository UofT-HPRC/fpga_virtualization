`timescale 1ns / 1ps
`default_nettype none

/*
Simple network loopback with counter

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This application connects one interface to a second interface (both
   TX to RX and RX to TX) while providing AXI-Lite registers to count
   number of packets transfered in both directions.

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



module packet_loopback_app
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Features
    parameter MAX_FIFO_DEPTH = 256 //Must be power of 2, greater than MTU/AXIS_BUS_WIDTH
)
(
    //Egress Output AXI stream 0
    output wire [AXIS_BUS_WIDTH-1:0]     axis_out_0_tdata,
    output wire [AXIS_ID_WIDTH-1:0]      axis_out_0_tid,
    output wire [AXIS_DEST_WIDTH-1:0]    axis_out_0_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0] axis_out_0_tkeep,
    output wire                          axis_out_0_tlast,
    output wire                          axis_out_0_tvalid,
    input wire                           axis_out_0_tready,

    //Ingress Input AXI stream 0
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_0_tdata,
    input wire [AXIS_ID_WIDTH-1:0]      axis_in_0_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0] axis_in_0_tkeep,
    input wire                          axis_in_0_tlast,
    input wire                          axis_in_0_tvalid,
    output wire                         axis_in_0_tready,

    //Egress Output AXI stream 1
    output wire [AXIS_BUS_WIDTH-1:0]     axis_out_1_tdata,
    output wire [AXIS_ID_WIDTH-1:0]      axis_out_1_tid,
    output wire [AXIS_DEST_WIDTH-1:0]    axis_out_1_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0] axis_out_1_tkeep,
    output wire                          axis_out_1_tlast,
    output wire                          axis_out_1_tvalid,
    input wire                           axis_out_1_tready,

    //Ingress Input AXI stream 0
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_1_tdata,
    input wire [AXIS_ID_WIDTH-1:0]      axis_in_1_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0] axis_in_1_tkeep,
    input wire                          axis_in_1_tlast,
    input wire                          axis_in_1_tvalid,
    output wire                         axis_in_1_tready,

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
    //   AXIL Ctrl Implementation                             //
    //--------------------------------------------------------//
    
    //The counter registers
    reg [31:0]  packet_count_0_to_1_rx;
    reg [31:0]  packet_count_0_to_1_tx;
    reg         fifo_0_to_1_was_full;
    reg         read_en_0_to_1;
    wire        packet_dropped_0_to_1;

    reg [31:0]  packet_count_1_to_0_rx;
    reg [31:0]  packet_count_1_to_0_tx;
    reg         fifo_1_to_0_was_full;
    reg         read_en_1_to_0;
    wire        packet_dropped_1_to_0;

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
    wire [ADDR_WIDTH_ALIGNED-1:0] rd_addr = ctrl_araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];

    reg count_0_to_1_rx_write;
    reg count_0_to_1_tx_write;
    reg fifo_0_to_1_full_write;
    reg read_en_0_to_1_write;

    reg count_1_to_0_rx_write;
    reg count_1_to_0_tx_write;
    reg fifo_1_to_0_full_write;
    reg read_en_1_to_0_write;

    //Determine which register to write to
    always @(*) begin
        count_0_to_1_rx_write = 0;
        count_0_to_1_tx_write = 0;
        fifo_0_to_1_full_write = 0;
        read_en_0_to_1_write = 0;

        count_1_to_0_rx_write = 0;
        count_1_to_0_tx_write = 0;
        fifo_1_to_0_full_write = 0;
        read_en_1_to_0_write = 0;

        if(slv_reg_wren)
            if(wr_addr == 0)        count_0_to_1_rx_write = 1;
            else if(wr_addr == 1)   count_0_to_1_tx_write = 1;
            else if(wr_addr == 2)   fifo_0_to_1_full_write = 1;
            else if(wr_addr == 3)   read_en_0_to_1_write = 1;
            else if(wr_addr == 4)   count_1_to_0_rx_write = 1;
            else if(wr_addr == 5)   count_1_to_0_tx_write = 1;
            else if(wr_addr == 6)   fifo_1_to_0_full_write = 1;
            else if(wr_addr == 7)   read_en_1_to_0_write = 1;
    end 

    //Update the 0->1 RX counter
    always @(posedge aclk) begin
        if(~aresetn) 
            packet_count_0_to_1_rx <= 0;
        else if(count_0_to_1_rx_write)
            packet_count_0_to_1_rx <= ctrl_wdata;
        else if(axis_in_0_tvalid && axis_in_0_tready && axis_in_0_tlast)
            packet_count_0_to_1_rx <= packet_count_0_to_1_rx + 1;
    end 

    //Update the 0->1 TX counter
    always @(posedge aclk) begin
        if(~aresetn) 
            packet_count_0_to_1_tx <= 0;
        else if(count_0_to_1_tx_write)
            packet_count_0_to_1_tx <= ctrl_wdata;
        else if(axis_out_1_tvalid && axis_out_1_tready && axis_out_1_tlast)
            packet_count_0_to_1_tx <= packet_count_0_to_1_tx + 1;
    end 

    //Update the 0->1 fifo full register
    always @(posedge aclk) begin
        if(~aresetn) 
            fifo_0_to_1_was_full <= 0;
        else if(fifo_0_to_1_full_write)
            fifo_0_to_1_was_full <= ctrl_wdata[0];
        else if(packet_dropped_0_to_1)
            fifo_0_to_1_was_full <= 1;
    end

    //Update the 0->1 read enable
    always @(posedge aclk) begin
        if(~aresetn) 
            read_en_0_to_1 <= 1;
        else if(read_en_0_to_1_write)
            read_en_0_to_1 <= ctrl_wdata[0];
    end

    //Update the 1->0 RX counter
    always @(posedge aclk) begin
        if(~aresetn) 
            packet_count_1_to_0_rx <= 0;
        else if(count_1_to_0_rx_write)
            packet_count_1_to_0_rx <= ctrl_wdata;
        else if(axis_in_1_tvalid && axis_in_1_tready && axis_in_1_tlast)
            packet_count_1_to_0_rx <= packet_count_1_to_0_rx + 1;
    end 

    //Update the 1->0 TX counter
    always @(posedge aclk) begin
        if(~aresetn) 
            packet_count_1_to_0_tx <= 0;
        else if(count_1_to_0_tx_write)
            packet_count_1_to_0_tx <= ctrl_wdata;
        else if(axis_out_0_tvalid && axis_out_0_tready && axis_out_0_tlast)
            packet_count_1_to_0_tx <= packet_count_1_to_0_tx + 1;
    end 

    //Update the 1->0 fifo full register
    always @(posedge aclk) begin
        if(~aresetn) 
            fifo_1_to_0_was_full <= 0;
        else if(fifo_1_to_0_full_write)
            fifo_1_to_0_was_full <= ctrl_wdata[0];
        else if(packet_dropped_1_to_0)
            fifo_1_to_0_was_full <= 1;
    end

    //Update the 1->0 read enable
    always @(posedge aclk) begin
        if(~aresetn) 
            read_en_1_to_0 <= 1;
        else if(read_en_1_to_0_write)
            read_en_1_to_0 <= ctrl_wdata[0];
    end

    //Do the read
    always @(posedge aclk) begin
        if(~aresetn) 
            ctrl_rdata <= 0;
        else if(slv_reg_rden) begin

            if(rd_addr == 0)
                ctrl_rdata <= packet_count_0_to_1_rx;
            else if(rd_addr == 1)
                ctrl_rdata <= packet_count_0_to_1_tx;
            else if(rd_addr == 2)
                ctrl_rdata <= fifo_0_to_1_was_full;
            else if(rd_addr == 3)
                ctrl_rdata <= read_en_0_to_1;
            else if(rd_addr == 4)
                ctrl_rdata <= packet_count_1_to_0_rx;
            else if(rd_addr == 5)
                ctrl_rdata <= packet_count_1_to_0_tx;
            else if(rd_addr == 6)
                ctrl_rdata <= fifo_1_to_0_was_full;
            else if(rd_addr == 7)
                ctrl_rdata <= read_en_1_to_0;
            else if(rd_addr == 8)
                ctrl_rdata <= 32'h42;
            else
                ctrl_rdata <= 32'hcafeca5a; //

        end
    end 



    //--------------------------------------------------------//
    //   Passthrough Connections                              //
    //--------------------------------------------------------//

    wire fifo_out_0_tvalid;
    wire fifo_out_1_tvalid;

    //The packet mode FIFO to connect RX to TX (0->1)
    axi_stream_fifo
    #(
        //AXI Stream Params
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_TID_WIDTH             (AXIS_ID_WIDTH),
        .AXIS_TDEST_WDITH           (AXIS_DEST_WIDTH),
        .AXIS_TUSER_WIDTH           (1),

        //FIFO Depth
        .BUFFER_DEPTH_LOG2          ( $clog2(MAX_FIFO_DEPTH) ),

        //Dropping features
        .DROP_ON_BACK_PRESSURE          (1), //whether or not to drop if FIFO full
        .DROP_ON_TUSER_SIG              (0), //i.e. some 'drop this packet' signal (we don't need this signal)
        .DROP_TUSER_SIG_INDEX           (0),
        .IGNORE_TUSER_DROP_IF_STABLE    (0), //i.e. some 'done checking for drop condition' signal (we don't need this signal)
        .STABLE_TUSER_SIG_INDEX         (0),
        .DROP_ON_UNSTABLE_TLAST         (0), //whether or not to drop packets if the 'stable' sgnal isn't asserted by tlast

        //Wait features (buffer packet before transmitting)
        .WAIT_UNTIL_TLAST               (1), //whether or not to buffer until end of packet
        .WAIT_UNTIL_TUSER_SIG           (0), //i.e. some 'buffering done' signal (we don't need this feature)
        .WAIT_TUSER_SIG_INDEX           (0),

        //Seperate Side-Channel features (only one should be enabled)
        .WRITE_SIDE_ONCE_ON_STABLE      (0),
        .WRITE_SIDE_ONCE_ON_BUFFER_DONE (0)
    )
    packet_mode_fifo_0_to_1
    (
        //Input AXI stream
        .axis_in_tdata      (axis_in_0_tdata),
        .axis_in_tkeep      (axis_in_0_tkeep),
        .axis_in_tid        (0),
        .axis_in_tdest      (axis_in_0_tdest),
        .axis_in_tuser      (0),
        .axis_in_tlast      (axis_in_0_tlast),
        .axis_in_tvalid     (axis_in_0_tvalid),
        .axis_in_tready     (axis_in_0_tready),
        
        //Output AXI stream
        .axis_out_tdata     (axis_out_1_tdata),
        .axis_out_tkeep     (axis_out_1_tkeep),
        .axis_out_tid       (axis_out_1_tid),
        .axis_out_tdest     (axis_out_1_tdest),
        .axis_out_tuser     ( ),
        .axis_out_tlast     (axis_out_1_tlast),
        .axis_out_tvalid    (fifo_out_1_tvalid),
        .axis_out_tready    (axis_out_1_tready & read_en_0_to_1),

        //Dropped packet indicator
        .packet_dropped     (packet_dropped_0_to_1),
    
        //Clocking
        .aclk               (aclk),
        .aresetn            (aresetn)
    );

    assign axis_out_1_tvalid = fifo_out_1_tvalid & read_en_0_to_1;


    //The packet mode FIFO to connect RX to TX (1->0)
    axi_stream_fifo
    #(
        //AXI Stream Params
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_TID_WIDTH             (AXIS_ID_WIDTH),
        .AXIS_TDEST_WDITH           (AXIS_DEST_WIDTH),
        .AXIS_TUSER_WIDTH           (1),

        //FIFO Depth
        .BUFFER_DEPTH_LOG2          ( $clog2(MAX_FIFO_DEPTH) ),

        //Dropping features
        .DROP_ON_BACK_PRESSURE          (1), //whether or not to drop if FIFO full
        .DROP_ON_TUSER_SIG              (0), //i.e. some 'drop this packet' signal (we don't need this signal)
        .DROP_TUSER_SIG_INDEX           (0),
        .IGNORE_TUSER_DROP_IF_STABLE    (0), //i.e. some 'done checking for drop condition' signal (we don't need this signal)
        .STABLE_TUSER_SIG_INDEX         (0),
        .DROP_ON_UNSTABLE_TLAST         (0), //whether or not to drop packets if the 'stable' sgnal isn't asserted by tlast

        //Wait features (buffer packet before transmitting)
        .WAIT_UNTIL_TLAST               (1), //whether or not to buffer until end of packet
        .WAIT_UNTIL_TUSER_SIG           (0), //i.e. some 'buffering done' signal (we don't need this feature)
        .WAIT_TUSER_SIG_INDEX           (0),

        //Seperate Side-Channel features (only one should be enabled)
        .WRITE_SIDE_ONCE_ON_STABLE      (0),
        .WRITE_SIDE_ONCE_ON_BUFFER_DONE (0)
    )
    packet_mode_fifo_1_to_0
    (
        //Input AXI stream
        .axis_in_tdata      (axis_in_1_tdata),
        .axis_in_tkeep      (axis_in_1_tkeep),
        .axis_in_tid        (0),
        .axis_in_tdest      (axis_in_1_tdest),
        .axis_in_tuser      (0),
        .axis_in_tlast      (axis_in_1_tlast),
        .axis_in_tvalid     (axis_in_1_tvalid),
        .axis_in_tready     (axis_in_1_tready),
        
        //Output AXI stream
        .axis_out_tdata     (axis_out_0_tdata),
        .axis_out_tkeep     (axis_out_0_tkeep),
        .axis_out_tid       (axis_out_0_tid),
        .axis_out_tdest     (axis_out_0_tdest),
        .axis_out_tuser     ( ),
        .axis_out_tlast     (axis_out_0_tlast),
        .axis_out_tvalid    (fifo_out_0_tvalid),
        .axis_out_tready    (axis_out_0_tready & read_en_1_to_0),

        //Dropped packet indicator
        .packet_dropped     (packet_dropped_1_to_0),
    
        //Clocking
        .aclk               (aclk),
        .aresetn            (aresetn)
    );

    assign axis_out_0_tvalid = fifo_out_0_tvalid & read_en_1_to_0;



endmodule

`default_nettype wire