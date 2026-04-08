ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPORTS_DIR := $(ROOT_DIR)/reports
BUILD_DIR := $(ROOT_DIR)/build/verilator_regression

PYTHON ?= python3
VERILATOR ?= verilator
SEED ?= 20260329
RANDOM_SEEDS ?= 3

RUN_REGRESSION := $(ROOT_DIR)/scripts/run_regression.py

REPORT_ARTIFACTS := \
	$(REPORTS_DIR)/regress_summary.csv \
	$(REPORTS_DIR)/coverage_summary.csv \
	$(REPORTS_DIR)/failure_buckets.csv \
	$(REPORTS_DIR)/top_failures.md \
	$(REPORTS_DIR)/verification_dashboard.md \
	$(REPORTS_DIR)/regression_history.csv \
	$(REPORTS_DIR)/closure_targets.md

.PHONY: chiplet-sim chiplet-report regress stress bug-validate clean

chiplet-sim:
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_smoke,soc_smoke --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

chiplet-report: regress

regress:
	$(PYTHON) $(RUN_REGRESSION) --suite stable --random-seeds $(RANDOM_SEEDS) --seed $(SEED) --verilator $(VERILATOR)

stress:
	$(PYTHON) $(RUN_REGRESSION) --suite stress --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

bug-validate:
	$(PYTHON) $(RUN_REGRESSION) --suite bug --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

clean:
	@rm -rf $(BUILD_DIR)
	@find $(REPORTS_DIR) -maxdepth 1 \( \
		-name 'regress_summary.csv' -o \
		-name 'coverage_summary.csv' -o \
		-name 'failure_buckets.csv' -o \
		-name 'top_failures.md' -o \
		-name 'verification_dashboard.md' -o \
		-name 'regression_history.csv' -o \
		-name 'closure_targets.md' -o \
		-name '*_coverage.csv' -o \
		-name '*_scoreboard.csv' \
	\) -delete
	@echo "Cleaned Verilator regression artifacts"
