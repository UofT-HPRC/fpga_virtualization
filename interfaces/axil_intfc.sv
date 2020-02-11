//A SystemVerilog interface for the AXI-4 Lite Memory Mapped protocol

interface axil_intfc
#(
    //Width parameters for various AXI Signals
    parameter IS_64_BIT = 0,
    parameter AXI_ADDR_WIDTH = 32
)
(
    //The clock and reset the AXI interface is synchronous to
    input wire aclk,
    input wire aresetn
);
    //The Data Width from parameter
    localparam AXI_DATA_WIDTH = (IS_64_BIT ? 64 : 32);

    //Write Address Channel
    logic [AXI_ADDR_WIDTH-1:0]     awaddr; //no default value
    logic                          awvalid;
    logic                          awready;
    //Write Data Channel
    logic [AXI_DATA_WIDTH-1:0]     wdata; //no default value
    logic [(AXI_DATA_WIDTH/8)-1:0] wstrb; //default value = '1
    logic                          wvalid;
    logic                          wready;
    //Write Response Channel
    logic [1:0]                    bresp; //default value = 2'b00 (OKAY)
    logic                          bvalid;
    logic                          bready;
    //Read Address Channel
    logic [AXI_ADDR_WIDTH-1:0]     araddr; //no default value
    logic                          arvalid;
    logic                          arready;
    //Read Data Response Channel
    logic [AXI_DATA_WIDTH-1:0]     rdata; //no default value
    logic [1:0]                    rresp; //default value = 2'b00 (OKAY)
    logic                          rvalid;
    logic                          rready;

    //Master modport
    modport master
    (
        output
        awaddr,awvalid, //Write Address Channel
        wdata,wstrb,wvalid, //Write Data Channel
        bready, //Write Response Channel
        araddr,arvalid, //Read Address Channel
        rready, //Read Data Response Channel

        input 
        awready, //Write Address Channel
        wready, //Write Data Channel
        bresp,bvalid, //Write Response Channel
        arready, //Read Address Channel
        rdata,rresp,rvalid, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );

    //Slave modport
    modport slave
    (
        output 
        awready, //Write Address Channel
        wready, //Write Data Channel
        bresp,bvalid, //Write Response Channel
        arready, //Read Address Channel
        rdata,rresp,rvalid, //Read Data Response Channel

        input
        awaddr,awvalid, //Write Address Channel
        wdata,wstrb,wvalid, //Write Data Channel
        bready, //Write Response Channel
        araddr,arvalid, //Read Address Channel
        rready, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );

    //Special modports including only subset of channels
    modport aw_master (
        output awaddr,awvalid,
        input awready
    );
    modport aw_slave (
        input awaddr,awvalid,
        output awready
    );
    modport w_master (
        output wdata,wstrb,wvalid,
        input wready
    );
    modport w_slave (
        output wready,
        input wdata,wstrb,wvalid
    );
    modport b_master (
        output bready,
        input bresp,bvalid
    );
    modport b_slave (
        output bresp,bvalid,
        input bready
    );
    modport ar_master (
        output araddr,arvalid,
        input arready
    );
    modport ar_slave (
        output arready,
        input araddr,arvalid
    );
    modport r_master (
        output rready,
        input rdata,rresp,rvalid
    );
    modport r_slave (
        output rdata,rresp,rvalid,
        input rready
    );

    //Monitor signals modport
    modport monitor 
    (
        input
        awaddr,awvalid,awready, //Write Address Channel
        wdata,wstrb,wvalid,wready, //Write Data Channel
        bresp,bvalid,bready, //Write Response Channel
        araddr,arvalid,arready, //Read Address Channel
        rdata,rresp,rvalid,rready, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );
    
endinterface



//Modules used to assign interfaces in pass-through scenarios (avoiding boiler-plate assignment each time)

//Module to assign Write Address Channel signals (pass-through)
module axil_assign_aw (axil_intf.aw_master A, axil_intfc.aw_slave B);
    assign A.awaddr = B.awaddr;
    assign A.awvalid = B.awvalid;
    assign B.awready = A.awready;
endmodule

//Module to assign Write Data Channel signals (pass-through)
module axil_assign_w (axil_intf.w_master A, axil_intfc.w_slave B);
    assign A.wdata = B.wdata;
    assign A.wstrb = B.wstrb;
    assign A.wvalid = B.wvalid;
    assign B.wready = A.wready;
endmodule

//Module to assign Write Response Channel signals (pass-through)
module axil_assign_b (axil_intf.b_master A, axil_intfc.b_slave B);
    assign B.bresp = A.bresp;
    assign B.bvalid = A.bvalid;
    assign A.bready = B.bready;
endmodule

//Module to assign Read Address Channel signals (pass-through)
module axil_assign_ar (axil_intf.ar_master A, axil_intfc.ar_slave B);
    assign A.arid = B.arid;
    assign A.arvalid = B.arvalid;
    assign B.arready = A.arready;
endmodule

//Module to assign Read Data Response Channel signals (pass-through)
module axil_assign_r (axil_intf.r_master A, axil_intfc.r_slave B);
    assign B.rdata = A.rdata;
    assign B.rresp = A.rresp;
    assign B.rvalid = A.rvalid;
    assign A.ready = B.rready;
endmodule

//Module to assign all signals (pass-through)
module axil_assign_all (axil_intf.master A, axil_intfc.slave B);
    //Write Address Channel
    assign A.awaddr = B.awaddr;
    assign A.awvalid = B.awvalid;
    assign B.awready = A.awready;
    //Write Data Channel
    assign A.wdata = B.wdata;
    assign A.wstrb = B.wstrb;
    assign A.wvalid = B.wvalid;
    assign B.wready = A.wready;
    //Write Response Channel
    assign B.bid = A.bid;
    assign B.bvalid = A.bvalid;
    assign A.bready = B.bready;
    //Read Address Channel
    assign A.araddr = B.araddr;
    assign A.arvalid = B.arvalid;
    assign B.arready = A.arready;
    //Read Data Response Channel
    assign B.rdata = A.rdata;
    assign B.rresp = A.rresp;
    assign B.rvalid = A.rvalid;
    assign A.ready = B.rready;
endmodule
