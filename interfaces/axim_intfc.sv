//A SystemVerilog interface for the AXI-4 Memory Mapped (Full) protocol

interface axim_intfc
#(
    //Width parameters for various AXI Signals
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_ID_WIDTH = 1,
    parameter AXI_AWUSER_WIDTH = 1,
    parameter AXI_ARUSER_WIDTH = 1,
    parameter AXI_WUSER_WIDTH = 1,
    parameter AXI_BUSER_WIDTH = 1,
    parameter AXI_RUSER_WIDTH = 1
)
(
    //The clock and reset the AXI interface is synchronous to
    input wire aclk,
    input wire aresetn
);
    //Write Address Channel
    logic [AXI_ID_WIDTH-1:0]       awid; //default value = '0
    logic [AXI_ADDR_WIDTH-1:0]     awaddr; //no default value
    logic [7:0]                    awlen; //default value = '0
    logic [2:0]                    awsize; //default value = $log2(AXI_DATA_WIDTH)
    logic [1:0]                    awburst; //default value = 2'b01
    logic [1:0]                    awlock; //default value = '0
    logic [3:0]                    awcache; //default value = '0
    logic [2:0]                    awprot; //no default value
    logic [3:0]                    awqos; //default value = '0
    logic [AXI_AWUSER_WIDTH-1:0]   awuser; //no default value
    logic                          awvalid;
    logic                          awready;
    //Write Data Channel
    logic [AXI_DATA_WIDTH-1:0]     wdata; //no default value
    logic [(AXI_DATA_WIDTH/8)-1:0] wstrb; //default value = '1
    logic                          wlast; //no default value
    logic [AXI_WUSER_WIDTH-1:0]    wuser; //no default value
    logic                          wvalid;
    logic                          wready;
    //Write Response Channel
    logic [AXI_ID_WIDTH-1:0]       bid; //no default value
    logic [1:0]                    bresp; //default value = 2'b00 (OKAY)
    logic [AXI_BUSER_WIDTH-1:0]    buser; //no default value
    logic                          bvalid;
    logic                          bready;
    //Read Address Channel
    logic [AXI_ID_WIDTH-1:0]       arid; //default value = '0
    logic [AXI_ADDR_WIDTH-1:0]     araddr; //no default value
    logic [7:0]                    arlen; //default value = '0
    logic [2:0]                    arsize; //default value = $log2(AXI_DATA_WIDTH)
    logic [1:0]                    arburst; //default value = 2'b01
    logic [1:0]                    arlock; //default value = '0
    logic [3:0]                    arcache; //default value = '0
    logic [2:0]                    arprot; //no default value
    logic [3:0]                    arqos; //default value = '0
    logic [AXI_ARUSER_WIDTH-1:0]   aruser; //no default value
    logic                          arvalid;
    logic                          arready;
    //Read Data Response Channel
    logic [AXI_ID_WIDTH-1:0]       rid; //no default value
    logic [AXI_DATA_WIDTH-1:0]     rdata; //no default value
    logic [1:0]                    rresp; //default value = 2'b00 (OKAY)
    logic                          rlast; //no default value
    logic [AXI_RUSER_WIDTH-1:0]    ruser; //no default value
    logic                          rvalid;
    logic                          rready;

    //Master modport
    modport master
    (
        output
        awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awuser,awvalid, //Write Address Channel
        wdata,wstrb,wlast,wuser,wvalid, //Write Data Channel
        bready, //Write Response Channel
        arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,aruser,arvalid, //Read Address Channel
        rready, //Read Data Response Channel

        input 
        awready, //Write Address Channel
        wready, //Write Data Channel
        bid,bresp,buser,bvalid, //Write Response Channel
        arready, //Read Address Channel
        rid,rdata,rresp,rlast,ruser,rvalid, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );

    //Slave modport
    modport slave
    (
        output 
        awready, //Write Address Channel
        wready, //Write Data Channel
        bid,bresp,buser,bvalid, //Write Response Channel
        arready, //Read Address Channel
        rid,rdata,rresp,rlast,ruser,rvalid, //Read Data Response Channel

        input
        awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awuser,awvalid, //Write Address Channel
        wdata,wstrb,wlast,wuser,wvalid, //Write Data Channel
        bready, //Write Response Channel
        arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,aruser,arvalid, //Read Address Channel
        rready, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );

    //Special modports including only subset of channels
    modport aw_master (
        output awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awuser,awvalid,
        input awready
    );
    modport aw_slave (
        input awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awuser,awvalid,
        output awready
    );
    modport w_master (
        output wdata,wstrb,wlast,wuser,wvalid,
        input wready
    );
    modport w_slave (
        output wready,
        input wdata,wstrb,wlast,wuser,wvalid
    );
    modport b_master (
        output bready,
        input bid,bresp,buser,bvalid
    );
    modport b_slave (
        output bid,bresp,buser,bvalid,
        input bready
    );
    modport ar_master (
        output arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,aruser,arvalid,
        input arready
    );
    modport ar_slave (
        output arready,
        input arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,aruser,arvalid
    );
    modport r_master (
        output rready,
        input rid,rdata,rresp,rlast,ruser,rvalid
    );
    modport r_slave (
        output rid,rdata,rresp,rlast,ruser,rvalid,
        input rready
    );

    //Monitor signals modport
    modport monitor 
    (
        input
        awid,awaddr,awlen,awsize,awburst,awlock,awcache,awprot,awqos,awuser,awvalid,awready, //Write Address Channel
        wdata,wstrb,wlast,wuser,wvalid,wready, //Write Data Channel
        bid,bresp,buser,bvalid,bready, //Write Response Channel
        arid,araddr,arlen,arsize,arburst,arlock,arcache,arprot,arqos,aruser,arvalid,arready, //Read Address Channel
        rid,rdata,rresp,rlast,ruser,rvalid,rready, //Read Data Response Channel
        aclk, aresetn //Clocking signals
    );
    
endinterface



//Modules used to assign interfaces in pass-through scenarios (avoiding boiler-plate assignment each time)

//Module to assign Write Address Channel signals (pass-through)
module axim_assign_aw (axim_intf.aw_master A, axim_intfc.aw_slave B);
    assign A.awid = B.awid;
    assign A.awaddr = B.awaddr;
    assign A.awlen = B.awlen;
    assign A.awsize = B.awsize;
    assign A.awburst = B.awburst;
    assign A.awlock = B.awlock;
    assign A.awcache = B.awcache;
    assign A.awprot = B.awprot;
    assign A.awqos = B.awqos;
    assign A.awuser = B.awuser;
    assign A.awvalid = B.awvalid;
    assign B.awready = A.awready;
endmodule

//Module to assign Write Data Channel signals (pass-through)
module axim_assign_w (axim_intf.w_master A, axim_intfc.w_slave B);
    assign A.wdata = B.wdata;
    assign A.wstrb = B.wstrb;
    assign A.wlast = B.wlast;
    assign A.wuser = B.wuser;
    assign A.wvalid = B.wvalid;
    assign B.wready = A.wready;
endmodule

//Module to assign Write Response Channel signals (pass-through)
module axim_assign_b (axim_intf.b_master A, axim_intfc.b_slave B);
    assign B.bid = A.bid;
    assign B.bresp = A.bresp;
    assign B.buser = A.buser;
    assign B.bvalid = A.bvalid;
    assign A.bready = B.bready;
endmodule

//Module to assign Read Address Channel signals (pass-through)
module axim_assign_ar (axim_intf.ar_master A, axim_intfc.ar_slave B);
    assign A.arid = B.arid;
    assign A.araddr = B.araddr;
    assign A.arlen = B.arlen;
    assign A.arsize = B.arsize;
    assign A.arburst = B.arburst;
    assign A.arlock = B.arlock;
    assign A.arcache = B.arcache;
    assign A.arprot = B.arprot;
    assign A.arqos = B.arqos;
    assign A.aruser = B.aruser;
    assign A.arvalid = B.arvalid;
    assign B.arready = A.arready;
endmodule

//Module to assign Read Data Response Channel signals (pass-through)
module axim_assign_r (axim_intf.r_master A, axim_intfc.r_slave B);
    assign B.rid = A.rid;
    assign B.rdata = A.rdata;
    assign B.rresp = A.rresp;
    assign B.rlast = A.rlast;
    assign B.ruser = A.ruser;
    assign B.rvalid = A.rvalid;
    assign A.ready = B.rready;
endmodule

//Module to assign all signals (pass-through)
module axim_assign_all (axim_intf.master A, axim_intfc.slave B);
    //Write Address Channel
    assign A.awid = B.awid;
    assign A.awaddr = B.awaddr;
    assign A.awlen = B.awlen;
    assign A.awsize = B.awsize;
    assign A.awburst = B.awburst;
    assign A.awlock = B.awlock;
    assign A.awcache = B.awcache;
    assign A.awprot = B.awprot;
    assign A.awqos = B.awqos;
    assign A.awuser = B.awuser;
    assign A.awvalid = B.awvalid;
    assign B.awready = A.awready;
    //Write Data Channel
    assign A.wdata = B.wdata;
    assign A.wstrb = B.wstrb;
    assign A.wlast = B.wlast;
    assign A.wuser = B.wuser;
    assign A.wvalid = B.wvalid;
    assign B.wready = A.wready;
    //Write Response Channel
    assign B.bid = A.bid;
    assign B.bresp = A.bresp;
    assign B.buser = A.buser;
    assign B.bvalid = A.bvalid;
    assign A.bready = B.bready;
    //Read Address Channel
    assign A.arid = B.arid;
    assign A.araddr = B.araddr;
    assign A.arlen = B.arlen;
    assign A.arsize = B.arsize;
    assign A.arburst = B.arburst;
    assign A.arlock = B.arlock;
    assign A.arcache = B.arcache;
    assign A.arprot = B.arprot;
    assign A.arqos = B.arqos;
    assign A.aruser = B.aruser;
    assign A.arvalid = B.arvalid;
    assign B.arready = A.arready;
    //Read Data Response Channel
    assign B.rid = A.rid;
    assign B.rdata = A.rdata;
    assign B.rresp = A.rresp;
    assign B.rlast = A.rlast;
    assign B.ruser = A.ruser;
    assign B.rvalid = A.rvalid;
    assign A.ready = B.rready;
endmodule
