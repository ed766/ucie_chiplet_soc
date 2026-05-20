`ifndef POWER_UVM_PKG_SV
`define POWER_UVM_PKG_SV

package power_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum bit [1:0] {
        PWR_RUN         = 2'd0,
        PWR_CRYPTO_ONLY = 2'd1,
        PWR_SLEEP       = 2'd2,
        PWR_DEEP_SLEEP  = 2'd3
    } chiplet_power_state_e;

    virtual chiplet_power_if g_pwr_vif;
    int unsigned g_run_cycles;
    int unsigned g_crypto_only_cycles;
    int unsigned g_sleep_cycles;
    int unsigned g_deep_sleep_cycles;
    int unsigned g_isolation_cycles;
    int unsigned g_retention_events;

    class power_state_item extends uvm_sequence_item;
        rand chiplet_power_state_e state;
        rand int unsigned hold_cycles;

        `uvm_object_utils(power_state_item)

        function new(string name = "power_state_item");
            super.new(name);
            hold_cycles = 8;
        endfunction
    endclass

    class power_event_item extends uvm_sequence_item;
        chiplet_power_state_e state;
        bit any_iso_asserted;
        bit save_dma_sleep;
        bit restore_dma_sleep;
        bit save_dma_mem;
        bit restore_dma_mem;

        `uvm_object_utils(power_event_item)

        function new(string name = "power_event_item");
            super.new(name);
        endfunction
    endclass

    class power_sequencer extends uvm_sequencer #(power_state_item);
        `uvm_component_utils(power_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class power_driver extends uvm_driver #(power_state_item);
        `uvm_component_utils(power_driver)

        virtual chiplet_power_if pwr_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            pwr_vif = g_pwr_vif;
            if (pwr_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_power_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            power_state_item item;
            forever begin
                seq_item_port.get_next_item(item);
                pwr_vif.set_power_state(item.state);
                repeat (item.hold_cycles) #10;
                seq_item_port.item_done();
            end
        endtask
    endclass

    class power_monitor extends uvm_monitor;
        `uvm_component_utils(power_monitor)

        virtual chiplet_power_if pwr_vif;
`ifndef VERILATOR
        uvm_analysis_port #(power_event_item) ap;
`endif

        function new(string name, uvm_component parent);
            super.new(name, parent);
`ifndef VERILATOR
            ap = new("ap", this);
`endif
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            pwr_vif = g_pwr_vif;
            if (pwr_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_power_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            power_event_item item;
            forever begin
                #10;
                if (pwr_vif.rst_n) begin
                    item = power_event_item::type_id::create("item");
                    item.state = chiplet_power_state_e'(pwr_vif.power_state);
                    item.any_iso_asserted = !(pwr_vif.iso_pd_a_traffic_n &&
                                              pwr_vif.iso_pd_a_dma_n &&
                                              pwr_vif.iso_pd_a_link_n &&
                                              pwr_vif.iso_pd_b_crypto_n &&
                                              pwr_vif.iso_pd_b_link_n &&
                                              pwr_vif.iso_pd_channel_n);
                    item.save_dma_sleep = pwr_vif.save_dma_sleep;
                    item.restore_dma_sleep = pwr_vif.restore_dma_sleep;
                    item.save_dma_mem = pwr_vif.save_dma_mem;
                    item.restore_dma_mem = pwr_vif.restore_dma_mem;
                    case (item.state)
                        PWR_RUN: g_run_cycles++;
                        PWR_CRYPTO_ONLY: g_crypto_only_cycles++;
                        PWR_SLEEP: g_sleep_cycles++;
                        PWR_DEEP_SLEEP: g_deep_sleep_cycles++;
                        default: ;
                    endcase
                    if (item.any_iso_asserted) begin
                        g_isolation_cycles++;
                    end
                    if (item.save_dma_sleep || item.restore_dma_sleep ||
                        item.save_dma_mem || item.restore_dma_mem) begin
                        g_retention_events++;
                    end
`ifndef VERILATOR
                    ap.write(item);
`endif
                end
            end
        endtask
    endclass

    class power_agent extends uvm_agent;
        `uvm_component_utils(power_agent)

        power_sequencer sequencer;
        power_driver driver;
        power_monitor monitor;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
`ifndef VERILATOR
            sequencer = power_sequencer::type_id::create("sequencer", this);
            driver = power_driver::type_id::create("driver", this);
`endif
            monitor = power_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
`ifndef VERILATOR
            driver.seq_item_port.connect(sequencer.seq_item_export);
`endif
        endfunction
    endclass

    class power_coverage extends uvm_subscriber #(power_event_item);
        `uvm_component_utils(power_coverage)

        chiplet_power_state_e state_q;
        bit iso_q;
        bit retention_q;

`ifndef VERILATOR
        covergroup power_cg;
            option.per_instance = 1;
            cp_state: coverpoint state_q {
                bins run = {PWR_RUN};
                bins crypto_only = {PWR_CRYPTO_ONLY};
                bins sleep = {PWR_SLEEP};
                bins deep_sleep = {PWR_DEEP_SLEEP};
            }
            cp_isolation: coverpoint iso_q {
                bins deasserted = {1'b0};
                bins asserted = {1'b1};
            }
            cp_retention: coverpoint retention_q {
                bins no_event = {1'b0};
                bins event_seen = {1'b1};
            }
            x_state_iso: cross cp_state, cp_isolation;
        endgroup
`endif

        function new(string name, uvm_component parent);
            super.new(name, parent);
`ifndef VERILATOR
            power_cg = new();
`endif
        endfunction

        function void write(power_event_item t);
            state_q = t.state;
            iso_q = t.any_iso_asserted;
            retention_q = t.save_dma_sleep || t.restore_dma_sleep ||
                          t.save_dma_mem || t.restore_dma_mem;
`ifndef VERILATOR
            power_cg.sample();
`endif
        endfunction
    endclass

    class power_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(power_scoreboard)

        uvm_analysis_imp #(power_event_item, power_scoreboard) analysis_export;
        int unsigned run_cycles;
        int unsigned crypto_only_cycles;
        int unsigned sleep_cycles;
        int unsigned deep_sleep_cycles;
        int unsigned isolation_cycles;
        int unsigned retention_events;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function void write(power_event_item t);
            case (t.state)
                PWR_RUN: run_cycles++;
                PWR_CRYPTO_ONLY: crypto_only_cycles++;
                PWR_SLEEP: sleep_cycles++;
                PWR_DEEP_SLEEP: deep_sleep_cycles++;
                default: ;
            endcase
            if (t.any_iso_asserted) begin
                isolation_cycles++;
            end
            if (t.save_dma_sleep || t.restore_dma_sleep || t.save_dma_mem || t.restore_dma_mem) begin
                retention_events++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info(get_type_name(),
                      $sformatf("Power observed run=%0d crypto=%0d sleep=%0d deep=%0d iso=%0d retention=%0d",
                                run_cycles, crypto_only_cycles, sleep_cycles, deep_sleep_cycles,
                                isolation_cycles, retention_events),
                      UVM_LOW)
        endfunction
    endclass

    class power_sleep_resume_sequence extends uvm_sequence #(power_state_item);
        `uvm_object_utils(power_sleep_resume_sequence)

        function new(string name = "power_sleep_resume_sequence");
            super.new(name);
        endfunction

        task body();
            set_state(PWR_SLEEP, 16);
            set_state(PWR_RUN, 32);
        endtask

        task set_state(chiplet_power_state_e state, int unsigned hold_cycles);
            power_state_item item;
            item = power_state_item::type_id::create("state_item");
            start_item(item);
            item.state = state;
            item.hold_cycles = hold_cycles;
            finish_item(item);
        endtask
    endclass
endpackage

`endif
