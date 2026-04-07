`timescale 1ns/1ps

module ucie_link_checker #(
    parameter int TRAIN_WINDOW = 512,
    parameter int PROGRESS_WINDOW = 64
) (
    input  logic clk,
    input  logic rst_n,
    input  logic link_up,
    input  logic link_ready,
    input  logic start_training,
    input  logic fault_detected,
    input  logic tx_fire,
    input  logic traffic_present
);

    logic training_watch_q;
    logic progress_watch_q;
    logic last_training_cond_q;
    logic last_progress_cond_q;
    int unsigned training_window_q;
    int unsigned progress_window_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            training_watch_q <= 1'b0;
            progress_watch_q <= 1'b0;
            last_training_cond_q <= 1'b0;
            last_progress_cond_q <= 1'b0;
            training_window_q <= 0;
            progress_window_q <= 0;
        end else begin
            logic training_cond;
            logic progress_cond;

            training_cond = start_training && traffic_present && !fault_detected;
            progress_cond = link_ready && traffic_present && !fault_detected;

            if (tx_fire && !link_ready) begin
                $error("LINK_NO_TX_BEFORE_READY: transfer fired before link_ready");
            end

            if (training_cond && !last_training_cond_q && !link_up) begin
                training_watch_q <= 1'b1;
                training_window_q <= TRAIN_WINDOW;
            end else if (!training_cond || link_up) begin
                training_watch_q <= 1'b0;
                training_window_q <= 0;
            end else if (training_watch_q && training_window_q != 0) begin
                training_window_q <= training_window_q - 1;
                if (training_window_q == 1) begin
                    $error("LINK_TRAINING_BOUNDED: link_up missing within %0d cycles", TRAIN_WINDOW);
                    training_watch_q <= 1'b0;
                end
            end

            if (progress_cond && !last_progress_cond_q) begin
                progress_watch_q <= 1'b1;
                progress_window_q <= PROGRESS_WINDOW;
            end else if (!progress_cond || tx_fire) begin
                progress_watch_q <= 1'b0;
                progress_window_q <= 0;
            end else if (progress_watch_q && progress_window_q != 0) begin
                progress_window_q <= progress_window_q - 1;
                if (progress_window_q == 1) begin
                    $error("LINK_PROGRESS_BOUNDED: no tx progress within %0d cycles", PROGRESS_WINDOW);
                    progress_watch_q <= 1'b0;
                end
            end

            last_training_cond_q <= training_cond;
            last_progress_cond_q <= progress_cond;
        end
    end

endmodule : ucie_link_checker
