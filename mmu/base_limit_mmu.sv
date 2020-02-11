`timescale 1ns / 1ps
`default_nettype none

/*
Base-Limit MMU Module

Author: Daniel Rozhko, PhD Candidate University of Toronto

Description:
   This MMU implements the base-limit remapping methodolgy, whereby
   the incoming address is compared to the limit address to ensure
   it is within the allocated size of the memory region, and then
   the address is added to the base to calculate the remapped address,
   effectively offset within the physical memory. Note, zero widths 
   for any of the signals is not supported.

Parameters:
   AXI_ID_WIDTH - the width of all AXI ID signals
   AXI_IN_ADDR_WIDTH - the width of the input address field
   AXI_DATA_WIDTH - the width of the data path
   INCLUDE_ERROR - binary, indicates to append the error indicator at the MSB of the output address (in order to force the request to an unmapped address)
   INCLUDE_LIMIT - binary, whether the limit check is performed
   IGNORE_ID_MSB - binary, ignores the MSB of the ID fields for the pruposes of remapping, and does not remap when the MSB is equal to 1
                 - useful if a privledged master interface is connected in addition to a power of two number of applications
                 - if the priv. master is connected to the last interface, it will always be the only interface where the MSB is set (e.g. the 5th port with four applications)
   ID_BITS_USED - number of ID bits used to find mapping (number of unique mappings)
   *_BITS_UNTOUCHED - number of bits not modified in remapping, should always be 12 for AXI (default values)
   AXI_OUT_ADDR_WIDTH - the width of the output address field, calculated automatically (use default values only)

AXI-Lite Control Interface Register Space
   For N ID_BITS_USED, and 2**N unique mappings, we have the following memory map (word addressable, x4 for byte addressable systems)
       [0]..[N-1]   --> Write Channel Base Registers
       [N]..[2N-1]  --> Write Channel Limit Registers
       [2N]..[3N-1] --> Read Channel Base Registers
       [3N]..[4N-1] --> Read Channel limit Registers

Ports:
   axi_s_* - the input memory mapped AXI interface
   axi_m_* the output memory mapped AXI interface
   ctrl_* - the AXI-Lite control interface
   aclk - axi clock signal, all interfaces synchronous to this clock
   aresetn - active-low reset, synchronous
*/

module base_limit_mmu
#(
    //AXI4 Interface Params
    parameter AXI_ID_WIDTH = 5,
    parameter AXI_IN_ADDR_WIDTH = 33,
    parameter AXI_DATA_WIDTH = 128,

    //Core Options
    parameter INCLUDE_ERROR = 1, // whether or not error is indicated on addr output
    parameter INCLUDE_LIMIT = 1, // whether or not the limit is checked for out-of-bounds access
    parameter IGNORE_ID_MSB = 1, // whether or not IDs with MSB=1 pass-through with no MMU remapping

    //Core Params
    parameter ID_BITS_USED = 4, // number of ID bits considered for unique mappings
    parameter BASE_ADDR_BITS_UNTOUCHED = 12, //4k boundary crossing or greater needed for proper operation
    parameter LIM_ADDR_BITS_UNTOUCHED = 12, //4k boundary crossing or greater needed for proper operation

    //Values derived from parameters (not to be changed)
    parameter AXI_OUT_ADDR_WIDTH = AXI_IN_ADDR_WIDTH + INCLUDE_ERROR
    //parameter CTRL_AXIL_ADDR_WIDTH = (((ID_BITS_USED + 4) < 12) ? 12 : (ID_BITS_USED + 4))
)
(
    //AXI4 slave connection (input of requests)
    //Write Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_awid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      axi_s_awaddr,
    input wire [7:0]                        axi_s_awlen,
    input wire [2:0]                        axi_s_awsize,
    input wire [1:0]                        axi_s_awburst,
    input wire                              axi_s_awuser, //error indicator
    input wire                              axi_s_awvalid,
    output wire                             axi_s_awready,
    //Write Data Channel
    input wire [AXI_DATA_WIDTH-1:0]         axi_s_wdata,
    input wire [(AXI_DATA_WIDTH/8)-1:0]     axi_s_wstrb,
    input wire                              axi_s_wlast,
    input wire                              axi_s_wvalid,
    output wire                             axi_s_wready,
    //Write Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_bid,
    output wire [1:0]                       axi_s_bresp,
    output wire                             axi_s_bvalid,
    input wire                              axi_s_bready,
    //Read Address Channel     
    input wire [AXI_ID_WIDTH-1:0]           axi_s_arid,
    input wire [AXI_IN_ADDR_WIDTH-1:0]      axi_s_araddr,
    input wire [7:0]                        axi_s_arlen,
    input wire [2:0]                        axi_s_arsize,
    input wire [1:0]                        axi_s_arburst,
    input wire                              axi_s_aruser,
    input wire                              axi_s_arvalid,
    output wire                             axi_s_arready,
    //Read Data Response Channel
    output wire [AXI_ID_WIDTH-1:0]          axi_s_rid,
    output wire [AXI_DATA_WIDTH-1:0]        axi_s_rdata,
    output wire [1:0]                       axi_s_rresp,
    output wire                             axi_s_rlast,
    output wire                             axi_s_rvalid,
    input wire                              axi_s_rready,

    //AXI4 master connection (output of requests)
    //Write Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_awid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    axi_m_awaddr,
    output wire [7:0]                       axi_m_awlen,
    output wire [2:0]                       axi_m_awsize,
    output wire [1:0]                       axi_m_awburst,
    output wire                             axi_m_awuser, //error indicator
    output wire                             axi_m_awvalid,
    input wire                              axi_m_awready,
    //Write Data Channel
    output wire [AXI_DATA_WIDTH-1:0]        axi_m_wdata,
    output wire [(AXI_DATA_WIDTH/8)-1:0]    axi_m_wstrb,
    output wire                             axi_m_wlast,
    output wire                             axi_m_wvalid,
    input wire                              axi_m_wready,
    //Write Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_bid,
    input wire [1:0]                        axi_m_bresp,
    input wire                              axi_m_bvalid,
    output wire                             axi_m_bready,
    //Read Address Channel     
    output wire [AXI_ID_WIDTH-1:0]          axi_m_arid,
    output wire [AXI_OUT_ADDR_WIDTH-1:0]    axi_m_araddr,
    output wire [7:0]                       axi_m_arlen,
    output wire [2:0]                       axi_m_arsize,
    output wire [1:0]                       axi_m_arburst,
    output wire                             axi_m_aruser,
    output wire                             axi_m_arvalid,
    input wire                              axi_m_arready,
    //Read Data Response Channel
    input wire [AXI_ID_WIDTH-1:0]           axi_m_rid,
    input wire [AXI_DATA_WIDTH-1:0]         axi_m_rdata,
    input wire [1:0]                        axi_m_rresp,
    input wire                              axi_m_rlast,
    input wire                              axi_m_rvalid,
    output wire                             axi_m_rready,
    
    //The AXI-Lite Control Interface
    //Write Address Channel  
    input wire  [31:0]                      ctrl_awaddr,
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
    input wire  [31:0]                      ctrl_araddr,
    input wire                              ctrl_arvalid,
    output reg                              ctrl_arready,
    //Read Data Response Channel
    output reg [31:0]                       ctrl_rdata,
    output reg [1:0]                        ctrl_rresp,
    output reg                              ctrl_rvalid,
    input wire                              ctrl_rready,

    //Clocking
    input wire  aclk,
    input wire  aresetn
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
    reg [31:0] ctrl_awaddr_reg;
    reg [31:0] ctrl_araddr_reg;
    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_awready <= 1'b0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awready <= 1'b1;
        else ctrl_awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge aclk) begin
        if (~aresetn) ctrl_awaddr_reg <= 0;
        else if (~ctrl_awready && ctrl_awvalid && ctrl_wvalid) ctrl_awaddr_reg <= ctrl_awaddr; 
    end
    
    //wready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) ctrl_wready <= 1'b0;
        else if (~ctrl_wready && ctrl_wvalid && ctrl_awvalid) ctrl_wready <= 1'b1;
        else ctrl_wready <= 1'b0;
    end

    //write response logic
    always @(posedge aclk) begin
        if (~aresetn) begin
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
    always @(posedge aclk) begin
        if (~aresetn) ctrl_arready <= 1'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_arready <= 1'b1;
        else ctrl_arready <= 1'b0;
    end

    //Register araddr value
    always @(posedge aclk) begin
        if (~aresetn) ctrl_araddr_reg  <= 32'b0;
        else if (~ctrl_arready && ctrl_arvalid) ctrl_araddr_reg  <= ctrl_araddr;
    end
    
    //Read response logic  
    always @(posedge aclk) begin
        if (~aresetn) begin
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
    localparam ADDR_WIDTH_ALIGNED = 32 - ADDR_LSB;

    wire [ADDR_WIDTH_ALIGNED-1:0] wr_addr = ctrl_awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [ADDR_WIDTH_ALIGNED-1:0] rd_addr = ctrl_araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];

    //Write to the LUTRAMs (infer write port)
    always @(posedge aclk) begin
        if(slv_reg_wren) begin
            if(wr_addr >= AW_BRAM_BASE_FIRST_WORD && wr_addr < AW_BRAM_BASE_LAST_WORD) begin

                aw_base_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:BASE_RAM_WIDTH];

            end else if(wr_addr >= AW_BRAM_LIM_FIRST_WORD && wr_addr < AW_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                aw_lim_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:LIMIT_RAM_WIDTH];

            end else if(wr_addr >= AR_BRAM_BASE_FIRST_WORD && wr_addr < AR_BRAM_BASE_LAST_WORD) begin

                ar_base_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:BASE_RAM_WIDTH];

            end else if(wr_addr >= AR_BRAM_LIM_FIRST_WORD && wr_addr < AR_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                ar_lim_ram[ wr_addr[0+:ID_BITS_USED] ] <= ctrl_wdata[0+:LIMIT_RAM_WIDTH];

            end 
        end 
    end 

    //Read from LUTRAMs (infer read ports)
    always @(posedge aclk) begin
        if(~aresetn) ctrl_rdata <= 0;
        else if(slv_reg_rden) begin
            if(rd_addr >= AW_BRAM_BASE_FIRST_WORD && rd_addr < AW_BRAM_BASE_LAST_WORD) begin

                ctrl_rdata <= aw_base_ram[ rd_addr[0+:ID_BITS_USED] ];

            end else if(rd_addr >= AW_BRAM_LIM_FIRST_WORD && rd_addr < AW_BRAM_LIM_LAST_WORD && INCLUDE_LIMIT) begin

                ctrl_rdata <= aw_lim_ram[ rd_addr[0+:ID_BITS_USED] ];

            end else if(rd_addr >= AR_BRAM_BASE_FIRST_WORD && rd_addr < AR_BRAM_BASE_LAST_WORD) begin

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
    
    always @(posedge aclk) begin
        if(~aresetn) begin
            reg_awvalid <= 0;
        end
        else if(axi_s_awvalid && reg_awready) begin
            reg_awaddr <= axi_s_awaddr;
            reg_awid <= axi_s_awid;
            reg_awburst <= axi_s_awburst;
            reg_awsize <= axi_s_awsize;
            reg_awlen <= axi_s_awlen;
            reg_awuser <= axi_s_awuser;
            reg_awvalid <= 1'b1;
        end 
        else if(axi_m_awready) reg_awvalid <= 0;
    end

    assign reg_awready = (axi_m_awready || !reg_awvalid); 
    
    //Obtain address remapping with inferred second port
    reg [BASE_RAM_WIDTH-1:0] aw_base_dout;
    reg [LIMIT_RAM_WIDTH-1:0] aw_lim_dout;

    wire [ID_BITS_USED-1:0] aw_rd_addr = axi_s_awid[AXI_ID_WIDTH-1-IGNORE_ID_MSB-:ID_BITS_USED];
    
    always @(posedge aclk) begin
        if(~aresetn) begin
            aw_base_dout <= 0;
            aw_lim_dout <= 0;
        end 
        else if(axi_s_awvalid && reg_awready) begin
            aw_base_dout <= aw_base_ram[ aw_rd_addr ];
            aw_lim_dout <= aw_lim_ram[ aw_rd_addr ];
        end 
    end
    
    //Assign output values that don't need to be remapped
    assign axi_m_awid = reg_awid;
    assign axi_m_awburst = reg_awburst;
    assign axi_m_awsize = reg_awsize;
    assign axi_m_awlen = reg_awlen;
    assign axi_m_awvalid = reg_awvalid;
    assign axi_s_awready = reg_awready;

    //Calculate remapped address
    wire [BASE_RAM_WIDTH-INCLUDE_ERROR-1:0] aw_base_adder = aw_base_dout[BASE_RAM_WIDTH-INCLUDE_ERROR-1:0];
    wire aw_base_permission = (INCLUDE_ERROR ? aw_base_dout[BASE_RAM_WIDTH-1] : 0);

    wire [AXI_IN_ADDR_WIDTH:0] remapped_awaddr = reg_awaddr + { aw_base_adder, {BASE_ADDR_BITS_UNTOUCHED{1'b0}} };

    //Determine whether a limit was reached or we have wrapping
    wire aw_limited = (INCLUDE_LIMIT ? (reg_awaddr[AXI_IN_ADDR_WIDTH-1:LIM_ADDR_BITS_UNTOUCHED] > aw_lim_dout) : 0);
    wire aw_error = aw_limited || reg_awuser || remapped_awaddr[AXI_IN_ADDR_WIDTH] || aw_base_permission;

    //Indicate error on output (if not bypassing remapping)
    assign axi_m_awuser = ((IGNORE_ID_MSB && reg_awid[AXI_ID_WIDTH-1] == 1'b1) ? reg_awuser : aw_error);

    assign axi_m_awaddr = ((IGNORE_ID_MSB && reg_awid[AXI_ID_WIDTH-1] == 1'b1) ? reg_awaddr : {aw_error, remapped_awaddr[AXI_IN_ADDR_WIDTH-1:0]});

    
    
    //--------------------------------------------------------//
    //   AXI Write Data Channel                               //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign axi_m_wdata = axi_s_wdata;
    assign axi_m_wstrb = axi_s_wstrb;
    assign axi_m_wlast = axi_s_wlast;
    assign axi_m_wvalid = axi_s_wvalid;
    assign axi_s_wready = axi_m_wready;
    
    
    
    //--------------------------------------------------------//
    //   AXI Write Response Channel                           //
    //--------------------------------------------------------//
    
    //Nothing to do, simply forward
    assign axi_m_bready = axi_s_bready;
    assign axi_s_bid = axi_m_bid;
    assign axi_s_bresp = axi_m_bresp;
    assign axi_s_bvalid = axi_m_bvalid;
        
    
    
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
    
    always @(posedge aclk) begin
        if(~aresetn) begin
            reg_arvalid <= 0;
        end
        else if(axi_s_arvalid && reg_arready) begin
            reg_araddr <= axi_s_araddr;
            reg_arid <= axi_s_arid;
            reg_arburst <= axi_s_arburst;
            reg_arsize <= axi_s_arsize;
            reg_arlen <= axi_s_arlen;
            reg_aruser <= axi_s_aruser;
            reg_arvalid <= 1'b1;
        end 
        else if(axi_m_arready) reg_arvalid <= 0;
    end

    assign reg_arready = (axi_m_arready || !reg_arvalid); 
    
    //Obtain address remapping with inferred second port
    reg [BASE_RAM_WIDTH-1:0] ar_base_dout;
    reg [LIMIT_RAM_WIDTH-1:0] ar_lim_dout;

    wire [ID_BITS_USED-1:0] ar_rd_addr = axi_s_arid[AXI_ID_WIDTH-1-IGNORE_ID_MSB-:ID_BITS_USED];
    
    always @(posedge aclk) begin
        if(~aresetn) begin
            ar_base_dout <= 0;
            ar_lim_dout <= 0;
        end 
        else if(axi_s_arvalid && reg_arready) begin
            ar_base_dout <= ar_base_ram[ ar_rd_addr ];
            ar_lim_dout <= ar_lim_ram[ ar_rd_addr ];
        end 
    end
    
    //Assign output values that don't need to be remapped
    assign axi_m_arid = reg_arid;
    assign axi_m_arburst = reg_arburst;
    assign axi_m_arsize = reg_arsize;
    assign axi_m_arlen = reg_arlen;
    assign axi_m_arvalid = reg_arvalid;
    assign axi_s_arready = reg_arready;

    //Calculate remapped address
    wire [BASE_RAM_WIDTH-INCLUDE_ERROR-1:0] ar_base_adder = ar_base_dout[BASE_RAM_WIDTH-INCLUDE_ERROR-1:0];
    wire ar_base_permission = (INCLUDE_ERROR ? ar_base_dout[BASE_RAM_WIDTH-1] : 0);

    wire [AXI_IN_ADDR_WIDTH:0] remapped_araddr = reg_araddr + { ar_base_adder, {BASE_ADDR_BITS_UNTOUCHED{1'b0}} };

    //Determine whether a limit was reached or we have wrapping
    wire ar_limited = (INCLUDE_LIMIT ? (reg_araddr[AXI_IN_ADDR_WIDTH-1:LIM_ADDR_BITS_UNTOUCHED] > ar_lim_dout) : 0);
    wire ar_error = ar_limited || reg_aruser || remapped_araddr[AXI_IN_ADDR_WIDTH] || ar_base_permission;

    //Indicate error on output (if not bypassing remapping)
    assign axi_m_aruser = ((IGNORE_ID_MSB && reg_arid[AXI_ID_WIDTH-1] == 1'b1) ? reg_aruser : ar_error);

    assign axi_m_araddr = ((IGNORE_ID_MSB && reg_arid[AXI_ID_WIDTH-1] == 1'b1) ? reg_araddr : {ar_error, remapped_araddr[AXI_IN_ADDR_WIDTH-1:0]});
    
    
    
    //--------------------------------------------------------//
    //   AXI Read Response Channel                            //
    //--------------------------------------------------------//

    //Nothing to do, simply forward
    assign axi_m_rready = axi_s_rready;
    assign axi_s_rid = axi_m_rid;
    assign axi_s_rdata = axi_m_rdata;
    assign axi_s_rresp = axi_m_rresp;
    assign axi_s_rlast = axi_m_rlast;
    assign axi_s_rvalid = axi_m_rvalid;



endmodule

`default_nettype wire