`timescale 1ns/1ps
`include "sva_macros.svh"

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

    // Do not transmit before the link is reported ready.
    `ASSERT_PROP("LINK_NO_TX_BEFORE_READY",
        @(posedge clk) disable iff (!rst_n)
        tx_fire |-> link_ready
    )

    // Under nominal conditions (no fault), training should complete in a bounded window.
    `ASSERT_PROP("LINK_TRAINING_BOUNDED",
        @(posedge clk) disable iff (!rst_n)
        (start_training && traffic_present && !fault_detected)
            |-> ##[1:TRAIN_WINDOW] link_up
    )

    // Bounded liveness: active link with traffic should make progress.
    `ASSERT_PROP("LINK_PROGRESS_BOUNDED",
        @(posedge clk) disable iff (!rst_n)
        (link_up && traffic_present && !fault_detected) |-> ##[1:PROGRESS_WINDOW] tx_fire
    )

endmodule : ucie_link_checker
