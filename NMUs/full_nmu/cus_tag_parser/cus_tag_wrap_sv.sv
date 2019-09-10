`timescale 1ns / 1ps
`default_nettype none




//Tag field constants
`define ET_SIZE 16
`define TAG_OFFSET 14




//The Tag Parser
module cus_tag_wrap_sv
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,
    localparam NUM_AXIS_ID = (2**AXIS_ID_WIDTH),

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,
    parameter MAX_TAG_SIZE_BITS = 64, //bits

    //Constants and Derived params for network packet
    localparam PACKET_LENGTH_CBITS = $clog2(MAX_PACKET_LENGTH+1),

    localparam MAX_TAG_BYTES = (MAX_TAG_SIZE_BITS/8),
    localparam LAST_BYTE = `TAG_OFFSET + MAX_TAG_BYTES - 1,

    //Packed input signals size
    localparam CUS_TUSER_OUT_WDITH = NUM_AXIS_ID + 1,
    localparam CUS_TAG_CONFIG_REG_WIDTH = `ET_SIZE,
    localparam CUS_TAG_CAM_WIDTH = ((MAX_TAG_SIZE_BITS*2) + 1) * NUM_AXIS_ID,

    //Features to Implement
    parameter DETAG_ALL_ETYPE_MATCH = 0,

    //Retiming register stages (to be modified until timing met)
    parameter RETIMING_STAGES = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]       axis_in_tdata,
    input wire [(AXIS_BUS_WIDTH/8)-1:0]   axis_in_tkeep,
    input wire                            axis_in_tlast,
    input wire                            axis_in_tvalid,
    output wire                           axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]      axis_out_tdata,
    output wire [((2**AXIS_ID_WIDTH)+1)-1:0]  axis_out_tuser,
    output wire [(AXIS_BUS_WIDTH/8)-1:0]  axis_out_tkeep,
    output wire                           axis_out_tlast,
    output wire                           axis_out_tvalid,
    input wire                            axis_out_tready,

    //Configuration register inputs (used for ACL and CAM)
    input wire [(`ET_SIZE)-1:0]            cus_tag_config_regs,
    input wire [(((MAX_TAG_SIZE_BITS*2)+1)*(2**AXIS_ID_WIDTH))-1:0] 
                                          cus_tag_cam_values,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Unpack signals                                       //
    //--------------------------------------------------------//


    //Output signal declarations
    wire [NUM_AXIS_ID-1:0]       route_mask;
    wire                         cus_tag_present;
    wire                         parsing_done; //Not passed on to next stage

    wire [CUS_TUSER_OUT_WDITH-1:0] axis_pack_out_tuser = {cus_tag_present,route_mask};

    //Configuration signal declarations
    wire [`ET_SIZE-1:0]            expected_etype = cus_tag_config_regs;

    //Unpack CAM signals
    wire                          has_cus_tag [NUM_AXIS_ID-1:0];
    wire [MAX_TAG_SIZE_BITS-1:0]  custom_tags [NUM_AXIS_ID-1:0];
    wire [MAX_TAG_SIZE_BITS-1:0]  custom_tag_masks [NUM_AXIS_ID-1:0];

    localparam PER_ID = ((MAX_TAG_SIZE_BITS*2) + 1);
    
    genvar j;
    generate
        for(j = 0; j < NUM_AXIS_ID; j = j + 1) begin : config0 

            assign {has_cus_tag[j],custom_tag_masks[j],custom_tags[j]} 
            = cus_tag_cam_values[(PER_ID*j)+:PER_ID];

        end
    endgenerate



    //--------------------------------------------------------//
    //   Parser Instantiation                                 //
    //--------------------------------------------------------//

    //Registered stream signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_tdata;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_tkeep;
    wire                           axis_buff_tlast;
    wire                           axis_buff_tvalid;
    wire                           axis_buff_tready;

    //Parser
    cus_tag_parser
    #(
        .AXIS_BUS_WIDTH             (AXIS_BUS_WIDTH),
        .AXIS_ID_WIDTH              (AXIS_ID_WIDTH),
        .MAX_PACKET_LENGTH          (MAX_PACKET_LENGTH),
        .MAX_TAG_SIZE_BITS          (MAX_TAG_SIZE_BITS),
        .DETAG_ALL_ETYPE_MATCH      (DETAG_ALL_ETYPE_MATCH)
    )
    parse
    (
        .axis_out_tdata     (axis_buff_tdata),
        .axis_out_tkeep     (axis_buff_tkeep),
        .axis_out_tlast     (axis_buff_tlast),
        .axis_out_tvalid    (axis_buff_tvalid),
        .axis_out_tready    (axis_buff_tready),
        .*
    );



    //--------------------------------------------------------//
    //   Retiming registers                                   //
    //--------------------------------------------------------//

    //Registered stream output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_buff_out_tdata;
    wire [CUS_TUSER_OUT_WDITH-1:0] axis_buff_out_tuser;
    wire [NUM_BUS_BYTES-1:0]       axis_buff_out_tkeep;
    wire                           axis_buff_out_tlast;
    wire                           axis_buff_out_tvalid;
    wire                           axis_buff_out_tready;
    
    wire                           parsing_done_out;

    //Registers instantiated
    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (CUS_TUSER_OUT_WDITH+1),
        .REG_STAGES         (RETIMING_STAGES)
    )
    regs 
    (
        .axis_in_tdata      (axis_buff_tdata),
        .axis_in_tuser      ({axis_pack_out_tuser,parsing_done}),                                         
        .axis_in_tkeep      (axis_buff_tkeep),
        .axis_in_tlast      (axis_buff_tlast),
        .axis_in_tvalid     (axis_buff_tvalid),
        .axis_in_tready     (axis_buff_tready),

        .axis_out_tdata     (axis_buff_out_tdata),
        .axis_out_tuser     ({axis_buff_out_tuser,parsing_done_out}),                                          
        .axis_out_tkeep     (axis_buff_out_tkeep),
        .axis_out_tlast     (axis_buff_out_tlast),
        .axis_out_tvalid    (axis_buff_out_tvalid),
        .axis_out_tready    (axis_buff_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );



    //--------------------------------------------------------//
    //   Buffer Until Tag Parsed                              //
    //--------------------------------------------------------//

    generate if (!DETAG_ALL_ETYPE_MATCH) begin : gen_buffer

        //The FIFO buffer
        parse_wait_buffer
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .SIDE_CHAN_WIDTH    (CUS_TUSER_OUT_WDITH),
            .LAST_BYTE          (LAST_BYTE)
        )
        bufer
        (
            .axis_in_tdata      (axis_buff_out_tdata),
            .axis_in_tkeep      (axis_buff_out_tkeep),
            .axis_in_tlast      (axis_buff_out_tlast),
            .axis_in_tvalid     (axis_buff_out_tvalid),
            .axis_in_tready     (axis_buff_out_tready),

            .chan_in_data       (axis_buff_out_tuser),
            .chan_in_error      (1'b0),
            .chan_in_done_opt   (parsing_done_out),
            .chan_in_done_req   (parsing_done_out), 
            
            .axis_out_tdata     (axis_out_tdata),
            .axis_out_tkeep     (axis_out_tkeep),
            .axis_out_tlast     (axis_out_tlast),
            .axis_out_tvalid    (axis_out_tvalid),
            .axis_out_tready    (axis_out_tready),

            .chan_out_data      (axis_out_tuser),
            .chan_out_error     (),
            
            .aclk               (aclk),
            .aresetn            (aresetn)
        );

    end else begin

        assign axis_out_tdata = axis_buff_out_tdata;
        assign axis_out_tuser = axis_buff_out_tuser;
        assign axis_out_tkeep = axis_buff_out_tkeep;
        assign axis_out_tlast = axis_buff_out_tlast;
        assign axis_out_tvalid = axis_buff_out_tvalid;

        assign axis_buff_out_tready = axis_out_tready;

    end 
    endgenerate
    


endmodule

`default_nettype wire