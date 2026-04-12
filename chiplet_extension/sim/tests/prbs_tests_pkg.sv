`ifndef UCIE_PRBS_TESTS_PKG_SV
`define UCIE_PRBS_TESTS_PKG_SV

package prbs_tests_pkg;

    import txn_pkg::*;

    task automatic apply_prbs_named_test(
        input string test_name,
        output bit found,
        output ucie_test_cfg cfg
    );
        cfg = new("tb_ucie_prbs");
        cfg.test_name = test_name;
        found = 1'b1;

        case (test_name)
            "prbs_smoke": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 128;
                cfg.link.gap_ceiling = 2;
            end
            "prbs_credit_starve": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 160;
                cfg.link.enable_credit_starve = 1'b1;
                cfg.link.credit_block_start = 140;
                cfg.link.credit_block_cycles = 80;
            end
            "prbs_credit_low": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 48;
                cfg.link.enable_backpressure = 1'b0;
                cfg.link.gap_ceiling = 0;
                cfg.link.enable_credit_init_override = 1'b1;
                cfg.link.credit_init_override = 12;
            end
            "prbs_retry_single": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 64;
                cfg.allow_crc_error = 1'b1;
                cfg.link.gap_ceiling = 48;
                cfg.link.enable_crc_window = 1'b1;
                cfg.link.crc_window_start = 160;
                cfg.link.crc_window_count = 1;
                cfg.link.crc_window_spacing = 1;
                cfg.max_cycles = 12000;
            end
            "prbs_retry_backpressure": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 80;
                cfg.allow_crc_error = 1'b1;
                cfg.link.gap_ceiling = 48;
                cfg.link.enable_crc_window = 1'b1;
                cfg.link.crc_window_start = 140;
                cfg.link.crc_window_count = 2;
                cfg.link.crc_window_spacing = 16;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 4;
                cfg.link.backpressure_hold_cycles = 2;
                cfg.max_cycles = 14000;
            end
            "prbs_crc_burst_recover": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 80;
                cfg.allow_crc_error = 1'b1;
                cfg.link.gap_ceiling = 40;
                cfg.link.enable_crc_window = 1'b1;
                cfg.link.crc_window_start = 140;
                cfg.link.crc_window_count = 2;
                cfg.link.crc_window_spacing = 16;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 5;
                cfg.link.backpressure_hold_cycles = 1;
                cfg.max_cycles = 14000;
            end
            "prbs_lane_fault_recover": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 96;
                cfg.allow_crc_error = 1'b1;
                cfg.link.gap_ceiling = 40;
                cfg.link.enable_lane_fault_window = 1'b1;
                cfg.link.lane_fault_start = 176;
                cfg.link.lane_fault_cycles = 2;
                cfg.link.training_hold_start = 176;
                cfg.link.training_hold_cycles = 320;
                cfg.max_cycles = 15000;
            end
            "prbs_latency_low": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 64;
                cfg.link.enable_backpressure = 1'b0;
                cfg.link.gap_ceiling = 0;
                cfg.link.channel_delay_cycles = 0;
            end
            "prbs_latency_high": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 64;
                cfg.link.enable_backpressure = 1'b0;
                cfg.link.gap_ceiling = 0;
                cfg.link.channel_delay_cycles = 20;
                cfg.max_cycles = 14000;
            end
            "prbs_latency_nominal": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 64;
                cfg.link.enable_backpressure = 1'b0;
                cfg.link.gap_ceiling = 0;
                cfg.link.channel_delay_cycles = 10;
            end
            "prbs_retry_burst": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 96;
                cfg.allow_crc_error = 1'b1;
                cfg.link.enable_retry_burst = 1'b1;
                cfg.link.error_inject_modulus = 256;
            end
            "prbs_reset_midflight": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 160;
                cfg.link.enable_midflight_reset = 1'b1;
                cfg.link.midflight_reset_cycle = 220;
            end
            "prbs_backpressure_wave": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 160;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 4;
                cfg.link.backpressure_hold_cycles = 3;
            end
            "prbs_crc_storm": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 96;
                cfg.allow_crc_error = 1'b1;
                cfg.link.enable_retry_burst = 1'b1;
                cfg.link.error_inject_modulus = 128;
            end
            "prbs_fault_retrain": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 128;
                cfg.allow_crc_error = 1'b1;
                cfg.link.enable_retry_burst = 1'b1;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.error_inject_modulus = 192;
            end
            "prbs_rand_stress": begin
                cfg.scenario_kind = "random";
                cfg.randomized = 1'b1;
                cfg.target_tx_count = 128;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.backpressure_modulus = 0;
                cfg.link.backpressure_hold_cycles = 1;
                cfg.link.gap_ceiling = 0;
            end
            "bug_credit_off_by_one": begin
                cfg.scenario_kind = "bug_validation";
                cfg.bug_mode = "UCIE_BUG_CREDIT_OFF_BY_ONE";
                cfg.target_tx_count = 224;
                cfg.link.enable_credit_starve = 1'b1;
                cfg.link.enable_backpressure = 1'b1;
                cfg.link.credit_block_start = 120;
                cfg.link.credit_block_cycles = 100;
            end
            "bug_crc_poly": begin
                cfg.scenario_kind = "bug_validation";
                cfg.bug_mode = "UCIE_BUG_CRC_POLY";
                cfg.target_tx_count = 128;
            end
            "bug_retry_seq": begin
                cfg.scenario_kind = "bug_validation";
                cfg.bug_mode = "UCIE_BUG_RETRY_SEQ";
                cfg.target_tx_count = 64;
                cfg.allow_crc_error = 1'b1;
                cfg.link.gap_ceiling = 48;
                cfg.link.enable_crc_window = 1'b1;
                cfg.link.crc_window_start = 160;
                cfg.link.crc_window_count = 1;
                cfg.link.crc_window_spacing = 1;
                cfg.max_cycles = 12000;
            end
            default: begin
                found = 1'b0;
            end
        endcase
    endtask

endpackage : prbs_tests_pkg

`endif
