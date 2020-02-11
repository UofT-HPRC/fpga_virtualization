`timescale 1ns / 1ps
`default_nettype none




//Egress filtering
module egress_filtering
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Amount of buffering
    parameter LAST_BYTE = 41,

    //Features to implement
    parameter bit INCLUDE_TDEST_CALC = 1,
    parameter bit INCLUDE_CONFIG_ETYPE = 1
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]           axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]         axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]          axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,

    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]          axis_out_tid,
    output reg [AXIS_ID_WIDTH:0]            axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]         axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,

    //Side channel signals from previous stage (port parser)
    input wire [NUM_AXIS_ID-1:0]            route_mask,
    input wire                              poisoned,
    input wire                              parsing_done,
    input wire                              next_is_config,
    //input wire [PACKET_LENGTH_CBITS-1:0]  cur_pos, //Unused
    //input wire [MAX_ADDED_OFFSET_CBITS-1:0] added_offset, //Unused
    //input wire                            next_can_have_vsid, //Unused
    //input wire                            has_udp_checksum, //Unused
    
    //Side channel signals to next stage (tagger/encap/xbar)
    output wire [EFF_DEST_WIDTH-1:0]        axis_out_tdest_old,

    //Filtering parameters
    output wire [EFF_ID_WIDTH-1:0]      egress_sel_id,

    input wire [NUM_AXIS_ID-1:0]        must_route_mask,
    input wire [NUM_AXIS_ID-1:0]        cannot_route_mask,
    input wire                          reroute_if_config,
    input wire [AXIS_ID_WIDTH:0]        reroute_dest,

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
        .SIDE_CHAN_WIDTH    (AXIS_DEST_WIDTH+AXIS_ID_WIDTH+NUM_AXIS_ID+1),
        .LAST_BYTE          (LAST_BYTE)
    )
    bufer
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .chan_in_data       ({axis_in_tdest,axis_in_tid,next_is_config,route_mask}),
        .chan_in_error      (poisoned),
        .chan_in_done_opt   (parsing_done),
        .chan_in_done_req   (parsing_done), 
        
        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_pop_tvalid),
        .axis_out_tready    (axis_pop_tready),

        .chan_out_data      ({axis_out_tdest_old,axis_out_tid,next_is_config_pop,route_mask_pop}),
        .chan_out_error     (poisoned_pop),
        
        .aclk               (aclk),
        .aresetn            (aresetn)
    );

    //Known Bug - above doesn't work if AXIS_ID_WIDTH == 0 and AXIS_DEST_WIDTH != 0



    //--------------------------------------------------------//
    //   Decode destination                                   //
    //--------------------------------------------------------//

    //Use TID to determine parameters to use
    assign egress_sel_id = axis_out_tid;

generate if(INCLUDE_TDEST_CALC) begin : tdest

    wire [NUM_AXIS_ID-1:0]  final_mask = (route_mask_pop & ~cannot_route_mask) | must_route_mask;

    always@(*) begin

        //Default route to outside
        axis_out_tdest = { 1'b1 , {AXIS_ID_WIDTH{1'b0}} };

        //Reroute internal if specific configuration etypes
        if(reroute_if_config && next_is_config_pop && INCLUDE_CONFIG_ETYPE) axis_out_tdest = reroute_dest;
        else begin

            for(integer i = NUM_AXIS_ID-1; i >= 0; i = i - 1)
                if(final_mask[i]) axis_out_tdest = i;

        end
    end

end else begin

    assign axis_out_tdest = { 1'b1 , {AXIS_ID_WIDTH{1'b0}} };

end
endgenerate

    

    //--------------------------------------------------------//
    //   Discard errorful packets                             //
    //--------------------------------------------------------//

    wire errorful = poisoned_pop && axis_pop_tvalid;
    assign axis_pop_tready = errorful || axis_out_tready;
    assign axis_out_tvalid = !errorful && axis_pop_tvalid;
    
    
   
endmodule

`default_nettype wire