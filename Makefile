CROSS_COMPILE ?= riscv64-unknown-elf-
CC            := $(CROSS_COMPILE)gcc
OBJCOPY       := $(CROSS_COMPILE)objcopy
OBJDUMP       := $(CROSS_COMPILE)objdump
VERILATOR     := verilator

SW_DIR        := Sw
RTL_DIR       := Rtl
BUILD_DIR     := Build
SIM_DIR       := $(BUILD_DIR)/sim

RTL_SRCS      := $(shell find $(RTL_DIR) -name "*.sv" -o -name "*.v")
V_FLAGS       := -sv --binary -I$(RTL_DIR) -Wno-fatal --Mdir $(SIM_DIR)

# Standard Simulation (tb_core)
TOP_MODULE    := tb_core
SIM_EXE       := $(SIM_DIR)/V$(TOP_MODULE)

# RISC-V ISA Tests (tb_riscv_tests)
RISCV_TESTS_DIR ?= ~/Downloads/riscv-tests/isa
TEST_PATTERN    ?= rv64ui-p-*
ISA_TOP_MODULE  := tb_riscv_tests
ISA_SIM_EXE     := $(SIM_DIR)/V$(ISA_TOP_MODULE)

# Software Compilation
TEST          ?= basic
TEST_DIR      := $(BUILD_DIR)/tests/$(TEST)
SW_SRCS       := $(wildcard $(SW_DIR)/$(TEST)/*.c) $(wildcard $(SW_DIR)/$(TEST)/*.S)
SW_COMMON     := $(SW_DIR)/common/crt0.S
LINK_LD       := $(SW_DIR)/common/link.ld

ELF           := $(TEST_DIR)/$(TEST).elf
BIN           := $(TEST_DIR)/$(TEST).bin
HEX_I         := $(TEST_DIR)/imem.hex
HEX_D         := $(TEST_DIR)/dmem.hex

CFLAGS        := -march=rv64ima_zicsr_zifencei -mabi=lp64 -static \
                 -mcmodel=medany -ffreestanding -nostdlib -T $(LINK_LD)

.PHONY: all run clean test-isa

all: $(SIM_EXE) $(HEX_I) $(HEX_D)

$(SIM_EXE): $(RTL_SRCS) Sim/$(TOP_MODULE).sv
	@echo "--- Building Simulator ($(TOP_MODULE)) ---"
	@mkdir -p $(SIM_DIR)
	$(VERILATOR) $(V_FLAGS) --top-module $(TOP_MODULE) -o V$(TOP_MODULE) $^

$(ISA_SIM_EXE): $(RTL_SRCS) Sim/$(ISA_TOP_MODULE).sv
	@echo "--- Building ISA Simulator ($(ISA_TOP_MODULE)) ---"
	@mkdir -p $(SIM_DIR)
	$(VERILATOR) $(V_FLAGS) --top-module $(ISA_TOP_MODULE) -o V$(ISA_TOP_MODULE) $^

$(ELF): $(SW_SRCS) $(SW_COMMON) $(LINK_LD)
	@echo "--- Compiling SW: $(TEST) ---"
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(SW_COMMON) $(SW_SRCS) -o $@

$(BIN): $(ELF)
	@echo "--- Extracting Binary & Dump ---"
	$(OBJCOPY) -O binary $< $@
	$(OBJDUMP) -D $< > $(TEST_DIR)/$(TEST).dump

$(HEX_I): $(BIN)
	@echo "--- Generating IMEM Hex ---"
	hexdump -v -e '1/4 "%08x\n"' $< > $@

$(HEX_D): $(BIN)
	@echo "--- Generating DMEM Hex ---"
	hexdump -v -e '1/1 "%02x\n"' $< > $@

run: $(SIM_EXE) $(HEX_I) $(HEX_D)
	@echo "--- Running Simulation: $(TEST) ---"
	$(SIM_EXE) +IMEM=$(HEX_I) +DMEM=$(HEX_D)

test-isa: $(ISA_SIM_EXE)
	@echo "--- Running ISA Tests ($(TEST_PATTERN)) ---"
	@./Scripts/run_riscv_tests.sh $(RISCV_TESTS_DIR) $(ISA_SIM_EXE) $(TEST_PATTERN)

clean:
	@echo "--- Cleaning Build Directory ---"
	rm -rf $(BUILD_DIR)/*
