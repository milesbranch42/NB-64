CROSS_COMPILE ?= riscv64-unknown-elf-
CC            := $(CROSS_COMPILE)gcc
OBJCOPY       := $(CROSS_COMPILE)objcopy
OBJDUMP       := $(CROSS_COMPILE)objdump
VERILATOR     := verilator

SW_DIR        := Sw
RTL_DIR       := Rtl
BUILD_DIR     := Build

RTL_SRCS      := $(shell find $(RTL_DIR) -name "*.sv" -o -name "*.v") Sim/tb_core.sv
TOP_MODULE    := tb_core
SIM_DIR       := $(BUILD_DIR)/sim
SIM_EXE       := $(SIM_DIR)/V$(TOP_MODULE)

TEST          ?= basic
TEST_DIR      := $(BUILD_DIR)/tests/$(TEST)
SW_SRCS       := $(wildcard $(SW_DIR)/$(TEST)/*.c) $(wildcard $(SW_DIR)/$(TEST)/*.S)
SW_COMMON     := $(SW_DIR)/common/crt0.S
LINK_LD       := $(SW_DIR)/common/link.ld

ELF           := $(TEST_DIR)/$(TEST).elf
BIN           := $(TEST_DIR)/$(TEST).bin
HEX_I         := $(TEST_DIR)/imem.hex
HEX_D         := $(TEST_DIR)/dmem.hex

V_FLAGS       := -sv --binary --top-module $(TOP_MODULE) -I$(RTL_DIR) -Wno-fatal --Mdir $(SIM_DIR)
CFLAGS        := -march=rv64ima_zicsr_zifencei -mabi=lp64 -static \
				 -mcmodel=medany -ffreestanding -nostdlib -T $(LINK_LD)

.PHONY: all run clean

all: $(SIM_EXE) $(HEX_I) $(HEX_D)

$(SIM_EXE): $(RTL_SRCS)
	@echo "--- Building Simulator ---"
	@mkdir -p $(SIM_DIR)
	$(VERILATOR) $(V_FLAGS) -o V$(TOP_MODULE) $^

$(ELF): $(SW_SRCS) $(SW_COMMON) $(LINK_LD)
	@echo "--- Compiling SW: $(TEST) ---"
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(SW_COMMON) $(SW_SRCS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@
	$(OBJDUMP) -D $< > $(TEST_DIR)/$(TEST).dump

$(HEX_I): $(BIN)
	hexdump -v -e '1/4 "%08x\n"' $< > $@

$(HEX_D): $(BIN)
	hexdump -v -e '1/1 "%02x\n"' $< > $@

run: $(SIM_EXE) $(HEX_I) $(HEX_D)
	@echo "--- Running Simulation: $(TEST) ---"
	$(SIM_EXE) +IMEM=$(HEX_I) +DMEM=$(HEX_D)

clean:
	rm -rf $(BUILD_DIR)/*
