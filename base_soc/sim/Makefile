SIM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
RTL_DIR := $(abspath $(SIM_DIR)/../rtl)
BUILD_DIR := $(SIM_DIR)/build
OBJ_DIR := $(BUILD_DIR)/obj_dir
SIM_EXE := $(OBJ_DIR)/Vtb_rv32_core

VERILATOR ?= verilator
GTKWAVE ?= gtkwave
SEED ?= 1592642302
RAND_COUNT ?= 48
WAVES ?= 0
WAVE_FILE ?= rv32_core_wave.fst
WAVE_VIEW ?= $(SIM_DIR)/rv32_core_wave.gtkw
WAVE_EXPORT_TCL ?= $(SIM_DIR)/rv32_core_wave_export.tcl
SIM_FLAGS ?=
VERILATOR_FLAGS ?= --binary --sv --timing --trace-fst -Wall -Wno-fatal -Wno-TIMESCALEMOD
SIM_PLUSARGS = +SEED=$(SEED) +RAND_COUNT=$(RAND_COUNT)$(if $(filter 1,$(WAVES)), +WAVES=1 +WAVE_FILE=$(WAVE_FILE))

RV32_TB_SOURCES := \
	$(SIM_DIR)/rv32_tb_pkg.sv \
	$(SIM_DIR)/rv32_core_if.sv \
	$(SIM_DIR)/rv32_driver.sv \
	$(SIM_DIR)/rv32_generator.sv \
	$(SIM_DIR)/rv32_monitor.sv \
	$(SIM_DIR)/rv32_scoreboard.sv \
	$(SIM_DIR)/rv32_assertions.sv \
	$(SIM_DIR)/rv32_coverage.sv \
	$(SIM_DIR)/tb_rv32_core.sv \
	$(RTL_DIR)/pd1_rv32/rv32_core.sv

.PHONY: rv32-core rv32-core-waves rv32-core-wave-print clean

rv32-core: $(SIM_EXE)
	cd $(BUILD_DIR) && ./obj_dir/Vtb_rv32_core $(SIM_PLUSARGS)

rv32-core-waves: WAVES=1
rv32-core-waves: rv32-core

rv32-core-wave-print: rv32-core-waves
	cd $(BUILD_DIR) && $(GTKWAVE) -N -M -f $(WAVE_FILE) -a $(WAVE_VIEW) -S $(WAVE_EXPORT_TCL) -O gtkwave_export.log

$(SIM_EXE): $(RV32_TB_SOURCES) | $(BUILD_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) -I$(SIM_DIR) $(SIM_FLAGS) $(RV32_TB_SOURCES) --top-module tb_rv32_core --Mdir $(OBJ_DIR)

$(BUILD_DIR):
	mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)
