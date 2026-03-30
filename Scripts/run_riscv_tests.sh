#!/bin/bash

TEST_DIR=$1
SIM_EXE=$2
TEST_PATTERN=${3:-"rv64ui-p-*"}
BUILD_DIR="Build/isa_tests"
LOG_DIR="$BUILD_DIR/logs"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$BUILD_DIR"
mkdir -p "$LOG_DIR"

echo "====================================="
echo "   Running RISC-V ISA Tests          "
echo "====================================="

PASSED=0
FAILED=0

for elf_file in "$TEST_DIR"/$TEST_PATTERN; do
	if [[ "$elf_file" == *".dump" ]] || [[ -d "$elf_file" ]]; then
		continue
	fi

	test_name=$(basename "$elf_file")

	tohost_hex=$(riscv64-unknown-elf-nm "$elf_file" | grep " tohost$" | awk '{print $1}')
	
	if [ -z "$tohost_hex" ]; then
		printf "%-35s ${RED}ERROR${NC}: No 'tohost' symbol found.\n" "[$test_name]"
		continue
	fi

	bin_file="$BUILD_DIR/$test_name.bin"
	imem_hex="$BUILD_DIR/$test_name.imem.hex"
	dmem_hex="$BUILD_DIR/$test_name.dmem.hex"

	riscv64-unknown-elf-objcopy -O binary "$elf_file" "$bin_file"
	hexdump -v -e '1/4 "%08x\n"' "$bin_file" > "$imem_hex"
	hexdump -v -e '1/1 "%02x\n"' "$bin_file" > "$dmem_hex"

	sim_output=$($SIM_EXE +IMEM="$imem_hex" +DMEM="$dmem_hex" +TOHOST="$tohost_hex" 2>&1)

	if echo "$sim_output" | grep -q "PASS"; then
		printf "%-35s ${GREEN}PASS${NC}\n" "[$test_name]"
		((PASSED++))
	elif echo "$sim_output" | grep -q "FAIL"; then
		fail_reason=$(echo "$sim_output" | grep "FAIL")
		printf "%-35s ${RED}%s${NC}\n" "[$test_name]" "$fail_reason"
		echo "$sim_output" > "$LOG_DIR/$test_name.log"
		((FAILED++))
	else
		printf "%-35s ${RED}TIMEOUT / CRASH${NC}\n" "[$test_name]"
		echo "$sim_output" > "$LOG_DIR/$test_name.log"
		((FAILED++))
	fi
done

echo "====================================="
echo " Passed: $PASSED | Failed: $FAILED"
echo "====================================="
