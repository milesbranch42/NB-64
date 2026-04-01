import rv64_pkg::*;

module csrfile #(
	parameter int XLEN = 64
)(
	input logic             clk,
	input logic             rst,

	input  logic            id_csr_re,
	input  logic            id_csr_we_intent,
	input  logic [11:0]     id_csr_raddr,
	output logic [XLEN-1:0] csr_rdata,
	output logic            csr_fault,

	input  logic            wb_csr_we,
	input  logic [11:0]     wb_csr_waddr,
	input  logic [XLEN-1:0] wb_csr_wdata,

	input  logic            wb_trap_valid,
	input  logic [4:0]      wb_trap_cause,
	input  logic [XLEN-1:0] wb_trap_tval,
	input  logic [XLEN-1:0] wb_trap_pc,

	input  logic            wb_is_mret,
	input  logic            wb_is_sret,
	input  logic            wb_is_valid,
	output logic [XLEN-1:0] trap_pc_target,

	output logic [XLEN-1:0] mepc_o,
	output logic [XLEN-1:0] sepc_o,
	output logic [1:0]      priv_o,
	output logic            mstatus_tsr,
	output logic            mstatus_tvm
);
	localparam logic [31:0] SSTATUS_MASK32  = 32'h818fe762;
	localparam logic [63:0] SSTATUS_MASK64  = 64'h80000003018de762;

	// MSTATUS.SXL = 10, MSTATUS.UXL = 10, MSTATUS.MPP = 11
	localparam logic [63:0] MSTATUS_RV64IMA = 64'h0000000a00001800;
	localparam logic [63:0] MISA_RV64IMA    = 64'h8000000000141101;

	logic [1:0] priv;

	logic csr_access;
	logic priv_fault;
	logic ro_fault;
	logic tvm_fault;
	logic unmapped_fault;

	assign csr_access = id_csr_re || id_csr_we_intent;

	assign priv_fault = (id_csr_raddr[9:8] > priv);
	assign ro_fault   = id_csr_we_intent && (id_csr_raddr[11:10] == 2'b11);
	assign tvm_fault  = (priv == 2'b01) && mstatus[20] && (id_csr_raddr == CSR_SATP);
	assign csr_fault  = csr_access && (priv_fault || ro_fault || tvm_fault || unmapped_fault);

	assign mepc_o      = mepc;
	assign sepc_o      = sepc;
	assign priv_o      = priv;
	assign mstatus_tsr = mstatus[22];
	assign mstatus_tvm = mstatus[20];

	logic [31:0]     mvendorid;
	logic [XLEN-1:0] marchid;
	logic [XLEN-1:0] mimpid;
	logic [XLEN-1:0] mhartid;
	logic [XLEN-1:0] mconfigptr;

	logic [XLEN-1:0] mstatus;
	logic [XLEN-1:0] misa;
	logic [63:0]     medeleg;
	logic [XLEN-1:0] mideleg;
	logic [XLEN-1:0] mie;
	logic [XLEN-1:0] mtvec;
	logic [31:0]     mcounteren;

	logic [XLEN-1:0] mscratch;
	logic [XLEN-1:0] mepc;
	logic [XLEN-1:0] mcause;
	logic [XLEN-1:0] mtval;
	logic [XLEN-1:0] mip;
	logic [XLEN-1:0] mtinst;
	logic [XLEN-1:0] mtval2;

	logic [63:0]     menvcfg;
	logic [63:0]     mseccfg;

	logic [XLEN-1:0] mstateen0;
	logic [XLEN-1:0] mstateen1;
	logic [XLEN-1:0] mstateen2;
	logic [XLEN-1:0] mstateen3;

	logic [XLEN-1:0] mnscratch;
	logic [XLEN-1:0] mnepc;
	logic [XLEN-1:0] mncause;
	logic [XLEN-1:0] mnstatus;

	logic [63:0]     mcycle;
	logic [63:0]     minstret;
	logic [31:0]     mcountinhibit;

	logic [63:0]     mhpmcounter [3:31];
	logic [63:0]     mhpmevent   [3:31];

	logic [XLEN-1:0] pmpcfg      [0:15];
	logic [XLEN-1:0] pmpaddr     [0:63];

	logic [XLEN-1:0] stvec;
	logic [31:0]     scounteren;
	logic [XLEN-1:0] senvcfg;

	logic [XLEN-1:0] sscratch;
	logic [XLEN-1:0] sepc;
	logic [XLEN-1:0] scause;
	logic [XLEN-1:0] stval;

	logic [XLEN-1:0] satp;

	logic [XLEN-1:0] sstateen0;
	logic [XLEN-1:0] sstateen1;
	logic [XLEN-1:0] sstateen2;
	logic [XLEN-1:0] sstateen3;

	// Debug specification not currently implemented. These are placeholders.
	logic [XLEN-1:0] tselect;
	logic [XLEN-1:0] tcontrol;
	logic [XLEN-1:0] tdata1;
	logic [XLEN-1:0] tdata2;
	logic [XLEN-1:0] tdata3;
	logic [XLEN-1:0] mcontext;

	// Need to add support for interrupts
	always_comb begin
		trap_pc_target = '0;

		if (wb_is_mret) begin
			trap_pc_target = mepc;
		end
		else if (wb_is_sret) begin
			trap_pc_target = sepc;
		end
		else if (wb_trap_valid) begin
			if (priv <= 2'b01 && medeleg[wb_trap_cause]) begin
				trap_pc_target = {stvec[XLEN-1:2], 2'b00};
			end
			else begin
				trap_pc_target = {mtvec[XLEN-1:2], 2'b00};
			end
		end
	end

	// sie: page 44
	// sip: page 44
	// scountinhibit: section 9.2 page 96
	// scountovf: Section 20.2 page 157
	// scontext: page 76

	always_ff @(posedge clk) begin
		if (rst) begin
			mcycle   <= '0;
			minstret <= '0;
		end
		else begin
			if (wb_csr_we && (wb_csr_waddr == CSR_MCYCLE)) begin
				mcycle <= 64'(wb_csr_wdata);
			end
			else if (!mcountinhibit[0]) begin
				mcycle <= mcycle + 1;
			end

			if (wb_csr_we && (wb_csr_waddr == CSR_MINSTRET)) begin
				minstret <= 64'(wb_csr_wdata);
			end
			else if (wb_is_valid && !mcountinhibit[2]) begin
				minstret <= minstret + 1;
			end
		end
	end

	always_comb begin
		csr_rdata = '0;
		unmapped_fault = 1'b0;

		// This was 'id_csr_re', but complicated the setting of unmapped_fault, since
		// id_csr_re may be zero, while id_csr_we_intent may be set. Revisit this
		// to make your architecture more elegant. ??
		if (csr_access) begin
			unique case (id_csr_raddr)
				CSR_MVENDORID:     csr_rdata = XLEN'(mvendorid);
				CSR_MARCHID:       csr_rdata = marchid;
				CSR_MIMPID:        csr_rdata = mimpid;
				CSR_MHARTID:       csr_rdata = mhartid;
				CSR_MCONFIGPTR:    csr_rdata = mconfigptr;
				CSR_MSTATUS:       csr_rdata = mstatus;
				CSR_MISA:          csr_rdata = misa;
				CSR_MEDELEG:       csr_rdata = XLEN'(medeleg);
				CSR_MIDELEG:       csr_rdata = mideleg;
				CSR_MIE:           csr_rdata = mie;
				CSR_MTVEC:         csr_rdata = mtvec;
				CSR_MCOUNTEREN:    csr_rdata = XLEN'(mcounteren);
				CSR_MSCRATCH:      csr_rdata = mscratch;
				CSR_MEPC:          csr_rdata = mepc;
				CSR_MCAUSE:        csr_rdata = mcause;
				CSR_MTVAL:         csr_rdata = mtval;
				CSR_MIP:           csr_rdata = mip;
				CSR_MTINST:        csr_rdata = mtinst;
				CSR_MTVAL2:        csr_rdata = mtval2;
				CSR_MENVCFG:       csr_rdata = XLEN'(menvcfg);
				CSR_MSECCFG:       csr_rdata = XLEN'(mseccfg);
				CSR_MSTATEEN0:     csr_rdata = mstateen0;
				CSR_MSTATEEN1:     csr_rdata = mstateen1;
				CSR_MSTATEEN2:     csr_rdata = mstateen2;
				CSR_MSTATEEN3:     csr_rdata = mstateen3;
				CSR_MNSCRATCH:     csr_rdata = mnscratch;
				CSR_MNEPC:         csr_rdata = mnepc;
				CSR_MNCAUSE:       csr_rdata = mncause;
				CSR_MNSTATUS:      csr_rdata = mnstatus;
				CSR_MCYCLE:        csr_rdata = XLEN'(mcycle);
				CSR_MINSTRET:      csr_rdata = XLEN'(minstret);
				CSR_MCOUNTINHIBIT: csr_rdata = XLEN'(mcountinhibit);

				CSR_SSTATUS:       csr_rdata = (XLEN == 32) ? (mstatus & SSTATUS_MASK32) : (mstatus & SSTATUS_MASK64);
				CSR_SIE:           csr_rdata = 0; // ?
				CSR_STVEC:         csr_rdata = stvec;
				CSR_SCOUNTEREN:    csr_rdata = XLEN'(scounteren);
				CSR_SENVCFG:       csr_rdata = senvcfg;
				CSR_SCOUNTINHIBIT: csr_rdata = 0; // ?
				CSR_SSCRATCH:      csr_rdata = sscratch;
				CSR_SEPC:          csr_rdata = sepc;
				CSR_SCAUSE:        csr_rdata = scause;
				CSR_STVAL:         csr_rdata = stval;
				CSR_SIP:           csr_rdata = 0; // ?
				CSR_SCOUNTOVF:     csr_rdata = 0; // ?
				CSR_SATP:          csr_rdata = satp;
				CSR_SCONTEXT:      csr_rdata = 0; // ?
				CSR_SSTATEEN0:     csr_rdata = sstateen0;
				CSR_SSTATEEN1:     csr_rdata = sstateen1;
				CSR_SSTATEEN2:     csr_rdata = sstateen2;
				CSR_SSTATEEN3:     csr_rdata = sstateen3;

				CSR_CYCLE:         csr_rdata = mcycle;
				CSR_TIME:          csr_rdata = mcycle; // Temporary; Supposed to be memory-mapped ??? mtime EXISTS!!
				CSR_INSTRET:       csr_rdata = minstret;

				// Revisit and decide the number of triggers
				CSR_TSELECT:       csr_rdata = tselect;
				CSR_TCONTROL:      csr_rdata = tcontrol;
				CSR_TDATA1:        csr_rdata = tdata1;
				CSR_TDATA2:        csr_rdata = tdata2;
				CSR_TDATA3:        csr_rdata = tdata3;
				CSR_MCONTEXT:      csr_rdata = mcontext;

				// Unoptimized
				default: begin
					if (id_csr_raddr >= CSR_MHPMCOUNTER && id_csr_raddr <= CSR_MHPMCOUNTER + 28) begin
						csr_rdata = XLEN'(mhpmcounter[(id_csr_raddr - CSR_MHPMCOUNTER) + 3]);
					end
					else if (id_csr_raddr >= CSR_MHPMEVENT && id_csr_raddr <= CSR_MHPMEVENT + 28) begin
						csr_rdata = XLEN'(mhpmevent[(id_csr_raddr - CSR_MHPMEVENT) + 3]);
					end
					else if (id_csr_raddr >= CSR_PMPCFG && id_csr_raddr <= CSR_PMPCFG + 15) begin
						csr_rdata = pmpcfg[id_csr_raddr - CSR_PMPCFG];
					end
					else if (id_csr_raddr >= CSR_PMPADDR && id_csr_raddr <= CSR_PMPADDR + 63) begin
						csr_rdata = pmpaddr[id_csr_raddr - CSR_PMPADDR];
					end
					else begin
						unmapped_fault = 1'b1;
					end
				end
			endcase
		end
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			priv          <= 2'b11;

			mvendorid     <= '0;
			marchid       <= '0;
			mimpid        <= '0;
			mhartid       <= '0;
			mconfigptr    <= '0;
			mstatus       <= MSTATUS_RV64IMA;
			misa          <= MISA_RV64IMA;
			medeleg       <= '0;
			mideleg       <= '0;
			mie           <= '0;
			mtvec         <= '0;
			mcounteren    <= '0;
			mscratch      <= '0;
			mepc          <= '0;
			mcause        <= '0;
			mtval         <= '0;
			mip           <= '0;
			mtinst        <= '0;
			mtval2        <= '0;
			menvcfg       <= '0;
			mseccfg       <= '0;
			mstateen0     <= '0;
			mstateen1     <= '0;
			mstateen2     <= '0;
			mstateen3     <= '0;
			mnscratch     <= '0;
			mnepc         <= '0;
			mncause       <= '0;
			mnstatus      <= '0;
			mcountinhibit <= '0;

			stvec         <= '0;
			scounteren    <= '0;
			senvcfg       <= '0;
			sscratch      <= '0;
			sepc          <= '0;
			scause        <= '0;
			stval         <= '0;
			satp          <= '0;
			sstateen0     <= '0;
			sstateen1     <= '0;
			sstateen2     <= '0;
			sstateen3     <= '0;

			for (int i = 3; i < 32; i++) begin
				mhpmcounter[i] <= '0;
				mhpmevent[i]   <= '0;
			end

			for (int i = 0; i < 16; i++) pmpcfg[i]  <= '0;
			for (int i = 0; i < 64; i++) pmpaddr[i] <= '0;
		end
		else if (wb_trap_valid) begin
			if (priv <= 2'b01 && medeleg[wb_trap_cause]) begin
				mstatus[5] <= mstatus[1]; // SPIE = SIE
				mstatus[1] <= 1'b0;       // SIE = 0
				mstatus[8] <= priv[0];    // SPP = Previous Privilege
				priv       <= 2'b01;      // S-Mode
				sepc       <= wb_trap_pc;
				scause     <= XLEN'(wb_trap_cause); // ? DOESN'T WORK FOR INTERRUPTS
				stval      <= wb_trap_tval;
			end
			else begin
				mstatus[7]     <= mstatus[3]; // MPIE = MIE
				mstatus[3]     <= 1'b0;       // MIE = 0
				mstatus[12:11] <= priv;       // MPP = Previous Privilege
				priv           <= 2'b11;      // M-Mode
				mepc           <= wb_trap_pc;
				mcause         <= XLEN'(wb_trap_cause); // ? DOESN'T WORK FOR INTERRUPTS
				mtval          <= wb_trap_tval;
			end
		end
		else if (wb_is_mret) begin
			priv           <= mstatus[12:11]; // Priv = MPP
			mstatus[3]     <= mstatus[7];     // MIE = MPIE
			mstatus[7]     <= 1'b1;           // MPIE = 1
			mstatus[12:11] <= 2'b00;          // MPP = U-Mode

			// If returning to a mode less privileged than M-Mode, clear MPRV
			if (mstatus[12:11] < 2'b11) begin
				mstatus[17] <= 1'b0;
			end
		end
		else if (wb_is_sret) begin
			priv        <= {1'b0, mstatus[8]}; // Priv = SPP
			mstatus[1]  <= mstatus[5];         // SIE = SPIE
			mstatus[5]  <= 1'b1;               // SPIE = 1
			mstatus[8]  <= 1'b0;               // SPP = U-Mode
			mstatus[17] <= 1'b0;               // Clear MPRV
		end
		else if (wb_csr_we) begin
			unique case (wb_csr_waddr)
				CSR_MSTATUS:       mstatus           <= (wb_csr_wdata & ~(XLEN'('hF) << 32)) | (XLEN'('hA) << 32); // SXL=10, UXL=10 ??
				CSR_MISA:          misa              <= wb_csr_wdata & ~(XLEN'(1) << 2); // C = 0 ??
				CSR_MEDELEG:       medeleg           <= 64'(wb_csr_wdata);
				CSR_MIDELEG:       mideleg           <= wb_csr_wdata;
				CSR_MIE:           mie               <= wb_csr_wdata;
				CSR_MTVEC:         mtvec             <= {wb_csr_wdata[XLEN-1:2], 2'b00}; // No support for vectored interrupts ??
				CSR_MCOUNTEREN:    mcounteren        <= 32'(wb_csr_wdata);
				CSR_MSCRATCH:      mscratch          <= wb_csr_wdata;
				CSR_MEPC:          mepc              <= wb_csr_wdata;
				CSR_MCAUSE:        mcause            <= wb_csr_wdata;
				CSR_MTVAL:         mtval             <= wb_csr_wdata;
				CSR_MIP:           mip               <= wb_csr_wdata;
				CSR_MTINST:        mtinst            <= wb_csr_wdata;
				CSR_MTVAL2:        mtval2            <= wb_csr_wdata;
				CSR_MENVCFG:       menvcfg           <= 64'(wb_csr_wdata);
				CSR_MSECCFG:       mseccfg           <= 64'(wb_csr_wdata);
				CSR_MSTATEEN0:     mstateen0         <= wb_csr_wdata;
				CSR_MSTATEEN1:     mstateen1         <= wb_csr_wdata;
				CSR_MSTATEEN2:     mstateen2         <= wb_csr_wdata;
				CSR_MSTATEEN3:     mstateen3         <= wb_csr_wdata;
				CSR_MNSCRATCH:     mnscratch         <= wb_csr_wdata;
				CSR_MNEPC:         mnepc             <= wb_csr_wdata;
				CSR_MNCAUSE:       mncause           <= wb_csr_wdata;
				CSR_MNSTATUS:      mnstatus          <= wb_csr_wdata;
				CSR_MCOUNTINHIBIT: mcountinhibit     <= 32'(wb_csr_wdata);

				CSR_SSTATUS:       mstatus <= (XLEN == 32) ? ((mstatus & ~SSTATUS_MASK32) | (wb_csr_wdata & SSTATUS_MASK32)) :
															 ((mstatus & ~SSTATUS_MASK64) | (wb_csr_wdata & SSTATUS_MASK64)) ;
				//CSR_SIE:           0          <= wb_csr_wdata; // ?
				CSR_STVEC:         stvec      <= wb_csr_wdata;
				CSR_SCOUNTEREN:    scounteren <= 32'(wb_csr_wdata);
				CSR_SENVCFG:       senvcfg    <= wb_csr_wdata;
				//CSR_SCOUNTINHIBIT: 0          <= wb_csr_wdata; // ?
				CSR_SSCRATCH:      sscratch   <= wb_csr_wdata;
				CSR_SEPC:          sepc       <= wb_csr_wdata;
				CSR_SCAUSE:        scause     <= wb_csr_wdata;
				CSR_STVAL:         stval      <= wb_csr_wdata;
				//CSR_SIP:           0          <= wb_csr_wdata; // ?
				CSR_SATP:          satp       <= wb_csr_wdata;
				//CSR_SCONTEXT:      0          <= wb_csr_wdata; // ?
				CSR_SSTATEEN0:     sstateen0  <= wb_csr_wdata;
				CSR_SSTATEEN1:     sstateen1  <= wb_csr_wdata;
				CSR_SSTATEEN2:     sstateen2  <= wb_csr_wdata;
				CSR_SSTATEEN3:     sstateen3  <= wb_csr_wdata;

				CSR_TSELECT:       tselect    <= wb_csr_wdata;
				CSR_TCONTROL:      tcontrol   <= wb_csr_wdata;
				CSR_TDATA1:        tdata1     <= wb_csr_wdata;
				CSR_TDATA2:        tdata2     <= wb_csr_wdata;
				CSR_TDATA3:        tdata3     <= wb_csr_wdata;
				CSR_MCONTEXT:      mcontext   <= wb_csr_wdata;

				default: begin
					if (wb_csr_waddr >= CSR_MHPMCOUNTER && wb_csr_waddr <= CSR_MHPMCOUNTER + 28) begin
						mhpmcounter[(wb_csr_waddr - CSR_MHPMCOUNTER) + 3] <= 64'(wb_csr_wdata);
					end
					else if (wb_csr_waddr >= CSR_MHPMEVENT && wb_csr_waddr <= CSR_MHPMEVENT + 28) begin
						mhpmevent[(wb_csr_waddr - CSR_MHPMEVENT) + 3] <= 64'(wb_csr_wdata);
					end
					else if (wb_csr_waddr >= CSR_PMPCFG && wb_csr_waddr <= CSR_PMPCFG + 15) begin
						pmpcfg[wb_csr_waddr - CSR_PMPCFG] <= wb_csr_wdata;
					end
					else if (wb_csr_waddr >= CSR_PMPADDR && wb_csr_waddr <= CSR_PMPADDR + 63) begin
						pmpaddr[wb_csr_waddr - CSR_PMPADDR] <= wb_csr_wdata;
					end
				end
			endcase
		end
	end
endmodule
