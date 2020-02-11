`timescale 1ns / 1ps
`default_nettype none


module ingress_filtering
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),

    //Features to implement
    parameter bit INCLUDE_UDP = 1,
    parameter bit INCLUDE_VSID = 1,
    parameter bit INCLUDE_CONFIG_ETYPE = 1,

    //Parsing Limit Params
    parameter LAST_BYTE = 1522
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,

    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output reg [AXIS_ID_WIDTH:0]            axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Side channel signals from previous stage (vsid parser)
    input wire [NUM_AXIS_ID-1:0]            route_mask,
    input wire                              poisoned,
    input wire                              parsing_done,
    input wire                              next_is_config,
    input wire                              has_udp_checksum_in,
    input wire                              parsing_vsid_done,

    //Side channel signals to next stage (de-encap)
    output wire                             has_udp_checksum_out,
        
    //Filtering parameters
    input wire                              reroute_if_config,
    input wire [AXIS_ID_WIDTH:0]            reroute_dest,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Buffer Input until parsing complete                  //
    //--------------------------------------------------------//

    //Output signals
    wire                     axis_pop_tvalid;
    wire                     axis_pop_tready;
    wire                     next_is_config_pop;
    wire                     poisoned_pop;
    wire [NUM_AXIS_ID-1:0]   route_mask_pop;

    //The FIFO buffer
    parse_wait_buffer
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .SIDE_CHAN_WIDTH    (INCLUDE_UDP+NUM_AXIS_ID+1),
        .LAST_BYTE          (LAST_BYTE)
    )
    bufer
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .chan_in_data       ({has_udp_checksum_in,next_is_config,route_mask}),
        .chan_in_error      (poisoned),
        .chan_in_done_opt   ((INCLUDE_VSID ? parsing_vsid_done : parsing_done)),
        .chan_in_done_req   (parsing_done), 
        
        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_pop_tvalid),
        .axis_out_tready    (axis_pop_tready),

        .chan_out_data      ({has_udp_checksum_out,next_is_config_pop,route_mask_pop}),
        .chan_out_error     (poisoned_pop),
        
        .aclk               (aclk),
        .aresetn            (aresetn)
    );



    //--------------------------------------------------------//
    //   Decode destination                                   //
    //--------------------------------------------------------//

    always@(*) begin

        //Default route to outside
        axis_out_tdest = { 1'b1 , {AXIS_ID_WIDTH{1'b0}} };

        //Reroute internal if specific configuration etypes
        if(reroute_if_config && next_is_config_pop && INCLUDE_CONFIG_ETYPE) axis_out_tdest = reroute_dest;
        else begin

            for(integer i = NUM_AXIS_ID-1; i >= 0; i = i - 1)
                if(route_mask_pop[i]) axis_out_tdest = i;

        end
    end



    //--------------------------------------------------------//
    //   Discard errorful packets                             //
    //--------------------------------------------------------//

    wire route_error = axis_out_tdest[AXIS_ID_WIDTH];

    wire errorful = (poisoned_pop || route_error) && axis_pop_tvalid;
    assign axis_pop_tready = errorful || axis_out_tready;
    assign axis_out_tvalid = !errorful && axis_pop_tvalid;
    
    
   
endmodule

`default_nettype wire