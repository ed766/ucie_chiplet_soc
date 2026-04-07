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
            "prbs_retry_burst": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 96;
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
                cfg.link.enable_retry_burst = 1'b1;
                cfg.link.error_inject_modulus = 128;
            end
            "prbs_fault_retrain": begin
                cfg.scenario_kind = "directed";
                cfg.target_tx_count = 128;
                cfg.link.enable_retry_burst = 1'b1;
                cfg.link.enable_fault_echo = 1'b1;
                cfg.link.error_inject_modulus = 192;
            end
            "prbs_rand_stress": begin
                cfg.scenario_kind = "random";
                cfg.randomized = 1'b1;
                cfg.target_tx_count = 192;
                cfg.link.enable_credit_starve = 1'b1;
                cfg.link.enable_backpressure = 1'b1;
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
            default: begin
                found = 1'b0;
            end
        endcase
    endtask

endpackage : prbs_tests_pkg

`endif
