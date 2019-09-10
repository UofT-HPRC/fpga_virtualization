`timescale 1ns / 1ps
`default_nettype none


module packet_buffer
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    parameter MAX_PACKET_COUNT = 2,

    localparam FINAL_BUFFER_BYTES = (MAX_PACKET_LENGTH*MAX_PACKET_COUNT),

    //Packed input signals size
    localparam BUFF_TUSER_IN_WIDTH = 2,

    //Features to implement
    parameter WAIT_FOR_ERRORS = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]         axis_in_tdata,
    input wire [(2)-1:0]                    axis_in_tuser,
    input wire [AXIS_ID_WIDTH:0]            axis_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]     axis_in_tkeep,
    input wire                              axis_in_tlast,
    input wire                              axis_in_tvalid,
    output wire                             axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]        axis_out_tdata,
    output wire [AXIS_ID_WIDTH:0]           axis_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]    axis_out_tkeep,
    output wire                             axis_out_tlast,
    output wire                             axis_out_tvalid,
    input wire                              axis_out_tready,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack Signals                                       //
    //--------------------------------------------------------//

    //The input signals
    wire    poisoned;
    wire    parsing_done;

    assign {parsing_done,poisoned} = axis_in_tuser;



    //--------------------------------------------------------//
    //   The Buffering                                        //
    //--------------------------------------------------------//

    //Output signals
    wire    axis_pop_tvalid;
    wire    axis_pop_tready;
    wire    errorful;

    //The FIFO buffer
    parse_wait_buffer
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .SIDE_CHAN_WIDTH    (AXIS_ID_WIDTH+1),
        .LAST_BYTE          (FINAL_BUFFER_BYTES-1)
    )
    final_bufer
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .chan_in_data       (axis_in_tdest),
        .chan_in_error      (poisoned),
        .chan_in_done_opt   (parsing_done),
        .chan_in_done_req   (parsing_done),
        
        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_pop_tvalid),
        .axis_out_tready    (axis_pop_tready),

        .chan_out_data      (axis_out_tdest),
        .chan_out_error     (errorful),
        
        .aclk               (aclk),
        .aresetn            (aresetn)
    );

    //Discard errorful packets
    assign axis_pop_tready = (errorful && WAIT_FOR_ERRORS) || axis_out_tready;
    assign axis_out_tvalid = !(errorful && WAIT_FOR_ERRORS) && axis_pop_tvalid;



endmodule

`default_nettype wire