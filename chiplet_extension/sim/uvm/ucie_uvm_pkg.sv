`ifndef UCIE_UVM_PKG_SV
`define UCIE_UVM_PKG_SV

`include "tb_params.svh"

package ucie_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        UCIE_DIR_A_TX = 0,
        UCIE_DIR_B_TX = 1,
        UCIE_DIR_A_RX = 2,
        UCIE_DIR_B_RX = 3
    } ucie_dir_e;

    virtual ucie_stream_if g_ucie_vif;
    int unsigned g_observed_flits;
    int unsigned g_a_tx_count;
    int unsigned g_b_tx_count;
    int unsigned g_a_rx_count;
    int unsigned g_b_rx_count;

    class ucie_flit_item extends uvm_sequence_item;
        rand ucie_dir_e dir;
        rand bit [`TB_FLIT_WIDTH-1:0] flit;
        int unsigned cycle;

        `uvm_object_utils(ucie_flit_item)

        function new(string name = "ucie_flit_item");
            super.new(name);
        endfunction
    endclass

    class ucie_sequencer extends uvm_sequencer #(ucie_flit_item);
        `uvm_component_utils(ucie_sequencer)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class ucie_driver extends uvm_driver #(ucie_flit_item);
        `uvm_component_utils(ucie_driver)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            ucie_flit_item item;
            forever begin
                seq_item_port.get_next_item(item);
                `uvm_info(get_type_name(),
                          $sformatf("UCIe active driving is not used for the self-generating chiplet DUT: %s",
                                    item.convert2string()),
                          UVM_HIGH)
                seq_item_port.item_done();
            end
        endtask
    endclass

    class ucie_monitor extends uvm_monitor;
        `uvm_component_utils(ucie_monitor)

        virtual ucie_stream_if vif;
`ifdef CHIPLET_REAL_UVM
        uvm_analysis_port #(ucie_flit_item) ap;
`endif
        int unsigned cycle_q;

        function new(string name, uvm_component parent);
            super.new(name, parent);
`ifdef CHIPLET_REAL_UVM
            ap = new("ap", this);
`endif
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            vif = g_ucie_vif;
            if (vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface ucie_stream_if")
            end
        endfunction

        task run_phase(uvm_phase phase);
            cycle_q = 0;
            forever begin
                #10;
                if (!vif.rst_n) begin
                    cycle_q = 0;
                end else begin
                    cycle_q++;
                    sample(UCIE_DIR_A_TX, vif.a_tx_valid && vif.a_tx_ready, vif.a_tx_data);
                    sample(UCIE_DIR_B_TX, vif.b_tx_valid && vif.b_tx_ready, vif.b_tx_data);
                    sample(UCIE_DIR_A_RX, vif.a_rx_valid, vif.a_rx_data);
                    sample(UCIE_DIR_B_RX, vif.b_rx_valid, vif.b_rx_data);
                end
            end
        endtask

        function void sample(ucie_dir_e dir, bit valid, bit [`TB_FLIT_WIDTH-1:0] flit);
            ucie_flit_item item;
            if (valid) begin
                item = ucie_flit_item::type_id::create("item");
                item.dir = dir;
                item.flit = flit;
                item.cycle = cycle_q;
                g_observed_flits++;
                case (dir)
                    UCIE_DIR_A_TX: g_a_tx_count++;
                    UCIE_DIR_B_TX: g_b_tx_count++;
                    UCIE_DIR_A_RX: g_a_rx_count++;
                    UCIE_DIR_B_RX: g_b_rx_count++;
                    default: ;
                endcase
`ifdef CHIPLET_REAL_UVM
                ap.write(item);
`endif
            end
        endfunction
    endclass

    class ucie_agent extends uvm_agent;
        `uvm_component_utils(ucie_agent)

        ucie_sequencer sequencer;
        ucie_driver    driver;
        ucie_monitor   monitor;
        uvm_active_passive_enum is_active_cfg;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            is_active_cfg = UVM_PASSIVE;
            monitor = ucie_monitor::type_id::create("monitor", this);
            if (is_active_cfg == UVM_ACTIVE) begin
                sequencer = ucie_sequencer::type_id::create("sequencer", this);
                driver = ucie_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (is_active_cfg == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass

    class ucie_coverage extends uvm_subscriber #(ucie_flit_item);
        `uvm_component_utils(ucie_coverage)

        ucie_dir_e dir_q;

`ifndef VERILATOR
        covergroup ucie_cg;
            option.per_instance = 1;
            cp_dir: coverpoint dir_q {
                bins a_tx = {UCIE_DIR_A_TX};
                bins b_tx = {UCIE_DIR_B_TX};
                bins a_rx = {UCIE_DIR_A_RX};
                bins b_rx = {UCIE_DIR_B_RX};
            }
        endgroup
`endif

        function new(string name, uvm_component parent);
            super.new(name, parent);
`ifndef VERILATOR
            ucie_cg = new();
`endif
        endfunction

        function void write(ucie_flit_item t);
            dir_q = t.dir;
`ifndef VERILATOR
            ucie_cg.sample();
`endif
        endfunction
    endclass

    class ucie_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(ucie_scoreboard)

        uvm_analysis_imp #(ucie_flit_item, ucie_scoreboard) analysis_export;
        int unsigned observed_flits;
        int unsigned a_tx_count;
        int unsigned b_tx_count;
        int unsigned a_rx_count;
        int unsigned b_rx_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function void write(ucie_flit_item t);
            observed_flits++;
            case (t.dir)
                UCIE_DIR_A_TX: a_tx_count++;
                UCIE_DIR_B_TX: b_tx_count++;
                UCIE_DIR_A_RX: a_rx_count++;
                UCIE_DIR_B_RX: b_rx_count++;
                default: ;
            endcase
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info(get_type_name(),
                      $sformatf("Observed UCIe flits total=%0d a_tx=%0d b_tx=%0d a_rx=%0d b_rx=%0d",
                                observed_flits, a_tx_count, b_tx_count, a_rx_count, b_rx_count),
                      UVM_LOW)
        endfunction
    endclass
endpackage

`endif
