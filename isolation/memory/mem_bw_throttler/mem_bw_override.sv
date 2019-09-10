`timescale 1ns / 1ps
`default_nettype none


//The memory prtocol checker/corrector
module mem_bw_override
#(
    //AXI4 Interface Params
    parameter NUM_MASTERS = 4
)
(
    //Override token decoupling
    output wire [NUM_MASTERS-1:0] aw_overrides,
    output wire [NUM_MASTERS-1:0] ar_overrides,

    input wire [NUM_MASTERS-1:0] aw_has_outstanding,
    input wire [NUM_MASTERS-1:0] aw_can_override,
    input wire [NUM_MASTERS-1:0] ar_has_outstanding,
    input wire [NUM_MASTERS-1:0] ar_can_override,

    //CLocking
    input wire aclk,
    input wire aresetn
);

    //Assign overirde value to a single interface
    wire no_outstanding = !( |aw_has_outstanding || |ar_has_outstanding );

    reg [(NUM_MASTERS*2)-1:0] rotating_mask;

    generate for (genvar j = 0; j < NUM_MASTERS; j = j + 1) begin : assigment

        assign aw_overrides[j] = no_outstanding && aw_can_override[j] && rotating_mask[j];
        assign ar_overrides[j] = no_outstanding && ar_can_override[j] && rotating_mask[NUM_MASTERS+j];

    end endgenerate

    //Generate a rotating mask with a signle enabled bit (TODO: Maybe a better system)
    wire [(NUM_MASTERS*2)-1:0] mask_update = (rotating_mask << 1);

    always@(posedge aclk) begin
        if(~aresetn || mask_update == 0) rotating_mask <= 1;
        else rotating_mask <= mask_update;
    end 
    
    

endmodule

`default_nettype wire