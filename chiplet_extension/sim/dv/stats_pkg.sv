`ifndef UCIE_STATS_PKG_SV
`define UCIE_STATS_PKG_SV

package stats_pkg;

    localparam string DV_RESULT_PREFIX = "DV_RESULT";

    function automatic string result_status(input bit pass);
        if (pass) begin
            return "PASS";
        end
        return "FAIL";
    endfunction

    task automatic emit_result_line(
        input string bench_name,
        input string test_name,
        input string scenario_kind,
        input int unsigned seed,
        input string bug_mode,
        input bit pass,
        input string detail,
        input int unsigned tx_count,
        input int unsigned rx_count,
        input int unsigned retry_count,
        input int unsigned mismatch_count,
        input int unsigned drop_count,
        input int unsigned latency_violation_count,
        input int unsigned e2e_mismatch_count,
        input int unsigned expected_empty_count,
        input int unsigned dma_desc_completed_count,
        input int unsigned dma_submit_accepted_count,
        input int unsigned dma_submit_rejected_count,
        input int unsigned dma_completion_push_count,
        input int unsigned dma_completion_pop_count,
        input int unsigned dma_irq_count,
        input int unsigned dma_error_count,
        input int unsigned dma_mem_mismatch_count,
        input int unsigned cov_hits,
        input int unsigned cov_total,
        input string score_path,
        input string cov_path,
        input string power_path
    );
        string local_bug_mode;
        string local_power_path;
        local_bug_mode = bug_mode;
        if (local_bug_mode.len() == 0) begin
            local_bug_mode = "none";
        end
        local_power_path = power_path;
        $display("%s|bench=%s|test=%s|scenario=%s|seed=%0d|bug_mode=%s|status=%s|detail=%s|tx=%0d|rx=%0d|retries=%0d|mismatch=%0d|drop=%0d|latency_violations=%0d|e2e_mismatch=%0d|expected_empty=%0d|dma_desc_completed=%0d|dma_submit_accepted=%0d|dma_submit_rejected=%0d|dma_completion_push=%0d|dma_completion_pop=%0d|dma_irq_count=%0d|dma_error_count=%0d|dma_mem_mismatch=%0d|cov_hits=%0d|cov_total=%0d|score_csv=%s|cov_csv=%s|power_csv=%s",
                 DV_RESULT_PREFIX,
                 bench_name,
                 test_name,
                 scenario_kind,
                 seed,
                 local_bug_mode,
                 result_status(pass),
                 detail,
                 tx_count,
                 rx_count,
                 retry_count,
                 mismatch_count,
                 drop_count,
                 latency_violation_count,
                 e2e_mismatch_count,
                 expected_empty_count,
                 dma_desc_completed_count,
                 dma_submit_accepted_count,
                 dma_submit_rejected_count,
                 dma_completion_push_count,
                 dma_completion_pop_count,
                 dma_irq_count,
                 dma_error_count,
                 dma_mem_mismatch_count,
                 cov_hits,
                 cov_total,
                 score_path,
                 cov_path,
                 local_power_path);
    endtask

endpackage : stats_pkg

`endif
