module forwarding_unit (
	input  logic [4:0] id_ex_rs1_addr,
	input  logic [4:0] id_ex_rs2_addr,
	input  logic [4:0] ex_mem_rs2_addr,
	input  logic [4:0] ex_mem_rd_addr,
	input  logic [4:0] mem_wb_rd_addr,
	input  logic       ex_mem_reg_write,
	input  logic       mem_wb_reg_write,
	input  logic       ex_mem_mem_write,
	input  logic       mem_wb_mem_read,

	output logic [1:0] ex_forward_a,
	output logic [1:0] ex_forward_b,
	output logic       mem_forward
);
	always_comb begin
		ex_forward_a = 2'b00;
		ex_forward_b = 2'b00;
		mem_forward  = 1'b0;

		if (ex_mem_reg_write && (ex_mem_rd_addr != 0) && (ex_mem_rd_addr == id_ex_rs1_addr))
			ex_forward_a = 2'b01;
		else if (mem_wb_reg_write && (mem_wb_rd_addr != 0) && (mem_wb_rd_addr == id_ex_rs1_addr))
			ex_forward_a = 2'b10;
		
		if (ex_mem_reg_write && (ex_mem_rd_addr != 0) && (ex_mem_rd_addr == id_ex_rs2_addr))
			ex_forward_b = 2'b01;
		else if (mem_wb_reg_write && (mem_wb_rd_addr != 0) && (mem_wb_rd_addr == id_ex_rs2_addr))
			ex_forward_b = 2'b10;
		
		if (ex_mem_mem_write && mem_wb_reg_write && mem_wb_mem_read &&
		   (mem_wb_rd_addr != 0) && (mem_wb_rd_addr == ex_mem_rs2_addr)) begin

			mem_forward = 1'b1;	
		end
	end
endmodule
