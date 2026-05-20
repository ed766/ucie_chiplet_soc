`timescale 1ns/1ps

`include "tb_params.svh"

module tb_chiplet_uvm;
    import uvm_pkg::*;
    import ucie_uvm_pkg::*;
    import dma_uvm_pkg::*;
    import power_uvm_pkg::*;
    import chiplet_uvm_pkg::*;

    logic clk;
    logic rst_n;
    logic [1:0] power_state;
    logic dma_mode_force;
    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;

    chiplet_csr_if   csr_if(clk);
    chiplet_power_if pwr_if(clk);
    ucie_stream_if   ucie_if(clk);
    chiplet_obs_if   obs_if(clk);

    logic [31:0] cfg_rdata;
    logic        cfg_ready;
    logic        irq_done;
    logic [63:0] plaintext_monitor;
    logic [63:0] ciphertext_monitor;
    logic [63:0] die_b_ciphertext_monitor;
    logic        crypto_error_flag;
    logic        dma_busy_monitor;
    logic        dma_done_monitor;
    logic        dma_error_monitor;
    logic        irq_done_monitor;
    logic [15:0] dma_tag_monitor;
    logic        last_dma_done_monitor;
    logic        last_dma_error_monitor;
    logic        last_irq_done_monitor;
    logic        last_submit_accept_event;
    logic        last_comp_push_event;
    logic        last_comp_pop_event;
    logic [2:0]  prev_link_state_a;
    logic [2:0]  prev_link_state_b;
    logic [1:0]  prev_power_state;
    logic        dma_retry_seen;
    logic        dma_recovery_seen;
    logic        dma_sleep_resume_seen;
    logic        latency_valid;
    logic [15:0] latency_value;
    logic        tx_fire;
    logic        rx_fire;
    logic        power_idle_proxy;

    assign tx_fire = u_dut.u_die_a.tx_stream_valid && u_dut.u_die_a.tx_stream_ready;
    assign rx_fire = u_dut.u_die_a.rx_stream_valid && u_dut.u_die_a.rx_stream_ready;
    assign power_idle_proxy = pwr_if.rst_n &&
                              !u_dut.u_die_a.flit_tx_valid &&
                              !u_dut.u_die_b.flit_tx_valid &&
                              !u_dut.u_die_a.rx_stream_valid;

    initial begin
        pwr_if.rst_n = 1'b0;
        pwr_if.power_state = 2'd0;
        pwr_if.dma_mode_force = 1'b0;
        csr_if.cfg_valid = 1'b0;
        csr_if.cfg_write = 1'b0;
        csr_if.cfg_addr = '0;
        csr_if.cfg_wdata = '0;
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    assign rst_n = pwr_if.rst_n;
    assign power_state = pwr_if.power_state;
    assign dma_mode_force = pwr_if.dma_mode_force;
    assign cfg_valid = csr_if.cfg_valid;
    assign cfg_write = csr_if.cfg_write;
    assign cfg_addr = csr_if.cfg_addr;
    assign cfg_wdata = csr_if.cfg_wdata;

    soc_chiplet_top #(
        .DATA_WIDTH(`TB_DATA_WIDTH),
        .FLIT_WIDTH(`TB_FLIT_WIDTH),
        .LANES(`TB_LANES)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .power_state(power_state),
        .dma_mode_force(dma_mode_force),
        .cfg_valid(cfg_valid),
        .cfg_write(cfg_write),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .cfg_ready(cfg_ready),
        .irq_done(irq_done),
        .plaintext_monitor(plaintext_monitor),
        .ciphertext_monitor(ciphertext_monitor),
        .die_b_ciphertext_monitor(die_b_ciphertext_monitor),
        .crypto_error_flag(crypto_error_flag),
        .dma_busy_monitor(dma_busy_monitor),
        .dma_done_monitor(dma_done_monitor),
        .dma_error_monitor(dma_error_monitor),
        .irq_done_monitor(irq_done_monitor),
        .dma_tag_monitor(dma_tag_monitor)
    );

    assign csr_if.cfg_rdata = cfg_rdata;
    assign csr_if.cfg_ready = cfg_ready;

    stats_monitor u_uvm_stats (
        .clk               (clk),
        .rst_n             (pwr_if.rst_n),
        .link_state_a      (u_dut.u_die_a.u_link_fsm.state_q),
        .link_state_b      (u_dut.u_die_b.u_link_fsm.state_q),
        .credit_available_a(u_dut.u_die_a.credit_available),
        .credit_available_b(u_dut.u_die_b.credit_available),
        .backpressure_a    (u_dut.u_die_a.flit_tx_valid && !u_dut.u_die_a.flit_tx_ready),
        .backpressure_b    (u_dut.u_die_b.flit_tx_valid && !u_dut.u_die_b.flit_tx_ready),
        .crc_error_a       (u_dut.u_die_a.depacketizer_crc_error),
        .crc_error_b       (u_dut.u_die_b.depacketizer_crc_error),
        .resend_request_a  (u_dut.u_die_a.resend_request),
        .resend_request_b  (u_dut.u_die_b.resend_request),
        .lane_fault_a      (u_dut.u_die_a.lane_adapter_lane_fault),
        .lane_fault_b      (u_dut.u_die_b.lane_adapter_lane_fault),
        .latency_valid     (latency_valid),
        .latency_value     (latency_value),
        .tx_fire           (tx_fire),
        .rx_fire           (rx_fire),
        .e2e_update        (rx_fire || u_dut.u_die_a.u_dma.comp_push_event_q),
        .e2e_mismatch      (1'b0),
        .expected_empty    (1'b0),
        .power_reset_proxy (!pwr_if.rst_n),
        .power_idle_proxy  (power_idle_proxy),
        .dma_mode_active   (pwr_if.dma_mode_force),
        .dma_active_valid  (u_dut.u_die_a.u_dma.active_valid_q),
        .dma_state         (u_dut.u_die_a.u_dma.state_q),
        .dma_submit_count  (u_dut.u_die_a.u_dma.submit_count_q),
        .dma_comp_count    (u_dut.u_die_a.u_dma.comp_count_q),
        .dma_submit_head   (u_dut.u_die_a.u_dma.submit_head_q),
        .dma_submit_tail   (u_dut.u_die_a.u_dma.submit_tail_q),
        .dma_comp_head     (u_dut.u_die_a.u_dma.comp_head_q),
        .dma_comp_tail     (u_dut.u_die_a.u_dma.comp_tail_q),
        .dma_comp_full_stall(u_dut.u_die_a.u_dma.comp_full_stall_q),
        .dma_submit_accept_event(u_dut.u_die_a.u_dma.submit_accept_event_q),
        .dma_submit_reject_event(u_dut.u_die_a.u_dma.submit_reject_event_q),
        .dma_submit_reject_err_code(u_dut.u_die_a.u_dma.submit_reject_err_code_q),
        .dma_comp_push_event(u_dut.u_die_a.u_dma.comp_push_event_q),
        .dma_comp_pop_event (u_dut.u_die_a.u_dma.comp_pop_event_q),
        .dma_comp_push_status(u_dut.u_die_a.u_dma.comp_push_status_q),
        .dma_comp_push_err_code(u_dut.u_die_a.u_dma.comp_push_err_code_q),
        .dma_reject_overflow_count(u_dut.u_die_a.u_dma.reject_overflow_count_q),
        .dma_retry_seen    (dma_retry_seen),
        .dma_recovery_seen (dma_recovery_seen),
        .dma_sleep_resume_seen(dma_sleep_resume_seen),
        .mem_src_conflicts (u_dut.u_die_a.u_dma.src_conflicts_q),
        .mem_dst_conflicts (u_dut.u_die_a.u_dma.dst_conflicts_q),
        .mem_src_wait_cycles(u_dut.u_die_a.u_dma.src_wait_cycles_q),
        .mem_dst_wait_cycles(u_dut.u_die_a.u_dma.dst_wait_cycles_q),
        .mem_op_parity_error(u_dut.u_die_a.u_dma.mem_op_parity_error_q),
        .mem_op_invalid_read_seen(u_dut.u_die_a.u_dma.mem_op_invalid_read_seen_q),
        .mem_write_reject_dma_active(u_dut.u_die_a.u_dma.mem_op_write_reject_dma_active_q),
        .mem_src_invalid_bank_mask(u_dut.u_die_a.u_dma.src_invalid_bank_mask_q),
        .mem_dst_invalid_bank_mask(u_dut.u_die_a.u_dma.dst_invalid_bank_mask_q),
        .mem_wake_apply_seen(u_dut.u_die_a.u_dma.wake_apply_seen_q)
    );

    always_ff @(posedge clk) begin
        obs_if.rst_n <= pwr_if.rst_n;
        obs_if.plaintext_monitor <= plaintext_monitor;
        obs_if.ciphertext_monitor <= ciphertext_monitor;
        obs_if.die_b_ciphertext_monitor <= die_b_ciphertext_monitor;
        obs_if.crypto_error_flag <= crypto_error_flag;
        obs_if.dma_busy_monitor <= dma_busy_monitor;
        obs_if.dma_done_monitor <= dma_done_monitor;
        obs_if.dma_error_monitor <= dma_error_monitor;
        obs_if.irq_done_monitor <= irq_done_monitor;
        obs_if.dma_tag_monitor <= dma_tag_monitor;

        ucie_if.rst_n <= pwr_if.rst_n;
        ucie_if.a_tx_data <= u_dut.u_die_a.flit_tx_payload;
        ucie_if.a_tx_valid <= u_dut.u_die_a.flit_tx_valid;
        ucie_if.a_tx_ready <= u_dut.u_die_a.flit_tx_ready;
        ucie_if.b_tx_data <= u_dut.u_die_b.flit_tx_payload;
        ucie_if.b_tx_valid <= u_dut.u_die_b.flit_tx_valid;
        ucie_if.b_tx_ready <= u_dut.u_die_b.flit_tx_ready;
        ucie_if.a_rx_data <= u_dut.u_die_a.flit_rx_payload;
        ucie_if.a_rx_valid <= u_dut.u_die_a.flit_rx_valid;
        ucie_if.b_rx_data <= u_dut.u_die_b.flit_rx_payload;
        ucie_if.b_rx_valid <= u_dut.u_die_b.flit_rx_valid;

        pwr_if.sw_pd_a_traffic <= u_dut.u_pwr_ctrl.sw_pd_a_traffic;
        pwr_if.sw_pd_a_dma <= u_dut.u_pwr_ctrl.sw_pd_a_dma;
        pwr_if.sw_pd_a_link <= u_dut.u_pwr_ctrl.sw_pd_a_link;
        pwr_if.sw_pd_b_crypto <= u_dut.u_pwr_ctrl.sw_pd_b_crypto;
        pwr_if.sw_pd_b_link <= u_dut.u_pwr_ctrl.sw_pd_b_link;
        pwr_if.sw_pd_channel <= u_dut.u_pwr_ctrl.sw_pd_channel;
        pwr_if.iso_pd_a_traffic_n <= u_dut.u_pwr_ctrl.iso_pd_a_traffic_n;
        pwr_if.iso_pd_a_dma_n <= u_dut.u_pwr_ctrl.iso_pd_a_dma_n;
        pwr_if.iso_pd_a_link_n <= u_dut.u_pwr_ctrl.iso_pd_a_link_n;
        pwr_if.iso_pd_b_crypto_n <= u_dut.u_pwr_ctrl.iso_pd_b_crypto_n;
        pwr_if.iso_pd_b_link_n <= u_dut.u_pwr_ctrl.iso_pd_b_link_n;
        pwr_if.iso_pd_channel_n <= u_dut.u_pwr_ctrl.iso_pd_channel_n;
        pwr_if.save_dma_sleep <= u_dut.u_pwr_ctrl.save_dma_sleep;
        pwr_if.restore_dma_sleep <= u_dut.u_pwr_ctrl.restore_dma_sleep;
        pwr_if.save_dma_mem <= u_dut.u_pwr_ctrl.save_dma_mem;
        pwr_if.restore_dma_mem <= u_dut.u_pwr_ctrl.restore_dma_mem;

        if (!pwr_if.rst_n) begin
            last_dma_done_monitor <= 1'b0;
            last_dma_error_monitor <= 1'b0;
            last_irq_done_monitor <= 1'b0;
            last_submit_accept_event <= 1'b0;
            last_comp_push_event <= 1'b0;
            last_comp_pop_event <= 1'b0;
            prev_link_state_a <= 3'd0;
            prev_link_state_b <= 3'd0;
            prev_power_state <= PWR_RUN;
            dma_retry_seen <= 1'b0;
            dma_recovery_seen <= 1'b0;
            dma_sleep_resume_seen <= 1'b0;
            latency_valid <= 1'b0;
            latency_value <= '0;
        end else begin
            latency_valid <= rx_fire || u_dut.u_die_a.u_dma.comp_push_event_q;
            latency_value <= 16'd32;
            if (u_dut.u_die_a.resend_request ||
                u_dut.u_die_b.resend_request ||
                u_dut.u_die_a.depacketizer_crc_error ||
                u_dut.u_die_b.depacketizer_crc_error ||
                u_dut.u_die_a.lane_adapter_lane_fault ||
                u_dut.u_die_b.lane_adapter_lane_fault) begin
                dma_retry_seen <= 1'b1;
            end
            if ((((prev_link_state_a == 3'd3) || (prev_link_state_a == 3'd4)) &&
                 (u_dut.u_die_a.u_link_fsm.state_q == 3'd2)) ||
                (((prev_link_state_b == 3'd3) || (prev_link_state_b == 3'd4)) &&
                 (u_dut.u_die_b.u_link_fsm.state_q == 3'd2))) begin
                dma_recovery_seen <= 1'b1;
            end
            if ((prev_power_state != PWR_RUN) && (pwr_if.power_state == PWR_RUN)) begin
                dma_sleep_resume_seen <= 1'b1;
            end
            if (u_dut.u_die_a.flit_tx_valid && u_dut.u_die_a.flit_tx_ready) begin
                ucie_uvm_pkg::g_observed_flits++;
                ucie_uvm_pkg::g_a_tx_count++;
            end
            if (u_dut.u_die_b.flit_tx_valid && u_dut.u_die_b.flit_tx_ready) begin
                ucie_uvm_pkg::g_observed_flits++;
                ucie_uvm_pkg::g_b_tx_count++;
            end
            if (u_dut.u_die_a.flit_rx_valid) begin
                ucie_uvm_pkg::g_observed_flits++;
                ucie_uvm_pkg::g_a_rx_count++;
            end
            if (u_dut.u_die_b.flit_rx_valid) begin
                ucie_uvm_pkg::g_observed_flits++;
                ucie_uvm_pkg::g_b_rx_count++;
            end
            if (dma_done_monitor && !last_dma_done_monitor) begin
                dma_uvm_pkg::g_done_events++;
            end
            if (dma_error_monitor && !last_dma_error_monitor) begin
                dma_uvm_pkg::g_error_events++;
            end
            if (irq_done_monitor && !last_irq_done_monitor) begin
                dma_uvm_pkg::g_irq_events++;
            end
            case (pwr_if.power_state)
                PWR_RUN: power_uvm_pkg::g_run_cycles++;
                PWR_CRYPTO_ONLY: power_uvm_pkg::g_crypto_only_cycles++;
                PWR_SLEEP: power_uvm_pkg::g_sleep_cycles++;
                PWR_DEEP_SLEEP: power_uvm_pkg::g_deep_sleep_cycles++;
                default: ;
            endcase
            if (!(u_dut.u_pwr_ctrl.iso_pd_a_traffic_n &&
                  u_dut.u_pwr_ctrl.iso_pd_a_dma_n &&
                  u_dut.u_pwr_ctrl.iso_pd_a_link_n &&
                  u_dut.u_pwr_ctrl.iso_pd_b_crypto_n &&
                  u_dut.u_pwr_ctrl.iso_pd_b_link_n &&
                  u_dut.u_pwr_ctrl.iso_pd_channel_n)) begin
                power_uvm_pkg::g_isolation_cycles++;
            end
            if (u_dut.u_pwr_ctrl.save_dma_sleep || u_dut.u_pwr_ctrl.restore_dma_sleep ||
                u_dut.u_pwr_ctrl.save_dma_mem || u_dut.u_pwr_ctrl.restore_dma_mem) begin
                power_uvm_pkg::g_retention_events++;
            end
            last_dma_done_monitor <= dma_done_monitor;
            last_dma_error_monitor <= dma_error_monitor;
            last_irq_done_monitor <= irq_done_monitor;
            last_submit_accept_event <= u_dut.u_die_a.u_dma.submit_accept_event_q;
            last_comp_push_event <= u_dut.u_die_a.u_dma.comp_push_event_q;
            last_comp_pop_event <= u_dut.u_die_a.u_dma.comp_pop_event_q;
            prev_link_state_a <= u_dut.u_die_a.u_link_fsm.state_q;
            prev_link_state_b <= u_dut.u_die_b.u_link_fsm.state_q;
            prev_power_state <= pwr_if.power_state;
        end
    end

    task automatic reset_uvm_counters();
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
    endtask

    task automatic verilator_reset_dut(bit dma_mode);
        reset_uvm_counters();
        csr_if.init();
        pwr_if.init();
        pwr_if.dma_mode_force = dma_mode;
        pwr_if.apply_reset(8);
        repeat (16) #10;
    endtask

    task automatic verilator_wait_dma_irq(int unsigned timeout_cycles);
        int unsigned waited;
        waited = 0;
        while (!irq_done_monitor && waited < timeout_cycles) begin
            waited++;
            #10;
        end
        if (!irq_done_monitor) begin
            `uvm_error("UVM_DMASMOKE", $sformatf("Timed out waiting for DMA IRQ after %0d cycles", timeout_cycles))
        end
    endtask

    task automatic verilator_dma_queue_smoke();
        verilator_reset_dut(1'b1);
        csr_if.write32(DMA_UVM_IRQ_EN_ADDR, 32'h1);
        csr_if.write32(DMA_UVM_SRC_ADDR, 32'd0);
        csr_if.write32(DMA_UVM_DST_ADDR, 32'd32);
        csr_if.write32(DMA_UVM_LEN_ADDR, 32'd4);
        csr_if.write32(DMA_UVM_TAG_ADDR, 32'h5001);
        csr_if.write32(DMA_UVM_CTRL_ADDR, 32'h1);
        verilator_wait_dma_irq(4096);
        repeat (64) #10;
        if (dma_uvm_pkg::g_irq_events == 0) begin
            `uvm_error("UVM_DMASMOKE", "Expected DMA IRQ event in queue smoke test")
        end
        if (dma_uvm_pkg::g_error_events != 0) begin
            `uvm_error("UVM_DMASMOKE", $sformatf("Unexpected DMA errors=%0d", dma_uvm_pkg::g_error_events))
        end
    endtask

    task automatic verilator_power_sleep_resume();
        verilator_reset_dut(1'b0);
        pwr_if.set_power_state(PWR_SLEEP);
        repeat (16) #10;
        pwr_if.set_power_state(PWR_RUN);
        repeat (96) #10;
        if (power_uvm_pkg::g_sleep_cycles == 0 || power_uvm_pkg::g_retention_events == 0) begin
            `uvm_error("UVM_POWERSMOKE", "Expected sleep cycles and retention events in power sleep/resume test")
        end
    endtask

    task automatic run_verilator_uvm_smoke();
        string test_name;
        string cov_path;
        if (!$value$plusargs("UVM_TESTNAME=%s", test_name)) begin
            test_name = "uvm_prbs_smoke_test";
        end
        if (!$value$plusargs("UVM_COV_OUT=%s", cov_path)) begin
            cov_path = "reports/uvm_coverage.csv";
        end
        `uvm_info("RNTST", $sformatf("Running test %s...", test_name), UVM_LOW)
        case (test_name)
            "uvm_prbs_smoke_test": begin
                verilator_reset_dut(1'b0);
                repeat (512) #10;
                if (ucie_uvm_pkg::g_observed_flits == 0) begin
                    `uvm_error("UVM_PRBSSMOKE", "Expected UCIe traffic in PRBS smoke test")
                end
            end
            "uvm_soc_smoke_test": begin
                verilator_reset_dut(1'b0);
                repeat (768) #10;
                if (ucie_uvm_pkg::g_b_tx_count == 0) begin
                    `uvm_error("UVM_SOCSMOKE", "Expected Die B return traffic in SoC smoke test")
                end
            end
            "uvm_dma_queue_smoke_test": begin
                verilator_dma_queue_smoke();
            end
            "uvm_power_sleep_resume_test": begin
                verilator_power_sleep_resume();
            end
            default: begin
                `uvm_error("UVM_TESTSEL", $sformatf("Unknown UVM test %s", test_name))
            end
        endcase
        u_uvm_stats.write_coverage(cov_path);
        `uvm_info("UVM_SUMMARY",
                  $sformatf("flits=%0d dma_irq=%0d dma_err=%0d run=%0d sleep=%0d retention=%0d cov_hits=%0d cov_total=%0d cov_csv=%s",
                            ucie_uvm_pkg::g_observed_flits,
                            dma_uvm_pkg::g_irq_events,
                            dma_uvm_pkg::g_error_events,
                            power_uvm_pkg::g_run_cycles,
                            power_uvm_pkg::g_sleep_cycles,
                            power_uvm_pkg::g_retention_events,
                            u_uvm_stats.coverage_hits(),
                            u_uvm_stats.coverage_total(),
                            cov_path),
                  UVM_LOW)
        #10;
        $finish;
    endtask

    initial begin
        uvm_coreservice_t cs;
        chiplet_noop_component_visitor visitor;
        ucie_uvm_pkg::g_ucie_vif = ucie_if;
        dma_uvm_pkg::g_csr_vif = csr_if;
        dma_uvm_pkg::g_obs_vif = obs_if;
        power_uvm_pkg::g_pwr_vif = pwr_if;
        cs = uvm_coreservice_t::get();
        visitor = chiplet_noop_component_visitor::type_id::create("visitor");
        cs.set_component_visitor(visitor);
`ifdef VERILATOR
        run_verilator_uvm_smoke();
`else
        run_test();
`endif
    end
endmodule : tb_chiplet_uvm
