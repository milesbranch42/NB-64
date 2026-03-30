module tb_riscv_tests;
	localparam int XLEN = 64;
	localparam int ICACHE_DEPTH = 4096;
	localparam int DCACHE_DEPTH = 65536;
	localparam logic [XLEN-1:0] RESET_VECTOR = 64'h80000000;

	logic            clk;
	logic            rst;

	logic [XLEN-1:0] icache_addr;
	logic [31:0]     icache_rdata;

	logic            dcache_read;
	logic            dcache_write;
	logic [1:0]      dcache_size;
	logic [XLEN-1:0] dcache_addr;
	logic [XLEN-1:0] dcache_wdata;
	logic [XLEN-1:0] dcache_rdata;

	core #(
		.XLEN         (XLEN),
		.RESET_VECTOR (RESET_VECTOR)
	) u_core (
		.clk          (clk),
		.rst          (rst),
		.icache_addr  (icache_addr),
		.icache_rdata (icache_rdata),
		.dcache_read  (dcache_read),
		.dcache_write (dcache_write),
		.dcache_size  (dcache_size),
		.dcache_addr  (dcache_addr),
		.dcache_wdata (dcache_wdata),
		.dcache_rdata (dcache_rdata)
	);

	icache #(
		.XLEN  (XLEN),
		.DEPTH (ICACHE_DEPTH)
	) u_icache (
		.clk   (clk),
		.rst   (rst),
		.addr  (icache_addr & 64'h0FFF_FFFF), // Hacky. Need to change.
		.rdata (icache_rdata)
	);

	dcache #(
		.XLEN      (XLEN),
		.DEPTH     (DCACHE_DEPTH)
	) u_dcache (
		.clk       (clk),
		.req_read  (dcache_read),
		.req_write (dcache_write),
		.req_size  (dcache_size),
		.req_addr  (dcache_addr & 64'h0FFF_FFFF), // Also change.
		.req_wdata (dcache_wdata),
		.rdata     (dcache_rdata)
	);

	initial clk = 0;
	always #5 clk = ~clk;

	string imem_hex_path;
	string dmem_hex_path;

	logic [XLEN-1:0] tohost_addr;
	logic            tohost_found;

	initial begin
	
		if (!$value$plusargs("TOHOST=%x", tohost_addr)) begin
			$display("Error: No TOHOST address specified. Use +TOHOST=<addr>");
			$finish;
		end

		if (!$value$plusargs("IMEM=%s", imem_hex_path)) begin
			$display("Error: No IMEM file specified. Use +IMEM=<file>");
        	$finish;
		end

		if (!$value$plusargs("DMEM=%s", dmem_hex_path)) begin
			$display("Error: No DMEM file specified. Use +DMEM=<file>");
        	$finish;
		end

		$readmemh(imem_hex_path, u_icache.mem);
		$readmemh(dmem_hex_path, u_dcache.mem);

		rst = 1;
		@(negedge clk);

		rst = 0;
		repeat (1000000) @(negedge clk);

		$display("TIMEOUT: Test did not write to tohost in time.");
		$finish;
	end

	always_ff @(posedge clk) begin
		if (dcache_write && dcache_addr == tohost_addr) begin
			if (dcache_wdata == 64'h1) begin
				$display("PASS");
				$finish;
			end
			else if (dcache_wdata > 64'h1) begin
				$display("FAIL: Test %0d", dcache_wdata >> 1);
				$finish;
			end
		end

		// DEBUG
		$display("%016h", u_core.mem_wb.pc);
	end
endmodule
