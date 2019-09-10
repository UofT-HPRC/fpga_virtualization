`timescale 1ns / 1ps
`default_nettype none


//The memory decoupler
module net_decoupler
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Features to Implement
    parameter DISALLOW_INGR_BACKPRESSURE = 1
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

    //Indicate tlast asserted by protocol corretor
    input wire                                                  axis_egr_tlast_forced,

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

    //Decoupler signals
    input wire              decouple,
    input wire              decouple_force_egr,
    input wire              decouple_force_ingr,

    output wire             decouple_done,
    output wire [1:0]       decouple_status_vector,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //Any decouple request
    wire decoup_any_egr = decouple || decouple_force_egr;


    //--------------------------------------------------------//
    //   Egress Channel                                       //
    //--------------------------------------------------------//
    
    //Additional Necessary Signals
    wire safe_egr_decoup;
    wire effective_egr_tvalid = (safe_egr_decoup) ? 1'b0 : axis_egr_in_tvalid;
    wire effective_egr_tready = (safe_egr_decoup) ? 1'b0 : axis_egr_out_tready;

    //Assign effective values
    assign axis_egr_out_tvalid = effective_egr_tvalid;
    assign axis_egr_in_tready = effective_egr_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_egr_out_tdata = axis_egr_in_tdata;
    assign axis_egr_out_tid = axis_egr_in_tid;
    assign axis_egr_out_tdest = axis_egr_in_tdest;
    assign axis_egr_out_tkeep = axis_egr_in_tkeep;
    assign axis_egr_out_tlast = axis_egr_in_tlast;



    //--------------------------------------------------------//
    //   Egress Decoupling Logic                              //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_egr_packet;

    always@(posedge aclk) begin
        if(~aresetn) outst_egr_packet <= 0;
        else if(effective_egr_tvalid && effective_egr_tready) begin
            if(axis_egr_in_tlast || axis_egr_tlast_forced) outst_egr_packet <= 0;
            else outst_egr_packet <= 1;
        end 
    end 
    
    //Decoupling logic for egress channels
    assign safe_egr_decoup = (decoup_any_egr && !outst_egr_packet);
    
    //Output decoupling results
    wire egr_decoupled = safe_egr_decoup;



    //--------------------------------------------------------//
    //   Ingress Channel                                      //
    //--------------------------------------------------------//

    //Accept all data when decoupled
    reg safe_ingr_decoup;
    wire effective_ingr_tvalid = (safe_ingr_decoup) ? 1'b0 : axis_ingr_in_tvalid;
    wire effective_ingr_tready = (DISALLOW_INGR_BACKPRESSURE) ? 
        1'b1 : (safe_ingr_decoup) ? 1'b1 : axis_ingr_out_tready;

    //Assign effective values
    assign axis_ingr_out_tvalid = effective_ingr_tvalid;
    assign axis_ingr_in_tready = effective_ingr_tready;
        
    //Other signals don't need to be decoupled (same as Xilinx decoupler)
    assign axis_ingr_out_tdata = axis_ingr_in_tdata;
    assign axis_ingr_out_tdest = axis_ingr_in_tdest;
    assign axis_ingr_out_tkeep = axis_ingr_in_tkeep;
    assign axis_ingr_out_tlast = axis_ingr_in_tlast;



    //--------------------------------------------------------//
    //   Ingress Decoupling Logic                             //
    //--------------------------------------------------------//  
    
    //Keep track of whether a packet is currently being processed
    reg outst_ingr_packet_nxt;
    reg outst_ingr_packet;

    always@(*) begin
        if(~aresetn) outst_ingr_packet_nxt = 0;
        else if(axis_ingr_in_tvalid && effective_ingr_tready) begin
            if(axis_ingr_in_tlast) outst_ingr_packet_nxt = 0;
            else outst_ingr_packet_nxt = 1;
        end 
        else outst_ingr_packet_nxt = outst_ingr_packet;
    end

    always@(posedge aclk) outst_ingr_packet <= outst_ingr_packet_nxt;

    //Decoupling logic for ingress channel
    always@(posedge aclk) begin
        if(~aresetn) safe_ingr_decoup <= 0;
        else if(decouple_force_ingr) safe_ingr_decoup <= 1;
        else if(decouple && !outst_ingr_packet_nxt) safe_ingr_decoup <= 1;
        else if(!outst_ingr_packet_nxt) safe_ingr_decoup <= 0;
    end
    
    //Output decoupling results
    wire ingr_decoupled = safe_ingr_decoup;

    
    
    //--------------------------------------------------------//
    //   Output signalling logic                              //
    //--------------------------------------------------------//
    
    //decouple done signal
    assign decouple_done = decouple && !outst_egr_packet && !outst_ingr_packet;
    
    //output status vector
    assign decouple_status_vector[0] = egr_decoupled;
    assign decouple_status_vector[1] = ingr_decoupled;



endmodule

`default_nettype wire