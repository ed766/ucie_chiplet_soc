ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPORTS_DIR := $(ROOT_DIR)/reports
BUILD_DIR := $(ROOT_DIR)/build/verilator_regression

PYTHON ?= python3
VERILATOR ?= verilator
SEED ?= 20260329
RANDOM_SEEDS ?= 3

RUN_REGRESSION := $(ROOT_DIR)/scripts/run_regression.py
RUN_UVM_REGRESSION := $(ROOT_DIR)/scripts/run_uvm_regression.py
CHECK_CLOSURE_EQUIV := $(ROOT_DIR)/scripts/check_closure_equivalence.py
GEN_SEEDED_SCENARIOS := $(ROOT_DIR)/scripts/gen_seeded_scenarios.py
RENDER_DMA_RETRY_WAVEFORM := $(ROOT_DIR)/scripts/render_dma_retry_waveform.py
GEN_PERFORMANCE_CHARACTERIZATION := $(ROOT_DIR)/scripts/gen_performance_characterization.py
GEN_ASSERTION_INVENTORY := $(ROOT_DIR)/scripts/gen_assertion_inventory.py
GEN_RANDOM_STRESS_SUMMARY := $(ROOT_DIR)/scripts/gen_random_stress_summary.py
RUN_RANDOM_STRESS_MATRIX := $(ROOT_DIR)/scripts/run_random_stress_matrix.py
GEN_TRUE_CROSS_COVERAGE := $(ROOT_DIR)/scripts/gen_true_cross_coverage.py
GEN_NEGATIVE_TEST_SUMMARY := $(ROOT_DIR)/scripts/gen_negative_test_summary.py
GEN_PROJECT_METRICS := $(ROOT_DIR)/scripts/gen_project_metrics.py
RUN_FRONTEND_QUALITY := $(ROOT_DIR)/scripts/run_frontend_quality.py
GEN_CODE_COVERAGE_REPORT := $(ROOT_DIR)/scripts/gen_code_coverage_report.py
RUN_OPTIONAL_BENCHES := $(ROOT_DIR)/scripts/run_optional_benches.py
RUN_C_REFERENCE_CHECKS := $(ROOT_DIR)/scripts/run_c_reference_checks.py
RUN_FIRMWARE_SOC := $(ROOT_DIR)/scripts/run_firmware_soc.py
RENDER_FIRMWARE_WAVEFORM := $(ROOT_DIR)/scripts/render_firmware_waveform.py
RUN_SOLVER_FORMAL := $(ROOT_DIR)/scripts/run_solver_formal.py
RUN_ASYNC_CDC := $(ROOT_DIR)/scripts/run_async_cdc.py
NORMALIZE_REPORT_PATHS := $(ROOT_DIR)/scripts/normalize_report_paths.py
RUN_COMPILED_FIRMWARE := $(ROOT_DIR)/scripts/run_compiled_firmware.py
RUN_COMPILER_MATRIX := $(ROOT_DIR)/scripts/run_compiler_matrix.py
GEN_TIMER_WFI_COVERAGE := $(ROOT_DIR)/scripts/gen_timer_wfi_coverage.py
CHECK_EXTERNAL_RISCV_TOOLS := $(ROOT_DIR)/scripts/check_external_riscv_tools.py
INSTALL_EXTERNAL_RISCV_TOOLS := $(ROOT_DIR)/scripts/install_external_riscv_tools.py
RUN_EXTERNAL_ISS := $(ROOT_DIR)/scripts/run_external_iss.py
RUN_RV32_FORMAL := $(ROOT_DIR)/scripts/run_rv32_formal.py
RUN_ACT4 := $(ROOT_DIR)/scripts/run_act4.py
RUN_EXTERNAL_MUTATIONS := $(ROOT_DIR)/scripts/run_external_mutation_matrix.py
GEN_RV32_VALIDATION_DASHBOARD := $(ROOT_DIR)/scripts/gen_rv32_validation_dashboard.py
RUN_RTL_MUTATIONS := $(ROOT_DIR)/scripts/run_rtl_mutations.py
RUN_GENERATED_C_RANDOM := $(ROOT_DIR)/scripts/run_generated_c_random.py
GEN_FIRMWARE_ROBUSTNESS := $(ROOT_DIR)/scripts/gen_firmware_robustness.py
RUN_RV32_EBREAK_CHECK := $(ROOT_DIR)/scripts/run_rv32_ebreak_check.py
BUILD_COMPILED_FIRMWARE := $(ROOT_DIR)/scripts/build_compiled_firmware.py
CHECK_RV32_TOOLCHAIN := $(ROOT_DIR)/scripts/check_rv32_toolchain.py
INSTALL_RV32_TOOLCHAIN := $(ROOT_DIR)/scripts/install_rv32_toolchain.py

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
	$(REPORTS_DIR)/cross_coverage_summary.csv \
	$(REPORTS_DIR)/true_cross_coverage_summary.csv \
	$(REPORTS_DIR)/closure_equivalence.csv \
	$(REPORTS_DIR)/closure_equivalence.md \
	$(REPORTS_DIR)/formal_summary.csv \
	$(REPORTS_DIR)/perf_characterization.csv \
	$(REPORTS_DIR)/dma_mem_characterization.csv \
	$(REPORTS_DIR)/random_stress_regress_summary.csv \
		$(REPORTS_DIR)/negative_test_summary.csv \
		$(REPORTS_DIR)/project_metrics.csv \
		$(REPORTS_DIR)/frontend_quality_summary.csv \
		$(REPORTS_DIR)/frontend_quality_summary.md \
		$(REPORTS_DIR)/cdc_rdc_summary.csv \
		$(REPORTS_DIR)/code_coverage_summary.txt \
		$(REPORTS_DIR)/code_coverage_summary.md \
		$(REPORTS_DIR)/code_coverage_holes.csv \
		$(REPORTS_DIR)/c_reference_summary.csv \
		$(REPORTS_DIR)/firmware_soc_summary.csv \
		$(REPORTS_DIR)/firmware_coverage_summary.csv \
		$(REPORTS_DIR)/firmware_cross_coverage_summary.csv \
		$(REPORTS_DIR)/firmware_code_coverage_summary.md \
		$(REPORTS_DIR)/firmware_c_summary.csv \
		$(REPORTS_DIR)/firmware_c_coverage_summary.csv \
		$(REPORTS_DIR)/firmware_c_cross_coverage_summary.csv \
		$(REPORTS_DIR)/firmware_c_mutation_summary.csv \
		$(REPORTS_DIR)/firmware_c_code_coverage_summary.txt \
		$(REPORTS_DIR)/firmware_c_code_coverage_summary.md \
		$(REPORTS_DIR)/firmware_c_code_coverage_test_ranking.csv \
		$(ROOT_DIR)/../docs/reference/compiled_firmware_verification.md \
		$(ROOT_DIR)/../docs/performance_characterization.md \
		$(ROOT_DIR)/../docs/reference/assertion_inventory.md \
		$(ROOT_DIR)/../docs/reference/random_stress_summary.md \
		$(ROOT_DIR)/../docs/reference/true_cross_coverage_summary.md \
		$(ROOT_DIR)/../docs/reference/negative_test_summary.md \
		$(ROOT_DIR)/../docs/project_metrics.md \
		$(ROOT_DIR)/../docs/uvm_status.md \
		$(ROOT_DIR)/../docs/open_source_flow_summary.md \
		$(ROOT_DIR)/../docs/reference/clock_reset_cdc_plan.md \
		$(ROOT_DIR)/../docs/reference/c_reference_model_summary.md

.PHONY: chiplet-sim chiplet-report project-check regress closure closure-equivalence power-regress stress negative-regress negative-summary bug-validate formal-check formal-prove assertion-inventory upf-check frontend-quality code-coverage coverage-edges-check axi-lite-check cdc-rdc-check async-cdc-check credit-edges-check c-reference-check firmware-soc-smoke firmware-soc-check firmware-code-coverage firmware-waveform rv32-toolchain-install rv32-toolchain-check rv32-external-tools-install rv32-isa-check rv32-ebreak-check rv32-external-iss-check rv32-act-check rv32-formal-check rv32-external-mutation-check firmware-c-build firmware-c-smoke firmware-c-check firmware-c-isa-random firmware-c-workload-random firmware-c-generated-c-random firmware-c-closure firmware-c-coverage firmware-c-waveform firmware-c-mutation-check firmware-c-rtl-mutation-check firmware-c-compiler-matrix firmware-c-robustness-check firmware-c-release-check timer-wfi-check uvm-check-env uvm-smoke uvm-ci uvm-ral-smoke uvm-closure uvm-regress characterize characterize-link characterize-dma-mem performance-report project-metrics readme-metrics docs-check normalize-report-paths random-smoke-25 stress-retry-50 power-dma-cross-25 random-stress-run random-stress-summary cross-coverage-summary dma-retry-waveform clean

chiplet-sim:
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_smoke,soc_smoke --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix smoke --run-id-prefix smoke

chiplet-report: regress formal-check assertion-inventory characterize performance-report
	@echo "Chiplet verification reports:"
	@printf '  %s\n' $(REPORT_ARTIFACTS)
	@printf '  %s\n' $(ROOT_DIR)/../docs/performance_characterization.md

project-check:
	$(MAKE) closure RANDOM_SEEDS=1
	$(MAKE) cross-coverage-summary
	$(MAKE) negative-summary
	$(MAKE) formal-check
	$(MAKE) assertion-inventory
	$(MAKE) upf-check
	$(MAKE) firmware-soc-check
	$(MAKE) firmware-c-check
	$(MAKE) performance-report
	$(MAKE) project-metrics
	$(MAKE) readme-metrics
	$(MAKE) docs-check
	$(MAKE) normalize-report-paths
	@! rg -n "57 / 57|52 / 52|17 / 17|UPF scaffolding|UPF placeholders|Power-intent placeholders" $(ROOT_DIR)/../README.md $(ROOT_DIR)/../docs $(ROOT_DIR)/README.md

regress:
	$(PYTHON) $(RUN_REGRESSION) --suite stable --random-seeds $(RANDOM_SEEDS) --seed $(SEED) --verilator $(VERILATOR)

closure:
	$(PYTHON) $(RUN_REGRESSION) --suite closure --random-seeds $(RANDOM_SEEDS) --seed $(SEED) --verilator $(VERILATOR)
	$(PYTHON) $(CHECK_CLOSURE_EQUIV) --mode nonuvm

closure-equivalence: closure uvm-closure
	$(PYTHON) $(CHECK_CLOSURE_EQUIV) --mode equivalence

power-regress:
	$(PYTHON) $(RUN_REGRESSION) --suite power --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

stress:
	$(PYTHON) $(RUN_REGRESSION) --suite stress --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

random-smoke-25:
	$(PYTHON) $(GEN_SEEDED_SCENARIOS) --family random_smoke_25 --seed $(SEED) --output $(REPORTS_DIR)/random_smoke_25_manifest.csv
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_rand_stress --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix random_smoke_25_probe --run-id-prefix random_smoke_25_probe

stress-retry-50:
	$(PYTHON) $(GEN_SEEDED_SCENARIOS) --family stress_retry_50 --seed $(SEED) --output $(REPORTS_DIR)/stress_retry_50_manifest.csv
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_retry_backpressure --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix stress_retry_50_probe --run-id-prefix stress_retry_50_probe

power-dma-cross-25:
	$(PYTHON) $(GEN_SEEDED_SCENARIOS) --family power_dma_cross_25 --seed $(SEED) --output $(REPORTS_DIR)/power_dma_cross_25_manifest.csv
	$(PYTHON) $(RUN_REGRESSION) --tests power_traffic_cross_test --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix power_dma_cross_25_probe --run-id-prefix power_dma_cross_25_probe

random-stress-run: random-smoke-25 stress-retry-50 power-dma-cross-25
	$(PYTHON) $(RUN_RANDOM_STRESS_MATRIX) --verilator $(VERILATOR)
	$(PYTHON) $(NORMALIZE_REPORT_PATHS)

cross-coverage-summary:
	$(PYTHON) $(GEN_TRUE_CROSS_COVERAGE) --summary $(REPORTS_DIR)/regress_summary.csv --csv-out $(REPORTS_DIR)/true_cross_coverage_summary.csv --md-out $(ROOT_DIR)/../docs/reference/true_cross_coverage_summary.md

negative-regress:
	$(PYTHON) $(RUN_REGRESSION) --suite negative --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix negative --run-id-prefix negative

negative-summary: negative-regress
	$(PYTHON) $(GEN_NEGATIVE_TEST_SUMMARY) --summary $(REPORTS_DIR)/negative_regress_summary.csv --csv-out $(REPORTS_DIR)/negative_test_summary.csv --md-out $(ROOT_DIR)/../docs/reference/negative_test_summary.md

dma-retry-waveform:
	$(PYTHON) $(RENDER_DMA_RETRY_WAVEFORM) --output $(ROOT_DIR)/../docs/images/dma_retry_waveform.png

bug-validate:
	$(PYTHON) $(RUN_REGRESSION) --suite bug --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR)

formal-check:
	$(PYTHON) $(ROOT_DIR)/scripts/run_bounded_properties.py

formal-prove:
	$(PYTHON) $(RUN_SOLVER_FORMAL)

assertion-inventory:
	$(PYTHON) $(GEN_ASSERTION_INVENTORY)

upf-check:
	$(PYTHON) $(ROOT_DIR)/scripts/check_upf_intent.py

uvm-check-env:
	$(PYTHON) $(ROOT_DIR)/scripts/check_uvm_env.py

uvm-smoke: uvm-check-env
	$(PYTHON) $(RUN_UVM_REGRESSION) --suite smoke --tests uvm_prbs_smoke_test --report-prefix uvm_smoke

uvm-ci: uvm-check-env
	$(PYTHON) $(RUN_UVM_REGRESSION) --suite smoke --tests uvm_prbs_smoke_test,uvm_dma_queue_smoke_test,uvm_power_sleep_resume_test,uvm_axi_lite_ral_smoke_test --report-prefix uvm_ci

uvm-ral-smoke: uvm-check-env
	$(PYTHON) $(RUN_UVM_REGRESSION) --suite smoke --tests uvm_axi_lite_ral_smoke_test --report-prefix uvm_ral_smoke

uvm-closure: uvm-check-env
	$(PYTHON) $(RUN_UVM_REGRESSION) --suite closure --random-seeds $(RANDOM_SEEDS) --seed $(SEED) --verilator $(VERILATOR)
	$(PYTHON) $(CHECK_CLOSURE_EQUIV) --mode uvm

uvm-regress: uvm-closure

characterize-link:
	$(PYTHON) $(ROOT_DIR)/scripts/gen_perf_characterization.py --seed $(SEED) --csv-out $(REPORTS_DIR)/perf_characterization.csv --verilator $(VERILATOR)

characterize-dma-mem:
	$(PYTHON) $(ROOT_DIR)/scripts/gen_dma_mem_characterization.py --seed $(SEED) --csv-out $(REPORTS_DIR)/dma_mem_characterization.csv --verilator $(VERILATOR)

characterize: characterize-link characterize-dma-mem

performance-report:
	$(PYTHON) $(GEN_PERFORMANCE_CHARACTERIZATION) --perf-csv $(REPORTS_DIR)/perf_characterization.csv --regress-csv $(REPORTS_DIR)/regress_summary.csv --output $(ROOT_DIR)/../docs/performance_characterization.md

frontend-quality:
	$(PYTHON) $(RUN_FRONTEND_QUALITY) --verilator $(VERILATOR)

coverage-edges-check:
	$(PYTHON) $(RUN_REGRESSION) --suite coverage_edge --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix coverage_edges --run-id-prefix coverage_edges

code-coverage:
	$(PYTHON) $(RUN_REGRESSION) --suite closure --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov --run-id-prefix codecov --code-coverage
	$(PYTHON) $(RUN_REGRESSION) --suite negative --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_negative --run-id-prefix codecov_negative --code-coverage
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_link_degraded_timeout --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_edge --run-id-prefix codecov_edge --code-coverage
	$(PYTHON) $(RUN_REGRESSION) --tests dma_csr_readback_sweep --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_csr --run-id-prefix codecov_csr --code-coverage
	$(PYTHON) $(RUN_REGRESSION) --tests prbs_rand_stress --random-seeds 8 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_entropy --run-id-prefix codecov_entropy --code-coverage
	$(PYTHON) $(RUN_REGRESSION) --tests dma_queue_smoke --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_entropy_dma --run-id-prefix codecov_entropy_dma --code-coverage --plusarg DMA_SRC_BASE=240 --plusarg DMA_DST_BASE=224 --plusarg DMA_LEN_WORDS=16 --plusarg DMA_TAG=65535
	$(PYTHON) $(RUN_REGRESSION) --suite coverage_edge --random-seeds 1 --seed $(SEED) --verilator $(VERILATOR) --report-prefix codecov_coverage_edges --run-id-prefix codecov_coverage_edges --code-coverage
	$(PYTHON) $(RUN_OPTIONAL_BENCHES) --bench axi_lite --bench cdc_rdc --bench credit_mgr_edges --verilator $(VERILATOR) --code-coverage
	$(PYTHON) $(GEN_CODE_COVERAGE_REPORT) --prefix codecov_ --holes-out $(REPORTS_DIR)/code_coverage_holes.csv --enforce-release-targets

axi-lite-check:
	$(PYTHON) $(RUN_OPTIONAL_BENCHES) --bench axi_lite --verilator $(VERILATOR)

cdc-rdc-check:
	$(PYTHON) $(RUN_OPTIONAL_BENCHES) --bench cdc_rdc --verilator $(VERILATOR)

async-cdc-check:
	$(PYTHON) $(RUN_ASYNC_CDC) --verilator $(VERILATOR)

credit-edges-check:
	$(PYTHON) $(RUN_OPTIONAL_BENCHES) --bench credit_mgr_edges --verilator $(VERILATOR)

c-reference-check:
	$(PYTHON) $(RUN_C_REFERENCE_CHECKS)

firmware-soc-check:
	$(PYTHON) $(RUN_FIRMWARE_SOC) --verilator $(VERILATOR)

firmware-soc-smoke:
	$(PYTHON) $(RUN_FIRMWARE_SOC) --verilator $(VERILATOR) --smoke --report-prefix firmware_smoke_

firmware-code-coverage:
	$(PYTHON) $(RUN_FIRMWARE_SOC) --verilator $(VERILATOR) --code-coverage --report-prefix firmware_codecov_
	$(PYTHON) $(GEN_CODE_COVERAGE_REPORT) \
		--dat-dir $(ROOT_DIR)/build/firmware_soc/coverage_data --prefix firmware_ \
		--output-txt $(REPORTS_DIR)/firmware_code_coverage_summary.txt \
		--output-md $(REPORTS_DIR)/firmware_code_coverage_summary.md \
		--info-out $(REPORTS_DIR)/firmware_code_coverage.info \
		--focus-components rv32_core,apb_dma_csr_bridge,rv32_rom_feeder,soc_chiplet_rv32_top \
		--minimum-focus-pct 85

firmware-waveform: firmware-soc-check
	$(PYTHON) $(RENDER_FIRMWARE_WAVEFORM)

rv32-toolchain-install:
	$(PYTHON) $(INSTALL_RV32_TOOLCHAIN)

rv32-toolchain-check:
	$(PYTHON) $(CHECK_RV32_TOOLCHAIN)

rv32-external-tools-install:
	$(PYTHON) $(INSTALL_EXTERNAL_RISCV_TOOLS)

firmware-c-build: rv32-toolchain-check
	$(PYTHON) $(BUILD_COMPILED_FIRMWARE)

firmware-c-smoke: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --smoke

firmware-c-check: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR)

firmware-c-isa-random: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --isa-random --count 25

firmware-c-workload-random: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --workload-random --count 25

firmware-c-generated-c-random: rv32-toolchain-check
	$(PYTHON) $(RUN_GENERATED_C_RANDOM) --verilator $(VERILATOR) --count 25

firmware-c-closure: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --closure --count 25

rv32-isa-check: firmware-c-check
	@$(PYTHON) -c 'import csv; from pathlib import Path; p=Path("$(REPORTS_DIR)/firmware_c_coverage_summary.csv"); rows=list(csv.DictReader(p.open())); missing=[r["coverage_point"] for r in rows if r["coverage_point"].startswith("rv32_") and r["hit"]!="1"]; assert not missing, "missing RV32 ISA points: "+str(missing); print("RV32 ISA differential coverage PASS")'

rv32-ebreak-check:
	$(PYTHON) $(RUN_RV32_EBREAK_CHECK)

firmware-c-coverage: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --coverage --closure --count 25
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --coverage --timer-wfi --append-coverage
	$(PYTHON) $(GEN_CODE_COVERAGE_REPORT) \
		--dat-dir $(ROOT_DIR)/build/firmware_c/coverage_data --prefix firmware_c_ \
		--output-txt $(REPORTS_DIR)/firmware_c_code_coverage_summary.txt \
		--output-md $(REPORTS_DIR)/firmware_c_code_coverage_summary.md \
		--info-out $(REPORTS_DIR)/firmware_c_code_coverage.info \
		--ranking-out $(REPORTS_DIR)/firmware_c_code_coverage_test_ranking.csv \
		--holes-out $(REPORTS_DIR)/firmware_c_code_coverage_holes.csv \
		--annotate-dir $(ROOT_DIR)/build/firmware_c/code_coverage_annotated \
		--focus-components rv32_core,apb_dma_csr_bridge,apb_machine_timer,rv32_rom_feeder,soc_chiplet_rv32_top \
		--minimum-focus-pct 96 \
		--minimum-focus-branch-pct 85

firmware-c-mutation-check: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --mutation-check

firmware-c-compiler-matrix: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILER_MATRIX) --verilator $(VERILATOR)

firmware-c-robustness-check:
	$(PYTHON) $(GEN_FIRMWARE_ROBUSTNESS)

firmware-c-rtl-mutation-check: rv32-toolchain-check
	$(PYTHON) $(RUN_RTL_MUTATIONS) --verilator $(VERILATOR)

timer-wfi-check: rv32-toolchain-check
	$(PYTHON) $(RUN_COMPILED_FIRMWARE) --verilator $(VERILATOR) --timer-wfi
	$(PYTHON) $(GEN_TIMER_WFI_COVERAGE)

rv32-external-iss-check: firmware-c-check
	$(PYTHON) $(CHECK_EXTERNAL_RISCV_TOOLS)
	$(PYTHON) $(RUN_EXTERNAL_ISS)

rv32-act-check:
	$(PYTHON) $(CHECK_EXTERNAL_RISCV_TOOLS)
	$(PYTHON) $(RUN_ACT4)

rv32-formal-check:
	$(PYTHON) $(CHECK_EXTERNAL_RISCV_TOOLS)
	$(PYTHON) $(RUN_RV32_FORMAL)

rv32-external-mutation-check:
	@test -f $(ROOT_DIR)/build/external_riscv_tools/environment.sh || { echo "Missing pinned external tools; run 'make rv32-external-tools-install'"; exit 1; }
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(RUN_EXTERNAL_MUTATIONS)'

firmware-c-release-check: firmware-c-closure firmware-c-generated-c-random firmware-c-compiler-matrix timer-wfi-check rv32-ebreak-check firmware-c-rtl-mutation-check firmware-c-robustness-check
	@test -f $(ROOT_DIR)/build/external_riscv_tools/environment.sh || { echo "Missing pinned external tools; run 'make rv32-external-tools-install'"; exit 1; }
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(CHECK_EXTERNAL_RISCV_TOOLS) --require'
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(RUN_EXTERNAL_ISS) --require'
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(RUN_ACT4) --require'
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(RUN_RV32_FORMAL) --require'
	bash -c 'source $(ROOT_DIR)/build/external_riscv_tools/environment.sh && $(PYTHON) $(RUN_EXTERNAL_MUTATIONS)'
	$(MAKE) project-metrics readme-metrics normalize-report-paths docs-check

firmware-c-waveform: firmware-c-check
	$(PYTHON) $(RENDER_FIRMWARE_WAVEFORM) --trace $(ROOT_DIR)/build/firmware_c/compiled_firmware_trace.csv --output $(ROOT_DIR)/../docs/images/compiled_firmware_waveform.png

project-metrics:
	$(PYTHON) $(GEN_RV32_VALIDATION_DASHBOARD)
	$(PYTHON) $(GEN_PROJECT_METRICS)

readme-metrics:
	$(PYTHON) $(ROOT_DIR)/scripts/update_readme_metrics.py

docs-check:
	$(PYTHON) $(ROOT_DIR)/scripts/check_docs.py

normalize-report-paths:
	$(PYTHON) $(NORMALIZE_REPORT_PATHS)

random-stress-summary:
	$(PYTHON) $(GEN_RANDOM_STRESS_SUMMARY)

clean:
	@rm -rf $(BUILD_DIR) $(ROOT_DIR)/build/firmware_soc $(ROOT_DIR)/build/firmware_c $(ROOT_DIR)/build/characterization $(ROOT_DIR)/build/characterization_dma_mem $(ROOT_DIR)/build/formal_checks $(ROOT_DIR)/build/uvm_env_check $(ROOT_DIR)/build/uvm_regression
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
		-name 'cross_coverage_summary.csv' -o \
		-name 'true_cross_coverage_summary.csv' -o \
		-name 'closure_equivalence.csv' -o \
		-name 'closure_equivalence.md' -o \
		-name 'formal_summary.csv' -o \
		-name 'perf_characterization.csv' -o \
		-name 'dma_mem_characterization.csv' -o \
		-name 'random_stress_regress_summary.csv' -o \
		-name 'negative_regress_summary.csv' -o \
			-name 'negative_test_summary.csv' -o \
			-name 'project_metrics.csv' -o \
			-name 'frontend_quality_summary.csv' -o \
			-name 'frontend_quality_summary.md' -o \
			-name 'cdc_rdc_summary.csv' -o \
			-name 'code_coverage_summary.txt' -o \
			-name 'code_coverage_summary.md' -o \
			-name 'code_coverage_holes.csv' -o \
			-name 'code_coverage.info' -o \
			-name 'c_reference_summary.csv' -o \
			-name 'optional_bench_summary.csv' -o \
		-name 'firmware_*' -o \
		-name 'random_stress_*' -o \
		-name 'uvm_regress_summary.csv' -o \
		-name 'uvm_coverage_summary.csv' -o \
		-name 'uvm_power_state_summary.csv' -o \
		-name 'uvm_failure_buckets.csv' -o \
		-name 'uvm_top_failures.md' -o \
		-name 'uvm_verification_dashboard.md' -o \
		-name 'uvm_regression_history.csv' -o \
		-name 'uvm_closure_targets.md' -o \
		-name 'uvm_coverage_closure_matrix.md' -o \
		-name 'uvm_smoke_summary.csv' -o \
		-name 'uvm_smoke_coverage_summary.csv' -o \
		-name 'uvm_ral_smoke_regress_summary.csv' -o \
		-name 'uvm_ral_smoke_coverage_summary.csv' -o \
		-name 'smoke_regress_summary.csv' -o \
		-name 'smoke_coverage_summary.csv' -o \
		-name 'smoke_power_state_summary.csv' -o \
		-name 'smoke_failure_buckets.csv' -o \
		-name 'smoke_top_failures.md' -o \
		-name 'smoke_verification_dashboard.md' -o \
		-name 'smoke_regression_history.csv' -o \
		-name 'smoke_closure_targets.md' -o \
		-name 'smoke_coverage_closure_matrix.md' -o \
		-name '*_coverage.csv' -o \
		-name '*_scoreboard.csv' -o \
		-name '*_power.csv' \
	\) -delete
	@echo "Cleaned Verilator regression artifacts"
