`ifndef UCIE_TXN_PKG_SV
`define UCIE_TXN_PKG_SV

`include "tb_params.svh"

package txn_pkg;

    class ucie_link_txn;
        bit          enable_midflight_reset;
        bit          enable_credit_starve;
        bit          enable_retry_burst;
        bit          enable_backpressure;
        bit          enable_fault_echo;
        bit          enable_crc_window;
        bit          enable_lane_fault_window;
        int unsigned gap_ceiling;
        int unsigned backpressure_modulus;
        int unsigned backpressure_hold_cycles;
        int unsigned error_inject_modulus;
        int unsigned credit_block_start;
        int unsigned credit_block_cycles;
        int unsigned midflight_reset_cycle;
        int unsigned crc_window_start;
        int unsigned crc_window_count;
        int unsigned crc_window_spacing;
        int unsigned lane_fault_start;
        int unsigned lane_fault_cycles;
        int unsigned training_hold_start;
        int unsigned training_hold_cycles;

        function new();
            enable_midflight_reset = 1'b0;
            enable_credit_starve = 1'b0;
            enable_retry_burst = 1'b0;
            enable_backpressure = 1'b1;
            enable_fault_echo = 1'b0;
            enable_crc_window = 1'b0;
            enable_lane_fault_window = 1'b0;
            gap_ceiling = 3;
            backpressure_modulus = 8;
            backpressure_hold_cycles = 1;
            error_inject_modulus = 0;
            credit_block_start = 200;
            credit_block_cycles = 100;
            midflight_reset_cycle = 300;
            crc_window_start = 180;
            crc_window_count = 1;
            crc_window_spacing = 8;
            lane_fault_start = 180;
            lane_fault_cycles = 1;
            training_hold_start = 180;
            training_hold_cycles = 0;
        endfunction
    endclass

    class ucie_test_cfg;
        string       bench_name;
        string       test_name;
        string       scenario_kind;
        string       bug_mode;
        bit          randomized;
        bit          neg_wrong_key;
        bit          neg_misalign;
        bit          allow_crc_error;
        int unsigned seed;
        int unsigned target_tx_count;
        int unsigned target_cipher_updates;
        int unsigned max_cycles;
        ucie_link_txn link;

        function new(input string bench = "");
            bench_name = bench;
            test_name = "";
            scenario_kind = "directed";
            bug_mode = "none";
            randomized = 1'b0;
            neg_wrong_key = 1'b0;
            neg_misalign = 1'b0;
            allow_crc_error = 1'b0;
            seed = `TB_SEED_DEFAULT;
            target_tx_count = 128;
            target_cipher_updates = 8;
            max_cycles = 5000;
            link = new();
        endfunction

        function void apply_seed(input int unsigned new_seed);
            int unsigned state;
            seed = new_seed;
            if (randomized) begin
                state = new_seed ^ 32'h4d56_4456;
                if (link.gap_ceiling == 0) begin
                    link.gap_ceiling = 16 + (state % 24);
                end
                if (link.backpressure_modulus == 0) begin
                    link.backpressure_modulus = 4 + ((state >> 4) % 8);
                end
                if (link.error_inject_modulus == 0 && link.enable_retry_burst) begin
                    link.error_inject_modulus = 5 + ((state >> 9) % 11);
                end
                if (link.credit_block_cycles == 0 && link.enable_credit_starve) begin
                    link.credit_block_cycles = 40 + ((state >> 13) % 80);
                end
                if (link.credit_block_start == 0 && link.enable_credit_starve) begin
                    link.credit_block_start = 80 + ((state >> 18) % 160);
                end
                if (link.midflight_reset_cycle == 0 && link.enable_midflight_reset) begin
                    link.midflight_reset_cycle = 120 + ((state >> 22) % 200);
                end
                if (link.enable_crc_window && link.crc_window_start == 0) begin
                    link.crc_window_start = 80 + ((state >> 5) % 96);
                end
                if (link.enable_lane_fault_window && link.lane_fault_start == 0) begin
                    link.lane_fault_start = 96 + ((state >> 11) % 128);
                end
                if (link.enable_lane_fault_window && link.training_hold_cycles == 0) begin
                    link.training_hold_cycles = 24 + ((state >> 17) % 48);
                end
                target_tx_count = 160 + (new_seed % 96);
                target_cipher_updates = 8 + ((new_seed >> 7) % 8);
            end
        endfunction

        function void apply_runtime_plusargs();
            int unsigned local_u32;
            string local_bug_mode;

            if ($value$plusargs("SEED=%d", local_u32)) begin
                seed = local_u32;
            end
            if ($value$plusargs("TARGET_TX_COUNT=%d", local_u32)) begin
                target_tx_count = local_u32;
            end
            if ($value$plusargs("TARGET_CIPHER_UPDATES=%d", local_u32)) begin
                target_cipher_updates = local_u32;
            end
            if ($value$plusargs("MAX_CYCLES=%d", local_u32)) begin
                max_cycles = local_u32;
            end
            if ($value$plusargs("BUG_MODE=%s", local_bug_mode)) begin
                bug_mode = local_bug_mode;
            end
            if ($value$plusargs("GAP_CEILING=%d", local_u32)) begin
                link.gap_ceiling = local_u32;
            end
            if ($value$plusargs("BACKPRESSURE_MOD=%d", local_u32)) begin
                link.backpressure_modulus = local_u32;
            end
            if ($value$plusargs("BACKPRESSURE_HOLD=%d", local_u32)) begin
                link.backpressure_hold_cycles = local_u32;
            end
            if ($value$plusargs("ERROR_MOD=%d", local_u32)) begin
                link.error_inject_modulus = local_u32;
            end
            if ($value$plusargs("CREDIT_BLOCK_START=%d", local_u32)) begin
                link.credit_block_start = local_u32;
            end
            if ($value$plusargs("CREDIT_BLOCK_CYCLES=%d", local_u32)) begin
                link.credit_block_cycles = local_u32;
            end
            if ($value$plusargs("RESET_CYCLE=%d", local_u32)) begin
                link.midflight_reset_cycle = local_u32;
            end
            if ($value$plusargs("CRC_START=%d", local_u32)) begin
                link.crc_window_start = local_u32;
            end
            if ($value$plusargs("CRC_COUNT=%d", local_u32)) begin
                link.crc_window_count = local_u32;
            end
            if ($value$plusargs("CRC_SPACING=%d", local_u32)) begin
                link.crc_window_spacing = local_u32;
            end
            if ($value$plusargs("LANE_FAULT_START=%d", local_u32)) begin
                link.lane_fault_start = local_u32;
            end
            if ($value$plusargs("LANE_FAULT_CYCLES=%d", local_u32)) begin
                link.lane_fault_cycles = local_u32;
            end
            if ($value$plusargs("TRAINING_HOLD_START=%d", local_u32)) begin
                link.training_hold_start = local_u32;
            end
            if ($value$plusargs("TRAINING_HOLD_CYCLES=%d", local_u32)) begin
                link.training_hold_cycles = local_u32;
            end
        endfunction
    endclass

endpackage : txn_pkg

`endif
