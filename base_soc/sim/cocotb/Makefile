TOPLEVEL_LANG ?= verilog
SIM ?= verilator
TOPLEVEL ?= soc_top
MODULE ?= sim.cocotb.test_soc_top

ROOT := $(abspath ../..)
RTL_DIR := $(ROOT)/rtl
SIM_DIR := $(ROOT)/sim
REPORTS_DIR ?= $(ROOT)/reports

export PYTHONPATH := $(abspath $(ROOT))$(if $(PYTHONPATH),:$(PYTHONPATH),)
export REPORTS_DIR
export COCOTB_RESULTS_FILE := $(REPORTS_DIR)/regression/cocotb_results.xml

VERILOG_SOURCES := $(shell find $(RTL_DIR) -type f -name '*.sv') $(SIM_DIR)/pwr_assertions.sv
EXTRA_ARGS += --timing --trace --trace-structs --coverage --coverage-line --coverage-toggle --public-flat-rw --trace-fst
VERILATOR_INCLUDE += -I$(RTL_DIR) -I$(SIM_DIR)

WAVES ?= 0
ifeq ($(WAVES),1)
VERILATOR_TRACE := 1
else
VERILATOR_TRACE := 0
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
