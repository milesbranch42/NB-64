import rv64_pkg::*;

module wb_stage #(
	parameter int XLEN = 64
)(
	input  logic            clk,
	input  logic            rst,

	input  mem_wb_reg_t     mem_wb,

	output logic            is_fencei,
	output logic            is_mret,
	output logic            is_sret,
	output logic            is_valid,

	output logic            csr_we,
	output logic [11:0]     csr_waddr,
	output logic [XLEN-1:0] csr_wdata,

	output logic            trap_valid,
	output logic [4:0]      trap_cause,
	output logic [XLEN-1:0] trap_tval,
	output logic [XLEN-1:0] trap_pc,

	output logic            rf_we,
	output logic [4:0]      rf_waddr,
	output logic [XLEN-1:0] rf_wdata,

	output logic [XLEN-1:0] pc_plus_4
);
	assign is_fencei  = mem_wb.sys_ctrl.is_fencei;
	assign is_mret    = mem_wb.sys_ctrl.is_mret;
	assign is_sret    = mem_wb.sys_ctrl.is_sret;
	assign is_valid   = mem_wb.inst_valid;

	assign csr_we     = mem_wb.sys_ctrl.csr_ctrl.we && !mem_wb.trap_ctrl.valid;
	assign csr_waddr  = mem_wb.sys_ctrl.csr_ctrl.waddr;
	assign csr_wdata  = mem_wb.csr_wdata;

	assign trap_valid = mem_wb.trap_ctrl.valid;
	assign trap_cause = mem_wb.trap_ctrl.cause;
	assign trap_tval  = mem_wb.trap_ctrl.tval;
	assign trap_pc    = mem_wb.pc;

	assign rf_we      = mem_wb.wb_ctrl.reg_write && !mem_wb.trap_ctrl.valid;
	assign rf_waddr   = mem_wb.rd_addr;
	assign rf_wdata   = mem_wb.wb_ctrl.wb_sel ? mem_wb.mem_result : mem_wb.ex_result;

	assign pc_plus_4  = mem_wb.pc + 4;
endmodule
