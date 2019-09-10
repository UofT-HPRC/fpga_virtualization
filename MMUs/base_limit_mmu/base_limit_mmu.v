`timescale 1ns / 1ps
`default_nettype none


//The MMU
module base_limit_mmu
#(
    //Given AXI4 Interface Params
    parameter AXI_ID_WIDTH = 5,
    parameter AXI_IN_ADDR_WIDTH = 33,
    parameter AXI_DATA_WIDTH = 128,

    //Core Options
    parameter INCLUDE_ERROR = 1, // whether or not error is indicated on addr output
    parameter INCLUDE_BASE = 1, // whether or not the base part of calculation is included
    parameter INCLUDE_LIMIT = 1, // whether or not the limit is checked for out-of-bounds access
    parameter IGNORE_ID_MSB = 1, // whether or not IDs with MSB=1 pass-through with no MMU remapping

    //Core Params
    parameter ID_BITS_USED = 4, // number of ID bits considered for unique mappings
    parameter BASE_ADDR_BITS_UNTOUCHED = 12, //4k boundary crossing or greater needed for proper operation
    parameter LIM_ADDR_BITS_UNTOUCHED = 12, //4k boundary crossing or greater needed for proper operation

    //Values derived from parameters (not to be changed)
    parameter AXI_OUT_ADDR_WIDTH = AXI_IN_ADDR_WIDTH + INCLUDE_ERROR,
    parameter CTRL_AXIL_ADDR_WIDTH = ((ID_BITS_USED + 4) < 12) ? 12 : ID_BITS_USED + 4
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_awid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      mem_in_awaddr,
    input wire [7:0]                        mem_in_awlen,
    input wire [2:0]                        mem_in_awsize,
    input wire [1:0]                        mem_in_awburst,
    input wire                              mem_in_awuser, //error indicator
    input wire                              mem_in_awvalid,
    output wire                             mem_in_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         mem_in_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     mem_in_wstrb,
    input wire                              mem_in_wlast,
    input wire                              mem_in_wvalid,
    output wire                             mem_in_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_bid,
    output wire [1:0]                       mem_in_bresp,
    output wire                             mem_in_bvalid,
    input wire                              mem_in_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           mem_in_arid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      mem_in_araddr,
    input wire [7:0]                        mem_in_arlen,
    input wire [2:0]                        mem_in_arsize,
    input wire [1:0]                        mem_in_arburst,
    input wire                              mem_in_aruser,
    input wire                              mem_in_arvalid,
    output wire                             mem_in_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          mem_in_rid,
    output wire [AXI_DATA_WIDTH-1:0]        mem_in_rdata,
    output wire [1:0]                       mem_in_rresp,
    output wire                             mem_in_rlast,
    output wire                             mem_in_rvalid,
    input wire                              mem_in_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_awid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    mem_out_awaddr,
    output wire [7:0]                       mem_out_awlen,
    output wire [2:0]                       mem_out_awsize,
    output wire [1:0]                       mem_out_awburst,
    output wire                             mem_out_awuser, //error indicator
    output wire                             mem_out_awvalid,
    input wire                              mem_out_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        mem_out_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    mem_out_wstrb,
    output wire                             mem_out_wlast,
    output wire                             mem_out_wvalid,
    input wire                              mem_out_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_bid,
    input wire [1:0]                        mem_out_bresp,
    input wire                              mem_out_bvalid,
    output wire                             mem_out_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          mem_out_arid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    mem_out_araddr,
    output wire [7:0]                       mem_out_arlen,
    output wire [2:0]                       mem_out_arsize,
    output wire [1:0]                       mem_out_arburst,
    output wire                             mem_out_aruser,
    output wire                             mem_out_arvalid,
    input wire                              mem_out_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           mem_out_rid,
    input wire [AXI_DATA_WIDTH-1:0]         mem_out_rdata,
    input wire [1:0]                        mem_out_rresp,
    input wire                              mem_out_rlast,
    input wire                              mem_out_rvalid,
    output wire                             mem_out_rready,

    //Clocking
    input wire  mem_aclk,
    input wire  mem_aresetn,
    
    //The AXI-Lite Control Interface
    //Write Address Channel  
    input wire  [CTRL_AXIL_ADDR_WIDTH-1:0]  ctrl_awaddr,
    input wire                              ctrl_awvalid,
    output reg                              ctrl_awready,
    //Write Data Channel
    input wire  [31:0]                      ctrl_wdata,
    //input wire  [3:0]                       ctrl_wstrb,
    input wire                              ctrl_wvalid,
    output reg                              ctrl_wready,
    //Write Response Channel
    output reg [1:0]                        ctrl_bresp,
    output reg                              ctrl_bvalid,
    input wire                              ctrl_bready,
    //Read Address Channel 
    input wire  [CTRL_AXIL_ADDR_WIDTH-1:0]  ctrl_araddr,
    input wire                              ctrl_arvalid,
    output reg                              ctrl_arready,
    //Read Data Response Channel
    output reg [31:0]                       ctrl_rdata,
    output reg [1:0]                        ctrl_rresp,
    output reg                              ctrl_rvalid,
    input wire                              ctrl_rready,

    //Clocking (for control)
    input wire  ctrl_aclk,
    input wire  ctrl_aresetn
);

    //--------------------------------------------------------//
    //   BRAM Instantiation                                   //
    //--------------------------------------------------------//

    //Parameters
    localparam MMU_BRAM_DEPTH = 2 ** ID_BITS_USED;

    //Address Ranges
    localparam AW_BRAM_BASE_FIRST_WORD = 0;
    localparam AW_BRAM_BASE_LAST_WORD = AW_BRAM_BASE_FIRST_WORD + MMU_BRAM_DEPTH;

    localparam AW_BRAM_LIM_FIRST_WORD = AW_BRAM_BASE_LAST_WORD;
    localparam AW_BRAM_LIM_LAST_WORD = AW_BRAM_LIM_FIRST_WORD + MMU_BRAM_DEPTH;

    localparam AR_BRAM_BASE_FIRST_WORD = AW_BRAM_LIM_LAST_WORD;
    localparam AR_BRAM_BASE_LAST_WORD = AR_BRAM_BASE_FIRST_WORD + MMU_BRAM_DEPTH;

    localparam AR_BRAM_LIM_FIRST_WORD = AR_BRAM_BASE_LAST_WORD;
    localparam AR_BRAM_LIM_LAST_WORD = AR_BRAM_LIM_FIRST_WORD + MMU_BRAM_DEPTH;
    
    //BRAMs inferred
    localparam BASE_RAM_WIDTH = AXI_OUT_ADDR_WIDTH-BASE_ADDR_BITS_UNTOUCHED;
    localparam LIMIT_RAM_WIDTH = AXI_IN_ADDR_WIDTH-LIM_ADDR_BITS_UNTOUCHED;

    reg [BASE_RAM_WIDTH-1:0]  aw_base_ram [MMU_BRAM_DEPTH-1:0];
    reg [LIMIT_RAM_WIDTH-1:0] aw_lim_ram [MMU_BRAM_DEPTH-1:0];  

    reg [BASE_RAM_WIDTH-1:0]  ar_base_ram [MMU_BRAM_DEPTH-1:0];
    reg [LIMIT_RAM_WIDTH-1:0] ar_lim_ram [MMU_BRAM_DEPTH-1:0];  

    //AXI-LITE registered signals
    reg [CTRL_AXIL_ADDR_WIDTH-1:0] ctrl_awaddr_reg;
    reg [CTRL_AXIL_ADDR_WIDTH-1:0] ctrl_araddr_reg;
    
    //awready asserted once valid write request and data available
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) ctrl_awready <= 1'b0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awready <= 1'b1;
        else ctrl_awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) ctrl_awaddr_reg <= 0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awaddr_reg <= ctrl_awaddr; 
    end
    
    //wready asserted once valid write request and data available
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) ctrl_wready <= 1'b0;
        else if (~ctrl_wready && ctrl_wvalid && ctrl_awvalid) ctrl_wready <= 1'b1;
        else ctrl_wready <= 1'b0;
    end

    //write response logic
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) begin
            ctrl_bvalid  <= 1'b0;
            ctrl_bresp   <= 2'b0;
        end else if (ctrl_awready && ctrl_awvalid && ~ctrl_bvalid && ctrl_wready && ctrl_wvalid) begin
            ctrl_bvalid <= 1'b1;
            ctrl_bresp  <= 2'b0; // 'OKAY' response 
        end else if (ctrl_bready && ctrl_bvalid)  begin
            ctrl_bvalid <= 1'b0; 
            ctrl_bresp  <= 2'b0;
        end  
    end
    
    //arready asserted once valid read request available
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) ctrl_arready <= 1'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_arready <= 1'b1;
        else ctrl_arready <= 1'b0;
    end

    //Register araddr value
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) ctrl_araddr_reg  <= 32'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_araddr_reg  <= ctrl_araddr;
    end
    
    //Read response logic  
    always @(posedge ctrl_aclk) begin
        if (~ctrl_aresetn) begin
            ctrl_rvalid <= 1'b0;
            ctrl_rresp  <= 1'b0;
        end else if (ctrl_arready && ctrl_arvalid && ~ctrl_rvalid) begin
            ctrl_rvalid <= 1'b1;
            ctrl_rresp  <= 2'b0; // 'OKAY' response
        end else if (ctrl_rvalid && ctrl_rready) begin
            ctrl_rvalid <= 1'b0;
            ctrl_rresp  <= 2'b0;
        end                
    end

    //Read and write enables
    wire slv_reg_wren = ctrl_wready && ctrl_wvalid && ctrl_awready && ctrl_awvalid;
    wire slv_reg_rden = ctrl_arready & ctrl_arvalid & ~ctrl_rvalid;

    //Segment address signal
    localparam ADDR_LSB = 2;
    localparam ADDR_WIDTH_ALIGNED = CTRL_AXIL_ADDR_WIDTH - ADDR_LSB;

    wire [ADDR_WIDTH_ALIGNED-1:0] wr_addr = ctrl_awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [ADDR_WIDTH_ALIGNED-1:0] rd_addr = ctrl_araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];

    //Write to the LUTRAMs (infer write port)
    always @(posedge ctrl_aclk) begin
        if(slv_reg_wren) begin
            if(wr_addr >= AW_BRAM_BASE_FIRST_WORD && wr_addr < AW_BRAM_BASE_LAST_WORD && INCLUDE_BASE) begin

                aw_base_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:BASE_RAM_WIDTH];

            end else if(wr_addr >= AW_BRAM_LIM_FIRST_WORD && wr_addr < AW_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                aw_lim_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:LIMIT_RAM_WIDTH];

            end else if(wr_addr >= AR_BRAM_BASE_FIRST_WORD && wr_addr < AR_BRAM_BASE_LAST_WORD && INCLUDE_BASE) begin

                ar_base_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:BASE_RAM_WIDTH];

            end else if(wr_addr >= AR_BRAM_LIM_FIRST_WORD && wr_addr < AR_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                ar_lim_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:LIMIT_RAM_WIDTH];

            end 
        end 
    end 

    //Read from LUTRAMs (infer read ports)
    always @(posedge ctrl_aclk) begin
        if(~ctrl_aresetn) ctrl_rdata <= 0;
        else if(slv_reg_rden) begin
            if(rd_addr >= AW_BRAM_BASE_FIRST_WORD && rd_addr < AW_BRAM_BASE_LAST_WORD && INCLUDE_BASE) begin

                ctrl_rdata <= aw_base_ram[ rd_addr[0+:ID_BITS_USED] ];

            end else if(rd_addr >= AW_BRAM_LIM_FIRST_WORD && rd_addr < AW_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                ctrl_rdata <= aw_lim_ram[ rd_addr[0+:ID_BITS_USED] ];

            end else if(rd_addr >= AR_BRAM_BASE_FIRST_WORD && rd_addr < AR_BRAM_BASE_LAST_WORD && INCLUDE_BASE) begin

                ctrl_rdata <= ar_base_ram[ rd_addr[0+:ID_BITS_USED] ];

            end else if(rd_addr >= AR_BRAM_LIM_FIRST_WORD && rd_addr < AR_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                ctrl_rdata <= ar_lim_ram[ rd_addr[0+:ID_BITS_USED] ];

            end 
        end 
    end 



    //--------------------------------------------------------//
    //   AXI Write Address Channel                            //
    //--------------------------------------------------------//
    
    //Registered versions of inputs (need 1 cycle delay, to read memory)
    reg [AXI_IN_ADDR_WIDTH-1:0] reg_awaddr;
    reg [AXI_ID_WIDTH-1:0]      reg_awid;
    reg [1:0]                   reg_awburst;
    reg [2:0]                   reg_awsize;
    reg [7:0]                   reg_awlen;
    reg                         reg_awuser;
    reg                         reg_awvalid;
    wire                        reg_awready;
    
    always @(posedge mem_aclk) begin
        if(~mem_aresetn) begin
            reg_awvalid <= 0;
        end
        else if(mem_in_awvalid && reg_awready) begin
            reg_awaddr <= mem_in_awaddr;
            reg_awid <= mem_in_awid;
            reg_awburst <= mem_in_awburst;
            reg_awsize <= mem_in_awsize;
            reg_awlen <= mem_in_awlen;
            reg_awuser <= mem_in_awuser;
            reg_awvalid <= 1'b1;
        end 
        else if(mem_out_awready) reg_awvalid <= 0;
    end

    assign reg_awready = (mem_out_awready || !reg_awvalid); 
    
    //Obtain address remapping with inferred second port
    reg [BASE_RAM_WIDTH-1:0] aw_base_dout;
    reg [LIMIT_RAM_WIDTH-1:0] aw_lim_dout;

    wire [ID_BITS_USED-1:0] aw_rd_addr = mem_in_awid[AXI_ID_WIDTH-1-IGNORE_ID_MSB-:ID_BITS_USED];
    
    always @(posedge mem_aclk) begin
        if(~mem_aresetn) begin
            aw_base_dout <= 0;
            aw_lim_dout <= 0;
        end 
        else if(mem_in_awvalid && reg_awready) begin
            aw_base_dout <= aw_base_ram[ aw_rd_addr ];
            aw_lim_dout <= aw_lim_ram[ aw_rd_addr ];
        end 
    end
    
    //Assign output values that don't need to be remapped
    assign mem_out_awid = reg_awid;
    assign mem_out_awburst = reg_awburst;
    assign mem_out_awsize = reg_awsize;
    assign mem_out_awlen = reg_awlen;
    assign mem_out_awvalid = reg_awvalid;
    assign mem_in_awready = reg_awready;

    //Calculate remapped address
    wire [BASE_RAM_WIDTH-INCLUDE_ERROR-1:0] aw_base_adder = aw_base_dout[BASE_RAM_WIDTH-INCLUDE_ERROR-1:0];
    wire aw_base_permission = (INCLUDE_ERROR) ? aw_base_dout[BASE_RAM_WIDTH-1] : 0;

    wire [AXI_IN_ADDR_WIDTH:0] remapped_awaddr = reg_awaddr +
        (INCLUDE_BASE ? { aw_base_adder, {BASE_ADDR_BITS_UNTOUCHED{1'b0}} } : 0);

    //Determine whether a limit was reached or we have wrapping
    wire aw_limited = (INCLUDE_LIMIT ? (reg_awaddr[AXI_IN_ADDR_WIDTH-1:LIM_ADDR_BITS_UNTOUCHED] > aw_lim_dout) : 0);
    wire aw_error = aw_limited || reg_awuser || remapped_awaddr[AXI_IN_ADDR_WIDTH] || aw_base_permission;

    //Indicate error on output (if not bypassing remapping)
    assign mem_out_awuser = (IGNORE_ID_MSB && reg_awid[AXI_ID_WIDTH-1] == 1'b1) ?
    	reg_awuser : aw_error;

    assign mem_out_awaddr = (IGNORE_ID_MSB && reg_awid[AXI_ID_WIDTH-1] == 1'b1) ? 
        reg_awaddr : {aw_error, remapped_awaddr[AXI_IN_ADDR_WIDTH-1:0]};

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign mem_out_wdata = mem_in_wdata;
    assign mem_out_wstrb = mem_in_wstrb;
    assign mem_out_wlast = mem_in_wlast;
    assign mem_out_wvalid = mem_in_wvalid;
    assign mem_in_wready = mem_out_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign mem_out_bready = mem_in_bready;
    assign mem_in_bid = mem_out_bid;
    assign mem_in_bresp = mem_out_bresp;
    assign mem_in_bvalid = mem_out_bvalid;
        
    
    
    //--------------------------------------------------------//
    //   AXI Read Address Channel                             //
    //--------------------------------------------------------//
    
    //Registered versions of inputs (need 1 cycle delay, to read memory)
    reg [AXI_IN_ADDR_WIDTH-1:0] reg_araddr;
    reg [AXI_ID_WIDTH-1:0]      reg_arid;
    reg [1:0]                   reg_arburst;
    reg [2:0]                   reg_arsize;
    reg [7:0]                   reg_arlen;
    reg                         reg_aruser;
    reg                         reg_arvalid;
    wire                        reg_arready;
    
    always @(posedge mem_aclk) begin
        if(~mem_aresetn) begin
            reg_arvalid <= 0;
        end
        else if(mem_in_arvalid && reg_arready) begin
            reg_araddr <= mem_in_araddr;
            reg_arid <= mem_in_arid;
            reg_arburst <= mem_in_arburst;
            reg_arsize <= mem_in_arsize;
            reg_arlen <= mem_in_arlen;
            reg_aruser <= mem_in_aruser;
            reg_arvalid <= 1'b1;
        end 
        else if(mem_out_arready) reg_arvalid <= 0;
    end

    assign reg_arready = (mem_out_arready || !reg_arvalid); 
    
    //Obtain address remapping with inferred second port
    reg [BASE_RAM_WIDTH-1:0] ar_base_dout;
    reg [LIMIT_RAM_WIDTH-1:0] ar_lim_dout;

    wire [ID_BITS_USED-1:0] ar_rd_addr = mem_in_arid[AXI_ID_WIDTH-1-IGNORE_ID_MSB-:ID_BITS_USED];
    
    always @(posedge mem_aclk) begin
        if(~mem_aresetn) begin
            ar_base_dout <= 0;
            ar_lim_dout <= 0;
        end 
        else if(mem_in_arvalid && reg_arready) begin
            ar_base_dout <= ar_base_ram[ ar_rd_addr ];
            ar_lim_dout <= ar_lim_ram[ ar_rd_addr ];
        end 
    end
    
    //Assign output values that don't need to be remapped
    assign mem_out_arid = reg_arid;
    assign mem_out_arburst = reg_arburst;
    assign mem_out_arsize = reg_arsize;
    assign mem_out_arlen = reg_arlen;
    assign mem_out_arvalid = reg_arvalid;
    assign mem_in_arready = reg_arready;

    //Calculate remapped address
    wire [BASE_RAM_WIDTH-INCLUDE_ERROR-1:0] ar_base_adder = ar_base_dout[BASE_RAM_WIDTH-INCLUDE_ERROR-1:0];
    wire ar_base_permission = (INCLUDE_ERROR) ? ar_base_dout[BASE_RAM_WIDTH-1] : 0;

    wire [AXI_IN_ADDR_WIDTH:0] remapped_araddr = reg_araddr +
        (INCLUDE_BASE ? { ar_base_adder, {BASE_ADDR_BITS_UNTOUCHED{1'b0}} } : 0);

    //Determine whether a limit was reached or we have wrapping
    wire ar_limited = (INCLUDE_LIMIT ? (reg_araddr[AXI_IN_ADDR_WIDTH-1:LIM_ADDR_BITS_UNTOUCHED] > ar_lim_dout) : 0);
    wire ar_error = ar_limited || reg_aruser || remapped_araddr[AXI_IN_ADDR_WIDTH] || ar_base_permission;

    //Indicate error on output (if not bypassing remapping)
    assign mem_out_aruser = (IGNORE_ID_MSB && reg_arid[AXI_ID_WIDTH-1] == 1'b1) ? 
    	reg_aruser : ar_error;

    assign mem_out_araddr = (IGNORE_ID_MSB && reg_arid[AXI_ID_WIDTH-1] == 1'b1) ? 
        reg_araddr : {ar_error, remapped_araddr[AXI_IN_ADDR_WIDTH-1:0]};
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//

    //Nothing to do, simply forward
    assign mem_out_rready = mem_in_rready;
    assign mem_in_rid = mem_out_rid;
    assign mem_in_rdata = mem_out_rdata;
    assign mem_in_rresp = mem_out_rresp;
    assign mem_in_rlast = mem_out_rlast;
    assign mem_in_rvalid = mem_out_rvalid;



endmodule

`default_nettype wire