`ifndef UCIE_COV_PKG_SV
`define UCIE_COV_PKG_SV

package ucie_cov_pkg;

    localparam int unsigned UCIE_COV_TOTAL_BINS = 23;

    function automatic int unsigned coverage_total_bins();
        return UCIE_COV_TOTAL_BINS;
    endfunction

    function automatic int unsigned coverage_hit_count(
        input int unsigned link_reset,
        input int unsigned link_train,
        input int unsigned link_active,
        input int unsigned link_retrain,
        input int unsigned link_degraded,
        input int unsigned link_recoveries,
        input int unsigned credit_zero,
        input int unsigned credit_low,
        input int unsigned credit_mid,
        input int unsigned credit_high,
        input int unsigned backpressure,
        input int unsigned crc_error,
        input int unsigned resend_request,
        input int unsigned lane_fault,
        input int unsigned retry_backpressure_cross,
        input int unsigned latency_low,
        input int unsigned latency_nominal,
        input int unsigned latency_high,
        input int unsigned e2e_updates,
        input int unsigned e2e_mismatch,
        input int unsigned expected_empty,
        input int unsigned power_reset_proxy,
        input int unsigned power_idle_proxy
    );
        int unsigned hits;
        hits = 0;
        if (link_reset != 0) begin hits = hits + 1; end
        if (link_train != 0) begin hits = hits + 1; end
        if (link_active != 0) begin hits = hits + 1; end
        if (link_retrain != 0) begin hits = hits + 1; end
        if (link_degraded != 0) begin hits = hits + 1; end
        if (link_recoveries != 0) begin hits = hits + 1; end
        if (credit_zero != 0) begin hits = hits + 1; end
        if (credit_low != 0) begin hits = hits + 1; end
        if (credit_mid != 0) begin hits = hits + 1; end
        if (credit_high != 0) begin hits = hits + 1; end
        if (backpressure != 0) begin hits = hits + 1; end
        if (crc_error != 0) begin hits = hits + 1; end
        if (resend_request != 0) begin hits = hits + 1; end
        if (lane_fault != 0) begin hits = hits + 1; end
        if (retry_backpressure_cross != 0) begin hits = hits + 1; end
        if (latency_low != 0) begin hits = hits + 1; end
        if (latency_nominal != 0) begin hits = hits + 1; end
        if (latency_high != 0) begin hits = hits + 1; end
        if (e2e_updates != 0) begin hits = hits + 1; end
        if (e2e_mismatch != 0) begin hits = hits + 1; end
        if (expected_empty != 0) begin hits = hits + 1; end
        if (power_reset_proxy != 0) begin hits = hits + 1; end
        if (power_idle_proxy != 0) begin hits = hits + 1; end
        return hits;
    endfunction

    task automatic write_cov_csv(
        input string path,
        input int unsigned sample_cycles,
        input int unsigned link_reset,
        input int unsigned link_train,
        input int unsigned link_active,
        input int unsigned link_retrain,
        input int unsigned link_degraded,
        input int unsigned link_transitions,
        input int unsigned link_recoveries,
        input int unsigned credit_zero,
        input int unsigned credit_low,
        input int unsigned credit_mid,
        input int unsigned credit_high,
        input int unsigned backpressure,
        input int unsigned crc_error,
        input int unsigned resend_request,
        input int unsigned lane_fault,
        input int unsigned retry_backpressure_cross,
        input int unsigned latency_low,
        input int unsigned latency_nominal,
        input int unsigned latency_high,
        input int unsigned e2e_updates,
        input int unsigned e2e_mismatch,
        input int unsigned expected_empty,
        input int unsigned power_reset_proxy,
        input int unsigned power_idle_proxy
    );
        int fd;
        int unsigned covered_bins;
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open coverage report file: %s", path);
        end else begin
            covered_bins = coverage_hit_count(
                link_reset,
                link_train,
                link_active,
                link_retrain,
                link_degraded,
                link_recoveries,
                credit_zero,
                credit_low,
                credit_mid,
                credit_high,
                backpressure,
                crc_error,
                resend_request,
                lane_fault,
                retry_backpressure_cross,
                latency_low,
                latency_nominal,
                latency_high,
                e2e_updates,
                e2e_mismatch,
                expected_empty,
                power_reset_proxy,
                power_idle_proxy
            );

            $fdisplay(fd, "metric,value");
            $fdisplay(fd, "sample_cycles,%0d", sample_cycles);
            $fdisplay(fd, "link_reset,%0d", link_reset);
            $fdisplay(fd, "link_train,%0d", link_train);
            $fdisplay(fd, "link_active,%0d", link_active);
            $fdisplay(fd, "link_retrain,%0d", link_retrain);
            $fdisplay(fd, "link_degraded,%0d", link_degraded);
            $fdisplay(fd, "link_transitions,%0d", link_transitions);
            $fdisplay(fd, "link_recoveries,%0d", link_recoveries);
            $fdisplay(fd, "credit_zero,%0d", credit_zero);
            $fdisplay(fd, "credit_low,%0d", credit_low);
            $fdisplay(fd, "credit_mid,%0d", credit_mid);
            $fdisplay(fd, "credit_high,%0d", credit_high);
            $fdisplay(fd, "backpressure,%0d", backpressure);
            $fdisplay(fd, "crc_error,%0d", crc_error);
            $fdisplay(fd, "resend_request,%0d", resend_request);
            $fdisplay(fd, "lane_fault,%0d", lane_fault);
            $fdisplay(fd, "retry_backpressure_cross,%0d", retry_backpressure_cross);
            $fdisplay(fd, "latency_low,%0d", latency_low);
            $fdisplay(fd, "latency_nominal,%0d", latency_nominal);
            $fdisplay(fd, "latency_high,%0d", latency_high);
            $fdisplay(fd, "e2e_updates,%0d", e2e_updates);
            $fdisplay(fd, "e2e_mismatch,%0d", e2e_mismatch);
            $fdisplay(fd, "expected_empty,%0d", expected_empty);
            $fdisplay(fd, "power_reset_proxy,%0d", power_reset_proxy);
            $fdisplay(fd, "power_idle_proxy,%0d", power_idle_proxy);
            $fdisplay(fd, "covered_bins,%0d", covered_bins);
            $fdisplay(fd, "total_bins,%0d", coverage_total_bins());
            $fclose(fd);
        end
    endtask

endpackage : ucie_cov_pkg

`endif
