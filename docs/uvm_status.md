# UVM Lane Status

The chiplet project includes a parallel UVM lane as methodology collateral. It
is not the default verification gate; the default gate remains the non-UVM
Verilator closure flow.

## What Is Checked In

- `chiplet_extension/sim/tb_chiplet_uvm.sv`
- `chiplet_extension/sim/uvm/ucie_uvm_pkg.sv`
- `chiplet_extension/sim/uvm/dma_uvm_pkg.sv`
- `chiplet_extension/sim/uvm/power_uvm_pkg.sv`
- `chiplet_extension/sim/uvm/chiplet_uvm_pkg.sv`

The packages define UCIe, DMA/CSR, power, and top-level environment
components with UVM-style sequence items, drivers, monitors, scoreboards,
coverage subscribers, and virtual-interface plumbing.

## Supported Use

The primary supported command is:

```bash
make -C chiplet_extension uvm-smoke
```

It requires a UVM-capable Verilator setup through `VERILATOR_UVM` and
`UVM_HOME`. The local Debian Verilator `5.020` path is not treated as a full
UVM closure environment.

## Compatibility Limitation

The checked-in bench preserves a normal `run_test()` path for full-UVM
simulators, but the local open-source Verilator flow uses a compatibility
runner for practical phase/TLM limitations. That keeps the lane runnable as a
methodology demonstration without replacing the stable non-UVM gate.

## Closure Position

`make -C chiplet_extension closure-equivalence` remains available when the
external UVM environment is valid. It is intended to compare UVM and non-UVM
coverage vectors, power-proxy evidence, and expected bug-validation outcomes.

The project should be described as:

- default closure: non-UVM Verilator stable gate
- optional methodology collateral: UVM architecture and smoke lane
- environment-dependent comparison: UVM/non-UVM closure equivalence

It should not be described as commercial-simulator UVM signoff.
