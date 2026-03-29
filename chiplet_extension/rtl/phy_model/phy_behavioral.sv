// Behavioral PHY model introducing pipeline latency, optional jitter, and error injection.
// Role: bridge between adapter and channel models; models link-level timing noise.
module phy_behavioral #(
    parameter int LANES = 16,
    parameter int PIPELINE_STAGES = 2,
    parameter int JITTER_CYCLES = 1,
    parameter int ERROR_PROB_NUM = 0,
    parameter int ERROR_PROB_DEN = 1
) (
    input  logic      clk,
    input  logic      rst_n,
    input  logic [LANES-1:0] adapter_tx_data,
    input  logic             adapter_tx_valid,
    input  logic             adapter_link_enable,
    input  logic             adapter_link_training,
    input  logic             adapter_lane_clk,
    output logic [LANES-1:0] adapter_rx_data,
    output logic             adapter_rx_valid,
    output logic             adapter_lane_fault,
    output logic [LANES-1:0] channel_tx_data,
    output logic             channel_tx_valid,
    output logic             channel_link_enable,
    output logic             channel_link_training,
    output logic             channel_lane_clk,
    input  logic [LANES-1:0] channel_rx_data,
    input  logic             channel_rx_valid,
    input  logic             channel_lane_fault
);

    localparam int PIPE_STAGES = (PIPELINE_STAGES < 1) ? 1 : PIPELINE_STAGES;
    localparam int ERROR_SCALE = 1_000_000;

    logic [LANES-1:0] fwd_data_pipe   [PIPE_STAGES];
    logic             fwd_valid_pipe  [PIPE_STAGES];
    logic             fwd_enable_pipe [PIPE_STAGES];
    logic             fwd_train_pipe  [PIPE_STAGES];
    logic             fwd_clk_pipe    [PIPE_STAGES];

    logic [LANES-1:0] rev_data_pipe   [PIPE_STAGES];
    logic             rev_valid_pipe  [PIPE_STAGES];

    logic [LANES-1:0] rev_data_corrupted;
    logic             local_fault;

    localparam int ERROR_THRESHOLD_RAW = (ERROR_PROB_NUM <= 0) ? 0 : ((ERROR_PROB_NUM * ERROR_SCALE) / (ERROR_PROB_DEN <= 0 ? 1 : ERROR_PROB_DEN));
    localparam int ERROR_THRESHOLD = (ERROR_THRESHOLD_RAW > ERROR_SCALE) ? ERROR_SCALE : ERROR_THRESHOLD_RAW;
    localparam int JITTER_MOD      = (JITTER_CYCLES < 1) ? 1 : (JITTER_CYCLES + 1);

    logic inject_error_q;
    int unsigned err_lane_q;
    logic [15:0] jitter_lfsr_q;
    logic [15:0] err_lfsr_q;

    // Forward/reverse pipelines model PHY latency in both directions.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < PIPE_STAGES; i++) begin
                fwd_data_pipe[i]   <= '0;
                fwd_valid_pipe[i]  <= 1'b0;
                fwd_enable_pipe[i] <= 1'b0;
                fwd_train_pipe[i]  <= 1'b1;
                fwd_clk_pipe[i]    <= 1'b0;
                rev_data_pipe[i]   <= '0;
                rev_valid_pipe[i]  <= 1'b0;
            end
            jitter_lfsr_q <= 16'hACE1;
            err_lfsr_q    <= 16'hBEEF;
        end else begin
            fwd_data_pipe[0]   <= adapter_tx_data;
            fwd_valid_pipe[0]  <= adapter_tx_valid;
            fwd_enable_pipe[0] <= adapter_link_enable;
            fwd_train_pipe[0]  <= adapter_link_training;
            fwd_clk_pipe[0]    <= adapter_lane_clk;

            rev_data_pipe[0]   <= channel_rx_data;
            rev_valid_pipe[0]  <= channel_rx_valid;

            for (int i = 1; i < PIPE_STAGES; i++) begin
                fwd_data_pipe[i]   <= fwd_data_pipe[i-1];
                fwd_valid_pipe[i]  <= fwd_valid_pipe[i-1];
                fwd_enable_pipe[i] <= fwd_enable_pipe[i-1];
                fwd_train_pipe[i]  <= fwd_train_pipe[i-1];
                fwd_clk_pipe[i]    <= fwd_clk_pipe[i-1];

                rev_data_pipe[i]   <= rev_data_pipe[i-1];
                rev_valid_pipe[i]  <= rev_valid_pipe[i-1];
            end

            jitter_lfsr_q <= {jitter_lfsr_q[14:0], jitter_lfsr_q[15] ^ jitter_lfsr_q[13] ^ jitter_lfsr_q[12] ^ jitter_lfsr_q[10]};
            err_lfsr_q    <= {err_lfsr_q[14:0], err_lfsr_q[15] ^ err_lfsr_q[13] ^ err_lfsr_q[12] ^ err_lfsr_q[10]};
        end
    end

    // Apply optional jitter on the last stage clock.
    logic jitter_toggle;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            jitter_toggle <= 1'b0;
        end else if (JITTER_CYCLES > 0 && (int'(jitter_lfsr_q) % JITTER_MOD) == 0) begin
            jitter_toggle <= ~jitter_toggle;
        end
    end

    // Error injection on reverse data path to emulate noisy lanes.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inject_error_q <= 1'b0;
            err_lane_q     <= 0;
        end else begin
            inject_error_q <= 1'b0;
            if (rev_valid_pipe[PIPE_STAGES-1] && ERROR_THRESHOLD > 0 && LANES > 0) begin
                if ((int'(err_lfsr_q) % ERROR_SCALE) < ERROR_THRESHOLD) begin
                    inject_error_q <= 1'b1;
                    err_lane_q     <= (LANES > 0) ? (int'(err_lfsr_q) % LANES) : 0;
                end
            end
        end
    end

    always_comb begin
        rev_data_corrupted = rev_data_pipe[PIPE_STAGES-1];
        if (inject_error_q && LANES > 0) begin
            rev_data_corrupted[err_lane_q % LANES] = ~rev_data_corrupted[err_lane_q % LANES];
        end
        local_fault = channel_lane_fault | inject_error_q;
    end

    // Drive channel-facing signals.
    always_comb begin
        channel_tx_data       = fwd_data_pipe[PIPE_STAGES-1];
        channel_tx_valid      = fwd_valid_pipe[PIPE_STAGES-1];
        channel_link_enable   = fwd_enable_pipe[PIPE_STAGES-1];
        channel_link_training = fwd_train_pipe[PIPE_STAGES-1];
        channel_lane_clk      = fwd_clk_pipe[PIPE_STAGES-1] ^ jitter_toggle;
    end

    // Deliver receive data back to the adapter side.
    always_comb begin
        adapter_rx_data    = rev_data_corrupted;
        adapter_rx_valid   = rev_valid_pipe[PIPE_STAGES-1];
        adapter_lane_fault = local_fault;
    end

endmodule : phy_behavioral
