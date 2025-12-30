UCIe Chiplet SoC (Dual-Die Extension)

This repository extends the original RISC-V SoC into a two-die system connected
by a behavioral UCIe 2.0-style link. Die A generates plaintext traffic and
verifies returning ciphertext. Die B aggregates traffic into 128-bit blocks,
encrypts it using an iterative AES-128 core, and returns results over the link.
The link stack models flow control, retries, latency, jitter, and injected
faults to stress the design before hardening. The flow is functional and
exploratory (not sign-off ready).

Contents and Layout

    base_soc/              — untouched copy of the original RISCV_Project
    chiplet_extension/
        rtl/               — dual-die RTL, link adapter, PHY, channel models
        sim/               — SystemVerilog benches + assertion macros
        upf/               — UPF scaffolding for two-die power domains
        scripts/           — Python helpers for log parsing and reports
        reports/           — CSVs produced by the automation hooks
        openlane/          — LibreLane/OpenLane2 config for soc_chiplet_top
        Makefile           — simulation + reporting targets
    openlane/              — top-level copy of the chiplet OpenLane config
    docs/                  — placeholder for diagrams and waveform captures

Architecture

    Die A (compute chiplet):
        die_a_system.sv generates 64-bit plaintext words and assembles 128-bit
        AES blocks. It mirrors the AES core to compute expected ciphertext for
        scoreboarding. Packetization, credits, retries, and link bring-up are
        handled by the d2d_adapter stack (flit_packetizer, credit_mgr, ucie_tx,
        ucie_rx, link_fsm, retry_ctrl).

    Die B (crypto chiplet):
        die_b_system.sv buffers incoming data, forms 128-bit blocks, runs the
        aes128_iterative core, and returns ciphertext using the same adapter
        stack. A separate ciphertext monitor is exposed for debug.

    UCIe behavioral link:
        phy_model/phy_behavioral.sv adds pipeline latency, jitter, and error
        injection. channel_model/channel_model.sv adds skew, crosstalk stalls,
        and probabilistic lane faults. soc_chiplet_top.sv wires the dice and
        exposes plaintext/ciphertext monitors for verification.

Power Intent (UPF)

    upf/die_a.upf and upf/die_b.upf:
        Domains: AON_A, PD1_RV32 (Die A) and AON_B, PD2_AES (Die B).
        Supply ports and basic power states are declared, but the UPF is a
        scaffold: there are no power switches, isolation strategies, retention
        cell bindings, or level shifters defined yet.

    upf/pst_chiplet.upf:
        Power-state table with RUN, SLEEP, CRYPTO_ONLY, DEEP_SLEEP. The states
        capture intent but are not yet enforced by tool-driven power intent.

Verification Strategy

    Testbenches:
        chiplet_extension/sim/tb_ucie_prbs.sv stresses the link with PRBS
        traffic and checks integrity. tb_soc_chiplets.sv runs the full two-die
        loop and compares ciphertext against Die A's expected results.

    Assertions:
        sim/sva_macros.svh provides lightweight assertion macros. There is no
        external cryptographic golden model; checks are against internal
        expected behavior.

Running Tests

    The chiplet_extension/Makefile supports simulator-agnostic targets. By
    default it emits stub logs so reports still build; set SIM_TOOL to run a
    real simulator.

        cd chiplet_extension
        make chiplet-sim
        make chiplet-report

        # Run real benches when Icarus Verilog is installed
        make chiplet-sim SIM_TOOL=iverilog

    Outputs and logs:
        Logs land in chiplet_extension/logs/ and feed reports under
        chiplet_extension/reports/ (link_bw_latency.csv, link_summary.csv).

Reports and Physical Flow

    LibreLane/OpenLane2:
        chiplet_extension/openlane/chiplet/config.json targets soc_chiplet_top
        and includes soc_chiplet_top.sdc. The current config uses a relaxed
        CLOCK_PERIOD (200 ns) for exploratory runs; tighten the clock and SDC
        constraints for realistic timing closure.

        Example:
            cd ~/librelane
            python3 -m librelane \
              --pdk-root ~/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af \
              ~/ucie_chiplet_soc/chiplet_extension/openlane/chiplet/config.json

    Outputs:
        Runs are written under chiplet_extension/openlane/chiplet/runs/.

Status as of this revision

    LibreLane runs complete end-to-end in this workspace with the relaxed clock
    target, producing final layout outputs. Timing closure at tighter clocks is
    not representative yet, and slow-corner max slew/max cap warnings remain.
    UPF is still a scaffold and not suitable for power-aware sign-off.
