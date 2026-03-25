module dcache #(
    parameter int XLEN = 64,
    parameter int DEPTH = 65536
)(
    input  logic            clk,
    
    input  logic            req_read,
    input  logic            req_write,
    input  logic [1:0]      req_size,
    input  logic [XLEN-1:0] req_addr,
    input  logic [XLEN-1:0] req_wdata,
    
    output logic [XLEN-1:0] rdata
);
    logic [7:0] mem [0:DEPTH-1];

    always_comb begin
        rdata = '0;
        if (req_read) begin
            for (int i = 0; i < 8; i++) begin
                if ((req_addr + i) < DEPTH) begin
                    rdata[i*8 +: 8] = mem[req_addr + i];
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (req_write) begin
            int bytes_to_write;
            
            case (req_size)
                2'b00:   bytes_to_write = 1; 
                2'b01:   bytes_to_write = 2; 
                2'b10:   bytes_to_write = 4; 
                2'b11:   bytes_to_write = 8; 
                default: bytes_to_write = 0;
            endcase

            for (int i = 0; i < 8; i++) begin
                if (i < bytes_to_write && (req_addr + i) < DEPTH) begin
                    mem[req_addr + i] <= req_wdata[i*8 +: 8];
                end
            end
        end
    end
endmodule
