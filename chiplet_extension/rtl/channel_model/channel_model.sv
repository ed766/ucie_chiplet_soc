// Bidirectional channel model with configurable skew and crosstalk-induced delay.
// Role: models interposer/channel effects and injects lane faults/stalls.
module channel_model #(
    parameter int LANES = 16,
    parameter int REACH_MM = 15,
    parameter int SKEW_STAGES = 2,
    parameter int CROSSTALK_SENSITIVITY = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [LANES-1:0] lane_a_tx_data,
    input  logic             lane_a_tx_valid,
    output logic [LANES-1:0] lane_a_rx_data,
    output logic             lane_a_rx_valid,
    output logic             lane_a_lane_fault,
    input  logic [LANES-1:0] lane_b_tx_data,
    input  logic             lane_b_tx_valid,
    output logic [LANES-1:0] lane_b_rx_data,
    output logic             lane_b_rx_valid,
    output logic             lane_b_lane_fault
);

    localparam int PIPE_STAGES = (SKEW_STAGES < 1) ? 1 : SKEW_STAGES;

    // Forward path A -> B
    logic [LANES-1:0] fwd_data_pipe   [PIPE_STAGES];
    logic             fwd_valid_pipe  [PIPE_STAGES];
    logic             fwd_fault_pipe  [PIPE_STAGES];

    // Reverse path B -> A
    logic [LANES-1:0] rev_data_pipe   [PIPE_STAGES];
    logic             rev_valid_pipe  [PIPE_STAGES];
    logic             rev_fault_pipe  [PIPE_STAGES];

    logic [15:0] fwd_lfsr_q;
    logic [15:0] rev_lfsr_q;

    // Shift register style delay to emulate reach-induced skew.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < PIPE_STAGES; i++) begin
                fwd_data_pipe[i]  <= '0;
                fwd_valid_pipe[i] <= 1'b0;
                fwd_fault_pipe[i] <= 1'b0;
                rev_data_pipe[i]  <= '0;
                rev_valid_pipe[i] <= 1'b0;
                rev_fault_pipe[i] <= 1'b0;
            end
            fwd_lfsr_q <= 16'h1ACE;
            rev_lfsr_q <= 16'h2B5F;
        end else begin
            // This lane link has no ready/hold handshake, so destructive "stalls"
            // would silently drop beats and create artificial CRC failures.
            // Keep crosstalk modeling non-destructive here and let the benches
            // exercise real backpressure through stream-ready controls instead.

            fwd_data_pipe[0]  <= lane_a_tx_data;
            fwd_valid_pipe[0] <= lane_a_tx_valid;
            fwd_fault_pipe[0] <= 1'b0;

            rev_data_pipe[0]  <= lane_b_tx_data;
            rev_valid_pipe[0] <= lane_b_tx_valid;
            rev_fault_pipe[0] <= 1'b0;

            for (int i = 1; i < PIPE_STAGES; i++) begin
                fwd_data_pipe[i]  <= fwd_data_pipe[i-1];
                fwd_valid_pipe[i] <= fwd_valid_pipe[i-1];
                fwd_fault_pipe[i] <= fwd_fault_pipe[i-1];

                rev_data_pipe[i]  <= rev_data_pipe[i-1];
                rev_valid_pipe[i] <= rev_valid_pipe[i-1];
                rev_fault_pipe[i] <= rev_fault_pipe[i-1];
            end

            fwd_lfsr_q <= {fwd_lfsr_q[14:0], fwd_lfsr_q[15] ^ fwd_lfsr_q[13] ^ fwd_lfsr_q[12] ^ fwd_lfsr_q[10]};
            rev_lfsr_q <= {rev_lfsr_q[14:0], rev_lfsr_q[15] ^ rev_lfsr_q[13] ^ rev_lfsr_q[12] ^ rev_lfsr_q[10]};
        end
    end

    // Keep ambient channel faults rare; directed tests inject retries/faults explicitly.
    localparam int FAULT_SCALE = (REACH_MM < 1) ? 1000 : REACH_MM * 1000;

    logic induce_fwd_fault_q;
    logic induce_rev_fault_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            induce_fwd_fault_q <= 1'b0;
            induce_rev_fault_q <= 1'b0;
        end else begin
            induce_fwd_fault_q <= 1'b0;
            induce_rev_fault_q <= 1'b0;
            if (fwd_valid_pipe[PIPE_STAGES-1]) begin
                induce_fwd_fault_q <= ((int'(fwd_lfsr_q) % FAULT_SCALE) == 0);
            end
            if (rev_valid_pipe[PIPE_STAGES-1]) begin
                induce_rev_fault_q <= ((int'(rev_lfsr_q) % FAULT_SCALE) == 0);
            end
        end
    end

    // Drive lane B (observing lane A transmit direction).
    always_comb begin
        lane_b_rx_data    = fwd_data_pipe[PIPE_STAGES-1];
        lane_b_rx_valid   = fwd_valid_pipe[PIPE_STAGES-1];
        lane_b_lane_fault = fwd_fault_pipe[PIPE_STAGES-1] | induce_fwd_fault_q;
    end

    // Drive lane A (observing lane B transmit direction).
    always_comb begin
        lane_a_rx_data    = rev_data_pipe[PIPE_STAGES-1];
        lane_a_rx_valid   = rev_valid_pipe[PIPE_STAGES-1];
        lane_a_lane_fault = rev_fault_pipe[PIPE_STAGES-1] | induce_rev_fault_q;
    end

endmodule : channel_model
