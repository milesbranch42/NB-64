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
	logic            is_lr;
	logic            is_sc;
	logic            is_amo;

	logic [XLEN-1:0] rs2_fwd_data;
	logic [XLEN-1:0] loaded_data;

	logic [XLEN-1:0] amo_op1;
	logic [XLEN-1:0] amo_op2;
	logic [XLEN-1:0] amo_result;

	logic            sc_success;
	logic            reservation_valid;
	logic [1:0]      reservation_size;
	logic [XLEN-1:0] reservation_addr;

	logic            amo_misaligned;

	wb_ctrl_t        mem_wb_ctrl;
	sys_ctrl_t       mem_sys_ctrl;
	trap_ctrl_t      mem_trap_ctrl;

	logic [XLEN-1:0] final_mem_result;

	assign is_lr  = (ex_mem.mem_ctrl.amo_op == AMO_LR);
	assign is_sc  = (ex_mem.mem_ctrl.amo_op == AMO_SC);
	assign is_amo = ex_mem.mem_ctrl.is_amo && !is_lr && !is_sc; // Change mem_ctrl.is_amo to mem_ctrl.is_atomic in the future for clarity

	assign rs2_fwd_data = mem_forward ? wb_rf_wdata : ex_mem.mem_wdata;

    always_comb begin
        loaded_data = '0;
        
        if (ex_mem.mem_ctrl.read) begin
            unique case (ex_mem.mem_ctrl.size)
                2'b00:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {56{1'b0}}, dcache_rdata[7:0]  } : { {56{dcache_rdata[7]}},  dcache_rdata[7:0]  };
                2'b01:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {48{1'b0}}, dcache_rdata[15:0] } : { {48{dcache_rdata[15]}}, dcache_rdata[15:0] };
                2'b10:   loaded_data = ex_mem.mem_ctrl.is_unsigned ? { {32{1'b0}}, dcache_rdata[31:0] } : { {32{dcache_rdata[31]}}, dcache_rdata[31:0] };
                2'b11:   loaded_data = dcache_rdata;
                default: loaded_data = '0;
            endcase
        end
    end

	assign amo_op1 = loaded_data;
	assign amo_op2 = (ex_mem.mem_ctrl.size == 2'b10) ? { {32{rs2_fwd_data[31]}}, rs2_fwd_data[31:0] } : rs2_fwd_data;

	always_comb begin
		unique case (ex_mem.mem_ctrl.amo_op)
			AMO_SWAP: amo_result = amo_op2;
			AMO_ADD:  amo_result = amo_op1 + amo_op2;
			AMO_XOR:  amo_result = amo_op1 ^ amo_op2;
			AMO_AND:  amo_result = amo_op1 & amo_op2;
			AMO_OR:   amo_result = amo_op1 | amo_op2;
			AMO_MIN:  amo_result = ($signed(amo_op1) < $signed(amo_op2)) ? amo_op1 : amo_op2;
			AMO_MAX:  amo_result = ($signed(amo_op1) > $signed(amo_op2)) ? amo_op1 : amo_op2;
			AMO_MINU: amo_result = (amo_op1 < amo_op2) ? amo_op1 : amo_op2;
			AMO_MAXU: amo_result = (amo_op1 > amo_op2) ? amo_op1 : amo_op2;
			default:  amo_result = '0;
		endcase
	end

	assign sc_success = is_sc && reservation_valid             &&
						(reservation_addr == ex_mem.ex_result) &&
						(reservation_size == ex_mem.mem_ctrl.size);

	always_ff @(posedge clk) begin
		if (rst || flush) begin
			reservation_valid <= 1'b0;
			reservation_size  <= 2'b0;
			reservation_addr  <= '0;
		end
		else if (!stall && !mem_trap_ctrl.valid) begin // Check trap mask
			if (is_lr) begin
				reservation_valid <= 1'b1;
				reservation_size  <= ex_mem.mem_ctrl.size;
				reservation_addr  <= ex_mem.ex_result;
			end
			else if (is_sc) begin
				reservation_valid <= 1'b0;
			end
		end
	end

	assign amo_misaligned = ex_mem.mem_ctrl.is_amo && (
							(ex_mem.mem_ctrl.size == 2'b10 && ex_mem.ex_result[1:0] != 2'b00) ||
							(ex_mem.mem_ctrl.size == 2'b11 && ex_mem.ex_result[2:0] != 3'b000));

	always_comb begin
		mem_wb_ctrl   = ex_mem.wb_ctrl;
		mem_sys_ctrl  = ex_mem.sys_ctrl;
		mem_trap_ctrl = ex_mem.trap_ctrl;

		if (amo_misaligned && !ex_mem.trap_ctrl.valid) begin
			mem_trap_ctrl.valid = 1'b1;
			mem_trap_ctrl.tval  = ex_mem.ex_result;
			mem_trap_ctrl.cause = is_lr ? EXC_LOAD_ADDR_MISALIGNED : EXC_STORE_ADDR_MISALIGNED;

			mem_wb_ctrl  = '0;
			mem_sys_ctrl = '0;
		end
	end

    assign dcache_read  = ex_mem.mem_ctrl.read && !mem_trap_ctrl.valid;
    assign dcache_write = ex_mem.mem_ctrl.write && (!is_sc || sc_success) && !mem_trap_ctrl.valid;
    assign dcache_size  = ex_mem.mem_ctrl.size;
    assign dcache_addr  = ex_mem.ex_result;
	assign dcache_wdata = is_amo ? amo_result : rs2_fwd_data;

	always_comb begin
		if (is_sc) begin
			final_mem_result = sc_success ? '0 : XLEN'(1);
		end
		else begin
			final_mem_result = loaded_data;
		end
	end

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            mem_wb <= '0;
        end
        else if (!stall) begin
			mem_wb.inst_valid <= ex_mem.inst_valid; // Clarify naming convention
            mem_wb.pc         <= ex_mem.pc;
            mem_wb.ex_result  <= ex_mem.ex_result;
            mem_wb.mem_result <= final_mem_result;
			mem_wb.csr_wdata  <= ex_mem.csr_wdata;
            mem_wb.rd_addr    <= ex_mem.rd_addr;
			mem_wb.mem_read   <= ex_mem.mem_ctrl.read;
            mem_wb.wb_ctrl    <= mem_wb_ctrl;
            mem_wb.sys_ctrl   <= mem_sys_ctrl;
            mem_wb.trap_ctrl  <= mem_trap_ctrl;
        end
    end
endmodule
