import rv64_pkg::*;

module if_stage #(
	parameter int XLEN = 64,
	parameter logic [XLEN-1:0] RESET_VECTOR = '0
)(
	input  logic            clk,
	input  logic            rst,
	input  logic            stall,
	input  logic            flush,

	output logic [XLEN-1:0] icache_addr,
	input  logic [31:0]     icache_rdata,

	input  logic            pc_redirect,
	input  logic [XLEN-1:0] pc_target,

	output if_id_reg_t      if_id
);
	logic [XLEN-1:0] pc;
	trap_ctrl_t      trap_ctrl;

	assign icache_addr = pc;

	always_comb begin
		trap_ctrl = '0;

		if (pc[1:0] != 2'b00) begin
			trap_ctrl.valid = 1'b1;
			trap_ctrl.cause = EXC_INSTR_ADDR_MISALIGNED;
			trap_ctrl.tval  = pc;
		end
	end

	always_ff @(posedge clk) begin
		if (rst)
			pc <= RESET_VECTOR;
		else if (!stall)
			pc <= pc_redirect ? pc_target : (pc + 4);
	end

	always_ff @(posedge clk) begin
		if (rst || flush) begin
			if_id.pc        <= '0;
			if_id.pc_plus_4 <= XLEN'(4);
			if_id.instr     <= 32'h00000013;
			if_id.trap_ctrl <= '0;
		end
		else if (!stall) begin
			if_id.pc        <= pc;
			if_id.pc_plus_4 <= pc + 4;
			if_id.instr     <= icache_rdata;
			if_id.trap_ctrl <= trap_ctrl;
		end
	end
endmodule
