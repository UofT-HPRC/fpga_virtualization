`timescale 1ns / 1ps
`default_nettype none


module ingress_wrapper
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2 ** AXIS_ID_WIDTH),

    //Parsing Limit Params
    parameter LAST_BYTE = 41,

    //Packed input signals size
    localparam ING_TUSER_IN_WIDTH = NUM_AXIS_ID + 5,
    localparam ING_TUSER_OUT_WIDTH = 1,
    localparam ING_CONFIG_REG_WIDTH = (AXIS_ID_WIDTH + 1) + 1,

    //Features to implement
    parameter INCLUDE_UDP = 1,
    parameter INCLUDE_VSID = 1,
    parameter INCLUDE_CONFIG_ETYPE = 1,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [((2**AXIS_ID_WIDTH)+5)-1:0] // [ING_TUSER_IN_WIDTH-1:0]
                                          axis_in_tuser,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [(1)-1:0]                 axis_out_tuser, // [ING_TUSER_OUT_WIDTH-1:0]
    output wire [AXIS_ID_WIDTH:0]         axis_out_tdest,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    input wire [((AXIS_ID_WIDTH+1)+1)-1:0]    ingress_config_regs,                                        

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//

    //Input signal declarations
    wire [NUM_AXIS_ID-1:0]         route_mask;
    wire                           poisoned;
    wire                           parsing_done;
    wire                           next_is_config;
    wire                           has_udp_checksum_in;
    wire                           parsing_vsid_done;

    assign {parsing_vsid_done,has_udp_checksum_in,next_is_config,
            parsing_done,poisoned,route_mask}
    = axis_in_tuser;

    //Output signal declaration
    wire                            has_udp_checksum_out;
    wire [ING_TUSER_OUT_WIDTH-1:0]  axis_pack_out_tuser = {has_udp_checksum_out};

    //Configuration signal declarations
    wire                   reroute_if_config;
    wire [AXIS_ID_WIDTH:0] reroute_dest;

    assign {reroute_dest,reroute_if_config} = ingress_config_regs;



    //--------------------------------------------------------//
    //   FIlter Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [AXIS_ID_WIDTH:0]         axis_buff_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    ingress_filtering
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .INCLUDE_UDP                (INCLUDE_UDP),
        .INCLUDE_VSID               (INCLUDE_VSID),
        .INCLUDE_CONFIG_ETYPE       (INCLUDE_CONFIG_ETYPE),
        .LAST_BYTE                  (LAST_BYTE)
    )
    parse
    (
        .axis_out_tdata     (axis_buff_tdata),
        .axis_out_tdest     (axis_buff_tdest),
        .axis_out_tkeep     (axis_buff_tkeep),
        .axis_out_tlast     (axis_buff_tlast),
        .axis_out_tvalid    (axis_buff_tvalid),
        .axis_out_tready    (axis_buff_tready),
        
        .axis_in_tdata (axis_in_tdata),
        .axis_in_tkeep (axis_in_tkeep),
        .axis_in_tlast (axis_in_tlast),
        .axis_in_tvalid (axis_in_tvalid),
        .axis_in_tready (axis_in_tready),

        .route_mask (route_mask),
        .poisoned (poisoned),
        .parsing_done (parsing_done),
        .next_is_config (next_is_config),
        .has_udp_checksum_in (has_udp_checksum_in),
        .parsing_vsid_done (parsing_vsid_done),

        .has_udp_checksum_out (has_udp_checksum_out),
            
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
        .AXIS_USER_WIDTH    (ING_TUSER_OUT_WIDTH+AXIS_ID_WIDTH+1),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      ({axis_pack_out_tuser,axis_buff_tdest}),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tuser,axis_out_tdest}),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );
    


endmodule

`default_nettype wire