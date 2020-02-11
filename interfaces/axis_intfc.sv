//A SystemVerilog interface for the AXI-Stream protocol

interface axis_intfc
#(
    //Width parameters for various AXI Signals
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ID_WIDTH = 1,
    parameter AXI_DEST_WIDTH = 1,
    parameter AXI_USER_WIDTH = 1,
)
(
    //The clock and reset the AXI interface is synchronous to
    input wire aclk,
    input wire aresetn
);
    //Interface Signals
    logic [AXI_DATA_WIDTH-1:0]     tdata; //no default value
    logic [(AXI_DATA_WIDTH/8)-1:0] tkeep; //default value = '1
    logic [AXI_ID_WIDTH-1:0]       tid;
    logic [AXI_DEST_WIDTH-1:0]     tdest;
    logic [AXI_USER_WIDTH-1:0]     tuser;
    logic                          tvalid;
    logic                          tready;

    //Master modport
    modport master
    (
        output tdata,tkeep,tid,tdest,tuser,tvalid,
        input tready,aclk,aresetn
    );

    //Slave modport
    modport slave
    (
        output tready,
        input tdata,tkeep,tid,tdest,tuser,tvalid,aclk,aresetn
    );

    //Monitor signals modport
    modport monitor 
    (
        input tdata,tkeep,tid,tdest,tuser,tvalid,tready,aclk,aresetn
    );
    
endinterface



//Modules used to assign interfaces in pass-through scenarios (avoiding boiler-plate assignment each time)
module axis_assign_all (axis_intf.master A, axis_intfc.slave B);
    assign A.tdata = B.tdata;
    assign A.tkeep = B.tkeep;
    assign A.tid = B.tid;
    assign A.tdest = B.tdest;
    assign A.tuser = B.tuser;
    assign A.tvalid = B.tvalid;
    assign B.tready = A.tready;
endmodule
