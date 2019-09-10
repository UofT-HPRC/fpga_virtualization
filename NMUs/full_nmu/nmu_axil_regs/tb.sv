`timescale 1ns / 1ps
`default_nettype none


module tb ();

    //The AXI-Lite interface
    reg  [16:0]   awaddr;
    wire  [2:0]   awprot = '0;
    wire          awvalid = 1;
    wire          awready;
    
    reg  [31:0]   wdata;
    wire  [3:0]   wstrb = '1;
    wire          wvalid = 1;
    wire          wready;

    wire [1:0]    bresp;
    wire          bvalid;
    wire          bready = 1;
    
    reg  [16:0]   araddr;
    wire  [2:0]   arprot = '0;
    wire          arvalid = 1;
    wire          arready;

    wire [31:0]   rdata;
    wire [1:0]    rresp;
    wire          rvalid;
    wire          rready = 1;

    reg           aclk;
    reg           aresetn;
    
    
    
    wire[99:0] mac_config_regs;
    wire[17:0] vlan_config_regs;
    wire[40:0] etype_config_regs;
    wire[145:0] arp_config_regs;                                                        
    wire[100:0] ip4_config_regs;
    wire[33:0] port_config_regs;
    wire[11:0] egress_config_regs;
    wire[2:0] encap_config1_regs;
    wire[290:0] encap_config2_regs;
    wire[65:0] tag_config_regs;
    wire[15:0] cus_tag_config_regs;                                                        
    wire[1:0] detag_config_regs;
    wire[0:0] vsid_config_regs;
    wire[3:0] ingress_config_regs;
    wire[3:0] decap_config1_regs;
    wire[2:0] decap_config2_regs;

    wire[195:0] mac_cam_values;
    wire[67:0] vlan_cam_values;
    wire[19:0] etype_cam_values;
    wire[131:0] arp_cam_values;
    wire[131:0] ip4_cam_values;
    wire[67:0] port_cam_values;
    wire[515:0] cus_tag_cam_values;
    wire[327:0] vsid_cam_values;
            

    reg_file_wrapper 
    #(
        .AXIS_ID_WIDTH(2),
        .AXIS_DEST_WIDTH(2)
    )
    regs
    (
        .mac_config_sel (4'h01),
        .vlan_config_sel (2'h0),
        .etype_config_sel (2'h0),
        .arp_config_sel (4'h00),
        .ip4_config_sel (4'h00),                                                                                                                                                           
        .port_config_sel (4'h00),                                       
        .egress_config_sel (2'h0),                                       
        .encap_config1_sel (2'h0),
        .encap_config2_sel (4'h00),                              
        .tag_config_sel (2'h0),
        .decap_config1_sel (2'h0),
        .decap_config2_sel (2'h0),                                                                                                                                                                                 
        .*
    );

    initial begin

        aclk = 1'b0;
        aresetn = 1'b0;
        awaddr = '0;
        araddr = -4;
        wdata = '1;

        repeat(4) #10 aclk = ~aclk;
        aresetn = 1'b1;
        repeat(16) #10 aclk = ~aclk;

        do begin
            awaddr = awaddr + 4;
            araddr = araddr + 4;
            repeat(4) #10 aclk = ~aclk;
        end while (awaddr <= 20'h00260);

        awaddr = '0;
        araddr = -4;
        wdata = '0;
        repeat(4) #10 aclk = ~aclk;

        do begin
            awaddr = awaddr + 4;
            araddr = araddr + 4;
            repeat(4) #10 aclk = ~aclk;
        end while (awaddr <= 20'h00260);

    end


endmodule

`default_nettype wire