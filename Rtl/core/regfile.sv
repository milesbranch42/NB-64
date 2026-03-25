module regfile #(
	parameter int XLEN = 64
)(
	input  logic            clk,
	input  logic            rst,
	input  logic            we,
	input  logic [4:0]      rs1_addr,
	input  logic [4:0]      rs2_addr,
	input  logic [4:0]      rd_addr,
	input  logic [XLEN-1:0] wdata,
	output logic [XLEN-1:0] rs1_data,
	output logic [XLEN-1:0] rs2_data
);
	logic [XLEN-1:0] regs [0:31];

	always_comb begin

		if (rs1_addr == 5'd0)
			rs1_data = '0;
		else if (we && (rd_addr == rs1_addr))
			rs1_data = wdata;
		else
			rs1_data = regs[rs1_addr];
		
		if (rs2_addr == 5'd0)
			rs2_data = '0;
		else if (we && (rd_addr == rs2_addr))
			rs2_data = wdata;
		else
			rs2_data = regs[rs2_addr];
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			for (int i = 0; i < 32; i++) begin
				regs[i] <= '0;
			end
		end
		else if (we && (rd_addr != 5'd0)) begin
			regs[rd_addr] <= wdata;
		end
	end
endmodule
