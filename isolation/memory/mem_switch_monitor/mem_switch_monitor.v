`timescale 1ns / 1ps
`default_nettype none


//The memory decoupler
module mem_switch_monitor
#(
    //AXI4 Interface Params
    parameter AXI_ADDR_WIDTH = 32,

    //Additional Params to determine particular capabilities
    parameter PARAM_COUNT_WIDTH = 10,
    parameter BANK_WIDTH = 2,
    parameter BANK_GROUP_WIDTH = 2,
    parameter RANK_WIDTH = 0,
    parameter LR_WIDTH = 0,
    parameter ROW_WIDTH = 15,
    parameter COL_WIDTH = 10,
    parameter MEM_ADDR_ORDER = "BANK_ROW_COLUMN"
    // "ROW_BANK_COLUMN", "ROW_COLUMN_BANK", "ROW_COLUMN_BANK_INTLV"
    // "ROW_COLUMN_LRANK_BANK", "ROW_LRANK_COLUMN_BANK", 
)
(
    //AXI4 monitor connection
    //Write Address Channel
    input wire [AXI_ADDR_WIDTH-1:0]         aw_addr,
    input wire                              aw_valid,
    input wire                              aw_ready,
    //Read Address Channel     
    input wire [AXI_ADDR_WIDTH-1:0]         ar_addr,
    input wire                              ar_valid,
    input wire                              ar_ready,

    //Output monitoring result
    output wire [PARAM_COUNT_WIDTH:0]       rd_wr_switch,
    output wire [PARAM_COUNT_WIDTH:0]       miss_rate,

    //Clocking
    input wire  aclk,
    input wire  aresetn
);

    //--------------------------------------------------------//
    //   Monitor address channels for read-write switches     //
    //--------------------------------------------------------//

    //Valid data beats
    wire valid_write_req = aw_valid && aw_ready;
    wire valid_read_req = ar_valid && ar_ready;
    wire valid_both_req = valid_write_req && valid_read_req;
    wire valid_something = valid_write_req || valid_read_req;

    //Track last accepted transaction
    reg prev_was_write;
    reg prev_was_write_nxt;

    always@(*) begin
        if(~aresetn) prev_was_write_nxt = 1'b0;
        else if(valid_both_req) prev_was_write_nxt = ~prev_was_write;
        else if(valid_write_req) prev_was_write_nxt = 1'b1;
        else if(valid_read_req) prev_was_write_nxt = 1'b0;
        else prev_was_write_nxt = prev_was_write;
    end 

    always@(posedge aclk) prev_was_write <= prev_was_write_nxt;

    //Count number of switches
    wire rd_wr_switched = (prev_was_write != prev_was_write_nxt);

    reg [(2*PARAM_COUNT_WIDTH):0] rd_wr_counter;

    always@(posedge aclk) begin
        if(~aresetn) rd_wr_counter <= 0;
        else if(valid_something) begin
            rd_wr_counter <= rd_wr_counter
                + (rd_wr_switched << PARAM_COUNT_WIDTH)
                - (rd_wr_counter >> PARAM_COUNT_WIDTH)
                - (valid_both_req ? (rd_wr_counter >> PARAM_COUNT_WIDTH) : 0);
        end 
    end 

    //Assign output
    assign rd_wr_switch = rd_wr_counter[PARAM_COUNT_WIDTH+:PARAM_COUNT_WIDTH+1];



    //--------------------------------------------------------//
    //   Monitor address channels for page misses             //
    //--------------------------------------------------------//

    //Parameters
    localparam NUM_BANK_BITS = BANK_WIDTH + BANK_GROUP_WIDTH + RANK_WIDTH + LR_WIDTH;
    localparam NUM_BANKS = 2 ** NUM_BANK_BITS;

    //Seperate bits of address into index and row
    wire [AXI_ADDR_WIDTH-4:0] word_araddr = ar_addr[AXI_ADDR_WIDTH-1:3];
    wire [AXI_ADDR_WIDTH-4:0] word_awaddr = aw_addr[AXI_ADDR_WIDTH-1:3];
    reg [NUM_BANK_BITS-1:0] rd_idx;
    reg [NUM_BANK_BITS-1:0] wr_idx;
    reg [ROW_WIDTH-1:0] rd_row;
    reg [ROW_WIDTH-1:0] wr_row;

    always@(*) begin
        case(MEM_ADDR_ORDER)

            "ROW_BANK_COLUMN": begin
                if(LR_WIDTH+RANK_WIDTH != 0) begin
                    rd_idx = {  word_araddr[COL_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH],
                                word_araddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH+RANK_WIDTH] };
                    wr_idx = {  word_awaddr[COL_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH],
                                word_awaddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH+RANK_WIDTH] };
                end else begin
                    rd_idx = {  word_araddr[COL_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH] };
                    wr_idx = {  word_awaddr[COL_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH] };
                end 

                rd_row = word_araddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
            end
            "ROW_COLUMN_BANK": begin
                if(LR_WIDTH+RANK_WIDTH != 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_araddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH+RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_awaddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH+RANK_WIDTH] };
                 end else begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH] };
                end 

                rd_row = word_araddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
            end
            "ROW_COLUMN_BANK_INTLV": begin
                if(BANK_GROUP_WIDTH == 1 && RANK_WIDTH != 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+1],
                                word_araddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH-1],
                                word_araddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+1],
                                word_awaddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH-1],
                                word_awaddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                end else if(BANK_GROUP_WIDTH == 1 && RANK_WIDTH == 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+1],
                                word_araddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH-1] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+1],
                                word_awaddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH-1] };
                end else if(RANK_WIDTH != 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH],
                                word_araddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH],
                                word_araddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH],
                                word_awaddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH],
                                word_awaddr[COL_WIDTH+ROW_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                end else begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH],
                                word_araddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH],
                                word_awaddr[3+BANK_GROUP_WIDTH+1+:BANK_WIDTH] };
                end

                rd_row = word_araddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
            end
            "ROW_COLUMN_LRANK_BANK": begin
                if(RANK_WIDTH != 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH+LR_WIDTH],
                                word_araddr[ROW_WIDTH+COL_WIDTH+LR_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH+LR_WIDTH],
                                word_awaddr[ROW_WIDTH+COL_WIDTH+LR_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                end else begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH+LR_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH+LR_WIDTH] };
                end

                rd_row = word_araddr[COL_WIDTH+LR_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[COL_WIDTH+LR_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
            end
            "ROW_LRANK_COLUMN_BANK": begin
                if(LR_WIDTH == 0 && RANK_WIDTH == 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH] };
                end else if(LR_WIDTH == 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_araddr[ROW_WIDTH+LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_awaddr[ROW_WIDTH+LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                end else if(RANK_WIDTH == 0) begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_araddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_awaddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH] };
                end else begin
                    rd_idx = {  word_araddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_araddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH],
                                word_araddr[ROW_WIDTH+LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                    wr_idx = {  word_awaddr[3+:BANK_GROUP_WIDTH+BANK_WIDTH],
                                word_awaddr[COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:LR_WIDTH],
                                word_awaddr[ROW_WIDTH+LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:RANK_WIDTH] };
                end

                rd_row = word_araddr[LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[LR_WIDTH+COL_WIDTH+BANK_WIDTH+BANK_GROUP_WIDTH+:ROW_WIDTH];
            end
            default: begin // "BANK_ROW_COLUMN"
                rd_idx = word_araddr[COL_WIDTH+ROW_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH+LR_WIDTH+RANK_WIDTH];
                wr_idx = word_awaddr[COL_WIDTH+ROW_WIDTH+:BANK_WIDTH+BANK_GROUP_WIDTH+LR_WIDTH+RANK_WIDTH];
                rd_row = word_araddr[COL_WIDTH+:ROW_WIDTH];
                wr_row = word_awaddr[COL_WIDTH+:ROW_WIDTH];
            end

        endcase 
    end 

    //Remember open page for each bank
    reg [ROW_WIDTH-1:0] cur_page [NUM_BANKS-1:0];
    wire [NUM_BANK_BITS-1:0] idx = (prev_was_write) ? rd_idx : wr_idx;

    always@(posedge aclk) begin
        if(valid_both_req && rd_idx == wr_idx) begin
            cur_page[idx] <= (prev_was_write) ? rd_row : wr_row;
        end
        else if(valid_read_req) cur_page[rd_idx] <= rd_row;
        //if(valid_write_req) cur_page[wr_idx] <= wr_row;
    end
    
    always@(posedge aclk) begin
        if(!(valid_read_req && rd_idx == wr_idx) && valid_write_req) begin
            cur_page[wr_idx] <= wr_row;
        end
    end

    //Check for page missmatch
    reg rd_page_miss;
    reg wr_page_miss;

    always@(*) begin
        rd_page_miss = 1'b0;
        wr_page_miss = 1'b0;

        if(valid_both_req && rd_idx == wr_idx) begin
            rd_page_miss = (rd_row != (prev_was_write ? wr_row : cur_page[rd_idx]) );
            wr_page_miss = (wr_row != (prev_was_write ? cur_page[wr_idx] : rd_row) );
        end
        else begin
            if(valid_read_req) rd_page_miss = (rd_row != cur_page[rd_idx]);
            if(valid_write_req) wr_page_miss = (wr_row != cur_page[wr_idx]);
        end
    end

    reg [(2*PARAM_COUNT_WIDTH):0] miss_counter;

    always@(posedge aclk) begin
        if(~aresetn) miss_counter <= 0;
        else if(valid_something) begin
            miss_counter <= miss_counter
                + (rd_page_miss << PARAM_COUNT_WIDTH)
                + (wr_page_miss << PARAM_COUNT_WIDTH)
                - (miss_counter >> PARAM_COUNT_WIDTH)
                - (valid_both_req ? (miss_counter >> PARAM_COUNT_WIDTH) : 0);
        end 
    end 

    //Assign output
    assign miss_rate = miss_counter[PARAM_COUNT_WIDTH+:PARAM_COUNT_WIDTH+1];



endmodule

`default_nettype wire
