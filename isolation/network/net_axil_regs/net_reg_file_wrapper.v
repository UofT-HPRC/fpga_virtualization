`timescale 1ns / 1ps
`default_nettype none


//Number of masters
`define NUM_MASTERS 4
`define INC_M1
`define INC_M2
`define INC_M3
`define INC_M4
//`define INC_M5
//`define INC_M6
//`define INC_M7
//`define INC_M8

module net_reg_file_wrapper
#(
    //AXIL Params
    parameter AXIL_ADDR_WIDTH = 7,

    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam BW_THROT_BITS_PER_MAST = (TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH + 1),
    localparam BW_THROT_REG_WIDTH =  BW_THROT_BITS_PER_MAST * `NUM_MASTERS
)
(
    //The AXI-Lite interface
    input wire  [AXIL_ADDR_WIDTH-1:0]  awaddr,
    input wire                         awvalid,
    output reg                         awready,
    
    input wire  [31:0]                 wdata,
    //input wire  [3:0]                  wstrb,
    input wire                         wvalid,
    output reg                         wready,

    output reg [1:0]                   bresp,
    output reg                         bvalid,
    input wire                         bready,
    
    input wire  [AXIL_ADDR_WIDTH-1:0]  araddr,
    input wire                         arvalid,
    output reg                         arready,

    output reg [31:0]                  rdata,
    output reg [1:0]                   rresp,
    output reg                         rvalid,
    input wire                         rready,
    
    `ifdef INC_M1
    //Signals to/from decoupler
    output wire         decouple_1,
    input wire          decouple_done_1,
    input wire [1:0]    decouple_status_1,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_1,
    output wire         oversize_error_clear_1,
    input wire          timeout_error_1,
    input wire          oversize_error_1,
    `endif 
    `ifdef INC_M2
    //Signals to/from decoupler
    output wire         decouple_2,
    input wire          decouple_done_2,
    input wire [1:0]    decouple_status_2,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_2,
    output wire         oversize_error_clear_2,
    input wire          timeout_error_2,
    input wire          oversize_error_2,
    `endif 
    `ifdef INC_M3
    //Signals to/from decoupler
    output wire         decouple_3,
    input wire          decouple_done_3,
    input wire [1:0]    decouple_status_3,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_3,
    output wire         oversize_error_clear_3,
    input wire          timeout_error_3,
    input wire          oversize_error_3,
    `endif 
    `ifdef INC_M4
    //Signals to/from decoupler
    output wire         decouple_4,
    input wire          decouple_done_4,
    input wire [1:0]    decouple_status_4,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_4,
    output wire         oversize_error_clear_4,
    input wire          timeout_error_4,
    input wire          oversize_error_4,
    `endif 
    `ifdef INC_M5
    //Signals to/from decoupler
    output wire         decouple_5,
    input wire          decouple_done_5,
    input wire [1:0]    decouple_status_5,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_5,
    output wire         oversize_error_clear_5,
    input wire          timeout_error_5,
    input wire          oversize_error_5,
    `endif 
    `ifdef INC_M6
    //Signals to/from decoupler
    output wire         decouple_6,
    input wire          decouple_done_6,
    input wire [1:0]    decouple_status_6,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_6,
    output wire         oversize_error_clear_6,
    input wire          timeout_error_6,
    input wire          oversize_error_6,
    `endif 
    `ifdef INC_M7
    //Signals to/from decoupler
    output wire         decouple_7,
    input wire          decouple_done_7,
    input wire [1:0]    decouple_status_7,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_7,
    output wire         oversize_error_clear_7,
    input wire          timeout_error_7,
    input wire          oversize_error_7,
    `endif 
    `ifdef INC_M8
    //Signals to/from decoupler
    output wire         decouple_8,
    input wire          decouple_done_8,
    input wire [1:0]    decouple_status_8,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_8,
    output wire         oversize_error_clear_8,
    input wire          timeout_error_8,
    input wire          oversize_error_8,
    `endif


    //Signals to/from BW throttlers
    output wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*`NUM_MASTERS)-1:0]     
                        bw_throt_regs,

    //Clocking
    input wire aclk,
    input wire aresetn
);

    //--------------------------------------------------------//
    //  Create register value                                 //
    //--------------------------------------------------------//

    //Outputs
    reg [`NUM_MASTERS-1:0] decouple;
    reg [`NUM_MASTERS-1:0] timeout_error_clear;
    reg [`NUM_MASTERS-1:0] oversize_error_clear;

    //Inputs
    wire [`NUM_MASTERS-1:0] decouple_done;
    wire [(2*`NUM_MASTERS)-1:0] decouple_status;
    wire [`NUM_MASTERS-1:0] timeout_error;
    wire [`NUM_MASTERS-1:0] oversize_error;

    //Assign values
    `ifdef INC_M1
    assign decouple_1 = decouple[0];
    assign timeout_error_clear_1 = timeout_error_clear[0];
    assign oversize_error_clear_1 = oversize_error_clear[0];

    assign decouple_done[0] = decouple_done_1;
    assign decouple_status[(0*2)+:2] = decouple_status_1;
    assign timeout_error[0] = timeout_error_1;
    assign oversize_error[0] = oversize_error_1;
    `endif
    `ifdef INC_M2
    assign decouple_2 = decouple[1];
    assign timeout_error_clear_2 = timeout_error_clear[1];
    assign oversize_error_clear_2 = oversize_error_clear[1];

    assign decouple_done[1] = decouple_done_2;
    assign decouple_status[(1*2)+:2] = decouple_status_2;
    assign timeout_error[1] = timeout_error_2;
    assign oversize_error[1] = oversize_error_2;
    `endif
    `ifdef INC_M3
    assign decouple_3 = decouple[2];
    assign timeout_error_clear_3 = timeout_error_clear[2];
    assign oversize_error_clear_3 = oversize_error_clear[2];

    assign decouple_done[2] = decouple_done_3;
    assign decouple_status[(2*2)+:2] = decouple_status_3;
    assign timeout_error[2] = timeout_error_3;
    assign oversize_error[2] = oversize_error_3;
    `endif
    `ifdef INC_M4
    assign decouple_4 = decouple[3];
    assign timeout_error_clear_4 = timeout_error_clear[3];
    assign oversize_error_clear_4 = oversize_error_clear[3];

    assign decouple_done[3] = decouple_done_4;
    assign decouple_status[(3*2)+:2] = decouple_status_4;
    assign timeout_error[3] = timeout_error_4;
    assign oversize_error[3] = oversize_error_4;
    `endif
    `ifdef INC_M5
    assign decouple_5 = decouple[4];
    assign timeout_error_clear_5 = timeout_error_clear[4];
    assign oversize_error_clear_5 = oversize_error_clear[4];

    assign decouple_done[4] = decouple_done_5;
    assign decouple_status[(4*2)+:2] = decouple_status_5;
    assign timeout_error[4] = timeout_error_5;
    assign oversize_error[4] = oversize_error_5;
    `endif
    `ifdef INC_M6
    assign decouple_6 = decouple[5];
    assign timeout_error_clear_6 = timeout_error_clear[5];
    assign oversize_error_clear_6 = oversize_error_clear[5];

    assign decouple_done[5] = decouple_done_6;
    assign decouple_status[(5*2)+:2] = decouple_status_6;
    assign timeout_error[5] = timeout_error_6;
    assign oversize_error[5] = oversize_error_6;
    `endif
    `ifdef INC_M7
    assign decouple_7 = decouple[6];
    assign timeout_error_clear_7 = timeout_error_clear[6];
    assign oversize_error_clear_7 = oversize_error_clear[6];

    assign decouple_done[6] = decouple_done_7;
    assign decouple_status[(6*2)+:2] = decouple_status_7;
    assign timeout_error[6] = timeout_error_7;
    assign oversize_error[6] = oversize_error_7;
    `endif
    `ifdef INC_M8
    assign decouple_8 = decouple[7];
    assign timeout_error_clear_8 = timeout_error_clear[7];
    assign oversize_error_clear_8 = oversize_error_clear[7];

    assign decouple_done[7] = decouple_done_8;
    assign decouple_status[(7*2)+:2] = decouple_status_8;
    assign timeout_error[7] = timeout_error_8;
    assign oversize_error[7] = oversize_error_8;
    `endif

    //BW throttler outputs
    reg [TOKEN_COUNT_INT_WIDTH-1:0]  init_token [`NUM_MASTERS-1:0];
    reg [TOKEN_COUNT_FRAC_WIDTH:0]   upd_token [`NUM_MASTERS-1:0];

    genvar j;
    generate for(j = 0; j < `NUM_MASTERS; j = j + 1) begin : reg_pack

        assign bw_throt_regs[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST] 
            = {upd_token[j],init_token[j]};

    end endgenerate



    //--------------------------------------------------------//
    //  Parameters for register addresses in AXIL space       //
    //--------------------------------------------------------//

    //Params for register locations
    localparam INIT_FIRST_WORD = 0;
    localparam INIT_LAST_WORD = `NUM_MASTERS;

    localparam UPD_FIRST_WORD = INIT_LAST_WORD;
    localparam UPD_LAST_WORD = UPD_FIRST_WORD + `NUM_MASTERS;

    localparam DEC_STAT_ADDR= UPD_LAST_WORD;

    localparam DEC_DO_ADDR = DEC_STAT_ADDR + 1;

    localparam DEC_DONE_ADDR = DEC_DO_ADDR + 1;

    localparam TIME_ERR_ADDR = DEC_DONE_ADDR + 1;

    localparam TIME_CLR_ADDR = TIME_ERR_ADDR + 1;

    localparam OVS_ERR_ADDR = TIME_CLR_ADDR + 1;

    localparam OVS_CLR_ADDR = OVS_ERR_ADDR + 1;

    
    
    //--------------------------------------------------------//
    //  AXI-Lite protocol implementation                      //
    //--------------------------------------------------------//
    
    //AXI-LITE registered signals
    reg [AXIL_ADDR_WIDTH-1:0]       awaddr_reg;
    reg [AXIL_ADDR_WIDTH-1:0]       araddr_reg;
    reg [31:0]                      reg_data_out;
    
    //awready asserted once valid write request and data available
    always @(posedge aclk) begin
        if (~aresetn) awready <= 1'b0;
        else if (~awready && awvalid && wvalid) awready <= 1'b1;
        else awready <= 1'b0;
    end 
    
    //Register awaddr value
    always @(posedge aclk) begin
        if (~aresetn) awaddr_reg <= 0;
        else if (~awready && awvalid && wvalid) awaddr_reg <= awaddr; 
    end
    
    //wready asserted once valid write request and data availavle
    always @(posedge aclk) begin
        if (~aresetn) wready <= 1'b0;
        else if (~wready && wvalid && awvalid) wready <= 1'b1;
        else wready <= 1'b0;
    end

    //write response logic
    always @(posedge aclk) begin
        if (~aresetn) begin
            bvalid  <= 1'b0;
            bresp   <= 2'b0;
        end else if (awready && awvalid && ~bvalid && wready && wvalid) begin
            bvalid <= 1'b1;
            bresp  <= 2'b0; // 'OKAY' response 
        end else if (bready && bvalid)  begin
            bvalid <= 1'b0; 
            bresp  <= 2'b0;
        end  
    end
    
    //arready asserted once valid read request available
    always @(posedge aclk) begin
        if (~aresetn) arready <= 1'b0;
        else if (~arready && arvalid) arready <= 1'b1;
        else arready <= 1'b0;
    end

    //Register araddr value
    always @(posedge aclk) begin
        if (~aresetn) araddr_reg  <= 32'b0;
        else if (~arready && arvalid) araddr_reg  <= araddr;
    end
    
    //Read response logic  
    always @(posedge aclk) begin
        if (~aresetn) begin
            rvalid <= 1'b0;
            rresp  <= 1'b0;
        end else if (arready && arvalid && ~rvalid) begin
            rvalid <= 1'b1;
            rresp  <= 2'b0; // 'OKAY' response
        end else if (rvalid && rready) begin
            rvalid <= 1'b0;
            rresp  <= 2'b0;
        end                
    end

    //Read and write enables
    wire slv_reg_wren = wready && wvalid && awready && awvalid;
    wire slv_reg_rden = arready & arvalid & ~rvalid;

    //register the output rdata
    always @(posedge aclk) begin
        if (~aresetn) rdata  <= 0;
        else if (slv_reg_rden) rdata <= reg_data_out;
    end



    //--------------------------------------------------------//
    //  Write Functionality                                   //
    //--------------------------------------------------------//
    
    //Segment address signal
    localparam ADDR_LSB = 2;
    localparam ADDR_WIDTH_ALIGNED = AXIL_ADDR_WIDTH - ADDR_LSB;
    localparam SEL_WIDTH = $clog2(`NUM_MASTERS);

    wire [ADDR_WIDTH_ALIGNED-1:0]   wr_addr = awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [SEL_WIDTH-1:0]            wr_sel = awaddr_reg[ADDR_LSB+:SEL_WIDTH];

    //Loop vars
    integer i;

    //Write to the registers/RAMs
    //NOTE - ignores wstrb 
    always @(posedge aclk) begin

        //clear back to zero
        timeout_error_clear <= 0;
        oversize_error_clear <= 0;

        if(~aresetn) begin

            decouple <= 0;
            timeout_error_clear <= 0;
            oversize_error_clear <= 0;

            for(i = 0; i < `NUM_MASTERS; i = i + 1) begin

                init_token[i] <= 0;
                upd_token[i] <= 0;

            end 
        
        end else if(slv_reg_wren) begin

            //Check for group regions
            if(wr_addr >= INIT_FIRST_WORD && wr_addr < INIT_LAST_WORD) begin

                init_token[wr_sel] <= wdata[0+:TOKEN_COUNT_INT_WIDTH];

            end 
            else if(wr_addr >= UPD_FIRST_WORD && wr_addr < UPD_LAST_WORD) begin

                upd_token[wr_sel] <= wdata[0+:TOKEN_COUNT_FRAC_WIDTH+1];

            end 
            /*if(wr_addr == DEC_STAT_ADDR) begin

                decouple_status <= wdata[0+:`NUM_MASTERS*2]; //Not writeable

            end*/ //Not writeable
            else if(wr_addr == DEC_DO_ADDR) begin

                decouple <= wdata[0+:`NUM_MASTERS];

            end
            /*else if(wr_addr == DEC_DONE_ADDR) begin

                decouple_done <= wdata[0+:`NUM_MASTERS]; //Not writeable

            end*/ //Not writeable
            /*else if(wr_addr == TIME_ERR_ADDR) begin

                timeout_error <= wdata[0+:`NUM_MASTERS]; //Not writeable

            end*/ //Not writeable
            else if(wr_addr == TIME_CLR_ADDR) begin

                timeout_error_clear <= wdata[0+:`NUM_MASTERS];

            end
            /*else if(wr_addr == OVS_ERR_ADDR) begin

                oversize_error <= wdata[0+:`NUM_MASTERS]; //Not writeable

            end*/ //Not writeable
            else if(wr_addr == OVS_CLR_ADDR) begin

                oversize_error_clear <= wdata[0+:`NUM_MASTERS];

            end
           
        end

    end 


    
    //--------------------------------------------------------//
    //  Read Functionality                                    //
    //--------------------------------------------------------//

    //Segment address signal
    wire [ADDR_WIDTH_ALIGNED-1:0]   rd_addr = araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [SEL_WIDTH-1:0]            rd_sel = araddr_reg[ADDR_LSB+:SEL_WIDTH];

    //Read from the registers/RAMs
    always @(*) begin

        //Defualt assignment
        reg_data_out = 0;

        //Check for group regions
        if(rd_addr >= INIT_FIRST_WORD && rd_addr < INIT_LAST_WORD) begin

            reg_data_out = init_token[rd_sel];

        end 
        else if(rd_addr >= UPD_FIRST_WORD && rd_addr < UPD_LAST_WORD) begin

            reg_data_out = upd_token[rd_sel];

        end 
        else if(rd_addr >= DEC_STAT_ADDR) begin

            reg_data_out = decouple_status;

        end 
        else if(rd_addr == DEC_DO_ADDR) begin

            reg_data_out = decouple;

        end
        else if(rd_addr == DEC_DONE_ADDR) begin

            reg_data_out = decouple_done;

        end
        else if(rd_addr == TIME_ERR_ADDR) begin

            reg_data_out = timeout_error;

        end
        /*else if(rd_addr == TIME_CLR_ADDR) begin

            reg_data_out = timeout_error_clear;

        end*/ //Not readable
        else if(rd_addr == OVS_ERR_ADDR) begin

            reg_data_out = oversize_error;

        end
        /*else if(rd_addr == OVS_CLR_ADDR) begin

            reg_data_out = oversize_error_clear;

        end*/ //Not readable

    end 
    


endmodule

`default_nettype wire