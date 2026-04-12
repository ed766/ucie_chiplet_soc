`timescale 1ns/1ps

module tb_link_fsm_props;

    logic clk;
    logic rst_n;
    logic start_training;
    logic training_done;
    logic fault_detected;
    logic retry_in_progress;
    logic link_ready;
    logic link_up;
    logic degraded_mode;

    link_fsm #(
        .TRAIN_TIMEOUT_CYC(8),
        .RETRAIN_TIMEOUT_CYC(6),
        .DEGRADED_WAIT_CYC(12)
    ) dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_training   (start_training),
        .training_done    (training_done),
        .fault_detected   (fault_detected),
        .retry_in_progress(retry_in_progress),
        .link_ready       (link_ready),
        .link_up          (link_up),
        .degraded_mode    (degraded_mode)
    );

    always #5 clk = ~clk;

    property p_not_ready_before_active;
        @(posedge clk) rst_n && (dut.state_q inside {0, 1}) |-> !link_ready;
    endproperty

    assert property (p_not_ready_before_active);

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start_training = 1'b1;
        training_done = 1'b0;
        fault_detected = 1'b0;
        retry_in_progress = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        repeat (3) @(posedge clk);
        training_done = 1'b1;
        @(posedge clk);
        training_done = 1'b0;
        assert (dut.state_q == 3'd2);
        assert (link_up == 1'b1);

        fault_detected = 1'b1;
        @(posedge clk);
        fault_detected = 1'b0;
        assert (dut.state_q == 3'd3);

        repeat (2) @(posedge clk);
        training_done = 1'b1;
        @(posedge clk);
        training_done = 1'b0;
        assert (dut.state_q == 3'd2);
        assert (link_up == 1'b1);

        $display("PROP_RESULT|name=link_fsm_recovery|status=PASS|detail=training_active_retrain_recovery");
        $finish;
    end

endmodule : tb_link_fsm_props
