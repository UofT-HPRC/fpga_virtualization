`timescale 1ns / 1ps
`default_nettype none


module test
();

    reg aclk;
    reg aresetn;

    mac_wrapper
    #(
        .AXIS_BUS_WIDTH (64),
        .AXIS_ID_WIDTH (4),
        .AXIS_DEST_WIDTH (4),
        .MAX_PACKET_LENGTH (1522),
        .INGRESS (0),
        .INCLUDE_MAC_NEXT_ACL (1),
        .INCLUDE_MAC_SRC_ACL (1),
        .INCLUDE_MAC_DEST_ACL (1),
        .INCLUDE_MAC_DEST_CAM (1),
        .RETIMING_STAGES (2)
    )
    dut
    (
        .axis_in_tdata ('1),
        .axis_in_tid ('1),
        .axis_in_tuser ('1),
        .axis_in_tdest ('1),
        .axis_in_tkeep ('1),
        .axis_in_tlast ('0),
        .axis_in_tvalid ('1),
        .axis_in_tready (),
        
        .axis_out_tdata (),
        .axis_out_tid (),
        .axis_out_tuser (),
        .axis_out_tdest (),
        .axis_out_tkeep (),
        .axis_out_tlast (),
        .axis_out_tvalid (),
        .axis_out_tready ('1),
        
        .mac_config_sel (),
        
        .mac_config_regs ({1'b1,48'hFFFFFFFFFFFF,1'b1,48'h01010101FFFF,2'b10}),
        .mac_cam_values ({ {4{49'h1010101010101}},49'h1ffffffffffff,{10{49'h1010101010101}},49'h1ffffffffffff }),
        
        .aclk (aclk),
        .aresetn (aresetn)
    );

    initial begin
        aclk = 1'b0;
        aresetn = 1'b0;
        repeat(4) #10 aclk = ~aclk;
        aresetn = 1'b1;
        forever #10 aclk = ~aclk;
    end



endmodule

`default_nettype wire