`timescale 1ns / 1ps
`default_nettype none


module encap_inserter
#(
    //AXI Stream Params
    parameter AXIS_BUS_WIDTH = 64,
    parameter AXIS_USER_WIDTH = 4,

    //Derived params for AXI Stream
    localparam NUM_BUS_BYTES = AXIS_BUS_WIDTH/8,

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
    parameter bit ALLOW_ENCAP_W_TAG  = 0  
)
(
    //Input AXI stream
    input wire [AXIS_BUS_WIDTH-1:0]     axis_in_tdata,
    input wire [AXIS_USER_WIDTH-1:0]    axis_in_tuser,
    input wire [NUM_BUS_BYTES-1:0]      axis_in_tkeep,
    input wire                          axis_in_tlast,
    input wire                          axis_in_tvalid,
    output wire                         axis_in_tready,
    
    //Output AXI stream
    output wire [AXIS_BUS_WIDTH-1:0]    axis_out_tdata,
    output wire [AXIS_USER_WIDTH-1:0]   axis_out_tuser,
    output wire [NUM_BUS_BYTES-1:0]     axis_out_tkeep,
    output wire                         axis_out_tlast,
    output wire                         axis_out_tvalid,
    input wire                          axis_out_tready,

    //Side channel signals from previous stage (length & checksum)
    input wire [15:0]                   length_count,
    input wire [15:0]                   accumalted_checksum,

    //Configuration register inputs
    input wire [2:0]                    encap_mode,
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
    //   Encapsulation types and sizes params                 //
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
    //   Calculation of length and checksum final values      //
    //--------------------------------------------------------//

    //Signals counting packet length
    reg [15:0] length_ip_hdr;
    reg [15:0] length_udp_hdr;

    always@(*) begin
        //Default assignments
        length_ip_hdr = 'x;
        length_udp_hdr = 'x;

        case(encap_mode)
            4: begin
                length_ip_hdr = length_count + 20;
            end
            5: begin
                length_ip_hdr = length_count + 28;
                length_udp_hdr = length_count + 8;
            end
            6: begin
                length_ip_hdr = length_count + 28;
            end
            7: begin
                length_ip_hdr = length_count + 36;
                length_udp_hdr = length_count + 16;
            end
        endcase
    end

    wire [15:0] length_ip_hdr_be = {length_ip_hdr[7:0],length_ip_hdr[15:8]};
    wire [15:0] length_udp_hdr_be = {length_udp_hdr[7:0],length_udp_hdr[15:8]};

    //Signals calculating packet checksums
    wire [16:0] checksum_ip_hdr_im = ip4_partial_checksum + length_ip_hdr;
    wire [15:0] checksum_ip_hdr_im2 = checksum_ip_hdr_im[15:0] + checksum_ip_hdr_im[16];
    wire [15:0] checksum_ip_hdr = ~checksum_ip_hdr_im2;
    wire [15:0] checksum_ip_hdr_be = {checksum_ip_hdr[7:0],checksum_ip_hdr[15:8]};

    wire [17:0] checksum_udp_im1 = accumalted_checksum + udp_partial_checksum + (2*(length_count+8));
    wire [15:0] checksum_udp_im2 = checksum_udp_im1[15:0] + checksum_udp_im1[17:16];
    wire [15:0] checksum_udp_im3 = (checksum_udp_im2 == 16'hFFFF ? checksum_udp_im2 : ~checksum_udp_im2);
    wire [15:0] checksum_udp = (include_udp_checksum ? checksum_udp_im3 : 0);
    wire [15:0] checksum_udp_be = {checksum_udp[7:0],checksum_udp[15:8]};    



    //--------------------------------------------------------//
    //   Packet encapsulation signals                         //
    //--------------------------------------------------------//

    //Create different encapsualtion signals for different modes
    wire [431:0] encap_sigs [NUM_ENCAP_TYPES] =
        '{
            {   {432{1'bx}}   },

            {   {320{1'bx}},                                                        //320 bits = 40 bytes
                16'hB588,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {320{1'bx}},                                                        //320 bits = 40 bytes
                16'h0008,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {320{1'bx}},                                                        //320 bits = 40 bytes
                16'hDD86,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {160{1'bx}},                                                        //160 bits = 20 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,ip4_protocol,ip4_ttl, //96 bits = 8 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 12 bytes
                16'h0008,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {96{1'bx}},                                                         //96 bits = 12 bytes
                checksum_udp_be,length_udp_hdr_be,udp_dest_port,udp_src_port,       //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h11,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 8 bytes
                16'h0008,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {96{1'bx}},                                                         //96 bits = 12 bytes
                udp_src_port[15:8],virt_vsid,32'h58660020,                          //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h2F,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000, length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                //64 bits = 8 bytes
                16'h0008,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {32{1'bx}},                                                         //32 bits = 4 bytes
                4'h0,virt_vsid,32'h00000008,                                        //64 bits = 8 bytes
                16'h0000,length_udp_hdr_be,udp_dest_port,udp_src_port,              //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h11,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,24'h45,                //64 bits = 8 bytes
                16'h0008,mac_src_address,mac_dest_address},                         //112 bits = 14 bytes

            {   {432{1'bx}}   },

            {   {288{1'bx}},                                                        //288 bits = 36 bytes
                16'h0008,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   {288{1'bx}},                                                        //288 bits = 36 bytes
                16'hB588,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   {288{1'bx}},                                                        //288 bits = 36 bytes
                16'hDD86,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   {128{1'bx}},                                                        //128 bits = 16 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,ip4_protocol,ip4_ttl, //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 8 bytes
                16'h0008,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   {64{1'bx}},                                                         //64 bits = 8 bytes
                checksum_udp_be,length_udp_hdr_be,udp_dest_port,udp_src_port,       //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h11,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 8 bytes
                16'h0008,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   {64{1'bx}},                                                         //64 bits = 8 bytes
                udp_src_port[15:8],virt_vsid,32'h58660020,                          //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h2F,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 8 bytes
                16'h0008,vlan_field,16'h0081,mac_src_address,mac_dest_address},     //144 bits = 18 bytes

            {   4'h0,virt_vsid,32'h00000008,                                        //64 buts = 8 bytes
                16'h0000,length_udp_hdr_be,udp_dest_port,udp_src_port,              //64 bits = 8 bytes
                ip4_dest_address,ip4_src_address,checksum_ip_hdr_be,8'h11,ip4_ttl,  //96 bits = 12 bytes
                32'h00400000,length_ip_hdr_be,ip4_dhsp,2'b00,8'h45,                 //64 bits = 8 bytes
                16'h0008,vlan_field,16'h0081,mac_src_address,mac_dest_address}      //144 bits = 18 bytes
        };



    //--------------------------------------------------------//
    //   Actual Packet Encapsulation                          //
    //--------------------------------------------------------//

    generate if(NUM_ENCAP_SIZES_ALLOWED > 1) begin

        //Specific encap signals
        localparam MAX_ENCAP_SIZE = ENCAP_SIZES_ALLOWED[NUM_ENCAP_SIZES_ALLOWED-1];
        localparam NUM_ENCAP_BYTES_CBITS = $clog2(MAX_ENCAP_SIZE + 1);
        localparam NUM_ECNAP_SIZES_LOG2 = $clog2(NUM_ENCAP_SIZES_ALLOWED);

        reg [(MAX_ENCAP_SIZE*8)-1:0] encap;
        reg [NUM_ENCAP_BYTES_CBITS-1:0] encap_size;
        reg [NUM_ECNAP_SIZES_LOG2-1:0] encap_sel;

        always@(*) begin

            //Default Assignments
            encap = 'x;
            encap_size = 'x;
            encap_sel = 'x;

            case({ (insert_vlan_tag&TAG), encap_mode })

                0: if(ENCAP_SIZE_INDIRECT[0] >= 0) begin
                    encap = encap_sigs[0];
                    encap_size = ENCAP_SIZES_TOTAL[0];
                    encap_sel = ENCAP_SIZE_INDIRECT[0];
                end

                1: if(ENCAP_SIZE_INDIRECT[1] >= 0) begin
                    encap = encap_sigs[1];
                    encap_size = ENCAP_SIZES_TOTAL[1];
                    encap_sel = ENCAP_SIZE_INDIRECT[1];
                end

                2: if(ENCAP_SIZE_INDIRECT[2] >= 0) begin
                    encap = encap_sigs[2];
                    encap_size = ENCAP_SIZES_TOTAL[2];
                    encap_sel = ENCAP_SIZE_INDIRECT[2];
                end

                3: if(ENCAP_SIZE_INDIRECT[3] >= 0) begin
                    encap = encap_sigs[3];
                    encap_size = ENCAP_SIZES_TOTAL[3];
                    encap_sel = ENCAP_SIZE_INDIRECT[3];
                end

                4: if(ENCAP_SIZE_INDIRECT[4] >= 0) begin
                    encap = encap_sigs[4];
                    encap_size = ENCAP_SIZES_TOTAL[4];
                    encap_sel = ENCAP_SIZE_INDIRECT[4];
                end

                5: if(ENCAP_SIZE_INDIRECT[5] >= 0) begin
                    encap = encap_sigs[5];
                    encap_size = ENCAP_SIZES_TOTAL[5];
                    encap_sel = ENCAP_SIZE_INDIRECT[5];
                end

                6: if(ENCAP_SIZE_INDIRECT[6] >= 0) begin
                    encap = encap_sigs[6];
                    encap_size = ENCAP_SIZES_TOTAL[6];
                    encap_sel = ENCAP_SIZE_INDIRECT[6];
                end

                7: if(ENCAP_SIZE_INDIRECT[7] >= 0) begin
                    encap = encap_sigs[7];
                    encap_size = ENCAP_SIZES_TOTAL[7];
                    encap_sel = ENCAP_SIZE_INDIRECT[7];
                end

                8: if(ENCAP_SIZE_INDIRECT[8] >= 0) begin
                    encap = encap_sigs[8];
                    encap_size = ENCAP_SIZES_TOTAL[8];
                    encap_sel = ENCAP_SIZE_INDIRECT[8];
                end

                9: if(ENCAP_SIZE_INDIRECT[9] >= 0) begin
                    encap = encap_sigs[9];
                    encap_size = ENCAP_SIZES_TOTAL[9];
                    encap_sel = ENCAP_SIZE_INDIRECT[9];
                end

                10: if(ENCAP_SIZE_INDIRECT[10] >= 0) begin
                    encap = encap_sigs[10];
                    encap_size = ENCAP_SIZES_TOTAL[10];
                    encap_sel = ENCAP_SIZE_INDIRECT[10];
                end

                11: if(ENCAP_SIZE_INDIRECT[11] >= 0) begin
                    encap = encap_sigs[11];
                    encap_size = ENCAP_SIZES_TOTAL[11];
                    encap_sel = ENCAP_SIZE_INDIRECT[11];
                end

                12: if(ENCAP_SIZE_INDIRECT[12] >= 0) begin
                    encap = encap_sigs[12];
                    encap_size = ENCAP_SIZES_TOTAL[12];
                    encap_sel = ENCAP_SIZE_INDIRECT[12];
                end

                13: if(ENCAP_SIZE_INDIRECT[13] >= 0) begin
                    encap = encap_sigs[13];
                    encap_size = ENCAP_SIZES_TOTAL[13];
                    encap_sel = ENCAP_SIZE_INDIRECT[13];
                end

                14: if(ENCAP_SIZE_INDIRECT[14] >= 0) begin
                    encap = encap_sigs[14];
                    encap_size = ENCAP_SIZES_TOTAL[14];
                    encap_sel = ENCAP_SIZE_INDIRECT[14];
                end

                15: if(ENCAP_SIZE_INDIRECT[15] >= 0) begin
                    encap = encap_sigs[15];
                    encap_size = ENCAP_SIZES_TOTAL[15];
                    encap_sel = ENCAP_SIZE_INDIRECT[15];
                end

            endcase
        end

        segment_inserter_mult
        #(
            .AXIS_BUS_WIDTH      (AXIS_BUS_WIDTH),
            .AXIS_USER_WIDTH     (AXIS_USER_WIDTH),
            .MAX_PACKET_LENGTH   (MAX_PACKET_LENGTH),
            .USE_DYNAMIC_FSM     (USE_DYNAMIC_FSM),
            .INSERT_OFFSET       (0),
            .NUM_INSERT_SIZES    (NUM_ENCAP_SIZES_ALLOWED),
            .INSERT_SIZES_BYTES  (ENCAP_SIZES_ALLOWED)
        )
        insert
        (
            .axis_in_tdata      (axis_in_tdata),
            .axis_in_tuser      (axis_in_tuser),
            .axis_in_tkeep      (axis_in_tkeep),
            .axis_in_tlast      (axis_in_tlast),
            .axis_in_tvalid     (axis_in_tvalid),
            .axis_in_tready     (axis_in_tready),

            .axis_out_tdata     (axis_out_tdata),
            .axis_out_tuser     (axis_out_tuser),
            .axis_out_tkeep     (axis_out_tkeep),
            .axis_out_tlast     (axis_out_tlast),
            .axis_out_tvalid    (axis_out_tvalid),
            .axis_out_tready    (axis_out_tready),

            .seg_to_insert      (encap),
            .segment_size       (encap_size),
            .segment_sel        (encap_sel),
            
            .aclk       (aclk),
            .aresetn    (aresetn)
        );

    end else begin

        //Specific encap signal
        reg [(ENCAP_SIZES_ALLOWED[0]*8)-1:0] encap;

        always@(*) begin

            //Default Assignment
            encap = 'x;

            for(integer i = 0; i < 16; i = i + 1) begin

                if(ENCAP_SIZE_INDIRECT[i] >=0) encap = encap_sigs[i];

            end

        end

        segment_inserter_onesz
        #(
            .AXIS_BUS_WIDTH      (AXIS_BUS_WIDTH),
            .AXIS_USER_WIDTH     (AXIS_USER_WIDTH),
            .MAX_PACKET_LENGTH   (MAX_PACKET_LENGTH),
            .INSERT_OFFSET       (0),
            .INSERT_SIZE_BYTES   (ENCAP_SIZES_ALLOWED[0])
        )
        insert
        (
            .axis_in_tdata      (axis_in_tdata),
            .axis_in_tuser      (axis_in_tuser),
            .axis_in_tkeep      (axis_in_tkeep),
            .axis_in_tlast      (axis_in_tlast),
            .axis_in_tvalid     (axis_in_tvalid),
            .axis_in_tready     (axis_in_tready),

            .axis_out_tdata     (axis_out_tdata),
            .axis_out_tuser     (axis_out_tuser),
            .axis_out_tkeep     (axis_out_tkeep),
            .axis_out_tlast     (axis_out_tlast),
            .axis_out_tvalid    (axis_out_tvalid),
            .axis_out_tready    (axis_out_tready),

            .seg_to_insert      (encap),
            
            .aclk       (aclk),
            .aresetn    (aresetn)
        );

    end 
    endgenerate



endmodule

`default_nettype wire