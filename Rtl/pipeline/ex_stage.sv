import rv64_pkg::*;

module ex_stage #(
	parameter int XLEN = 64
)(
	input  logic            clk,
	input  logic            rst,
	input  logic            stall,
	input  logic            flush,

	input  id_ex_reg_t      id_ex,

	input  logic [1:0]      forward_a,
	input  logic [1:0]      forward_b,
	input  logic [XLEN-1:0] fwd_ex_mem_data,
	input  logic [XLEN-1:0] fwd_mem_wb_data,

	output logic            pc_redirect,
	output logic [XLEN-1:0] pc_target,

	output ex_mem_reg_t     ex_mem
);
	logic [XLEN-1:0]   fwd_rs1_val;
	logic [XLEN-1:0]   fwd_rs2_val;

	logic [XLEN-1:0]   op1;
	logic [XLEN-1:0]   op2;
	logic [XLEN-1:0]   result;

	logic [5:0]        shamt;
	logic [4:0]        shamt_w;
	logic [31:0]       result_w;

	logic [2*XLEN-1:0] mul_ss;
	logic [2*XLEN-1:0] mul_su;
	logic [2*XLEN-1:0] mul_uu;

	logic [XLEN-1:0]   final_result;

	logic [XLEN-1:0]   csr_operand;
	logic [XLEN-1:0]   csr_wdata;

	mem_ctrl_t         ex_mem_ctrl;
	wb_ctrl_t          ex_wb_ctrl;
	sys_ctrl_t         ex_sys_ctrl;
	trap_ctrl_t        ex_trap_ctrl;

	always_comb begin
		unique case (forward_a)
			2'b01:   fwd_rs1_val = fwd_ex_mem_data;
			2'b10:   fwd_rs1_val = fwd_mem_wb_data;
			default: fwd_rs1_val = id_ex.rs1_val;
		endcase

		unique case (forward_b)
			2'b01:   fwd_rs2_val = fwd_ex_mem_data;
			2'b10:   fwd_rs2_val = fwd_mem_wb_data;
			default: fwd_rs2_val = id_ex.rs2_val;
		endcase
	end

	assign op1     = id_ex.ex_ctrl.op1_is_pc  ? id_ex.pc  : fwd_rs1_val;
	assign op2     = id_ex.ex_ctrl.op2_is_imm ? id_ex.imm : fwd_rs2_val;

	assign shamt   = op2[5:0];
	assign shamt_w = op2[4:0];

	assign mul_ss  = $signed(op1) * $signed(op2);
	assign mul_su  = $signed(op1) * $signed({1'b0, op2});
	assign mul_uu  = op1 * op2;

	assign csr_operand = id_ex.sys_ctrl.csr_ctrl.imm_op ? { {(XLEN-5){1'b0}}, id_ex.rs1_addr } : fwd_rs1_val;

	always_comb begin
		result   = '0;
		result_w = '0;

		if (id_ex.ex_ctrl.word_op) begin
			unique case (id_ex.ex_ctrl.alu_op)
				ALU_ADD: result_w = op1[31:0] + op2[31:0];
				ALU_SLL: result_w = op1[31:0] << shamt_w;
				ALU_SRL: result_w = op1[31:0] >> shamt_w;
				ALU_SRA: result_w = $signed(op1[31:0]) >>> shamt_w;
				ALU_SUB: result_w = op1[31:0] - op2[31:0];
				default: result_w = '0;

				ALU_MUL:  result_w = op1[31:0] * op2[31:0];
				ALU_DIVU: result_w = (op2[31:0] == 0) ? '1 : (op1[31:0] / op2[31:0]);
				ALU_REMU: result_w = (op2[31:0] == 0) ? op1[31:0] : (op1[31:0] % op2[31:0]);

				ALU_DIV: begin
					if (op2[31:0] == 0) result_w = '1;
					else if (op1[31:0] == 32'h8000_0000 && op2[31:0] == '1) result_w = op1[31:0];
					else result_w = $signed(op1[31:0]) / $signed(op2[31:0]);
				end
				ALU_REM: begin
					if (op2[31:0] == 0) result_w = op1[31:0];
					else if (op1[31:0] == 32'h8000_0000 && op2[31:0] == '1) result_w = '0;
					else result_w = $signed(op1[31:0]) % $signed(op2[31:0]);
				end
			endcase

			result = { {32{result_w[31]}}, result_w };
		end
		else begin
			unique case (id_ex.ex_ctrl.alu_op)
				ALU_ADD:  result = op1 + op2;
				ALU_SUB:  result = op1 - op2;
				ALU_SLL:  result = op1 << shamt;
				ALU_SLT:  result = { {XLEN-1{1'b0}}, ($signed(op1) < $signed(op2)) };
				ALU_SLTU: result = { {XLEN-1{1'b0}}, (op1 < op2) };
				ALU_XOR:  result = op1 ^ op2;
				ALU_SRL:  result = op1 >> shamt;
				ALU_SRA:  result = $signed(op1) >>> shamt;
				ALU_OR:   result = op1 | op2;
				ALU_AND:  result = op1 & op2;
				default:  result = '0;

				ALU_MUL:    result = mul_ss[XLEN-1:0];
				ALU_MULH:   result = mul_ss[2*XLEN-1:XLEN];
				ALU_MULHSU: result = mul_su[2*XLEN-1:XLEN];
				ALU_MULHU:  result = mul_uu[2*XLEN-1:XLEN];
				ALU_DIVU:   result = (op2 == 0) ? '1  : (op1 / op2);
				ALU_REMU:   result = (op2 == 0) ? op1 : (op1 % op2);

				ALU_DIV: begin
					if (op2 == 0) result = '1;
					else if (op1 == { 1'b1, {XLEN-1{1'b0}} } && op2 == '1) result = op1;
					else result = $signed(op1) / $signed(op2);
				end
				ALU_REM: begin
					if (op2 == 0) result = op1;
					else if (op1 == { 1'b1, {XLEN-1{1'b0}} } && op2 == '1) result = '0;
					else result = $signed(op1) % $signed(op2);
				end
			endcase
		end
	end

	always_comb begin
		pc_redirect  = '0;
		pc_target    = '0;

		if (id_ex.ex_ctrl.is_jump) begin
			pc_redirect = 1'b1;
		end
		else if (id_ex.ex_ctrl.is_branch) begin
			unique case (id_ex.ex_ctrl.branch_op)
				BR_EQ:   pc_redirect = (fwd_rs1_val == fwd_rs2_val);
				BR_NE:   pc_redirect = (fwd_rs1_val != fwd_rs2_val);
				BR_LT:   pc_redirect = ($signed(fwd_rs1_val) < $signed(fwd_rs2_val));
				BR_GE:   pc_redirect = ($signed(fwd_rs1_val) >= $signed(fwd_rs2_val));
				BR_LTU:  pc_redirect = (fwd_rs1_val < fwd_rs2_val);
				BR_GEU:  pc_redirect = (fwd_rs1_val >= fwd_rs2_val);
				default: pc_redirect = 1'b0;
			endcase
		end

		if (id_ex.ex_ctrl.is_jalr)
			pc_target = (fwd_rs1_val + id_ex.imm) & ~XLEN'(1);
		else
			pc_target = id_ex.pc + id_ex.imm;
		
		ex_mem_ctrl  = id_ex.mem_ctrl;
		ex_wb_ctrl   = id_ex.wb_ctrl;
		ex_sys_ctrl  = id_ex.sys_ctrl;
		ex_trap_ctrl = id_ex.trap_ctrl;
		
		// Does not support C extension
		if (!id_ex.trap_ctrl.valid) begin
			if (pc_target[1:0] != 2'b00 && pc_redirect) begin

				ex_trap_ctrl.valid = 1'b1;
				ex_trap_ctrl.cause = EXC_INSTR_ADDR_MISALIGNED;
				ex_trap_ctrl.tval  = pc_target;

				pc_redirect = 1'b0;
				ex_mem_ctrl = '0;
				ex_wb_ctrl  = '0;
				ex_sys_ctrl = '0;
			end
		end
	end

	always_comb begin
		if (id_ex.ex_ctrl.is_jump)
			final_result = id_ex.pc_plus_4;
		else if (id_ex.sys_ctrl.is_csr)
			final_result = id_ex.csr_rdata;
		else
			final_result = result;
	end

	always_comb begin
		unique case (id_ex.sys_ctrl.csr_ctrl.op)
			2'b01:   csr_wdata = csr_operand;
			2'b10:   csr_wdata = id_ex.csr_rdata | csr_operand;
			2'b11:   csr_wdata = id_ex.csr_rdata & ~csr_operand;
			default: csr_wdata = '0;
		endcase
	end

	always_ff @(posedge clk) begin
		if (rst || flush) begin
			ex_mem <= '0;
		end
		else if (!stall) begin
			ex_mem.inst_valid <= id_ex.inst_valid && !ex_trap_ctrl.valid;
			ex_mem.pc         <= id_ex.pc;
			ex_mem.pc_plus_4  <= id_ex.pc_plus_4;
			ex_mem.ex_result  <= final_result;
			ex_mem.mem_wdata  <= fwd_rs2_val;
			ex_mem.csr_wdata  <= csr_wdata;
			ex_mem.rs2_addr   <= id_ex.rs2_addr;
			ex_mem.rd_addr    <= id_ex.rd_addr;
			ex_mem.mem_ctrl   <= ex_mem_ctrl;
			ex_mem.wb_ctrl    <= ex_wb_ctrl;
			ex_mem.sys_ctrl   <= ex_sys_ctrl;
			ex_mem.trap_ctrl  <= ex_trap_ctrl;
		end
	end
endmodule
