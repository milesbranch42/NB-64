import rv64_pkg::*;

module mem_stage #(
    parameter int XLEN = 64
)(
    input  logic            clk,
    input  logic            rst,
    input  logic            stall,
    input  logic            flush,

    input  ex_mem_reg_t     ex_mem,

	input  logic            mem_forward,
	input  logic [XLEN-1:0] wb_rf_wdata,

    output logic            dcache_read,
    output logic            dcache_write,
    output logic [1:0]      dcache_size,
    output logic [XLEN-1:0] dcache_addr,
    output logic [XLEN-1:0] dcache_wdata,
    input  logic [XLEN-1:0] dcache_rdata,

    output mem_wb_reg_t     mem_wb
);
    logic [XLEN-1:0] loaded_data;

	// Technically the !valid check is redundant since ID zeros out signals
    assign dcache_read  = ex_mem.mem_ctrl.read && !ex_mem.trap_ctrl.valid;
    assign dcache_write = ex_mem.mem_ctrl.write && !ex_mem.trap_ctrl.valid;
    assign dcache_size  = ex_mem.mem_ctrl.size;
    assign dcache_addr  = ex_mem.ex_result;
	assign dcache_wdata = mem_forward ? wb_rf_wdata : ex_mem.mem_wdata;

    always_comb begin
        loaded_data = '0;
        
        if (ex_mem.mem_ctrl.read) begin
            unique case (ex_mem.mem_ctrl.size)
                2'b00:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {56{1'b0}}, dcache_rdata[7:0] }  : { {56{dcache_rdata[7]}},  dcache_rdata[7:0]  };
                2'b01:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {48{1'b0}}, dcache_rdata[15:0] } : { {48{dcache_rdata[15]}}, dcache_rdata[15:0] };
                2'b10:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {32{1'b0}}, dcache_rdata[31:0] } : { {32{dcache_rdata[31]}}, dcache_rdata[31:0] };
                2'b11:   loaded_data = dcache_rdata;
                default: loaded_data = '0;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            mem_wb <= '0;
        end
        else if (!stall) begin
            mem_wb.pc         <= ex_mem.pc;
            mem_wb.ex_result  <= ex_mem.ex_result;
            mem_wb.mem_result <= loaded_data;
            mem_wb.rd_addr    <= ex_mem.rd_addr;
			mem_wb.mem_read   <= ex_mem.mem_ctrl.read;
            mem_wb.wb_ctrl    <= ex_mem.wb_ctrl;
            mem_wb.sys_ctrl   <= ex_mem.sys_ctrl;
            mem_wb.trap_ctrl  <= ex_mem.trap_ctrl;
        end
    end
endmodule
