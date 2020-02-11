`timescale 1ns / 1ps
`default_nettype none


module decapsulator
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_ID_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

    localparam EFF_ID_WIDTH = (AXIS_ID_WIDTH < 1) ? 1 : AXIS_ID_WIDTH,

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
    parameter RETIMING_STAGES_PSEUDO = 0,
    parameter RETIMING_STAGES_ENCAP = 0,
    parameter RETIMING_STAGES_CHECKSUM = 0
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [AXIS_ID_WIDTH:0]        axis_in_tdest,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [AXIS_ID_WIDTH:0]       axis_out_tdest,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals from previous stage (filtering)
    input wire                          has_udp_checksum,

    //Side channel signals passed to next stage (buffering)
    output wire                         poisoned,
    output wire                         parsing_done,

    //Configuration register inputs (1)
    output wire [EFF_ID_WIDTH-1:0]      decap_sel_id_1,

    input wire [2:0]                    encap_mode_1,
    input wire                          has_vlan_tag,

    //COnfiguration register inputs (2)
    output wire [EFF_ID_WIDTH-1:0]      decap_sel_id_2,

    input wire [2:0]                    encap_mode_2,
    
    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Encapsulation type and sizes params                  //
    //--------------------------------------------------------//

    localparam NON = ALLOW_NO_ENCAP;
    localparam MAC = ALLOW_MAC_ENCAP;
    localparam IP4 = ALLOW_IP4_ENCAP;
    localparam UDP = ALLOW_UDP_ENCAP;
    localparam NVG = ALLOW_NVGRE_ENCAP;
    localparam VXL = ALLOW_VXLAN_ENCAP;
    localparam TAG = ALLOW_ENCAP_W_TAG;

    localparam NUM_ENCAP_TYPES = 16;
    localparam integer ENCAP_SIZES_TOTAL[NUM_ENCAP_TYPES] = 
        '{0,14,14,14, 34,42,42,50, 0,18,18,18, 38,46,46,54};

    localparam integer ENCAP_SIZE_INDIRECT[NUM_ENCAP_TYPES] = 
        '{  (NON ? 0 : -1),
            (MAC ? NON : -1),
            (MAC ? NON : -1),
            (MAC ? NON : -1),

            (IP4 ? (NON + MAC) : -1),
            (UDP ? (NON + MAC + IP4) : -1),
            (NVG ? (NON + MAC + IP4) : -1),
            (VXL ? (NON + MAC + IP4 + (UDP||NVG)) : -1),

            ((NON&&TAG) ? 0 : -1),
            ((MAC&&TAG) ? (NON + MAC + IP4 + (UDP||NVG) + VXL) : -1),
            ((MAC&&TAG) ? (NON + MAC + IP4 + (UDP||NVG) + VXL) : -1),
            ((MAC&&TAG) ? (NON + MAC + IP4 + (UDP||NVG) + VXL) : -1),

            ((IP4&&TAG) ? (NON + (2*MAC) + IP4 + (UDP||NVG) + VXL) : -1),
            ((UDP&&TAG) ? (NON + (2*MAC) + (2*IP4) +(UDP||NVG) + VXL) : -1),
            ((NVG&&TAG) ? (NON + (2*MAC) + (2*IP4) +(UDP||NVG) + VXL) : -1),
            ((VXL&&TAG) ? (NON + (2*MAC) + (2*IP4) + (2*(UDP||NVG)) + VXL) : -1)
        };

    localparam NUM_ENCAP_SIZES_ALLOWED = NON + (MAC + IP4 + (UDP||NVG) + VXL)*(TAG+1) ;

    typedef integer ret_array [NUM_ENCAP_SIZES_ALLOWED];
    function ret_array sizes_allowed 
    (  
        input integer num_encap, 
        input integer encap_indirect[NUM_ENCAP_TYPES], 
        input integer encap_sizes[NUM_ENCAP_TYPES]
    ); 
    begin
        for(integer j = 0; j < num_encap; j = j + 1) begin 
            automatic integer index = encap_indirect[j];
            if(index >= 0) sizes_allowed[index] = encap_sizes[j];
        end
    end
    endfunction

    localparam integer ENCAP_SIZES_ALLOWED[NUM_ENCAP_SIZES_ALLOWED] = 
        sizes_allowed(NUM_ENCAP_TYPES,ENCAP_SIZE_INDIRECT,ENCAP_SIZES_TOTAL);



    //--------------------------------------------------------//
    //   Pseudo Header and UDP Header Checksum Calc           //
    //--------------------------------------------------------//

    //Output values
    wire [AXIS_BUS_WIDTH-1:0]     axis_check1_tdata;
    wire [AXIS_ID_WIDTH:0]        axis_check1_tdest;
    wire [NUM_BUS_BYTES-1:0]      axis_check1_tkeep;
    wire                          axis_check1_tlast;
    wire                          axis_check1_tvalid;
    wire                          axis_check1_tready;
    wire                          has_udp_checksum_1;

    wire [15:0]                   pseudo_udp_checksum;

    generate if(UDP) begin : gen_pseudo

        //Output values of retiming regs
        wire [AXIS_BUS_WIDTH-1:0]     axis_inter_tdata;
        wire [AXIS_ID_WIDTH:0]        axis_inter_tdest;
        wire [NUM_BUS_BYTES-1:0]      axis_inter_tkeep;
        wire                          axis_inter_tlast;
        wire                          axis_inter_tvalid;
        wire                          axis_inter_tready;
        wire                          has_udp_checksum_inter;
    
        //Retiming registers for pseudo checksum calc
        axis_reg_slices
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_USER_WIDTH    (AXIS_ID_WIDTH+2),
            .REG_STAGES         (RETIMING_STAGES_PSEUDO)
        )
        regs_pseudo
        (
            .axis_in_tdata      (axis_in_tdata),
            .axis_in_tuser      ({axis_in_tdest,has_udp_checksum}),                                         
            .axis_in_tkeep      (axis_in_tkeep),
            .axis_in_tlast      (axis_in_tlast),
            .axis_in_tvalid     (axis_in_tvalid),
            .axis_in_tready     (axis_in_tready),

            .axis_out_tdata     (axis_inter_tdata),
            .axis_out_tuser     ({axis_inter_tdest,has_udp_checksum_inter}),                                          
            .axis_out_tkeep     (axis_inter_tkeep),
            .axis_out_tlast     (axis_inter_tlast),
            .axis_out_tvalid    (axis_inter_tvalid),
            .axis_out_tready    (axis_inter_tready),

            .aclk       (aclk),
            .aresetn    (aresetn)
        );
        
        //The Checksum Calculation
        pseudo_udp_header_check
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_TUSER_WIDTH   (AXIS_ID_WIDTH+2),
            .MAX_PACKET_LENGTH  (MAX_PACKET_LENGTH)
        )
        pseudo_check 
        (
            .axis_in_tdata          (axis_inter_tdata),
            .axis_in_tkeep          (axis_inter_tkeep),
            .axis_in_tuser          ({axis_inter_tdest,has_udp_checksum_inter}),
            .axis_in_tlast          (axis_inter_tlast),
            .axis_in_tvalid         (axis_inter_tvalid),
            .axis_in_tready         (axis_inter_tready),

            .axis_out_tdata         (axis_check1_tdata),
            .axis_out_tkeep         (axis_check1_tkeep),
            .axis_out_tuser         ({axis_check1_tdest,has_udp_checksum_1}),
            .axis_out_tlast         (axis_check1_tlast),
            .axis_out_tvalid        (axis_check1_tvalid),
            .axis_out_tready        (axis_check1_tready),

            .is_tagged              (has_vlan_tag && TAG),
            .pseudo_udp_checksum    (pseudo_udp_checksum),
            
            .aclk       (aclk),
            .aresetn    (aresetn)
        );

    end else begin

        assign axis_check1_tdata = axis_in_tdata;
        assign axis_check1_tkeep = axis_in_tkeep;
        assign axis_check1_tdest = axis_in_tdest;
        assign axis_check1_tlast = axis_in_tlast;
        assign axis_check1_tvalid = axis_in_tvalid;

        assign axis_in_tready = axis_check1_tready;

        assign has_udp_checksum_1 = has_udp_checksum;
        assign pseudo_udp_checksum = '0;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Decapsulation                                        //
    //--------------------------------------------------------//

    //Decapsulation Outputs
    wire [AXIS_BUS_WIDTH-1:0]     axis_decap_tdata;
    wire [AXIS_ID_WIDTH:0]        axis_decap_tdest;
    wire [NUM_BUS_BYTES-1:0]      axis_decap_tkeep;
    wire                          axis_decap_tlast;
    wire                          axis_decap_tvalid;
    wire                          axis_decap_tready;

    wire                          has_udp_checksum_decap;
    wire [15:0]                   pseudo_udp_checksum_decap;



    //Configuration select
    assign decap_sel_id_1 = axis_check1_tdest[AXIS_ID_WIDTH-1:0];
    
    

    generate if(NUM_ENCAP_SIZES_ALLOWED > 1) begin

        //Specific encap signals
        localparam MAX_ENCAP_SIZE = ENCAP_SIZES_ALLOWED[NUM_ENCAP_SIZES_ALLOWED-1];
        localparam NUM_ENCAP_BYTES_CBITS = $clog2(MAX_ENCAP_SIZE + 1);
        localparam NUM_ECNAP_SIZES_LOG2 = $clog2(NUM_ENCAP_SIZES_ALLOWED);

        reg [NUM_ENCAP_BYTES_CBITS-1:0] encap_size;
        reg [NUM_ECNAP_SIZES_LOG2-1:0] encap_sel;

        always@(*) begin

            //Default Assignments
            encap_size = 'x;
            encap_sel = 'x;

            case({ (has_vlan_tag&TAG), encap_mode_1 })

                0: if(ENCAP_SIZE_INDIRECT[0] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[0];
                    encap_sel = ENCAP_SIZE_INDIRECT[0];
                end

                1: if(ENCAP_SIZE_INDIRECT[1] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[1];
                    encap_sel = ENCAP_SIZE_INDIRECT[1];
                end

                2: if(ENCAP_SIZE_INDIRECT[2] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[2];
                    encap_sel = ENCAP_SIZE_INDIRECT[2];
                end

                3: if(ENCAP_SIZE_INDIRECT[3] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[3];
                    encap_sel = ENCAP_SIZE_INDIRECT[3];
                end

                4: if(ENCAP_SIZE_INDIRECT[4] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[4];
                    encap_sel = ENCAP_SIZE_INDIRECT[4];
                end

                5: if(ENCAP_SIZE_INDIRECT[5] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[5];
                    encap_sel = ENCAP_SIZE_INDIRECT[5];
                end

                6: if(ENCAP_SIZE_INDIRECT[6] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[6];
                    encap_sel = ENCAP_SIZE_INDIRECT[6];
                end

                7: if(ENCAP_SIZE_INDIRECT[7] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[7];
                    encap_sel = ENCAP_SIZE_INDIRECT[7];
                end

                8: if(ENCAP_SIZE_INDIRECT[8] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[8];
                    encap_sel = ENCAP_SIZE_INDIRECT[8];
                end

                9: if(ENCAP_SIZE_INDIRECT[9] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[9];
                    encap_sel = ENCAP_SIZE_INDIRECT[9];
                end

                10: if(ENCAP_SIZE_INDIRECT[10] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[10];
                    encap_sel = ENCAP_SIZE_INDIRECT[10];
                end

                11: if(ENCAP_SIZE_INDIRECT[11] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[11];
                    encap_sel = ENCAP_SIZE_INDIRECT[11];
                end

                12: if(ENCAP_SIZE_INDIRECT[12] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[12];
                    encap_sel = ENCAP_SIZE_INDIRECT[12];
                end

                13: if(ENCAP_SIZE_INDIRECT[13] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[13];
                    encap_sel = ENCAP_SIZE_INDIRECT[13];
                end

                14: if(ENCAP_SIZE_INDIRECT[14] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[14];
                    encap_sel = ENCAP_SIZE_INDIRECT[14];
                end

                15: if(ENCAP_SIZE_INDIRECT[15] >= 0) begin
                    encap_size = ENCAP_SIZES_TOTAL[15];
                    encap_sel = ENCAP_SIZE_INDIRECT[15];
                end

            endcase
        end

        //Segment remover
        segment_remover_mult
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_TUSER_WIDTH   (AXIS_ID_WIDTH+18),
            .MAX_PACKET_LENGTH  (MAX_PACKET_LENGTH),
            .USE_DYNAMIC_FSM    (USE_DYNAMIC_FSM),
            .REMOVE_OFFSET      (0),
            .NUM_REMOVE_SIZES   (NUM_ENCAP_SIZES_ALLOWED),
            .REMOVE_SIZES_BYTES (ENCAP_SIZES_ALLOWED),
            .RETIMING_STAGES    (RETIMING_STAGES_ENCAP)
        )
        remove 
        (
            .axis_in_tdata      (axis_check1_tdata),
            .axis_in_tkeep      (axis_check1_tkeep),
            .axis_in_tuser      ({axis_check1_tdest,has_udp_checksum_1,pseudo_udp_checksum}),
            .axis_in_tlast      (axis_check1_tlast),
            .axis_in_tvalid     (axis_check1_tvalid),
            .axis_in_tready     (axis_check1_tready),

            .axis_out_tdata     (axis_decap_tdata),
            .axis_out_tkeep     (axis_decap_tkeep),
            .axis_out_tuser     ({axis_decap_tdest,has_udp_checksum_decap,pseudo_udp_checksum_decap}),
            .axis_out_tlast     (axis_decap_tlast),
            .axis_out_tvalid    (axis_decap_tvalid),
            .axis_out_tready    (axis_decap_tready),

            .segment_size       (encap_size),
            .segment_sel        (encap_sel),
            
            .aclk               (aclk),
            .aresetn            (aresetn)
        );

    end else if(ENCAP_SIZES_ALLOWED[0] != 0) begin

        //Segment remover
        segment_remover_onesz
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_TUSER_WIDTH   (AXIS_ID_WIDTH+18),
            .MAX_PACKET_LENGTH  (MAX_PACKET_LENGTH),
            .REMOVE_OFFSET      (0),
            .REMOVE_SIZE_BYTES  (ENCAP_SIZES_ALLOWED[0]),
            .RETIMING_STAGES    (RETIMING_STAGES_ENCAP)
        )
        remove 
        (
            .axis_in_tdata      (axis_check1_tdata),
            .axis_in_tkeep      (axis_check1_tkeep),
            .axis_in_tuser      ({axis_check1_tdest,has_udp_checksum_1,pseudo_udp_checksum}),
            .axis_in_tlast      (axis_check1_tlast),
            .axis_in_tvalid     (axis_check1_tvalid),
            .axis_in_tready     (axis_check1_tready),

            .axis_out_tdata     (axis_decap_tdata),
            .axis_out_tkeep     (axis_decap_tkeep),
            .axis_out_tuser     ({axis_decap_tdest,has_udp_checksum_decap,pseudo_udp_checksum_decap}),
            .axis_out_tlast     (axis_decap_tlast),
            .axis_out_tvalid    (axis_decap_tvalid),
            .axis_out_tready    (axis_decap_tready),
            
            .aclk               (aclk),
            .aresetn            (aresetn)
        );

    end else begin

        assign axis_decap_tdata = axis_check1_tdata;
        assign axis_decap_tkeep = axis_check1_tkeep;
        assign axis_decap_tdest = axis_check1_tdest;
        assign axis_decap_tlast = axis_check1_tlast;
        assign axis_decap_tvalid = axis_check1_tvalid;

        assign axis_check1_tready = axis_decap_tready;

        assign has_udp_checksum_decap = has_udp_checksum_1;
        assign pseudo_udp_checksum_decap = pseudo_udp_checksum;

    end 
    endgenerate



    //--------------------------------------------------------//
    //   Final Checksum Calc                                  //
    //--------------------------------------------------------//

    generate if(UDP) begin : gen_final_check

        //Retiming registers for after checksum calc
        wire [AXIS_BUS_WIDTH-1:0]     axis_buff_reg_tdata;
        wire [AXIS_ID_WIDTH:0]        axis_buff_reg_tdest;
        wire [NUM_BUS_BYTES-1:0]      axis_buff_reg_tkeep;
        wire                          axis_buff_reg_tlast;
        wire                          axis_buff_reg_tvalid;
        wire                          axis_buff_reg_tready;

        wire                          has_udp_checksum_reg;
        wire                          udp_error_reg;

        //Output checksum value of payload
        wire [15:0]     payload_checksum;
        wire            has_udp_checksum_buff;
        wire [15:0]     pseudo_udp_checksum_buff;

        //Checksum Calculation
        length_checksum_calc
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_TUSER_WIDTH   (AXIS_ID_WIDTH+18),
            .COUNT_LENGTH       (0),
            .CALC_CHECKSUM      (1)
        )
        load_check
        (
            .axis_in_tdata          (axis_decap_tdata),
            .axis_in_tuser          ({axis_decap_tdest,has_udp_checksum_decap,pseudo_udp_checksum_decap}),
            .axis_in_tkeep          (axis_decap_tkeep),
            .axis_in_tlast          (axis_decap_tlast),
            .axis_in_tvalid         (axis_decap_tvalid),
            .axis_in_tready         (axis_decap_tready),

            .axis_out_tdata         (axis_buff_reg_tdata),
            .axis_out_tuser         ({axis_buff_reg_tdest,has_udp_checksum_buff,pseudo_udp_checksum_buff}),
            .axis_out_tkeep         (axis_buff_reg_tkeep),
            .axis_out_tlast         (axis_buff_reg_tlast),
            .axis_out_tvalid        (axis_buff_reg_tvalid),
            .axis_out_tready        (axis_buff_reg_tready),

            .length_count           (),
            .accumalted_checksum    (payload_checksum),        
            
            .aclk       (aclk),
            .aresetn    (aresetn)
        );

        //Combine payload and pseudo checksum for final checksum value
        wire [16:0] intermediate_check = payload_checksum + pseudo_udp_checksum_buff;
        wire [15:0] final_checksum = intermediate_check[15:0] + intermediate_check[16];

        //Determine whether there is a relevant checksum error
        assign decap_sel_id_2 = axis_buff_reg_tdest[AXIS_ID_WIDTH-1:0];
        assign has_udp_checksum_reg = has_udp_checksum_buff && (encap_mode_2 == 5);
        assign udp_error_reg = has_udp_checksum_reg && (final_checksum != 16'hffff);




        //Retiming registers
        wire                          has_udp_checksum_reg_out;
        wire                          udp_error_reg_out;

        axis_reg_slices
        #(
            .AXIS_BUS_WIDTH     (AXIS_BUS_WIDTH),
            .AXIS_USER_WIDTH    (2 + AXIS_ID_WIDTH + 1),
            .REG_STAGES         (RETIMING_STAGES_CHECKSUM)
        )
        regs 
        (
            .axis_in_tdata      (axis_buff_reg_tdata),
            .axis_in_tuser      ({has_udp_checksum_reg,udp_error_reg,axis_buff_reg_tdest}),                                         
            .axis_in_tkeep      (axis_buff_reg_tkeep),
            .axis_in_tlast      (axis_buff_reg_tlast),
            .axis_in_tvalid     (axis_buff_reg_tvalid),
            .axis_in_tready     (axis_buff_reg_tready),

            .axis_out_tdata     (axis_out_tdata),
            .axis_out_tuser     ({has_udp_checksum_reg_out,udp_error_reg_out,axis_out_tdest}),                                          
            .axis_out_tkeep     (axis_out_tkeep),
            .axis_out_tlast     (axis_out_tlast),
            .axis_out_tvalid    (axis_out_tvalid),
            .axis_out_tready    (axis_out_tready),

            .aclk       (aclk),
            .aresetn    (aresetn)
        );

        assign parsing_done = !has_udp_checksum_reg_out || axis_out_tlast;
        assign poisoned = udp_error_reg_out && axis_out_tlast;

    end else begin

        assign axis_out_tdata = axis_decap_tdata;
        assign axis_out_tdest = axis_decap_tdest;
        assign axis_out_tkeep = axis_decap_tkeep;
        assign axis_out_tlast = axis_decap_tlast;
        assign axis_out_tvalid = axis_decap_tvalid;

        assign axis_decap_tready = axis_out_tready;

        assign parsing_done = 1'b1;
        assign poisoned = 1'b0;

    end 
    endgenerate



endmodule

`default_nettype wire