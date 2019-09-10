`timescale 1ns / 1ps
`default_nettype none


module egress_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 0,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH), 

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,   

    //Params for unused inputs (for sizing the bus width)
    parameter MAX_PACKET_LENGTH = 1522,
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),
    localparam MAX_ADDED_OFFSET = 64,
    localparam MAX_ADDED_OFFSET_CBITS = $clog2(MAX_ADDED_OFFSET),

    //Packed input signals size
    localparam EGR_TUSER_IN_WIDTH = NUM_AXIS_ID + PACKET_LENGTH_CBITS + MAX_ADDED_OFFSET_CBITS + 5,
    localparam EGR_TUSER_OUT_WIDTH = EFF_DEST_WIDTH,
    localparam EGR_CONFIG_SEL_WIDTH = EFF_ID_WIDTH,
    localparam EGR_CONFIG_REG_WIDTH = (AXIS_ID_WIDTH + 1) + 1 + (NUM_AXIS_ID*2),

    //Amount of buffering
    parameter LAST_BYTE = 41,

    //Features to implement
    parameter INCLUDE_TDEST_CALC = 1,
    parameter INCLUDE_CONFIG_ETYPE = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+$clog2(MAX_PACKET_LENGTH+1)+7+5)-1:0] // [EGR_TUSER_IN_WIDTH-1:0]
                                          axis_in_tuser,
    input wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]        
                                          axis_in_tid,
    input wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_in_tdest,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((AXIS_DEST_WIDTH<1)?1:AXIS_DEST_WIDTH)-1:0]
                                          axis_out_tuser,
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]       
                                          axis_out_tid,
    output wire [AXIS_ID_WIDTH:0]         axis_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    output wire [((AXIS_ID_WIDTH<1)?1:AXIS_ID_WIDTH)-1:0]
                                          egress_config_sel,
    input wire [(((2**AXIS_ID_WIDTH)*2)+(AXIS_ID_WIDTH+1)+1)-1:0]
                                          egress_config_regs,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//

    //Input signal declarations
    wire [NUM_AXIS_ID-1:0]            route_mask;
    wire                              poisoned;
    wire                              parsing_done;
    wire                              next_is_config;
    wire [PACKET_LENGTH_CBITS-1:0]    cur_pos; //Unused
    wire [MAX_ADDED_OFFSET_CBITS-1:0] added_offset; //Unused
    wire                              next_can_have_vsid; //Unused
    wire                              has_udp_checksum; //Unused

    assign {has_udp_checksum,next_can_have_vsid,added_offset,cur_pos,
            next_is_config,parsing_done,poisoned,route_mask}
    = axis_in_tuser;

    //Output signal declarations
    wire [EFF_DEST_WIDTH-1:0]        axis_out_tdest_old;

    //Configuration select signals
    wire [EFF_ID_WIDTH-1:0] egress_sel_id;
    assign egress_config_sel = egress_sel_id;

    //Configuration signal declarations
    wire [NUM_AXIS_ID-1:0]        must_route_mask;
    wire [NUM_AXIS_ID-1:0]        cannot_route_mask;
    wire                          reroute_if_config;
    wire [AXIS_ID_WIDTH:0]        reroute_dest;

    assign {reroute_dest,reroute_if_config,cannot_route_mask,must_route_mask} = egress_config_regs;



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_buff_tid;
    wire [AXIS_ID_WIDTH:0]         axis_buff_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    egress_filtering
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .AXIS_DEST_WIDTH            (AXIS_DEST_WIDTH),
        .LAST_BYTE                  (LAST_BYTE),
        .INCLUDE_TDEST_CALC         (INCLUDE_TDEST_CALC),
        .INCLUDE_CONFIG_ETYPE       (INCLUDE_CONFIG_ETYPE)
    )
    filter
    (
        .axis_out_tdata     (axis_buff_tdata),
        .axis_out_tid       (axis_buff_tid),
        .axis_out_tdest     (axis_buff_tdest),
        .axis_out_tkeep     (axis_buff_tkeep),
        .axis_out_tlast     (axis_buff_tlast),
        .axis_out_tvalid    (axis_buff_tvalid),
        .axis_out_tready    (axis_buff_tready),
        
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tid (axis_in_tid),
        .axis_in_tdest (axis_in_tdest),
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),

        .route_mask (route_mask),
        .poisoned (poisoned),
        .parsing_done (parsing_done),
        .next_is_config (next_is_config),
        
        .axis_out_tdest_old (axis_out_tdest_old),

        .egress_sel_id (egress_sel_id),

        .must_route_mask (must_route_mask),
        .cannot_route_mask (cannot_route_mask),
        .reroute_if_config (reroute_if_config),
        .reroute_dest (reroute_dest),

        .aclk (aclk),
        .aresetn (aresetn)
    );



    //--------------------------------------------------------//
    //   Retiming registers                                   //
    //--------------------------------------------------------//

    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (EGR_TUSER_OUT_WIDTH+EFF_ID_WIDTH+AXIS_ID_WIDTH+1),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      ({axis_out_tdest_old,axis_buff_tid,axis_buff_tdest}),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tuser,axis_out_tid,axis_out_tdest}),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );
    


endmodule

`default_nettype wire