`ifndef UCIE_SOC_TESTS_PKG_SV
`define UCIE_SOC_TESTS_PKG_SV

package soc_tests_pkg;

    import txn_pkg::*;

    task automatic apply_soc_named_test(
        input string test_name,
        output bit found,
        output ucie_test_cfg cfg
    );
        cfg = new("tb_soc_chiplets");
        cfg.test_name = test_name;
        found = 1'b1;

        case (test_name)
            "soc_smoke": begin
                cfg.scenario_kind = "directed";
                cfg.target_cipher_updates = 8;
            end
            "soc_wrong_key": begin
                cfg.scenario_kind = "negative";
                cfg.target_cipher_updates = 8;
                cfg.neg_wrong_key = 1'b1;
            end
            "soc_misalign": begin
                cfg.scenario_kind = "negative";
                cfg.target_cipher_updates = 8;
                cfg.neg_misalign = 1'b1;
            end
            "soc_backpressure": begin
                cfg.scenario_kind = "directed";
                cfg.target_cipher_updates = 10;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 5;
                cfg.link.backpressure_hold_cycles = 3;
            end
            "soc_expected_empty": begin
                cfg.scenario_kind = "negative";
                cfg.target_cipher_updates = 8;
                cfg.expect_expected_empty = 1'b1;
                cfg.ref_words = 4;
            end
            "soc_fault_echo": begin
                cfg.scenario_kind = "directed";
                cfg.target_cipher_updates = 10;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.enable_lane_fault_window = 1'b1;
                cfg.link.lane_fault_start = 170;
                cfg.link.lane_fault_cycles = 2;
                cfg.link.training_hold_start = 170;
                cfg.link.training_hold_cycles = 16;
            end
            "soc_retry_e2e": begin
                cfg.scenario_kind = "directed";
                cfg.target_cipher_updates = 12;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 4;
                cfg.link.backpressure_hold_cycles = 2;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.enable_lane_fault_window = 1'b1;
                cfg.link.lane_fault_start = 160;
                cfg.link.lane_fault_cycles = 2;
                cfg.link.training_hold_start = 160;
                cfg.link.training_hold_cycles = 24;
            end
            "soc_rand_mix": begin
                cfg.scenario_kind = "random";
                cfg.randomized = 1'b1;
                cfg.target_cipher_updates = 12;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.enable_lane_fault_window = 1'b1;
                cfg.link.lane_fault_start = 0;
                cfg.link.training_hold_start = 0;
                cfg.link.training_hold_cycles = 0;
            end
            "power_run_mode": begin
                cfg.scenario_kind = "power_proxy";
                cfg.target_cipher_updates = 8;
                cfg.power_mode = "run";
                cfg.link.enable_backpressure = 1'b0;
            end
            "power_crypto_only": begin
                cfg.scenario_kind = "power_proxy";
                cfg.target_cipher_updates = 10;
                cfg.power_mode = "crypto_only";
                cfg.link.enable_backpressure = 1'b0;
                cfg.power_event_start = 80;
                cfg.power_event_cycles = 48;
                cfg.max_cycles = 7000;
            end
            "power_sleep_entry_exit": begin
                cfg.scenario_kind = "power_proxy";
                cfg.target_cipher_updates = 8;
                cfg.power_mode = "sleep";
                cfg.link.enable_backpressure = 1'b0;
                cfg.power_event_start = 96;
                cfg.power_event_cycles = 10;
                cfg.max_cycles = 8000;
            end
            "power_deep_sleep_recover": begin
                cfg.scenario_kind = "power_proxy";
                cfg.target_cipher_updates = 8;
                cfg.power_mode = "deep_sleep";
                cfg.link.enable_backpressure = 1'b0;
                cfg.power_event_start = 96;
                cfg.power_event_cycles = 16;
                cfg.power_recovery_cycles = 40;
                cfg.max_cycles = 9000;
            end
            "dma_queue_smoke": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 4;
                cfg.max_cycles = 12000;
                cfg.dma_src_base = 8;
                cfg.dma_dst_base = 32;
                cfg.dma_len_words = 4;
                cfg.dma_tag = 16'h1101;
            end
            "dma_queue_back_to_back": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 12;
                cfg.max_cycles = 14000;
                cfg.dma_src_base = 8;
                cfg.dma_dst_base = 32;
                cfg.dma_len_words = 4;
                cfg.dma_tag = 16'h1102;
                cfg.dma_second_src_base = 16;
                cfg.dma_second_dst_base = 40;
                cfg.dma_second_len_words = 8;
                cfg.dma_second_tag = 16'h1103;
            end
            "dma_queue_full_reject": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 16;
                cfg.max_cycles = 18000;
            end
            "dma_completion_fifo_drain": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 12;
                cfg.max_cycles = 18000;
            end
            "dma_irq_masking": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 4;
                cfg.max_cycles = 14000;
                cfg.dma_src_base = 24;
                cfg.dma_dst_base = 56;
                cfg.dma_len_words = 4;
                cfg.dma_tag = 16'h1104;
            end
            "dma_odd_len_reject": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 8000;
                cfg.dma_src_base = 48;
                cfg.dma_dst_base = 80;
                cfg.dma_len_words = 3;
                cfg.dma_tag = 16'h1106;
            end
            "dma_range_reject": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 8000;
                cfg.dma_src_base = 252;
                cfg.dma_dst_base = 88;
                cfg.dma_len_words = 8;
                cfg.dma_tag = 16'h1107;
            end
            "dma_timeout_error": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
                cfg.dma_src_base = 56;
                cfg.dma_dst_base = 92;
                cfg.dma_len_words = 4;
                cfg.dma_tag = 16'h110b;
            end
            "dma_retry_recover_queue": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 22000;
                cfg.dma_src_base = 64;
                cfg.dma_dst_base = 96;
                cfg.dma_len_words = 4;
                cfg.dma_tag = 16'h1108;
                cfg.dma_second_src_base = 80;
                cfg.dma_second_dst_base = 112;
                cfg.dma_second_len_words = 4;
                cfg.dma_second_tag = 16'h110c;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 4;
                cfg.link.backpressure_hold_cycles = 2;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.enable_lane_fault_window = 1'b1;
                cfg.link.lane_fault_start = 120;
                cfg.link.lane_fault_cycles = 2;
                cfg.link.training_hold_start = 120;
                cfg.link.training_hold_cycles = 24;
            end
            "dma_power_sleep_resume_queue": begin
                cfg.scenario_kind = "dma_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 18000;
                cfg.dma_src_base = 72;
                cfg.dma_dst_base = 112;
                cfg.dma_len_words = 8;
                cfg.dma_tag = 16'h1109;
                cfg.power_mode = "sleep";
                cfg.power_event_start = 128;
                cfg.power_event_cycles = 10;
                cfg.power_recovery_cycles = 40;
                cfg.link.enable_backpressure = 1'b0;
            end
            "dma_comp_fifo_full_stall": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 20;
                cfg.max_cycles = 22000;
            end
            "dma_irq_pending_then_enable": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 4;
                cfg.max_cycles = 14000;
            end
            "dma_comp_pop_empty": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 6000;
            end
            "dma_reset_mid_queue": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "dma_tag_reuse": begin
                cfg.scenario_kind = "dma";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 16000;
            end
            "dma_power_state_retention_matrix": begin
                cfg.scenario_kind = "dma_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 4;
                cfg.max_cycles = 18000;
            end
            "dma_crypto_only_submit_blocked": begin
                cfg.scenario_kind = "dma_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 10000;
            end
            "mem_bank_parallel_service": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 16000;
            end
            "mem_src_bank_conflict": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 16000;
            end
            "mem_dst_bank_conflict": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 18000;
            end
            "mem_read_while_dma": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 16000;
            end
            "mem_write_while_dma_reject": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 16000;
            end
            "mem_parity_src_detect": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "mem_parity_dst_maint_detect": begin
                cfg.scenario_kind = "dma_mem";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 10000;
            end
            "mem_sleep_retained_bank": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "mem_sleep_nonretained_bank": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "mem_nonretained_readback_poison_clean": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "mem_invalid_clear_on_write": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "mem_deep_sleep_retention_matrix": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 14000;
            end
            "mem_crypto_only_cfg_access": begin
                cfg.scenario_kind = "dma_mem_power";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            "dma_bug_done_early": begin
                cfg.scenario_kind = "dma_bug";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 8;
                cfg.max_cycles = 14000;
                cfg.dma_src_base = 80;
                cfg.dma_dst_base = 128;
                cfg.dma_len_words = 8;
                cfg.dma_tag = 16'h110a;
            end
            "mem_bug_parity_skip": begin
                cfg.scenario_kind = "dma_mem_bug";
                cfg.use_dma = 1'b1;
                cfg.ref_words = 0;
                cfg.max_cycles = 12000;
            end
            default: begin
                found = 1'b0;
            end
        endcase
    endtask

endpackage : soc_tests_pkg

`endif
