`timescale 1ns/1ps

module ucie_coverage #(
    parameter int CREDIT_MAX   = 256,
    parameter int CREDIT_LOW   = 2,
    parameter int LATENCY_LOW  = 4,
    parameter int LATENCY_HIGH = 16
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [2:0]  link_state,
    input  logic [15:0] credit_available,
    input  logic        backpressure,
    input  logic        crc_error,
    input  logic        resend_request,
    input  logic        lane_fault,
    input  logic        error_during_backpressure,
    input  logic        latency_valid,
    input  logic [15:0] latency_value,
    input  logic [7:0]  jitter_setting,
    input  logic [7:0]  error_setting
);

    // Link state bins.
    int unsigned link_reset_cnt;
    int unsigned link_train_cnt;
    int unsigned link_active_cnt;
    int unsigned link_retrain_cnt;
    int unsigned link_degraded_cnt;

    // Credit/backpressure bins.
    int unsigned credit_zero_cnt;
    int unsigned credit_low_cnt;
    int unsigned credit_high_cnt;
    int unsigned credit_mid_cnt;
    int unsigned backpressure_cnt;

    // Error/retry bins.
    int unsigned crc_error_cnt;
    int unsigned resend_cnt;
    int unsigned err_during_bp_cnt;
    int unsigned lane_fault_cnt;

    // Latency bins.
    int unsigned latency_low_cnt;
    int unsigned latency_nom_cnt;
    int unsigned latency_high_cnt;

    // Knob bins (recorded at runtime for traceability).
    int unsigned jitter_low_cnt;
    int unsigned jitter_nom_cnt;
    int unsigned jitter_high_cnt;
    int unsigned err_low_cnt;
    int unsigned err_nom_cnt;
    int unsigned err_high_cnt;

    // Link state sampling.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            link_reset_cnt    <= 0;
            link_train_cnt    <= 0;
            link_active_cnt   <= 0;
            link_retrain_cnt  <= 0;
            link_degraded_cnt <= 0;

            credit_zero_cnt   <= 0;
            credit_low_cnt    <= 0;
            credit_high_cnt   <= 0;
            credit_mid_cnt    <= 0;
            backpressure_cnt  <= 0;

            crc_error_cnt     <= 0;
            resend_cnt        <= 0;
            err_during_bp_cnt <= 0;
            lane_fault_cnt    <= 0;

            latency_low_cnt   <= 0;
            latency_nom_cnt   <= 0;
            latency_high_cnt  <= 0;

            jitter_low_cnt    <= 0;
            jitter_nom_cnt    <= 0;
            jitter_high_cnt   <= 0;
            err_low_cnt       <= 0;
            err_nom_cnt       <= 0;
            err_high_cnt      <= 0;
        end else begin
            case (link_state)
                3'd0: link_reset_cnt   <= link_reset_cnt + 1;
                3'd1: link_train_cnt   <= link_train_cnt + 1;
                3'd2: link_active_cnt  <= link_active_cnt + 1;
                3'd3: link_retrain_cnt <= link_retrain_cnt + 1;
                3'd4: link_degraded_cnt<= link_degraded_cnt + 1;
                default: link_degraded_cnt <= link_degraded_cnt + 1;
            endcase

            if (credit_available == 0) begin
                credit_zero_cnt <= credit_zero_cnt + 1;
            end else if (credit_available <= CREDIT_LOW[15:0]) begin
                credit_low_cnt <= credit_low_cnt + 1;
            end else if (credit_available >= (CREDIT_MAX-1)) begin
                credit_high_cnt <= credit_high_cnt + 1;
            end else begin
                credit_mid_cnt <= credit_mid_cnt + 1;
            end

            if (backpressure) begin
                backpressure_cnt <= backpressure_cnt + 1;
            end

            if (crc_error) begin
                crc_error_cnt <= crc_error_cnt + 1;
            end
            if (resend_request) begin
                resend_cnt <= resend_cnt + 1;
            end
            if (error_during_backpressure) begin
                err_during_bp_cnt <= err_during_bp_cnt + 1;
            end
            if (lane_fault) begin
                lane_fault_cnt <= lane_fault_cnt + 1;
            end

            if (latency_valid) begin
                if (latency_value <= LATENCY_LOW[15:0]) begin
                    latency_low_cnt <= latency_low_cnt + 1;
                end else if (latency_value >= LATENCY_HIGH[15:0]) begin
                    latency_high_cnt <= latency_high_cnt + 1;
                end else begin
                    latency_nom_cnt <= latency_nom_cnt + 1;
                end
            end

            // Record knob settings into coarse bins for traceability.
            if (jitter_setting <= 1) begin
                jitter_low_cnt <= jitter_low_cnt + 1;
            end else if (jitter_setting <= 3) begin
                jitter_nom_cnt <= jitter_nom_cnt + 1;
            end else begin
                jitter_high_cnt <= jitter_high_cnt + 1;
            end

            if (error_setting <= 1) begin
                err_low_cnt <= err_low_cnt + 1;
            end else if (error_setting <= 4) begin
                err_nom_cnt <= err_nom_cnt + 1;
            end else begin
                err_high_cnt <= err_high_cnt + 1;
            end
        end
    end

    task automatic write_report(input string path);
        int fd;
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open coverage report file: %s", path);
            return;
        end
        $fdisplay(fd, "metric,value");
        $fdisplay(fd, "link_reset,%0d", link_reset_cnt);
        $fdisplay(fd, "link_train,%0d", link_train_cnt);
        $fdisplay(fd, "link_active,%0d", link_active_cnt);
        $fdisplay(fd, "link_retrain,%0d", link_retrain_cnt);
        $fdisplay(fd, "link_degraded,%0d", link_degraded_cnt);
        $fdisplay(fd, "credit_zero,%0d", credit_zero_cnt);
        $fdisplay(fd, "credit_low,%0d", credit_low_cnt);
        $fdisplay(fd, "credit_mid,%0d", credit_mid_cnt);
        $fdisplay(fd, "credit_high,%0d", credit_high_cnt);
        $fdisplay(fd, "backpressure,%0d", backpressure_cnt);
        $fdisplay(fd, "crc_error,%0d", crc_error_cnt);
        $fdisplay(fd, "resend_request,%0d", resend_cnt);
        $fdisplay(fd, "error_during_backpressure,%0d", err_during_bp_cnt);
        $fdisplay(fd, "lane_fault,%0d", lane_fault_cnt);
        $fdisplay(fd, "latency_low,%0d", latency_low_cnt);
        $fdisplay(fd, "latency_nominal,%0d", latency_nom_cnt);
        $fdisplay(fd, "latency_high,%0d", latency_high_cnt);
        $fdisplay(fd, "jitter_low,%0d", jitter_low_cnt);
        $fdisplay(fd, "jitter_nominal,%0d", jitter_nom_cnt);
        $fdisplay(fd, "jitter_high,%0d", jitter_high_cnt);
        $fdisplay(fd, "error_low,%0d", err_low_cnt);
        $fdisplay(fd, "error_nominal,%0d", err_nom_cnt);
        $fdisplay(fd, "error_high,%0d", err_high_cnt);
        $fclose(fd);
    endtask

endmodule : ucie_coverage
