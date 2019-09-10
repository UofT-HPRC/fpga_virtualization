`timescale 1ns / 1ps
`default_nettype none


//The memory decoupler
module net_prot_handler
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Timeout Limits
    parameter INGR_TIMEOUT_CYCLES = 15,
    parameter INCLUDE_TIMEOUT_ERROR = 0
)
(
    //Egress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_egr_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_egr_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]    axis_egr_in_tdest,                                          
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_egr_in_tkeep,
    input wire                                                  axis_egr_in_tlast,
    input wire                                                  axis_egr_in_tvalid,
    output wire                                                 axis_egr_in_tready,

    //Egress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_egr_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_egr_out_tid,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   axis_egr_out_tdest,                                           
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_egr_out_tkeep,
    output wire                                                 axis_egr_out_tlast,
    output wire                                                 axis_egr_out_tvalid,
    input wire                                                  axis_egr_out_tready,

    //Indicate tlast asserted
    output wire                                                 axis_egr_tlast_forced,

    //Ingress Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]                             axis_ingr_in_tdata,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        axis_ingr_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]                         axis_ingr_in_tkeep,
    input wire                                                  axis_ingr_in_tlast,
    input wire                                                  axis_ingr_in_tvalid,
    output wire                                                 axis_ingr_in_tready,

    //Ingress Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]                            axis_ingr_out_tdata,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       axis_ingr_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]                        axis_ingr_out_tkeep,
    output wire                                                 axis_ingr_out_tlast,
    output wire                                                 axis_ingr_out_tvalid,
    input wire                                                  axis_ingr_out_tready,

    //Protocol error indicators
    output wire         oversize_errror_irq,
    input wire          oversize_error_clear,

    output wire         timeout_error_irq,
    input wire          timeout_error_clear,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Egress Channel monitoring                            //
    //--------------------------------------------------------//
    
    //Values to be modified in egress correction
    wire effective_egr_tready;
    wire effective_egr_tvalid;
    wire effective_egr_tlast;

    //Keept track of outstanding packet, ensure tvalid is not deasserted until tlast
    reg outst_egr_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_egr_packet <= 0;
        else if(effective_egr_tvalid && effective_egr_tready) begin
            if(effective_egr_tlast) outst_egr_packet <= 0;
            else outst_egr_packet <= 1;
        end 
    end

    //Correct the tvalid value
    assign effective_egr_tvalid = axis_egr_in_tvalid || outst_egr_packet;

    //Count beats sent in current packet
    localparam MAX_BEATS = 
        (MAX_PACKET_LENGTH/AXIS_BUS_WIDTH) + (MAX_PACKET_LENGTH%AXIS_BUS_WIDTH == 0 ? 0 : 1);
    reg [$clog2(MAX_BEATS+1)-1:0] egr_beat_count;

    always@(posedge aclk) begin
        if(~aresetn) egr_beat_count <= 0;
        else if(effective_egr_tvalid && effective_egr_tready) begin
            if(effective_egr_tlast) egr_beat_count <= 0;
            else egr_beat_count <= egr_beat_count + 1;
        end 
    end

    //Correct tlast value
    assign axis_egr_tlast_forced = (egr_beat_count == (MAX_BEATS-1));
    assign effective_egr_tlast = (axis_egr_in_tlast || axis_egr_tlast_forced);

    //track oversize errors
    reg oversize_error;
    wire curr_oversize_error = (axis_egr_tlast_forced && !axis_egr_in_tlast);

    always@(posedge aclk) begin
        if(~aresetn || oversize_error_clear) oversize_error <= 0;
        else if(curr_oversize_error) oversize_error <= 1;
    end 

    assign oversize_errror_irq = (curr_oversize_error || oversize_error);



    //--------------------------------------------------------//
    //   Egress Channel Correction                            //
    //--------------------------------------------------------//

    //Register for output value
    reg [AXIS_BUS_WIDTH-1:0]                            reg_egr_tdata;
    reg [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       reg_egr_tid;
    reg [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]   reg_egr_tdest;
    reg [(AXIS_BUS_WIDTH/8)-1:0]                        reg_egr_tkeep;
    reg                                                 reg_egr_tlast;
    reg                                                 reg_egr_tvalid;

    always@(posedge aclk) begin
        if(~aresetn) reg_egr_tvalid <= 0;
        else if(effective_egr_tvalid && effective_egr_tready) begin
            reg_egr_tdata <= axis_egr_in_tdata;
            reg_egr_tid <= axis_egr_in_tid;
            reg_egr_tdest <= axis_egr_in_tdest;
            reg_egr_tkeep <= axis_egr_in_tkeep;
            reg_egr_tlast <= effective_egr_tlast;
            reg_egr_tvalid <= 1;
        end 
        else if(axis_egr_out_tready) reg_egr_tvalid <= 0;
    end 

    //Assign output values for egress channel
    assign axis_egr_out_tdata = reg_egr_tdata;
    assign axis_egr_out_tid = reg_egr_tid;
    assign axis_egr_out_tdest = reg_egr_tdest;
    assign axis_egr_out_tkeep = reg_egr_tkeep;
    assign axis_egr_out_tlast = reg_egr_tlast;
    assign axis_egr_out_tvalid = reg_egr_tvalid;

    assign effective_egr_tready = (axis_egr_out_tready || !reg_egr_tvalid);
    assign axis_egr_in_tready = effective_egr_tready;



    //--------------------------------------------------------//
    //   Ingress Channel monitoring                           //
    //--------------------------------------------------------//

    //Timeout calculation
    reg [$clog2(INGR_TIMEOUT_CYCLES+1)-1:0] ingr_time_count;
    wire ingr_timeout = (ingr_time_count == INGR_TIMEOUT_CYCLES);
    
    always@(posedge aclk) begin
       if(~aresetn || (axis_ingr_out_tready && axis_ingr_in_tvalid) || timeout_error_clear)
           ingr_time_count <= 0;
       else if(axis_ingr_in_tvalid && ~axis_ingr_out_tready && ~ingr_timeout)
           ingr_time_count <= ingr_time_count + 1;
    end

    //track timeout errors
    reg timeout_error;

    always@(posedge aclk) begin
        if(~aresetn || timeout_error_clear) timeout_error <= 0;
        else if(ingr_timeout) timeout_error <= 1;
    end 

    assign timeout_error_irq = (ingr_timeout || timeout_error) && INCLUDE_TIMEOUT_ERROR;



    //--------------------------------------------------------//
    //   Inress Channel Passthrough                           //
    //--------------------------------------------------------//
    assign axis_ingr_out_tdata = axis_ingr_in_tdata;
    assign axis_ingr_out_tdest = axis_ingr_in_tdest;
    assign axis_ingr_out_tkeep = axis_ingr_in_tkeep;
    assign axis_ingr_out_tlast = axis_ingr_in_tlast;
    assign axis_ingr_out_tvalid = axis_ingr_in_tvalid;
    assign axis_ingr_in_tready = axis_ingr_out_tready;
    


endmodule

`default_nettype wire