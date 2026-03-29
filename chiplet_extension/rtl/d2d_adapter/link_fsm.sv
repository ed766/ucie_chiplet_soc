// Link FSM covering training, active, retrain, and degraded operating modes.
// Role: gates link_ready/link_up based on training progress and fault handling.
module link_fsm #(
    parameter int TRAIN_TIMEOUT_CYC   = 512,
    parameter int RETRAIN_TIMEOUT_CYC = 256,
    parameter int DEGRADED_WAIT_CYC   = 1024
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start_training,
    input  logic training_done,
    input  logic fault_detected,
    input  logic retry_in_progress,
    output logic link_ready,
    output logic link_up,
    output logic degraded_mode
);

    typedef enum logic [2:0] {
        RESET,
        TRAIN,
        ACTIVE,
        RETRAIN,
        DEGRADED
    } link_state_e;

    link_state_e state_d, state_q;
    logic [$clog2(DEGRADED_WAIT_CYC+1)-1:0] timer_d, timer_q;

    assign link_up       = (state_q == ACTIVE);
    assign degraded_mode = (state_q == DEGRADED);

    always_comb begin
        // Timeouts drive fallback into DEGRADED when training/retrain stalls.
        state_d = state_q;
        timer_d = timer_q;
        link_ready = 1'b0;

        unique case (state_q)
            RESET: begin
                if (start_training) begin
                    state_d = TRAIN;
                    timer_d = TRAIN_TIMEOUT_CYC[$bits(timer_q)-1:0];
                end
            end
            TRAIN: begin
                if (training_done) begin
                    state_d = ACTIVE;
                    timer_d = '0;
                end else if (timer_q == 0) begin
                    state_d = DEGRADED;
                    timer_d = DEGRADED_WAIT_CYC[$bits(timer_q)-1:0];
                end else begin
                    timer_d = timer_q - 1'b1;
                end
            end
            ACTIVE: begin
                link_ready = !retry_in_progress;
                if (fault_detected) begin
                    state_d = RETRAIN;
                    timer_d = RETRAIN_TIMEOUT_CYC[$bits(timer_q)-1:0];
                end
            end
            RETRAIN: begin
                link_ready = training_done && !retry_in_progress;
                if (training_done) begin
                    state_d = ACTIVE;
                    timer_d = '0;
                end else if (timer_q == 0) begin
                    state_d = DEGRADED;
                    timer_d = DEGRADED_WAIT_CYC[$bits(timer_q)-1:0];
                end else begin
                    timer_d = timer_q - 1'b1;
                end
            end
            DEGRADED: begin
                link_ready = training_done && !retry_in_progress;
                if (training_done && !fault_detected) begin
                    state_d = ACTIVE;
                    timer_d = '0;
                end else if (timer_q == 0) begin
                    state_d = TRAIN;
                    timer_d = TRAIN_TIMEOUT_CYC[$bits(timer_q)-1:0];
                end else begin
                    timer_d = timer_q - 1'b1;
                end
            end
            default: state_d = RESET;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= RESET;
            timer_q <= '0;
        end else begin
            state_q <= state_d;
            timer_q <= timer_d;
        end
    end

endmodule : link_fsm
