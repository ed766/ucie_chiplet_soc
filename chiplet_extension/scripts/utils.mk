# Common makefile utilities for the chiplet extension
PYTHON ?= python3
REPORTS_DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../reports)

define run_python
	@echo "[PYTHON] $1"
	@$(PYTHON) $1
endef
