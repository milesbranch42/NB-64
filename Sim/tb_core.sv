module tb_core;
	localparam int XLEN = 64;
	localparam int ICACHE_DEPTH = 4096;
	localparam int DCACHE_DEPTH = 65536;
	localparam logic [XLEN-1:0] RESET_VECTOR = '0;

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
		.addr  (icache_addr),
		.rdata (icache_rdata)
	);

	dcache #(
		.XLEN      (XLEN),
		.DEPTH     (DCACHE_DEPTH)
	) u_dcache (
		.clk       (clk),
		.req_read  (dcache_read),
		.req_write (dcache_we), // Was dcache_write
		.req_size  (dcache_size),
		.req_addr  (dcache_addr),
		.req_wdata (dcache_wdata),
		.rdata     (dcache_rdata)
	);

	logic is_uart_addr;
	logic dcache_we;

	assign is_uart_addr = (dcache_addr == 64'h10000000);
	assign dcache_we = dcache_write && !is_uart_addr;

	always_ff @(posedge clk) begin
		if (dcache_write && is_uart_addr) begin
			$write("%c", dcache_wdata[7:0]);
		end
	end

	initial clk = 0;
	always #5 clk = ~clk;

	string imem_hex_path;
	string dmem_hex_path;

	initial begin
		if ($value$plusargs("IMEM=%s", imem_hex_path)) begin
        	$display("Loading IMEM from %s", imem_hex_path);
        	$readmemh(imem_hex_path, u_icache.mem);
    	end
		else begin
        	$display("Error: No IMEM file specified. Use +IMEM=<file>");
        	$finish;
    	end

    	if ($value$plusargs("DMEM=%s", dmem_hex_path)) begin
        	$display("Loading DMEM from %s", dmem_hex_path);
        	$readmemh(dmem_hex_path, u_dcache.mem);
    	end
		else begin
        	$display("Error: No DMEM file specified. Use +DMEM=<file>");
        	$finish;
    	end

		rst = 1;
		@(negedge clk);

		rst = 0;
		repeat (1000000) @(negedge clk);

		$display("\nSimulation Timeout.");
		$finish;
	end
endmodule

// ALERT!!! "logic vec = val" IS NOT CONTINUOUS ASSIGNMENT! IT IS ONLY INITIAL!!