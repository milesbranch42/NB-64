import rv64_pkg::*;

module id_stage #(
	parameter int XLEN = 64
)(
	input  logic            clk,
	input  logic            rst,
	input  logic            stall,
	input  logic            flush,

	input  if_id_reg_t      if_id,

	output logic [4:0]      rs1_addr,
	output logic [4:0]      rs2_addr,
	input  logic [XLEN-1:0] rs1_data,
	input  logic [XLEN-1:0] rs2_data,

	output logic            csr_re,
	output logic            csr_we_intent,
	output logic [11:0]     csr_raddr,
	input  logic [XLEN-1:0] csr_rdata,
	input  logic            csr_fault,
	input  logic [1:0]      csr_priv,
	input  logic            mstatus_tsr,
	input  logic            mstatus_tvm,

	output logic            uses_rs1,
	output logic            uses_rs2,
	output logic            is_store,

	output id_ex_reg_t      id_ex
);
	opcode_t         opcode;
	logic [2:0]      funct3;
	logic [4:0]      funct5;
	logic [6:0]      funct7;
	logic [11:0]     funct12;
	logic [4:0]      rd_addr;

	logic [XLEN-1:0] imm_i;
	logic [XLEN-1:0] imm_s;
	logic [XLEN-1:0] imm_u;
	logic [XLEN-1:0] imm_b;
	logic [XLEN-1:0] imm_j;
	logic [XLEN-1:0] imm;

	ex_ctrl_t        ex_ctrl;
	mem_ctrl_t       mem_ctrl;
	wb_ctrl_t        wb_ctrl;
	sys_ctrl_t       sys_ctrl;
	trap_ctrl_t      trap_ctrl;

	assign opcode  = opcode_t'(if_id.instr[6:0]);
	assign funct3  = if_id.instr[14:12];
	assign funct5  = if_id.instr[31:27];
	assign funct7  = if_id.instr[31:25];
	assign funct12 = if_id.instr[31:20];

	assign imm_i   = { {(XLEN-12){if_id.instr[31]}}, if_id.instr[31:20] };
	assign imm_s   = { {(XLEN-12){if_id.instr[31]}}, if_id.instr[31:25], if_id.instr[11:7] };
	assign imm_u   = { {(XLEN-32){if_id.instr[31]}}, if_id.instr[31:12], 12'b0 };
	assign imm_b   = { {(XLEN-12){if_id.instr[31]}}, if_id.instr[7], if_id.instr[30:25], if_id.instr[11:8], 1'b0 };
	assign imm_j   = { {(XLEN-20){if_id.instr[31]}}, if_id.instr[19:12], if_id.instr[20], if_id.instr[30:21], 1'b0 };

	assign uses_rs1 = !if_id.trap_ctrl.valid && !(
		(opcode == OP_LUI)      ||
		(opcode == OP_AUIPC)    ||
		(opcode == OP_JAL)      ||
		(opcode == OP_MISC_MEM) ||
		(opcode == OP_SYSTEM && (funct3 == 3'b000)) // ZICSR immediate-variants encode the immediate in rs1
	);
	
	assign uses_rs2 = !if_id.trap_ctrl.valid && !(
		(opcode == OP_LUI)      ||
		(opcode == OP_AUIPC)    ||
		(opcode == OP_JAL)      ||
		(opcode == OP_JALR)     ||
		(opcode == OP_LOAD)     ||
		(opcode == OP_IMM)      ||
		(opcode == OP_IMM_32)   ||
		(opcode == OP_MISC_MEM) ||
		(opcode == OP_SYSTEM)   ||
		(opcode == OP_AMO && (funct5 == AMO_LR))
	);

	assign is_store = (opcode == OP_STORE);

	assign rs1_addr = uses_rs1 ? if_id.instr[19:15] : 5'b0;
	assign rs2_addr = uses_rs2 ? if_id.instr[24:20] : 5'b0;
	assign rd_addr  = if_id.instr[11:7];

	always_comb begin
		imm       = '0;
		ex_ctrl   = '0;
		mem_ctrl  = '0;
		wb_ctrl   = '0;
		sys_ctrl  = '0;
		trap_ctrl = '0;

		csr_re        = 1'b0;
		csr_we_intent = 1'b0;
		csr_raddr     = '0;

		unique case (opcode)
			OP_REG: begin
				ex_ctrl.alu_op    = alu_op_t'({funct7[5], funct7[0], funct3});
				wb_ctrl.reg_write = 1'b1;
			end
			OP_IMM: begin
				imm                = imm_i;
				ex_ctrl.alu_op     = alu_op_t'({(funct3 == 3'b101 && imm_i[10]), 1'b0, funct3});
				ex_ctrl.op2_is_imm = 1'b1;
				wb_ctrl.reg_write  = 1'b1;
			end
			OP_REG_32: begin
				ex_ctrl.alu_op    = alu_op_t'({funct7[5], funct7[0], funct3});
				ex_ctrl.word_op   = 1'b1;
				wb_ctrl.reg_write = 1'b1;
			end
			OP_IMM_32: begin
				imm                = imm_i;
				ex_ctrl.alu_op     = alu_op_t'({(funct3 == 3'b101 && imm_i[10]), 1'b0, funct3});
				ex_ctrl.word_op    = 1'b1;
				ex_ctrl.op2_is_imm = 1'b1;
				wb_ctrl.reg_write  = 1'b1;
			end
			OP_LUI: begin
				imm                = imm_u;
				ex_ctrl.alu_op     = ALU_ADD;
				ex_ctrl.op2_is_imm = 1'b1;
				wb_ctrl.reg_write  = 1'b1;
			end
			OP_AUIPC: begin
				imm                = imm_u;
				ex_ctrl.alu_op     = ALU_ADD;
				ex_ctrl.op1_is_pc  = 1'b1;
				ex_ctrl.op2_is_imm = 1'b1;
				wb_ctrl.reg_write  = 1'b1;
			end
			OP_LOAD: begin
				imm                  = imm_i;
				ex_ctrl.alu_op       = ALU_ADD;
				ex_ctrl.op2_is_imm   = 1'b1;
				mem_ctrl.read        = 1'b1;
				mem_ctrl.is_unsigned = funct3[2];
				mem_ctrl.size        = funct3[1:0];
				wb_ctrl.reg_write    = 1'b1;
				wb_ctrl.wb_sel       = 1'b1;
			end
			OP_STORE: begin
				imm                = imm_s;
				ex_ctrl.alu_op     = ALU_ADD;
				ex_ctrl.op2_is_imm = 1'b1;
				mem_ctrl.write     = 1'b1;
				mem_ctrl.size      = funct3[1:0];
			end
			OP_AMO: begin
				if (funct3 == 3'b010 || funct3 == 3'b011) begin
					unique case (funct5)
						AMO_LR,
						AMO_SC,
						AMO_SWAP,
						AMO_ADD,
						AMO_XOR,
						AMO_AND,
						AMO_OR,
						AMO_MIN,
						AMO_MAX,
						AMO_MINU,
						AMO_MAXU: begin
							imm                = '0;
							ex_ctrl.alu_op     = ALU_ADD;
							ex_ctrl.op2_is_imm = 1'b1;
							
							mem_ctrl.is_amo    = 1'b1;
							mem_ctrl.amo_op    = amo_op_t'(funct5);
							mem_ctrl.size      = funct3[1:0];
							
							if (funct5 == AMO_LR) begin
								mem_ctrl.read  = 1'b1;
							end
							else if (funct5 == AMO_SC) begin
								mem_ctrl.write = 1'b1;
							end
							else begin
								mem_ctrl.read  = 1'b1;
								mem_ctrl.write = 1'b1;
							end

							wb_ctrl.reg_write  = 1'b1;
							wb_ctrl.wb_sel     = 1'b1;
						end
						default: begin
							trap_ctrl.valid = 1'b1;
							trap_ctrl.cause = EXC_ILLEGAL_INSTR;
							trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
						end
					endcase
				end
				else begin
					trap_ctrl.valid = 1'b1;
					trap_ctrl.cause = EXC_ILLEGAL_INSTR;
					trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
				end
			end
			OP_JAL: begin
				imm               = imm_j;
				wb_ctrl.reg_write = 1'b1;
				ex_ctrl.is_jump   = 1'b1;
			end
			OP_JALR: begin
				if (funct3 == 3'b000) begin
					imm               = imm_i;
					wb_ctrl.reg_write = 1'b1;
					ex_ctrl.is_jump   = 1'b1;
					ex_ctrl.is_jalr   = 1'b1;
				end
				else begin
					trap_ctrl.valid = 1'b1;
					trap_ctrl.cause = EXC_ILLEGAL_INSTR;
					trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
				end
			end
			OP_BRANCH: begin
				if (funct3 == 3'b010 || funct3 == 3'b011) begin
					trap_ctrl.valid = 1'b1;
					trap_ctrl.cause = EXC_ILLEGAL_INSTR;
					trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
				end
				else begin
					imm               = imm_b;
					ex_ctrl.is_branch = 1'b1;
					ex_ctrl.branch_op = branch_op_t'(funct3);
				end
			end
			OP_MISC_MEM: begin
				if (funct3 == 3'b000) begin // FENCE, FENCE.TSO, PAUSE
					// NA
				end
				else if (funct3 == 3'b001) begin // FENCE.I
					sys_ctrl.is_fencei = 1'b1;
				end
				else begin
					trap_ctrl.valid = 1'b1;
					trap_ctrl.cause = EXC_ILLEGAL_INSTR;
					trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
				end
			end
			OP_SYSTEM: begin
				if (funct3 == 3'b000) begin
					unique case (funct12)
						12'h000: begin // ECALL
							trap_ctrl.valid = 1'b1;

							unique case (csr_priv)
								2'b00:   trap_ctrl.cause = EXC_U_ECALL;
								2'b01:   trap_ctrl.cause = EXC_S_ECALL;
								2'b11:   trap_ctrl.cause = EXC_M_ECALL;
								default: trap_ctrl.cause = EXC_ILLEGAL_INSTR; // Unnecessary, but good defensive programming
							endcase
						end
						12'h001: begin // EBREAK
							trap_ctrl.valid = 1'b1;
							trap_ctrl.cause = EXC_BREAKPOINT;
						end
						12'h302: begin // MRET
							if (csr_priv < 2'b11) begin
								trap_ctrl.valid = 1'b1;
								trap_ctrl.cause = EXC_ILLEGAL_INSTR;
								trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
							end
							else begin
								sys_ctrl.is_mret = 1'b1;
							end
						end
						12'h102: begin // SRET
							if (csr_priv < 2'b01 || (csr_priv == 2'b01 && mstatus_tsr)) begin
								trap_ctrl.valid = 1'b1;
								trap_ctrl.cause = EXC_ILLEGAL_INSTR;
								trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
							end
							else begin
								sys_ctrl.is_sret = 1'b1;
							end
						end
						12'h105: begin // WFI
							// NOP
						end
						default: begin
							if (funct7 == 7'b001001) begin // SFENCE.VMA
								if ((csr_priv == 2'b00) || (csr_priv == 2'b01 && mstatus_tvm)) begin // Illegal in U-Mode
									trap_ctrl.valid = 1'b1;
									trap_ctrl.cause = EXC_ILLEGAL_INSTR;
									trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
								end
								// Otherwise, NOP for now
							end
							else begin
								trap_ctrl.valid = 1'b1;
								trap_ctrl.cause = EXC_ILLEGAL_INSTR;
								trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
							end
						end
					endcase
				end
				else if (funct3 != 3'b100) begin // CSR Instructions
					wb_ctrl.reg_write = 1'b1;

					sys_ctrl.is_csr          = 1'b1;
					sys_ctrl.csr_ctrl.op     = funct3[1:0];
					sys_ctrl.csr_ctrl.imm_op = funct3[2];
					sys_ctrl.csr_ctrl.waddr  = imm_i[11:0];

					csr_raddr = if_id.instr[31:20];

					if (funct3[1:0] == 2'b01) begin // CSRRW*
						sys_ctrl.csr_ctrl.we = 1'b1;
						csr_re               = (rd_addr != 0);
						csr_we_intent        = 1'b1;
					end
					else if (funct3[1:0] == 2'b10 || funct3[1:0] == 2'b11) begin // CSRRS* CSRRC*
						sys_ctrl.csr_ctrl.we = (rs1_addr != 0);
						csr_re               = 1'b1;
						csr_we_intent        = (rs1_addr != 0);
					end
					else begin
						trap_ctrl.valid = 1'b1;
						trap_ctrl.cause = EXC_ILLEGAL_INSTR;
						trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
					end

					if (csr_fault && !trap_ctrl.valid) begin
						trap_ctrl.valid = 1'b1;
						trap_ctrl.cause = EXC_ILLEGAL_INSTR;
						trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
					end
				end
				else begin
					trap_ctrl.valid = 1'b1;
					trap_ctrl.cause = EXC_ILLEGAL_INSTR;
					trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
				end
			end
			default: begin
				trap_ctrl.valid = 1'b1;
				trap_ctrl.cause = EXC_ILLEGAL_INSTR;
				trap_ctrl.tval  = { {(XLEN-32){1'b0}}, if_id.instr };
			end
		endcase

		if (if_id.trap_ctrl.valid) begin
			imm       = '0;
			ex_ctrl   = '0;
			mem_ctrl  = '0;
			wb_ctrl   = '0;
			sys_ctrl  = '0;
			trap_ctrl = if_id.trap_ctrl;
		end
	end

	always_ff @(posedge clk) begin
		if (rst || flush) begin
			id_ex <= '0;
		end
		else if (!stall) begin
			id_ex.inst_valid <= if_id.inst_valid && !trap_ctrl.valid;
			id_ex.pc         <= if_id.pc;
			id_ex.pc_plus_4  <= if_id.pc_plus_4;
			id_ex.imm        <= imm;
			id_ex.rs1_val    <= rs1_data;
			id_ex.rs2_val    <= rs2_data;
			id_ex.csr_rdata  <= csr_rdata;
			id_ex.rs1_addr   <= rs1_addr;
			id_ex.rs2_addr   <= rs2_addr;
			id_ex.rd_addr    <= rd_addr;
			id_ex.ex_ctrl    <= ex_ctrl;
			id_ex.mem_ctrl   <= mem_ctrl;
			id_ex.wb_ctrl    <= wb_ctrl;
			id_ex.sys_ctrl   <= sys_ctrl;
			id_ex.trap_ctrl  <= trap_ctrl;
		end
	end
endmodule
