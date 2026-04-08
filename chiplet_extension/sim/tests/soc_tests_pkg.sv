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
            default: begin
                found = 1'b0;
            end
        endcase
    endtask

endpackage : soc_tests_pkg

`endif
