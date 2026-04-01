module hazard_unit (
	input  logic [4:0] id_rs1_addr,
	input  logic [4:0] id_rs2_addr,
	input  logic       id_uses_rs1,
	input  logic       id_uses_rs2,
	input  logic       id_is_store,

	input  logic [4:0] ex_rd_addr,
	input  logic       ex_result_delayed, // Was ex_is_load
	input  logic       ex_pc_redirect,

	input  logic       wb_is_fencei,
	input  logic       wb_is_mret,
	input  logic       wb_is_sret,
	input  logic       wb_csr_we,
	input  logic       wb_trap_valid,

	output logic       if_id_stall,
	output logic       if_id_flush,
	output logic       id_ex_stall,
	output logic       id_ex_flush,
	output logic       ex_mem_stall,
	output logic       ex_mem_flush,
	output logic       mem_wb_stall,
	output logic       mem_wb_flush
);
	always_comb begin
		if_id_stall  = 1'b0;
		if_id_flush  = 1'b0;
		id_ex_stall  = 1'b0;
		id_ex_flush  = 1'b0;
		ex_mem_stall = 1'b0;
		ex_mem_flush = 1'b0;
		mem_wb_stall = 1'b0;
		mem_wb_flush = 1'b0;

		if (wb_is_fencei || wb_csr_we || wb_is_mret || wb_is_sret || wb_trap_valid) begin
			if_id_flush  = 1'b1;
			id_ex_flush  = 1'b1;
			ex_mem_flush = 1'b1;
			mem_wb_flush = 1'b1;
		end
		else if (ex_result_delayed && (ex_rd_addr != 0) &&
			   ((id_uses_rs1 && ex_rd_addr == id_rs1_addr) ||
			    (id_uses_rs2 && ex_rd_addr == id_rs2_addr && !id_is_store))) begin

			if_id_stall = 1'b1;
			id_ex_flush = 1'b1;
		end
		else if (ex_pc_redirect) begin
			if_id_flush = 1'b1;
			id_ex_flush = 1'b1;
		end
	end
endmodule
