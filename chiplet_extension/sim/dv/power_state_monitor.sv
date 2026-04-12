`ifndef UCIE_POWER_STATE_MONITOR_SV
`define UCIE_POWER_STATE_MONITOR_SV

module power_state_monitor #(
    parameter int CRYPTO_DRAIN_GRACE = 12,
    parameter int RESUME_WINDOW = 256
) (
    input  logic        clk,
    input  logic        mon_rst_n,
    input  logic [1:0]  power_state,
    input  logic        producer_valid,
    input  logic        tx_fire,
    input  logic        rx_fire,
    input  logic        e2e_update,
    output int unsigned run_cycles,
    output int unsigned crypto_only_cycles,
    output int unsigned sleep_cycles,
    output int unsigned deep_sleep_cycles,
    output int unsigned trans_run_to_crypto_only,
    output int unsigned trans_crypto_only_to_run,
    output int unsigned trans_run_to_sleep,
    output int unsigned trans_sleep_to_run,
    output int unsigned trans_run_to_deep_sleep,
    output int unsigned trans_deep_sleep_to_run,
    output int unsigned illegal_activity_violations,
    output int unsigned resume_events,
    output int unsigned resume_violations
);

    localparam logic [1:0] PWR_RUN         = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP       = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP  = 2'd3;

    logic [1:0]  last_state_q;
    logic        waiting_resume_q;
    int unsigned crypto_drain_q;
    int unsigned resume_window_q;

    always_ff @(posedge clk or negedge mon_rst_n) begin
        if (!mon_rst_n) begin
            run_cycles <= 0;
            crypto_only_cycles <= 0;
            sleep_cycles <= 0;
            deep_sleep_cycles <= 0;
            trans_run_to_crypto_only <= 0;
            trans_crypto_only_to_run <= 0;
            trans_run_to_sleep <= 0;
            trans_sleep_to_run <= 0;
            trans_run_to_deep_sleep <= 0;
            trans_deep_sleep_to_run <= 0;
            illegal_activity_violations <= 0;
            resume_events <= 0;
            resume_violations <= 0;
            last_state_q <= PWR_RUN;
            waiting_resume_q <= 1'b0;
            crypto_drain_q <= 0;
            resume_window_q <= 0;
        end else begin
            case (power_state)
                PWR_RUN: run_cycles <= run_cycles + 1;
                PWR_CRYPTO_ONLY: crypto_only_cycles <= crypto_only_cycles + 1;
                PWR_SLEEP: sleep_cycles <= sleep_cycles + 1;
                default: deep_sleep_cycles <= deep_sleep_cycles + 1;
            endcase

            if (power_state != last_state_q) begin
                if (last_state_q == PWR_RUN && power_state == PWR_CRYPTO_ONLY) begin
                    trans_run_to_crypto_only <= trans_run_to_crypto_only + 1;
                    crypto_drain_q <= CRYPTO_DRAIN_GRACE;
                end
                if (last_state_q == PWR_CRYPTO_ONLY && power_state == PWR_RUN) begin
                    trans_crypto_only_to_run <= trans_crypto_only_to_run + 1;
                end
                if (last_state_q == PWR_RUN && power_state == PWR_SLEEP) begin
                    trans_run_to_sleep <= trans_run_to_sleep + 1;
                end
                if (last_state_q == PWR_SLEEP && power_state == PWR_RUN) begin
                    trans_sleep_to_run <= trans_sleep_to_run + 1;
                    waiting_resume_q <= 1'b1;
                    resume_window_q <= RESUME_WINDOW;
                end
                if (last_state_q == PWR_RUN && power_state == PWR_DEEP_SLEEP) begin
                    trans_run_to_deep_sleep <= trans_run_to_deep_sleep + 1;
                end
                if (last_state_q == PWR_DEEP_SLEEP && power_state == PWR_RUN) begin
                    trans_deep_sleep_to_run <= trans_deep_sleep_to_run + 1;
                    waiting_resume_q <= 1'b1;
                    resume_window_q <= RESUME_WINDOW;
                end
                last_state_q <= power_state;
            end

            if (crypto_drain_q != 0) begin
                crypto_drain_q <= crypto_drain_q - 1;
            end

            if (power_state == PWR_CRYPTO_ONLY) begin
                if ((crypto_drain_q == 0) && (producer_valid || tx_fire)) begin
                    illegal_activity_violations <= illegal_activity_violations + 1;
                end
            end else if ((power_state == PWR_SLEEP) || (power_state == PWR_DEEP_SLEEP)) begin
                if (producer_valid || tx_fire || rx_fire || e2e_update) begin
                    illegal_activity_violations <= illegal_activity_violations + 1;
                end
            end

            if (waiting_resume_q) begin
                if (e2e_update) begin
                    resume_events <= resume_events + 1;
                    waiting_resume_q <= 1'b0;
                    resume_window_q <= 0;
                end else if (resume_window_q != 0) begin
                    resume_window_q <= resume_window_q - 1;
                    if (resume_window_q == 1) begin
                        resume_violations <= resume_violations + 1;
                        waiting_resume_q <= 1'b0;
                    end
                end
            end
        end
    end

    task automatic write_report(input string path, input string mode_name);
        int fd;
        fd = $fopen(path, "w");
        if (fd == 0) begin
            $display("Failed to open power report file: %s", path);
        end else begin
            $fdisplay(fd, "metric,value");
            $fdisplay(fd, "power_mode,%s", mode_name);
            $fdisplay(fd, "run_cycles,%0d", run_cycles);
            $fdisplay(fd, "crypto_only_cycles,%0d", crypto_only_cycles);
            $fdisplay(fd, "sleep_cycles,%0d", sleep_cycles);
            $fdisplay(fd, "deep_sleep_cycles,%0d", deep_sleep_cycles);
            $fdisplay(fd, "trans_run_to_crypto_only,%0d", trans_run_to_crypto_only);
            $fdisplay(fd, "trans_crypto_only_to_run,%0d", trans_crypto_only_to_run);
            $fdisplay(fd, "trans_run_to_sleep,%0d", trans_run_to_sleep);
            $fdisplay(fd, "trans_sleep_to_run,%0d", trans_sleep_to_run);
            $fdisplay(fd, "trans_run_to_deep_sleep,%0d", trans_run_to_deep_sleep);
            $fdisplay(fd, "trans_deep_sleep_to_run,%0d", trans_deep_sleep_to_run);
            $fdisplay(fd, "illegal_activity_violations,%0d", illegal_activity_violations);
            $fdisplay(fd, "resume_events,%0d", resume_events);
            $fdisplay(fd, "resume_violations,%0d", resume_violations);
            $fclose(fd);
        end
    endtask

endmodule : power_state_monitor

`endif
