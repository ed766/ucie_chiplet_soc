`timescale 1ns/1ps
`include "chiplet_protocol_assertions.svh"

module tb_ucie_tx_retry_props;

    logic clk;
    logic rst_n;
    logic [15:0] flit_in;
    logic flit_valid;
    logic flit_ready;
    logic link_ready;
    logic resend_request;
    logic crc_error;
    logic [15:0] available_credits;
    logic [15:0] credit_consumed;
    logic lane_tx_valid;
    logic [7:0] lane_tx_data;
    logic lane_link_enable;
    logic lane_link_training;
    logic debug_send_fire;
    logic [15:0] debug_send_flit;
    logic debug_resend_fire;

    logic [15:0] first_flit_q;
    logic have_first_q;

    ucie_tx #(
        .LANES(8),
        .FLIT_WIDTH(16)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .flit_in           (flit_in),
        .flit_valid        (flit_valid),
        .flit_ready        (flit_ready),
        .link_ready        (link_ready),
        .resend_request    (resend_request),
        .crc_error         (crc_error),
        .available_credits (available_credits),
        .credit_consumed   (credit_consumed),
        .lane_tx_valid     (lane_tx_valid),
        .lane_tx_data      (lane_tx_data),
        .lane_link_enable  (lane_link_enable),
        .lane_link_training(lane_link_training),
        .debug_send_fire   (debug_send_fire),
        .debug_send_flit   (debug_send_flit),
        .debug_resend_fire (debug_resend_fire)
    );

    always #5 clk = ~clk;

    `CHIPLET_ASSERT_RETRY_REPLAYS_LAST(
        p_retry_replays_last_flit,
        clk,
        rst_n,
        debug_resend_fire,
        debug_send_flit,
        dut.last_flit_q
    )
    `CHIPLET_ASSERT_STABLE_WHILE_BACKPRESSURED(
        p_flit_stable_under_backpressure,
        clk,
        rst_n,
        flit_valid,
        flit_ready || dut.sending_q,
        flit_in
    )
    `CHIPLET_ASSERT_RETRY_BLOCKS_NEW_RETIRE(
        p_retry_blocks_new_flit_before_replay,
        clk,
        rst_n,
        resend_request && !debug_resend_fire,
        debug_send_fire && (debug_send_flit != dut.last_flit_q)
    )

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        flit_in = 16'hbabe;
        flit_valid = 1'b0;
        link_ready = 1'b0;
        resend_request = 1'b0;
        available_credits = 16'd8;
        have_first_q = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        flit_valid = 1'b1;
        repeat (3) @(posedge clk);
        link_ready = 1'b1;
        wait (debug_send_fire);
        first_flit_q = debug_send_flit;
        have_first_q = 1'b1;
        @(posedge clk);
        flit_valid = 1'b0;

        repeat (3) @(posedge clk);
        resend_request = 1'b1;
        @(posedge clk);
        resend_request = 1'b0;

        wait (debug_resend_fire);
        assert (have_first_q);
        assert (debug_send_flit == first_flit_q);

        $display("PROP_RESULT|name=ucie_tx_retry_identity|status=PASS|detail=resend_matches_last_flit_payload");
        $finish;
    end

endmodule : tb_ucie_tx_retry_props
