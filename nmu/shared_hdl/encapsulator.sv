`timescale 1ns / 1ps
`default_nettype none


module encapsulator
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,
    parameter AXIS_DEST_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,
    localparam EFF_DEST_WIDTH = (AXIS_DEST_WIDTH < 1) ? 1 : AXIS_DEST_WIDTH,

    //Network Packet Params
    parameter MAX_PACKET_LENGTH = 1522,

    //Features to Implement
    parameter bit USE_DYNAMIC_FSM = 0,
    parameter bit ALLOW_NO_ENCAP = 1,
    parameter bit ALLOW_MAC_ENCAP = 1,
    parameter bit ALLOW_IP4_ENCAP = 1,
    parameter bit ALLOW_UDP_ENCAP = 1,
    parameter bit ALLOW_NVGRE_ENCAP = 1,
    parameter bit ALLOW_VXLAN_ENCAP = 1,
    parameter bit ALLOW_ENCAP_W_TAG  = 0,

    //Retiming register stages for checksum calc (to be modified until timing met)
    parameter RETIMING_STAGES_CHECKSUM = 0,
    parameter RETIMING_STAGES_ENCAP = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [EFF_ID_WIDTH-1:0]       axis_in_tid,
    input wire [EFF_DEST_WIDTH-1:0]     axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [EFF_ID_WIDTH-1:0]      axis_out_tid,
    output wire [EFF_DEST_WIDTH-1:0]    axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Configuration register inputs for stage 1
    output wire [EFF_ID_WIDTH-1:0]      encap_sel_id_1,

    input wire [2:0]                    encap_mode_1,

    //Configuration register inputs for stage 2
    output wire [EFF_ID_WIDTH-1:0]      encap_sel_id_2,
    output wire [EFF_DEST_WIDTH-1:0]    encap_sel_dest_2,

    input wire [2:0]                    encap_mode_2,
    input wire [47:0]                   mac_src_address,
    input wire [47:0]                   mac_dest_address,

    input wire                          insert_vlan_tag,
    input wire [15:0]                   vlan_field,

    input wire [5:0]                    ip4_dhsp,
    input wire [7:0]                    ip4_ttl,
    input wire [7:0]                    ip4_protocol,
    input wire [15:0]                   ip4_partial_checksum,
    input wire [31:0]                   ip4_src_address,
    input wire [31:0]                   ip4_dest_address,

    input wire [15:0]                   udp_src_port,
    input wire [15:0]                   udp_dest_port,
    input wire [15:0]                   udp_partial_checksum,
    input wire                          include_udp_checksum,

    input wire [23:0]                   virt_vsid,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);    

    //--------------------------------------------------------//
    //   Encapsulation type params                            //
    //--------------------------------------------------------//

    localparam NON = ALLOW_NO_ENCAP;
    localparam MAC = ALLOW_MAC_ENCAP;
    localparam IP4 = ALLOW_IP4_ENCAP;
    localparam UDP = ALLOW_UDP_ENCAP;
    localparam NVG = ALLOW_NVGRE_ENCAP;
    localparam VXL = ALLOW_VXLAN_ENCAP;
    localparam TAG = ALLOW_ENCAP_W_TAG;



    //--------------------------------------------------------//
    //   Calculation of length and checksum (+ retiming regs) //
    //--------------------------------------------------------//

    //Registered checksum signal outputs
    wire [AXIS_BUS_WIDTH-1:0]      axis_reg_in_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_reg_in_tid;
    wire [EFF_DEST_WIDTH-1:0]      axis_reg_in_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_reg_in_tkeep;
    wire                           axis_reg_in_tlast;
    wire                           axis_reg_in_tvalid;
    wire                           axis_reg_in_tready;

    //Retiming registers instantiated
    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .REG_STAGES         (RETIMING_STAGES_CHECKSUM)
    )
    regs 
    (
        .axis_in_tdata      (axis_in_tdata),
        .axis_in_tuser      ({axis_in_tid,axis_in_tdest}),                                         
        .axis_in_tkeep      (axis_in_tkeep),
        .axis_in_tlast      (axis_in_tlast),
        .axis_in_tvalid     (axis_in_tvalid),
        .axis_in_tready     (axis_in_tready),

        .axis_out_tdata     (axis_reg_in_tdata),
        .axis_out_tuser     ({axis_reg_in_tid,axis_reg_in_tdest}),                                          
        .axis_out_tkeep     (axis_reg_in_tkeep),
        .axis_out_tlast     (axis_reg_in_tlast),
        .axis_out_tvalid    (axis_reg_in_tvalid),
        .axis_out_tready    (axis_reg_in_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );

    //Registered checksum signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_check_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_check_tid;
    wire [EFF_DEST_WIDTH-1:0]      axis_check_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_check_tkeep;
    wire                           axis_check_tlast;
    wire                           axis_check_tvalid;
    wire                           axis_check_tready;

    wire [15:0]                    length_count;
    wire [15:0]                    acc_checksum;

    //Length and checksum calculation
    length_checksum_calc
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_TUSER_WIDTH   (EFF_ID_WIDTH + EFF_DEST_WIDTH),
        .COUNT_LENGTH       ( (IP4||UDP||NVG||VXL) ),
        .CALC_CHECKSUM      (UDP)
    )
    len_check
    (
        .axis_in_tdata          (axis_reg_in_tdata),
        .axis_in_tuser          ({axis_reg_in_tid,axis_reg_in_tdest}),
        .axis_in_tkeep          (axis_reg_in_tkeep),
        .axis_in_tlast          (axis_reg_in_tlast),
        .axis_in_tvalid         (axis_reg_in_tvalid),
        .axis_in_tready         (axis_reg_in_tready),

        .axis_out_tdata         (axis_check_tdata),
        .axis_out_tuser         ({axis_check_tid,axis_check_tdest}),
        .axis_out_tkeep         (axis_check_tkeep),
        .axis_out_tlast         (axis_check_tlast),
        .axis_out_tvalid        (axis_check_tvalid),
        .axis_out_tready        (axis_check_tready),

        .length_count           (length_count),
        .accumalted_checksum    (acc_checksum),        
        
        .aclk       (aclk),
        .aresetn    (aresetn)
    );



    
    //--------------------------------------------------------//
    //   Buffering until checksum calculation complete        //
    //--------------------------------------------------------//    

    //Output signals from buffering
    wire [AXIS_BUS_WIDTH-1:0] axis_buff_tdata;
    wire [EFF_ID_WIDTH-1:0]   axis_buff_tid;
    wire [EFF_DEST_WIDTH-1:0] axis_buff_tdest;
    wire [NUM_BUS_BYTES-1:0]  axis_buff_tkeep;
    wire                      axis_buff_tlast;
    wire                      axis_buff_tvalid;
    wire                      axis_buff_tready;

    wire [15:0]               length_count_buff;
    wire [15:0]               acc_checksum_buff;

    generate if(IP4 || UDP || NVG || VXL) begin :gen_buff

        //Input side channel bits to buffer
        localparam BUFFER_BITS = 16 + (16*UDP);
        wire [BUFFER_BITS-1:0] buffer_bits_in = 
            (UDP ? 
                {acc_checksum,length_count} 
            : 
                length_count
            );

        //Output of side channel signals
        wire [BUFFER_BITS-1:0] buffer_bits_out;
        assign {acc_checksum_buff,length_count_buff} = 
            (UDP ? buffer_bits_out : {16'h0000,buffer_bits_out});

        //Indicate side channel siganls have a valid value to store in buffer
        assign encap_sel_id_1 = axis_check_tid;
        reg buffered_bits_done;

        always@(*) begin
            //Default assignment
            buffered_bits_done = 1'b1;

            case(encap_mode_1)
                4:  if(IP4) buffered_bits_done = axis_check_tlast;
                5:  if(UDP) buffered_bits_done = axis_check_tlast;
                6:  if(NVG) buffered_bits_done = axis_check_tlast;
                7:  if(VXL) buffered_bits_done = axis_check_tlast;
            endcase
        end

        parse_wait_buffer
        #(
            .AXIS_BUS_WIDTH         (AXIS_BUS_WIDTH),
            .SIDE_CHAN_WIDTH        (AXIS_DEST_WIDTH+AXIS_ID_WIDTH+BUFFER_BITS),
            .LAST_BYTE              (MAX_PACKET_LENGTH-1)
        )
        buff
        (
            .axis_in_tdata      (axis_check_tdata),
            .axis_in_tkeep      (axis_check_tkeep),
            .axis_in_tlast      (axis_check_tlast),
            .axis_in_tvalid     (axis_check_tvalid),
            .axis_in_tready     (axis_check_tready),

            .chan_in_data       ({ axis_check_tdest,axis_check_tid,buffer_bits_in }),
            .chan_in_error      (1'b0),
            .chan_in_done_opt   (buffered_bits_done),
            .chan_in_done_req   (buffered_bits_done),

            .axis_out_tdata     (axis_buff_tdata),
            .axis_out_tkeep     (axis_buff_tkeep),
            .axis_out_tlast     (axis_buff_tlast),
            .axis_out_tvalid    (axis_buff_tvalid),
            .axis_out_tready    (axis_buff_tready),

            .chan_out_data      ({ axis_buff_tdest,axis_buff_tid,buffer_bits_out }),
            .chan_out_error     (),
            
            .aclk       (aclk),
            .aresetn    (aresetn)
        );

        //Known Bug - above doesn't work if AXIS_ID_WIDTH == 0 and AXIS_DEST_WIDTH != 0

    end else begin

        assign axis_buff_tdata = axis_check_tdata;
        assign axis_buff_tid = axis_check_tid;
        assign axis_buff_tdest = axis_check_tdest;
        assign axis_buff_tkeep = axis_check_tkeep;
        assign axis_buff_tlast = axis_check_tlast;
        assign axis_buff_tvalid = axis_check_tvalid;
        assign axis_check_tready = axis_buff_tready;

        assign length_count_buff = length_count;
        assign acc_checksum_buff = acc_checksum;

    end endgenerate



    //--------------------------------------------------------//
    //   Encapsulation (+ retiming regs)                      //
    //--------------------------------------------------------//

    //Registered output signals
    wire [AXIS_BUS_WIDTH-1:0]      axis_reg_out_tdata;
    wire [EFF_ID_WIDTH-1:0]        axis_reg_out_tid;
    wire [EFF_DEST_WIDTH-1:0]      axis_reg_out_tdest;
    wire [NUM_BUS_BYTES-1:0]       axis_reg_out_tkeep;
    wire                           axis_reg_out_tlast;
    wire                           axis_reg_out_tvalid;
    wire                           axis_reg_out_tready;
    
    //Select configuration signals (from output of encapsulator)
    assign encap_sel_id_2 = axis_reg_out_tid;
    assign encap_sel_dest_2 = axis_reg_out_tdest;

    //Encapsulator instantiated
    encap_inserter
    #(
        //AXI Stream Params
        .AXIS_BUS_WIDTH      (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH     (EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .MAX_PACKET_LENGTH   (MAX_PACKET_LENGTH),
        .USE_DYNAMIC_FSM     (USE_DYNAMIC_FSM),
        .ALLOW_NO_ENCAP      (ALLOW_NO_ENCAP),
        .ALLOW_MAC_ENCAP     (ALLOW_MAC_ENCAP),
        .ALLOW_IP4_ENCAP     (ALLOW_IP4_ENCAP),
        .ALLOW_UDP_ENCAP     (ALLOW_UDP_ENCAP),
        .ALLOW_NVGRE_ENCAP   (ALLOW_NVGRE_ENCAP),
        .ALLOW_VXLAN_ENCAP   (ALLOW_VXLAN_ENCAP),
        .ALLOW_ENCAP_W_TAG   (ALLOW_ENCAP_W_TAG)  
    )
    encap
    (
        .axis_in_tdata          (axis_buff_tdata),
        .axis_in_tuser          ({axis_buff_tid,axis_buff_tdest}),
        .axis_in_tkeep          (axis_buff_tkeep),
        .axis_in_tlast          (axis_buff_tlast),
        .axis_in_tvalid         (axis_buff_tvalid),
        .axis_in_tready         (axis_buff_tready),

        .axis_out_tdata         (axis_reg_out_tdata),
        .axis_out_tuser         ({axis_reg_out_tid,axis_reg_out_tdest}),
        .axis_out_tkeep         (axis_reg_out_tkeep),
        .axis_out_tlast         (axis_reg_out_tlast),
        .axis_out_tvalid        (axis_reg_out_tvalid),
        .axis_out_tready        (axis_reg_out_tready),

        .length_count           (length_count_buff),
        .accumalted_checksum    (acc_checksum_buff),
        .encap_mode             (encap_mode_2),

        .*
    );

    //Retiming registers instantiated
    axis_reg_slices
    #(
        .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
        .AXIS_USER_WIDTH    (EFF_ID_WIDTH+EFF_DEST_WIDTH),
        .REG_STAGES         (RETIMING_STAGES_ENCAP)
    )
    regs2
    (
        .axis_in_tdata      (axis_reg_out_tdata),
        .axis_in_tuser      ({axis_reg_out_tid,axis_reg_out_tdest}),                                         
        .axis_in_tkeep      (axis_reg_out_tkeep),
        .axis_in_tlast      (axis_reg_out_tlast),
        .axis_in_tvalid     (axis_reg_out_tvalid),
        .axis_in_tready     (axis_reg_out_tready),

        .axis_out_tdata     (axis_out_tdata),
        .axis_out_tuser     ({axis_out_tid,axis_out_tdest}),                                          
        .axis_out_tkeep     (axis_out_tkeep),
        .axis_out_tlast     (axis_out_tlast),
        .axis_out_tvalid    (axis_out_tvalid),
        .axis_out_tready    (axis_out_tready),

        .aclk       (aclk),
        .aresetn    (aresetn)
    );




endmodule

`default_nettype wire