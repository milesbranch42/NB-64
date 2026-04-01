# Changelog
All notable changes to the NB-64 project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- **Atomic Extension:** Implemented the RV64A extension, including Load-Reserved (LR), Store-Conditional (SC), and Atomic Memory Operations (AMO) ALU logic in the memory stage.
- **Initial Core:** Basic RV64IM pipeline implementation (IF, ID, EX, MEM, WB stages).
- **CSR Support:** Implemented M-mode and S-mode registers, along with `cycle` and `instret` hardware performance monitors. (Added stubs/placeholders for `time` and debug registers).
- **ID Stage CSR Interface:** Wired the CSR file read interface directly into the Instruction Decode (ID) stage.
- **CSR Immediate Control:** Added the `imm_op` flag to `csr_ctrl_t` to handle CSR immediate instructions.

### Changed
- **Hazard Unit Signals:** Renamed `ex_is_load` to `ex_result_delayed` to more accurately indicate instructions whose writeback results are produced in the MEM stage rather than the EX stage.
- **Late Trap Masking:** Refactored the `ex_stage` and `mem_stage` to use late masking for trap handling. Decode signals are no longer preemptively masked; instead, local control structs dynamically squash architectural state updates and downstream pipeline controls if a trap is active.
- **CSR Datapath Refactor:** Removed `csr_wdata` from the `csr_ctrl_t` struct and added it to the standard pipeline registers. The `csr_wdata` calculation is now performed in the EX stage instead of earlier in the pipeline.
- **Trap Priority Routing:** The EX stage now actively manages the `trap_ctrl` pipeline register, ensuring that traps from earlier stages (like IF or ID) are properly preserved and prioritized over new EX-stage traps.

### Fixed
- **Misaligned Instruction Traps:** Corrected an architectural bug where misaligned instruction addresses were being incorrectly detected in the IF stage. The check has been moved to the EX stage to properly trap on the faulting control-flow instruction (e.g., jumps/branches) and prevent false fetch traps.
- **EX Stage Trap Squashing:** Fixed a bug in the EX stage where local control structs were not being properly masked upon a trap. Additionally, the pipeline now correctly clears the `inst_valid` bit whenever an instruction traps, ensuring that aborted instructions cannot artificially inflate the `minstret` counter or trigger unintended writebacks.
