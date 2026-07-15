`ifndef CHIPLET_UVM_PKG_SV
`define CHIPLET_UVM_PKG_SV

package chiplet_uvm_pkg;
    import uvm_pkg::*;
    import ucie_uvm_pkg::*;
    import dma_uvm_pkg::*;
    import power_uvm_pkg::*;
    import axi_lite_ral_pkg::*;
    `include "uvm_macros.svh"

    class chiplet_noop_component_visitor extends uvm_visitor #(uvm_component);
        `uvm_object_utils(chiplet_noop_component_visitor)

        function new(string name = "chiplet_noop_component_visitor");
            super.new(name);
        endfunction

        virtual function void visit(uvm_component node);
        endfunction
    endclass

    class chiplet_env extends uvm_env;
        `uvm_component_utils(chiplet_env)

        ucie_agent      ucie;
        dma_agent       dma;
        power_agent     power;
        ucie_coverage   ucie_cov;
        power_coverage  power_cov;
        ucie_scoreboard ucie_sb;
        dma_scoreboard  dma_sb;
        power_scoreboard power_sb;
        axi_lite_ral_env axi_ral;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ucie = ucie_agent::type_id::create("ucie", this);
            dma = dma_agent::type_id::create("dma", this);
            power = power_agent::type_id::create("power", this);
`ifdef CHIPLET_REAL_UVM
            axi_ral = axi_lite_ral_env::type_id::create("axi_ral", this);
            ucie_cov = ucie_coverage::type_id::create("ucie_cov", this);
            power_cov = power_coverage::type_id::create("power_cov", this);
            ucie_sb = ucie_scoreboard::type_id::create("ucie_sb", this);
            dma_sb = dma_scoreboard::type_id::create("dma_sb", this);
            power_sb = power_scoreboard::type_id::create("power_sb", this);
`endif
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
`ifdef CHIPLET_REAL_UVM
            ucie.monitor.ap.connect(ucie_cov.analysis_export);
            ucie.monitor.ap.connect(ucie_sb.analysis_export);
            dma.monitor.ap.connect(dma_sb.analysis_export);
            power.monitor.ap.connect(power_cov.analysis_export);
            power.monitor.ap.connect(power_sb.analysis_export);
`endif
        endfunction
    endclass

    class chiplet_base_test extends uvm_test;
        `uvm_component_utils(chiplet_base_test)

        chiplet_env env;
        virtual chiplet_power_if pwr_vif;
        virtual chiplet_csr_if csr_vif;
        virtual axi_lite_uvm_if axi_vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = chiplet_env::type_id::create("env", this);
            pwr_vif = g_pwr_vif;
            csr_vif = g_csr_vif;
            axi_vif = axi_lite_ral_pkg::g_axi_lite_vif;
            if (pwr_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_power_if")
            end
            if (csr_vif == null) begin
                `uvm_fatal(get_type_name(), "Missing virtual interface chiplet_csr_if")
            end
        endfunction

        task reset_dut();
            ucie_uvm_pkg::g_observed_flits = 0;
            ucie_uvm_pkg::g_a_tx_count = 0;
            ucie_uvm_pkg::g_b_tx_count = 0;
            ucie_uvm_pkg::g_a_rx_count = 0;
            ucie_uvm_pkg::g_b_rx_count = 0;
            dma_uvm_pkg::g_done_events = 0;
            dma_uvm_pkg::g_error_events = 0;
            dma_uvm_pkg::g_irq_events = 0;
            power_uvm_pkg::g_run_cycles = 0;
            power_uvm_pkg::g_crypto_only_cycles = 0;
            power_uvm_pkg::g_sleep_cycles = 0;
            power_uvm_pkg::g_deep_sleep_cycles = 0;
            power_uvm_pkg::g_isolation_cycles = 0;
            power_uvm_pkg::g_retention_events = 0;
            csr_vif.init();
            if (axi_vif != null) begin
                axi_vif.init();
            end
            pwr_vif.init();
            pwr_vif.apply_reset(8);
            repeat (16) #10;
        endtask

        task wait_cycles(int unsigned cycles);
            repeat (cycles) #10;
        endtask

        function void require_no_errors(string test_context);
            if (dma_uvm_pkg::g_error_events != 0) begin
                `uvm_error(get_type_name(), $sformatf("%s observed unexpected DMA errors=%0d",
                                                      test_context, dma_uvm_pkg::g_error_events))
            end
        endfunction

        task finish_uvm_test(uvm_phase phase);
            phase.drop_objection(this);
            #10;
            $finish;
        endtask

        task run_dma_queue_smoke_direct();
            csr_vif.write32(DMA_UVM_IRQ_EN_ADDR, 32'h1);
            csr_vif.write32(DMA_UVM_SRC_ADDR, 32'd0);
            csr_vif.write32(DMA_UVM_DST_ADDR, 32'd32);
            csr_vif.write32(DMA_UVM_LEN_ADDR, 32'd4);
            csr_vif.write32(DMA_UVM_TAG_ADDR, 32'h5001);
            csr_vif.write32(DMA_UVM_CTRL_ADDR, 32'h1);
            wait_dma_irq_direct(4096);
        endtask

        task wait_dma_irq_direct(int unsigned timeout_cycles);
            int unsigned waited;
            waited = 0;
            while (!dma_uvm_pkg::g_obs_vif.irq_done_monitor && waited < timeout_cycles) begin
                waited++;
                #10;
            end
            if (!dma_uvm_pkg::g_obs_vif.irq_done_monitor) begin
                `uvm_error(get_type_name(), $sformatf("Timed out waiting for DMA IRQ after %0d cycles", timeout_cycles))
            end
        endtask

        task run_power_sleep_resume_direct();
            pwr_vif.set_power_state(PWR_SLEEP);
            repeat (16) #10;
            pwr_vif.set_power_state(PWR_RUN);
            repeat (32) #10;
        endtask
    endclass

    class uvm_prbs_smoke_test extends chiplet_base_test;
        `uvm_component_utils(uvm_prbs_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            reset_dut();
            wait_cycles(512);
            if (ucie_uvm_pkg::g_observed_flits == 0) begin
                `uvm_error(get_type_name(), "Expected UCIe traffic in PRBS smoke test")
            end
            finish_uvm_test(phase);
        endtask
    endclass

    class uvm_soc_smoke_test extends chiplet_base_test;
        `uvm_component_utils(uvm_soc_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            reset_dut();
            wait_cycles(768);
            if (ucie_uvm_pkg::g_b_tx_count == 0) begin
                `uvm_error(get_type_name(), "Expected Die B return traffic in SoC smoke test")
            end
            finish_uvm_test(phase);
        endtask
    endclass

    class uvm_dma_queue_smoke_test extends chiplet_base_test;
        `uvm_component_utils(uvm_dma_queue_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            dma_queue_smoke_sequence seq;
            phase.raise_objection(this);
            reset_dut();
            pwr_vif.dma_mode_force = 1'b1;
`ifdef CHIPLET_REAL_UVM
            seq = dma_queue_smoke_sequence::type_id::create("seq");
            seq.start(env.dma.sequencer);
`else
            run_dma_queue_smoke_direct();
`endif
            wait_cycles(64);
            if (dma_uvm_pkg::g_irq_events == 0) begin
                `uvm_error(get_type_name(), "Expected DMA IRQ event in queue smoke test")
            end
            require_no_errors("uvm_dma_queue_smoke_test");
            finish_uvm_test(phase);
        endtask
    endclass

    class uvm_power_sleep_resume_test extends chiplet_base_test;
        `uvm_component_utils(uvm_power_sleep_resume_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            power_sleep_resume_sequence pseq;
            phase.raise_objection(this);
            reset_dut();
            pwr_vif.dma_mode_force = 1'b1;
`ifdef CHIPLET_REAL_UVM
            pseq = power_sleep_resume_sequence::type_id::create("pseq");
            pseq.start(env.power.sequencer);
`else
            run_power_sleep_resume_direct();
`endif
            wait_cycles(64);
            if (power_uvm_pkg::g_sleep_cycles == 0 || power_uvm_pkg::g_retention_events == 0) begin
                `uvm_error(get_type_name(), "Expected sleep cycles and retention events in power sleep/resume test")
            end
            finish_uvm_test(phase);
        endtask
    endclass

    class uvm_axi_lite_ral_smoke_test extends chiplet_base_test;
        `uvm_component_utils(uvm_axi_lite_ral_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            uvm_status_e status;
            uvm_reg_data_t data;
            phase.raise_objection(this);
            reset_dut();
            pwr_vif.dma_mode_force = 1'b1;
`ifdef CHIPLET_REAL_UVM
            env.axi_ral.reg_model.dma_irq_en.write(status, 32'h1);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL write dma_irq_en failed")
            env.axi_ral.reg_model.dma_src_base.write(status, 32'd0);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL write dma_src_base failed")
            env.axi_ral.reg_model.dma_dst_base.write(status, 32'd32);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL write dma_dst_base failed")
            env.axi_ral.reg_model.dma_len.write(status, 32'd4);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL write dma_len failed")
            env.axi_ral.reg_model.dma_tag.write(status, 32'h0000_5a17);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL write dma_tag failed")
            env.axi_ral.reg_model.dma_ctrl.write(status, 32'h1);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL doorbell write failed")
            wait_dma_irq_direct(4096);
            env.axi_ral.reg_model.dma_submit_status.read(status, data);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL read dma_submit_status failed")
            env.axi_ral.reg_model.dma_submit_result.read(status, data);
            if (status != UVM_IS_OK) `uvm_error(get_type_name(), "RAL read dma_submit_result failed")
`else
            // The compatibility runner performs the same frontdoor accesses
            // procedurally when real UVM phase/TLM support is unavailable.
`endif
            finish_uvm_test(phase);
        endtask
    endclass
endpackage

`endif
