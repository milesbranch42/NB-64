import rv64_pkg::*;

module core #(
    parameter int XLEN = 64,
    parameter logic [XLEN-1:0] RESET_VECTOR = '0
)(
    input logic             clk,
    input logic             rst,

	output logic [XLEN-1:0] icache_addr,
	input  logic [31:0]     icache_rdata,

	output logic            dcache_read,
	output logic            dcache_write,
	output logic [1:0]      dcache_size,
	output logic [XLEN-1:0] dcache_addr,
	output logic [XLEN-1:0] dcache_wdata,
	input  logic [XLEN-1:0] dcache_rdata
);
    logic [4:0]      rs1_addr;
    logic [4:0]      rs2_addr;
    logic [XLEN-1:0] rs1_data;
    logic [XLEN-1:0] rs2_data;
	logic            id_uses_rs1;
	logic            id_uses_rs2;
	logic            id_is_store;
    
	logic            wb_is_fencei;
	logic            wb_is_mret;
	logic            wb_is_sret;
	logic            wb_csr_we;
	logic            wb_trap_valid;

    logic            rf_we;
    logic [4:0]      rf_waddr;
    logic [XLEN-1:0] rf_wdata;

    logic            pc_redirect;
    logic [XLEN-1:0] pc_target;

	logic [1:0]      ex_forward_a;
	logic [1:0]      ex_forward_b;
	logic            mem_forward;

	logic            if_id_stall;
	logic            if_id_flush;
	logic            id_ex_stall;
	logic            id_ex_flush;
	logic            ex_mem_stall;
	logic            ex_mem_flush;
	logic            mem_wb_stall;
	logic            mem_wb_flush;

    if_id_reg_t      if_id;
    id_ex_reg_t      id_ex;
    ex_mem_reg_t     ex_mem;
    mem_wb_reg_t     mem_wb;

    if_stage #(
        .XLEN         (XLEN),
        .RESET_VECTOR (RESET_VECTOR)
    ) u_if_stage (
        .clk          (clk),
        .rst          (rst),
        .stall        (if_id_stall),
        .flush        (if_id_flush),
        .icache_addr  (icache_addr),
        .icache_rdata (icache_rdata),
        .pc_redirect  (pc_redirect),
        .pc_target    (pc_target),
        .if_id        (if_id)
    );

    id_stage #(
        .XLEN     (XLEN)
	) u_id_stage (
        .clk      (clk),
        .rst      (rst),
        .stall    (id_ex_stall),
        .flush    (id_ex_flush),
        .if_id    (if_id),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
		.uses_rs1 (id_uses_rs1),
		.uses_rs2 (id_uses_rs2),
		.is_store (id_is_store),
        .id_ex    (id_ex)
    );

    ex_stage #(
        .XLEN            (XLEN)
	) u_ex_stage (
        .clk             (clk),
        .rst             (rst),
        .stall           (ex_mem_stall),
        .flush           (ex_mem_flush),
        .id_ex           (id_ex),
		.forward_a       (ex_forward_a),
		.forward_b       (ex_forward_b),
		.fwd_ex_mem_data (ex_mem.ex_result),
		.fwd_mem_wb_data (rf_wdata),
		.pc_redirect     (pc_redirect),
		.pc_target       (pc_target),
        .ex_mem          (ex_mem)
    );

    mem_stage #(
        .XLEN         (XLEN)
	) u_mem_stage (
        .clk          (clk),
        .rst          (rst),
        .stall        (mem_wb_stall),
        .flush        (mem_wb_flush),
        .ex_mem       (ex_mem),
		.mem_forward  (mem_forward),
		.wb_rf_wdata  (rf_wdata),
        .dcache_read  (dcache_read),
        .dcache_write (dcache_write),
        .dcache_size  (dcache_size),
        .dcache_addr  (dcache_addr),
        .dcache_wdata (dcache_wdata),
        .dcache_rdata (dcache_rdata),
        .mem_wb       (mem_wb)
    );

    wb_stage #(
        .XLEN      (XLEN)
	) u_wb_stage (
        .clk        (clk),
        .rst        (rst),
        .mem_wb     (mem_wb),
		.is_fencei  (wb_is_fencei),
		.is_mret    (wb_is_mret),
		.is_sret    (wb_is_sret),
		.csr_we     (wb_csr_we),
		.trap_valid (wb_trap_valid),
        .rf_we      (rf_we),
        .rf_waddr   (rf_waddr),
        .rf_wdata   (rf_wdata)
    );

    regfile #(
        .XLEN     (XLEN)
	) u_regfile (
        .clk      (clk),
        .rst      (rst),
        .we       (rf_we),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rf_waddr),
        .wdata    (rf_wdata),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

	forwarding_unit u_forwarding_unit (
		.id_ex_rs1_addr   (id_ex.rs1_addr),
		.id_ex_rs2_addr   (id_ex.rs2_addr),
		.ex_mem_rs2_addr  (ex_mem.rs2_addr),
		.ex_mem_rd_addr   (ex_mem.rd_addr),
		.mem_wb_rd_addr   (mem_wb.rd_addr),
		.ex_mem_reg_write (ex_mem.wb_ctrl.reg_write),
		.mem_wb_reg_write (mem_wb.wb_ctrl.reg_write),
		.ex_mem_mem_write (ex_mem.mem_ctrl.write),
		.mem_wb_mem_read  (mem_wb.mem_read),
		.ex_forward_a     (ex_forward_a),
		.ex_forward_b     (ex_forward_b),
		.mem_forward      (mem_forward)
	);

	hazard_unit u_hazard_unit (
		.id_rs1_addr    (rs1_addr),
		.id_rs2_addr    (rs2_addr),
		.id_uses_rs1    (id_uses_rs1),
		.id_uses_rs2    (id_uses_rs2),
		.id_is_store    (id_is_store),
		.ex_rd_addr     (id_ex.rd_addr),
		.ex_is_load     (id_ex.mem_ctrl.read),
		.ex_pc_redirect (pc_redirect),
		.wb_is_fencei   (wb_is_fencei),
		.wb_is_mret     (wb_is_mret),
		.wb_is_sret     (wb_is_sret),
		.wb_csr_we      (wb_csr_we),
		.wb_trap_valid  (wb_trap_valid),
		.if_id_stall    (if_id_stall),
		.if_id_flush    (if_id_flush),
		.id_ex_stall    (id_ex_stall),
		.id_ex_flush    (id_ex_flush),
		.ex_mem_stall   (ex_mem_stall),
		.ex_mem_flush   (ex_mem_flush),
		.mem_wb_stall   (mem_wb_stall),
		.mem_wb_flush   (mem_wb_flush)
	);
endmodule
