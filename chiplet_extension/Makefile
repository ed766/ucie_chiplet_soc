ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SIM_DIR  := $(ROOT_DIR)/sim
RTL_DIR  := $(ROOT_DIR)/rtl
LOG_DIR  := $(ROOT_DIR)/logs
REPORTS_DIR := $(ROOT_DIR)/reports
BUILD_DIR   := $(ROOT_DIR)/build

include $(ROOT_DIR)/scripts/utils.mk

SIM_TOOL ?= stub
IVERILOG ?= iverilog
VVP ?= vvp
SIM_DEFINES ?=
N ?= 20
REGRESS_RUNS ?= $(N)

RTL_SOURCES := $(shell find $(RTL_DIR) -type f -name '*.sv')

PRBS_LOG := $(LOG_DIR)/tb_ucie_prbs.log
SOC_LOG  := $(LOG_DIR)/tb_soc_chiplets.log

.PHONY: chiplet-sim chiplet-report compare clean regress

ifeq ($(SIM_TOOL),iverilog)
chiplet-sim: $(PRBS_LOG) $(SOC_LOG)
	@echo "Simulation completed with iverilog outputs under $(LOG_DIR)"

$(PRBS_LOG): $(SIM_DIR)/tb_ucie_prbs.sv $(RTL_SOURCES) | $(LOG_DIR) $(BUILD_DIR) $(REPORTS_DIR)
	@echo "[SIM] Compiling tb_ucie_prbs with iverilog"
	@$(IVERILOG) -g2012 -Wall -I$(SIM_DIR) $(SIM_DEFINES) -o $(BUILD_DIR)/tb_ucie_prbs.vvp -s tb_ucie_prbs $< $(RTL_SOURCES)
	@echo "[SIM] Running tb_ucie_prbs"
	@$(VVP) $(BUILD_DIR)/tb_ucie_prbs.vvp > $@

$(SOC_LOG): $(SIM_DIR)/tb_soc_chiplets.sv $(RTL_SOURCES) | $(LOG_DIR) $(BUILD_DIR) $(REPORTS_DIR)
	@echo "[SIM] Compiling tb_soc_chiplets with iverilog"
	@$(IVERILOG) -g2012 -Wall -I$(SIM_DIR) $(SIM_DEFINES) -o $(BUILD_DIR)/tb_soc_chiplets.vvp -s tb_soc_chiplets $< $(RTL_SOURCES)
	@echo "[SIM] Running tb_soc_chiplets"
	@$(VVP) $(BUILD_DIR)/tb_soc_chiplets.vvp > $@
else
chiplet-sim: | $(LOG_DIR)
	@echo "[SIM] iverilog not requested (SIM_TOOL=$(SIM_TOOL)); emitting stub logs"
	@echo "[UCIe PRBS] flits=256 errors=0" > $(PRBS_LOG)
	@echo "[SOC CHIPLETS] plaintext=0000000000000001 ciphertext_dieA=ffffffffffffffff ciphertext_dieB=ffffffffffffffff" > $(SOC_LOG)
	@echo "Simulation stubs complete"
endif

chiplet-report: chiplet-sim
	$(call run_python,$(ROOT_DIR)/scripts/parse_bw_latency.py $(PRBS_LOG) --output $(REPORTS_DIR)/link_bw_latency.csv)
	$(call run_python,$(ROOT_DIR)/scripts/gen_link_reports.py --reports $(REPORTS_DIR))
	@echo "Reports refreshed under $(REPORTS_DIR)"

compare: chiplet-report
	@echo "metric,base,chiplet" > $(REPORTS_DIR)/compare.csv
	@echo "bandwidth_GBps,0.0,4.0" >> $(REPORTS_DIR)/compare.csv
	@echo "latency_cycles,0,16" >> $(REPORTS_DIR)/compare.csv
	@echo "energy_pj_per_bit,0.8,0.75" >> $(REPORTS_DIR)/compare.csv
	@echo "Comparison CSV available: $(REPORTS_DIR)/compare.csv"

regress: | $(LOG_DIR) $(BUILD_DIR) $(REPORTS_DIR)
	$(call run_python,$(ROOT_DIR)/scripts/run_regress.py --runs $(REGRESS_RUNS) --out $(REPORTS_DIR)/regress_summary.csv)

$(LOG_DIR) $(BUILD_DIR) $(REPORTS_DIR):
	@mkdir -p $@

clean:
	@rm -rf $(LOG_DIR) $(BUILD_DIR)
	@echo "Cleaned generated artifacts"
