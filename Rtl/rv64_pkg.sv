package rv64_pkg;

	parameter int XLEN = 64;

	// Matches opcode
	typedef enum logic [6:0] {
		OP_LOAD     = 7'b0000011,
		OP_STORE    = 7'b0100011,
		OP_MADD     = 7'b1000011,
		OP_BRANCH   = 7'b1100011,
		OP_LOAD_FP  = 7'b0000111,
		OP_STORE_FP = 7'b0100111,
		OP_MSUB     = 7'b1000111,
		OP_JALR     = 7'b1100111,
		OP_CUSTOM0  = 7'b0001011,
		OP_CUSTOM1  = 7'b0101011,
		OP_NMSUB    = 7'b1001011,
		OP_RESERVED = 7'b1101011,
		OP_MISC_MEM = 7'b0001111,
		OP_AMO      = 7'b0101111,
		OP_NMADD    = 7'b1001111,
		OP_JAL      = 7'b1101111,
		OP_IMM      = 7'b0010011,
		OP_REG      = 7'b0110011,
		OP_FP       = 7'b1010011,
		OP_SYSTEM   = 7'b1110011,
		OP_AUIPC    = 7'b0010111,
		OP_LUI      = 7'b0110111,
		OP_V        = 7'b1010111,
		OP_VE       = 7'b1110111,
		OP_IMM_32   = 7'b0011011,
		OP_REG_32   = 7'b0111011,
		OP_CUSTOM2  = 7'b1011011,
		OP_CUSTOM3  = 7'b1111011
	} opcode_t;

	// RV64 M+S Mode
	typedef enum logic [11:0] {
		CSR_MVENDORID     = 12'hF11,
		CSR_MARCHID       = 12'hF12,
		CSR_MIMPID        = 12'hF13,
		CSR_MHARTID       = 12'hF14,
		CSR_MCONFIGPTR    = 12'hF15,
		CSR_MSTATUS       = 12'h300,
		CSR_MISA          = 12'h301,
		CSR_MEDELEG       = 12'h302,
		CSR_MIDELEG       = 12'h303,
		CSR_MIE           = 12'h304,
		CSR_MTVEC         = 12'h305,
		CSR_MCOUNTEREN    = 12'h306,
		CSR_MSCRATCH      = 12'h340,
		CSR_MEPC          = 12'h341,
		CSR_MCAUSE        = 12'h342,
		CSR_MTVAL         = 12'h343,
		CSR_MIP           = 12'h344,
		CSR_MTINST        = 12'h34A,
		CSR_MTVAL2        = 12'h34B,
		CSR_MENVCFG       = 12'h30A,
		CSR_MSECCFG       = 12'h747,
		CSR_PMPCFG        = 12'h3A0,
		CSR_PMPADDR       = 12'h3B0,
		CSR_MSTATEEN0     = 12'h30C,
		CSR_MSTATEEN1     = 12'h30D,
		CSR_MSTATEEN2     = 12'h30E,
		CSR_MSTATEEN3     = 12'h30F,
		CSR_MNSCRATCH     = 12'h740,
		CSR_MNEPC         = 12'h741,
		CSR_MNCAUSE       = 12'h742,
		CSR_MNSTATUS      = 12'h744,
		CSR_MCYCLE        = 12'hB00,
		CSR_MINSTRET      = 12'hB02,
		CSR_MHPMCOUNTER   = 12'hB03,
		CSR_MCOUNTINHIBIT = 12'h320,
		CSR_MHPMEVENT     = 12'h323,

		CSR_SSTATUS       = 12'h100,
		CSR_SIE           = 12'h104,
		CSR_STVEC         = 12'h105,
		CSR_SCOUNTEREN    = 12'h106,
		CSR_SENVCFG       = 12'h10A,
		CSR_SCOUNTINHIBIT = 12'h120,
		CSR_SSCRATCH      = 12'h140,
		CSR_SEPC          = 12'h141,
		CSR_SCAUSE        = 12'h142,
		CSR_STVAL         = 12'h143,
		CSR_SIP           = 12'h144,
		CSR_SCOUNTOVF     = 12'hDA0,
		CSR_SATP          = 12'h180,
		CSR_SCONTEXT      = 12'h5A8,
		CSR_SSTATEEN0     = 12'h10C,
		CSR_SSTATEEN1     = 12'h10D,
		CSR_SSTATEEN2     = 12'h10E,
		CSR_SSTATEEN3     = 12'h10F,

		CSR_CYCLE         = 12'hC00,
		CSR_TIME          = 12'hC01,
		CSR_INSTRET       = 12'hC02,

		CSR_TSELECT       = 12'h7A0,
		CSR_TCONTROL      = 12'h7A5,
		CSR_TDATA1        = 12'h7A1,
		CSR_TDATA2        = 12'h7A2,
		CSR_TDATA3        = 12'h7A3,
		CSR_MCONTEXT      = 12'h7A8
	} csr_addr_t;

	typedef enum logic [4:0] {
		EXC_INSTR_ADDR_MISALIGNED = 5'd0,
		EXC_INSTR_ACCESS_FAULT    = 5'd1,
		EXC_ILLEGAL_INSTR         = 5'd2,
		EXC_BREAKPOINT            = 5'd3,
		EXC_LOAD_ADDR_MISALIGNED  = 5'd4,
		EXC_LOAD_ACCESS_FAULT     = 5'd5,
		EXC_STORE_ADDR_MISALIGNED = 5'd6, // Valid for AMOs
		EXC_STORE_ACCESS_FAULT    = 5'd7, // Valid for AMOs
		EXC_U_ECALL               = 5'd8,
		EXC_S_ECALL               = 5'd9,
		EXC_M_ECALL               = 5'd11,
		EXC_INSTR_PAGE_FAULT      = 5'd12,
		EXC_LOAD_PAGE_FAULT       = 5'd13,
		EXC_STORE_PAGE_FAULT      = 5'd15,
		EXC_DOUBLE_TRAP           = 5'd16,
		EXC_SOFTWARE_CHECK        = 5'd18,
		EXC_HARDWARE_ERROR        = 5'd19
	} exc_cause_t;

	typedef enum logic [4:0] {
		INT_S_SOFTWARE       = 5'd1,
		INT_M_SOFTWARE       = 5'd3,
		INT_S_TIMER          = 5'd5,
		INT_M_TIMER          = 5'd7,
		INT_S_EXTERNAL       = 5'd9,
		INT_M_EXTERNAL       = 5'd11,
		INT_COUNTER_OVERFLOW = 5'd13
	} int_cause_t;

	// {alt(sub/sra), is_mul, funct3}
	typedef enum logic [4:0] {
		ALU_ADD     = 5'b00000,
		ALU_SUB     = 5'b10000,
		ALU_SLL     = 5'b00001,
		ALU_SLT     = 5'b00010,
		ALU_SLTU    = 5'b00011,
		ALU_XOR     = 5'b00100,
		ALU_SRL     = 5'b00101,
		ALU_SRA     = 5'b10101,
		ALU_OR      = 5'b00110,
		ALU_AND     = 5'b00111,
		ALU_MUL     = 5'b01000,
		ALU_MULH    = 5'b01001,
		ALU_MULHSU  = 5'b01010,
		ALU_MULHU   = 5'b01011,
		ALU_DIV     = 5'b01100,
		ALU_DIVU    = 5'b01101,
		ALU_REM     = 5'b01110,
		ALU_REMU    = 5'b01111
	} alu_op_t;

	// funct3
	typedef enum logic [2:0] {
		BR_EQ  = 3'b000,
		BR_NE  = 3'b001,
		BR_LT  = 3'b100,
		BR_GE  = 3'b101,
		BR_LTU = 3'b110,
		BR_GEU = 3'b111
	} branch_op_t;

	// funct5
	typedef enum logic [4:0] {
		AMO_LR   = 5'b00010,
		AMO_SC   = 5'b00011,
		AMO_SWAP = 5'b00001,
		AMO_ADD  = 5'b00000,
		AMO_XOR  = 5'b00100,
		AMO_AND  = 5'b01100,
		AMO_OR   = 5'b01000,
		AMO_MIN  = 5'b10000,
		AMO_MAX  = 5'b10100,
		AMO_MINU = 5'b11000,
		AMO_MAXU = 5'b11100
	} amo_op_t;

	typedef struct packed {
		alu_op_t    alu_op;
		logic       word_op;
		logic       op1_is_pc;
		logic       op2_is_imm;
		logic       is_jump;
		logic       is_jalr;
		logic       is_branch;
		branch_op_t branch_op;
	} ex_ctrl_t;

	typedef struct packed {
		logic       read;
		logic       write;
		logic       is_unsigned;
		logic [1:0] size;
		logic       is_amo;
		amo_op_t    amo_op;
	} mem_ctrl_t;

	typedef struct packed {
		logic reg_write;
		logic wb_sel; // 0=ex_result, 1=mem_result
	} wb_ctrl_t;

	typedef struct packed {
		logic            we;
		logic [1:0]      op;
		logic            imm_op;
		logic [11:0]     waddr;
	} csr_ctrl_t;

	typedef struct packed {
		logic      is_fencei;
		logic      is_mret;
		logic      is_sret;
		logic      is_wfi;
		logic      is_csr;
		csr_ctrl_t csr_ctrl;
	} sys_ctrl_t;

	typedef struct packed {
		logic            valid;
		logic            is_int;
		logic [4:0]      cause;
		logic [XLEN-1:0] tval;
	} trap_ctrl_t;

	typedef struct packed {
		logic            inst_valid;
		logic [XLEN-1:0] pc;
		logic [XLEN-1:0] pc_plus_4;
		logic [31:0]     instr;
		trap_ctrl_t      trap_ctrl;
	} if_id_reg_t;

	typedef struct packed {
		logic            inst_valid;
		logic [XLEN-1:0] pc;
		logic [XLEN-1:0] pc_plus_4;
		logic [XLEN-1:0] imm;
		logic [XLEN-1:0] rs1_val;
		logic [XLEN-1:0] rs2_val;
		logic [XLEN-1:0] csr_rdata;
		logic [4:0]      rs1_addr;
		logic [4:0]      rs2_addr;
		logic [4:0]      rd_addr;
		ex_ctrl_t        ex_ctrl;
		mem_ctrl_t       mem_ctrl;
		wb_ctrl_t        wb_ctrl;
		sys_ctrl_t       sys_ctrl;
		trap_ctrl_t      trap_ctrl;
	} id_ex_reg_t;

	typedef struct packed {
		logic            inst_valid;
		logic [XLEN-1:0] pc;
		logic [XLEN-1:0] pc_plus_4;
		logic [XLEN-1:0] ex_result;
		logic [XLEN-1:0] mem_wdata;
		logic [XLEN-1:0] csr_wdata;
		logic [4:0]      rs2_addr;
		logic [4:0]      rd_addr;
		mem_ctrl_t       mem_ctrl;
		wb_ctrl_t        wb_ctrl;
		sys_ctrl_t       sys_ctrl;
		trap_ctrl_t      trap_ctrl;
	} ex_mem_reg_t;

	typedef struct packed {
		logic            inst_valid;
		logic [XLEN-1:0] pc;
		logic [XLEN-1:0] pc_plus_4;
		logic [XLEN-1:0] ex_result;
		logic [XLEN-1:0] mem_result;
		logic [XLEN-1:0] csr_wdata;
		logic [4:0]      rd_addr;
		logic            mem_read;
		wb_ctrl_t        wb_ctrl;
		sys_ctrl_t       sys_ctrl;
		trap_ctrl_t      trap_ctrl;
	} mem_wb_reg_t;
endpackage
