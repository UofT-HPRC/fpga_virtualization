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

//Number of efective mem channels
`define NUM_CHAN 1
`define INC_C1
//`define INC_C2
//`define INC_C3
//`define INC_C4

module mem_reg_file_wrapper
#(
    //AXIL Params
    parameter AXIL_ADDR_WIDTH = 10,

    //Token counter params
    parameter TOKEN_COUNT_INT_WIDTH = 16,
    parameter TOKEN_COUNT_FRAC_WIDTH = 8,
    localparam BW_THROT_BITS_PER_MAST = (TOKEN_COUNT_INT_WIDTH + TOKEN_COUNT_FRAC_WIDTH + 1) * 2,
    localparam BW_THROT_REG_WIDTH =  BW_THROT_BITS_PER_MAST * `NUM_MASTERS,

    //Utilization counter precisions
    parameter UTIL_COUNT_WIDTH = 10
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
    input wire [4:0]    decouple_status_1,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_1,
    input wire [2:0]    timeout_status_1,
    `endif 
    `ifdef INC_M2
    //Signals to/from decoupler
    output wire         decouple_2,
    input wire          decouple_done_2,
    input wire [4:0]    decouple_status_2,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_2,
    input wire [2:0]    timeout_status_2,
    `endif 
    `ifdef INC_M3
    //Signals to/from decoupler
    output wire         decouple_3,
    input wire          decouple_done_3,
    input wire [4:0]    decouple_status_3,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_3,
    input wire [2:0]    timeout_status_3,
    `endif 
    `ifdef INC_M4
    //Signals to/from decoupler
    output wire         decouple_4,
    input wire          decouple_done_4,
    input wire [4:0]    decouple_status_4,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_4,
    input wire [2:0]    timeout_status_4,
    `endif 
    `ifdef INC_M5
    //Signals to/from decoupler
    output wire         decouple_5,
    input wire          decouple_done_5,
    input wire [4:0]    decouple_status_5,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_5,
    input wire [2:0]    timeout_status_5,
    `endif 
    `ifdef INC_M6
    //Signals to/from decoupler
    output wire         decouple_6,
    input wire          decouple_done_6,
    input wire [4:0]    decouple_status_6,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_6,
    input wire [2:0]    timeout_status_6,
    `endif 
    `ifdef INC_M7
    //Signals to/from decoupler
    output wire         decouple_7,
    input wire          decouple_done_7,
    input wire [4:0]    decouple_status_7,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_7,
    input wire [2:0]    timeout_status_7,
    `endif 
    `ifdef INC_M8
    //Signals to/from decoupler
    output wire         decouple_8,
    input wire          decouple_done_8,
    input wire [4:0]    decouple_status_8,

    //Signals to/from prot_handler
    output wire         timeout_error_clear_8,
    input wire [2:0]    timeout_status_8,
    `endif


    `ifdef INC_C1
    //Signal from utilization monitor
    input wire [UTIL_COUNT_WIDTH:0] utilization1,

    //Signals to/from BW throttlers
    output wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*2*`NUM_MASTERS)-1:0]     
                                    bw_throt_regs1,
    `endif
    `ifdef INC_C2
    //Signal from utilization monitor
    input wire [UTIL_COUNT_WIDTH:0] utilization2,

    //Signals to/from BW throttlers
    output wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*2*`NUM_MASTERS)-1:0]     
                                    bw_throt_regs2,
    `endif
    `ifdef INC_C3
    //Signal from utilization monitor
    input wire [UTIL_COUNT_WIDTH:0] utilization3,

    //Signals to/from BW throttlers
    output wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*2*`NUM_MASTERS)-1:0]     
                                    bw_throt_regs3,
    `endif
    `ifdef INC_C4
    //Signal from utilization monitor
    input wire [UTIL_COUNT_WIDTH:0] utilization4,

    //Signals to/from BW throttlers
    output wire [((TOKEN_COUNT_INT_WIDTH+TOKEN_COUNT_FRAC_WIDTH+1)*2*`NUM_MASTERS)-1:0]     
                                    bw_throt_regs4,
    `endif


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

    //Inputs
    wire [`NUM_MASTERS-1:0] decouple_done;
    wire [(5*`NUM_MASTERS)-1:0] decouple_status;
    wire [(3*`NUM_MASTERS)-1:0] timeout_status;

    //Assign values
    `ifdef INC_M1
    assign decouple_1 = decouple[0];
    assign timeout_error_clear_1 = timeout_error_clear[0];

    assign decouple_done[0] = decouple_done_1;
    assign decouple_status[(0*5)+:5] = decouple_status_1;
    assign timeout_status[(0*3)+:3] = timeout_status_1;
    `endif
    `ifdef INC_M2
    assign decouple_2 = decouple[1];
    assign timeout_error_clear_2 = timeout_error_clear[1];

    assign decouple_done[1] = decouple_done_2;
    assign decouple_status[(1*5)+:5] = decouple_status_2;
    assign timeout_status[(1*3)+:3] = timeout_status_2;
    `endif
    `ifdef INC_M3
    assign decouple_3 = decouple[2];
    assign timeout_error_clear_3 = timeout_error_clear[2];

    assign decouple_done[2] = decouple_done_3;
    assign decouple_status[(2*5)+:5] = decouple_status_3;
    assign timeout_status[(2*3)+:3] = timeout_status_3;
    `endif
    `ifdef INC_M4
    assign decouple_4 = decouple[3];
    assign timeout_error_clear_4 = timeout_error_clear[3];

    assign decouple_done[3] = decouple_done_4;
    assign decouple_status[(3*5)+:5] = decouple_status_4;
    assign timeout_status[(3*3)+:3] = timeout_status_4;
    `endif
    `ifdef INC_M5
    assign decouple_5 = decouple[4];
    assign timeout_error_clear_5 = timeout_error_clear[4];

    assign decouple_done[4] = decouple_done_5;
    assign decouple_status[(4*5)+:5] = decouple_status_5;
    assign timeout_status[(4*3)+:3] = timeout_status_5;
    `endif
    `ifdef INC_M6
    assign decouple_6 = decouple[5];
    assign timeout_error_clear_6 = timeout_error_clear[5];

    assign decouple_done[5] = decouple_done_6;
    assign decouple_status[(5*5)+:5] = decouple_status_6;
    assign timeout_status[(5*3)+:3] = timeout_status_6;
    `endif
    `ifdef INC_M7
    assign decouple_7 = decouple[6];
    assign timeout_error_clear_7 = timeout_error_clear[6];

    assign decouple_done[6] = decouple_done_7;
    assign decouple_status[(6*5)+:5] = decouple_status_7;
    assign timeout_status[(6*3)+:3] = timeout_status_7;
    `endif
    `ifdef INC_M8
    assign decouple_8 = decouple[7];
    assign timeout_error_clear_8 = timeout_error_clear[7];

    assign decouple_done[7] = decouple_done_8;
    assign decouple_status[(7*5)+:5] = decouple_status_8;
    assign timeout_status[(7*3)+:3] = timeout_status_8;
    `endif

    //BW throttler outputs
    reg [TOKEN_COUNT_INT_WIDTH-1:0]  aw_init_token [(`NUM_MASTERS*`NUM_CHAN)-1:0];
    reg [TOKEN_COUNT_FRAC_WIDTH:0]   aw_upd_token [(`NUM_MASTERS*`NUM_CHAN)-1:0];

    reg [TOKEN_COUNT_INT_WIDTH-1:0]  ar_init_token [(`NUM_MASTERS*`NUM_CHAN)-1:0];
    reg [TOKEN_COUNT_FRAC_WIDTH:0]   ar_upd_token [(`NUM_MASTERS*`NUM_CHAN)-1:0];

    genvar j;
    generate for(j = 0; j < `NUM_MASTERS; j = j + 1) begin : reg_pack

        `ifdef INC_C1
        assign bw_throt_regs1[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST] 
            = { ar_upd_token[(0*`NUM_MASTERS)+j],ar_init_token[(0*`NUM_MASTERS)+j],
                aw_upd_token[(0*`NUM_MASTERS)+j],aw_init_token[(0*`NUM_MASTERS)+j]};
        `endif
        `ifdef INC_C2
        assign bw_throt_regs2[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST] 
            = { ar_upd_token[(1*`NUM_MASTERS)+j],ar_init_token[(1*`NUM_MASTERS)+j],
                aw_upd_token[(1*`NUM_MASTERS)+j],aw_init_token[(1*`NUM_MASTERS)+j]};
        `endif
        `ifdef INC_C3
        assign bw_throt_regs3[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST] 
            = { ar_upd_token[(2*`NUM_MASTERS)+j],ar_init_token[(2*`NUM_MASTERS)+j],
                aw_upd_token[(2*`NUM_MASTERS)+j],aw_init_token[(2*`NUM_MASTERS)+j]};
        `endif
        `ifdef INC_C4
        assign bw_throt_regs4[(j*BW_THROT_BITS_PER_MAST)+:BW_THROT_BITS_PER_MAST] 
            = { ar_upd_token[(3*`NUM_MASTERS)+j],ar_init_token[(3*`NUM_MASTERS)+j],
                aw_upd_token[(3*`NUM_MASTERS)+j],aw_init_token[(3*`NUM_MASTERS)+j]};
        `endif

    end endgenerate



    //--------------------------------------------------------//
    //  Parameters for register addresses in AXIL space       //
    //--------------------------------------------------------//

    //Align address boundary to power of 2
    localparam NUM_BW_REGS = 2 ** $clog2(`NUM_MASTERS*`NUM_CHAN);

    //Params for register locations
    localparam AW_INIT_FIRST_WORD = 0;
    localparam AW_INIT_LAST_WORD = NUM_BW_REGS;

    localparam AR_INIT_FIRST_WORD = AW_INIT_LAST_WORD;
    localparam AR_INIT_LAST_WORD = AR_INIT_FIRST_WORD + NUM_BW_REGS;

    localparam AW_UPD_FIRST_WORD = AR_INIT_LAST_WORD;
    localparam AW_UPD_LAST_WORD = AW_UPD_FIRST_WORD + NUM_BW_REGS;

    localparam AR_UPD_FIRST_WORD = AW_UPD_LAST_WORD;
    localparam AR_UPD_LAST_WORD = AR_UPD_FIRST_WORD + NUM_BW_REGS;

    localparam DEC_STAT_FIRST_WORD = AR_UPD_LAST_WORD;
    localparam DEC_STAT_LAST_WORD = DEC_STAT_FIRST_WORD + 1;

    localparam DEC_DO_ADDR = DEC_STAT_LAST_WORD;

    localparam DEC_DONE_ADDR = DEC_DO_ADDR + 1;

    localparam TIME_STAT_ADDR = DEC_DONE_ADDR + 1;

    localparam TIME_CLR_ADDR = TIME_STAT_ADDR + 1;

    localparam UTIL1_ADDR = TIME_CLR_ADDR + 1;

    localparam UTIL2_ADDR = UTIL1_ADDR + 1;

    localparam UTIL3_ADDR = UTIL2_ADDR + 1;

    localparam UTIL4_ADDR = UTIL3_ADDR + 1;

    
    
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
    localparam SEL_WIDTH = $clog2(`NUM_MASTERS*`NUM_CHAN);

    wire [ADDR_WIDTH_ALIGNED-1:0]   wr_addr = awaddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [SEL_WIDTH-1:0]            wr_sel = awaddr_reg[2+:SEL_WIDTH];

    //Loop vars
    integer i;

    //Write to the registers/RAMs
    //NOTE - ignores wstrb 
    always @(posedge aclk) begin

        //clear back to zero
        timeout_error_clear <= 0;

        if(~aresetn) begin

            decouple <= 0;
            timeout_error_clear <= 0;

            for(i = 0; i < `NUM_MASTERS; i = i + 1) begin

                aw_init_token[i] <= 0;
                ar_init_token[i] <= 0;
                aw_upd_token[i] <= 0;
                ar_upd_token[i] <= 0;

            end 
        
        end else if(slv_reg_wren) begin

            //Check for group regions
            if(wr_addr >= AW_INIT_FIRST_WORD && wr_addr < AW_INIT_LAST_WORD) begin

                aw_init_token[wr_sel] <= wdata[0+:TOKEN_COUNT_INT_WIDTH];

            end 
            else if(wr_addr >= AR_INIT_FIRST_WORD && wr_addr < AR_INIT_LAST_WORD) begin

                ar_init_token[wr_sel] <= wdata[0+:TOKEN_COUNT_INT_WIDTH];

            end 
            else if(wr_addr >= AW_UPD_FIRST_WORD && wr_addr < AW_UPD_LAST_WORD) begin

                aw_upd_token[wr_sel] <= wdata[0+:TOKEN_COUNT_FRAC_WIDTH+1];

            end 
            else if(wr_addr >= AR_UPD_FIRST_WORD && wr_addr < AR_UPD_LAST_WORD) begin

                ar_upd_token[wr_sel] <= wdata[0+:TOKEN_COUNT_FRAC_WIDTH+1];

            end 
            /*else if(wr_addr >= DEC_STAT_FIRST_WORD && wr_addr < DEC_STAT_LAST_WORD) begin

                if(`NUM_MASTERS <= 6) begin
                    if(wr_addr[0] == 1'b0) decouple_status <= wdata[0+:`NUM_MASTERS*5];
                end else begin
                    if(wr_addr[0] == 1'b0) decouple_status[31:0] <= wdata;
                    else decouple_status[32+:(`NUM_MASTERS*5 -32)] <= wdata[0+:(`NUM_MASTERS*5 -32)];
                end

            end*/ //Not writeable
            else if(wr_addr == DEC_DO_ADDR) begin

                decouple <= wdata[0+:`NUM_MASTERS];

            end
            /*else if(wr_addr == DEC_DONE_ADDR) begin

                decouple_done <= wdata[0+:`NUM_MASTERS];

            end*/ //Not writeable
            /*else if(wr_addr == TIME_STAT_ADDR) begin

                timeout_status <= wdata[0+:`NUM_MASTERS*3];

            end*/ //Not writeable
            else if(wr_addr == TIME_CLR_ADDR) begin

                timeout_error_clear <= wdata[0+:`NUM_MASTERS];

            end
            /*else if(wr_addr == UTIL1_ADDR) begin
                `ifdef INC_C1
                utilization1 <= wdata[0+:UTIL_COUNT_WIDTH];
                `endif
            end*/ //Not writeable
            /*else if(wr_addr == UTIL2_ADDR) begin
                `ifdef INC_C2
                utilization2 <= wdata[0+:UTIL_COUNT_WIDTH];
                `endif
            end*/ //Not writeable
            /*else if(wr_addr == UTIL3_ADDR) begin
                `ifdef INC_C3
                utilization3 <= wdata[0+:UTIL_COUNT_WIDTH];
                `endif
            end*/ //Not writeable
            /*else if(wr_addr == UTIL4_ADDR) begin
                `ifdef INC_C4
                utilization4 <= wdata[0+:UTIL_COUNT_WIDTH];
                `endif
            end*/ //Not writeable
           
        end

    end 


    
    //--------------------------------------------------------//
    //  Read Functionality                                    //
    //--------------------------------------------------------//

    //Segment address signal
    wire [ADDR_WIDTH_ALIGNED-1:0]   rd_addr = araddr_reg[ADDR_LSB+:ADDR_WIDTH_ALIGNED];
    wire [SEL_WIDTH-1:0]            rd_sel = araddr_reg[2+:SEL_WIDTH];

    //Read from the registers/RAMs
    always @(*) begin

        //Defualt assignment
        reg_data_out = 0;

        //Check for group regions
        if(rd_addr >= AW_INIT_FIRST_WORD && rd_addr < AW_INIT_LAST_WORD) begin

            reg_data_out = aw_init_token[rd_sel];

        end 
        else if(rd_addr >= AR_INIT_FIRST_WORD && rd_addr < AR_INIT_LAST_WORD) begin

            reg_data_out = ar_init_token[rd_sel];

        end 
        else if(rd_addr >= AW_UPD_FIRST_WORD && rd_addr < AW_UPD_LAST_WORD) begin

            reg_data_out = aw_upd_token[rd_sel];

        end 
        else if(rd_addr >= AR_UPD_FIRST_WORD && rd_addr < AR_UPD_LAST_WORD) begin

            reg_data_out = ar_upd_token[rd_sel];

        end 
        else if(rd_addr >= DEC_STAT_FIRST_WORD && rd_addr < DEC_STAT_LAST_WORD) begin

            `ifdef INC_M7
                if(rd_addr[0] == 1'b0) reg_data_out = decouple_status[31:0];
                else reg_data_out = decouple_status[(`NUM_MASTERS*5)-1:32];
            `else 
                if(rd_addr[0] == 1'b0) reg_data_out = decouple_status;
            `endif
            
        end 
        else if(rd_addr == DEC_DO_ADDR) begin

            reg_data_out = decouple;

        end
        else if(rd_addr == DEC_DONE_ADDR) begin

            reg_data_out = decouple_done;

        end
        else if(rd_addr == TIME_STAT_ADDR) begin

            reg_data_out = timeout_status;

        end
        /*else if(rd_addr == TIME_CLR_ADDR) begin

            reg_data_out = timeout_error_clear;

        end*/ //Not readable
        else if(rd_addr == UTIL1_ADDR) begin
            `ifdef INC_C1
            reg_data_out = utilization1;
            `endif
        end
        else if(rd_addr == UTIL2_ADDR) begin
            `ifdef INC_C2
            reg_data_out = utilization2;
            `endif
        end
        else if(rd_addr == UTIL3_ADDR) begin
            `ifdef INC_C3
            reg_data_out = utilization3;
            `endif
        end
        else if(rd_addr == UTIL4_ADDR) begin
            `ifdef INC_C4
            reg_data_out = utilization4;
            `endif
        end

    end 
    


endmodule

`default_nettype wire