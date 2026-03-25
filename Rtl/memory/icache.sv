
module icache #(
    parameter int XLEN  = 64,
    parameter int DEPTH = 1024
)(
    input  logic            clk,
    input  logic            rst,
    input  logic [XLEN-1:0] addr,
    output logic [31:0]     rdata
);
    logic [31:0] mem [0:DEPTH-1];

    localparam int IDX_W = $clog2(DEPTH);

    logic [IDX_W-1:0] word_idx;
    logic valid_addr;

    assign word_idx = addr[IDX_W+1:2]; 
    assign valid_addr = (XLEN'(addr[XLEN-1:2]) < XLEN'(DEPTH));

    always_comb begin
        if (valid_addr) begin
            rdata = mem[word_idx];
        end
        else begin
            rdata = 32'h00000013;
        end
    end
endmodule
