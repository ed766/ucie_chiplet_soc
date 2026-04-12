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
	$(REPORTS_DIR)/closure_targets.md \
	$(REPORTS_DIR)/power_state_summary.csv \
	$(REPORTS_DIR)/coverage_closure_matrix.md \
	$(REPORTS_DIR)/formal_summary.csv \
	$(REPORTS_DIR)/perf_characterization.csv

.PHONY: chiplet-sim chiplet-report regress power-regress stress bug-validate formal-check characterize clean

chiplet-sim:
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_smoke,soc_smoke --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

chiplet-report: regress formal-check characterize
	@echo "Chiplet verification reports:"
	@printf '  %s\n' $(REPORT_ARTIFACTS)
	@printf '  %s\n' $(ROOT_DIR)/../docs/protocol_characterization.md

regress:
	$(PYTHON) $(RUN_REGRESSION) --suite stable --random-seeds $(RANDOM_SEEDS) --seed $(SEED) --verilator $(VERILATOR)

power-regress:
	$(PYTHON) $(RUN_REGRESSION) --suite power --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

stress:
	$(PYTHON) $(RUN_REGRESSION) --suite stress --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

bug-validate:
	$(PYTHON) $(RUN_REGRESSION) --suite bug --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

formal-check:
	$(PYTHON) $(ROOT_DIR)/scripts/run_bounded_properties.py

characterize:
	$(PYTHON) $(ROOT_DIR)/scripts/gen_perf_characterization.py --seed $(SEED) --csv-out $(REPORTS_DIR)/perf_characterization.csv --verilator $(VERILATOR)

clean:
	@rm -rf $(BUILD_DIR) $(ROOT_DIR)/build/characterization $(ROOT_DIR)/build/formal_checks
	@find $(REPORTS_DIR) -maxdepth 1 \( \
		-name 'regress_summary.csv' -o \
		-name 'coverage_summary.csv' -o \
		-name 'failure_buckets.csv' -o \
		-name 'top_failures.md' -o \
		-name 'verification_dashboard.md' -o \
		-name 'regression_history.csv' -o \
		-name 'closure_targets.md' -o \
		-name 'power_state_summary.csv' -o \
		-name 'coverage_closure_matrix.md' -o \
		-name 'formal_summary.csv' -o \
		-name 'perf_characterization.csv' -o \
		-name '*_coverage.csv' -o \
		-name '*_scoreboard.csv' -o \
		-name '*_power.csv' \
	\) -delete
	@echo "Cleaned Verilator regression artifacts"
