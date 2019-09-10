`timescale 1ns / 1ps
`default_nettype none


module detag_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Inserted Tag Params
    parameter USE_DYNAMIC_FSM = 0,
    parameter MIN_TAG_SIZE_BITS = 32,
    parameter MAX_TAG_SIZE_BITS = 64,

    //Derived params for tag
    localparam NUM_TAG_SIZES = ((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16) + 2,
    localparam NUM_TAG_SIZES_LOG2 = $clog2(NUM_TAG_SIZES),

    //Packed input signals size
    localparam DETAG_TUSER_IN_WIDTH = NUM_AXIS_ID + 1,
    localparam DETAG_TUSER_OUT_WIDTH = NUM_AXIS_ID,
    localparam DETAG_CONFIG_REG_WIDTH = NUM_TAG_SIZES_LOG2,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+1)-1:0]  axis_in_tuser, // [DETAG_TUSER_IN_WIDTH-1:0]
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [(2**AXIS_ID_WIDTH)-1:0]  axis_out_tuser, // [DETAG_TUSER_OUT_WIDTH-1:0]
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    input wire [($clog2(((MAX_TAG_SIZE_BITS-MIN_TAG_SIZE_BITS)/16)+2))-1:0]
                                          detag_config_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//

    //Input signal declarations
    wire [NUM_AXIS_ID-1:0]  route_mask_in;
    wire                    cus_tag_present;

    assign {cus_tag_present,route_mask_in} = axis_in_tuser;

    //Output signal declarations
    wire [NUM_AXIS_ID-1:0] route_mask_out;
    assign axis_out_tuser = route_mask_out;

    //Configuration signal declarations
    wire [NUM_TAG_SIZES_LOG2-1:0] tag_mode = detag_config_regs;



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Parser
    detagger
    #(
        .AXIS_BUS_WIDTH          (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH           (AXIS_ID_WIDTH),
        .MAX_PACKET_LENGTH       (MAX_PACKET_LENGTH),
        .USE_DYNAMIC_FSM         (USE_DYNAMIC_FSM),
        .MIN_TAG_SIZE_BITS       (MIN_TAG_SIZE_BITS),
        .MAX_TAG_SIZE_BITS       (MAX_TAG_SIZE_BITS),
        .RETIMING_STAGES         (RETIMING_STAGES)
    )
    detag
    (
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),
        
        .axis_out_tdata (axis_out_tdata),
        .axis_out_tkeep (axis_out_tkeep),
        .axis_out_tlast (axis_out_tlast),
        .axis_out_tvalid (axis_out_tvalid),
        .axis_out_tready (axis_out_tready),

        .route_mask_in (route_mask_in),
        .cus_tag_present (cus_tag_present),

        .route_mask_out (route_mask_out),

        .tag_mode (tag_mode),
        
        .aclk (aclk),
        .aresetn (aresetn)
    );



endmodule

`default_nettype wire