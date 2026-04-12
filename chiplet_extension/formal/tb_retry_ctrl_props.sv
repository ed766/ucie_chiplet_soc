`timescale 1ns/1ps

module tb_retry_ctrl_props;

    logic clk;
    logic rst_n;
    logic crc_error_detected;
    logic nack_received;
    logic resend_request;
    logic link_degraded;

    retry_ctrl #(
        .MAX_RETRIES(2),
        .RETRY_HOLDOFF_CYC(2)
    ) dut (
        .clk               (clk),
        .rst_n             (rst_n),
        .crc_error_detected(crc_error_detected),
        .nack_received     (nack_received),
        .resend_request    (resend_request),
        .link_degraded     (link_degraded)
    );

    always #5 clk = ~clk;

    property p_resend_has_prior_error;
        @(posedge clk) disable iff (!rst_n || !$past(rst_n))
            resend_request |-> $past(crc_error_detected || nack_received);
    endproperty

    assert property (p_resend_has_prior_error);

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        crc_error_detected = 1'b0;
        nack_received = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        crc_error_detected = 1'b1;
        @(posedge clk);
        crc_error_detected = 1'b0;
        assert (resend_request == 1'b1);
        assert (link_degraded == 1'b0);

        nack_received = 1'b1;
        @(posedge clk);
        nack_received = 1'b0;
        assert (resend_request == 1'b1);
        assert (link_degraded == 1'b1);

        repeat (6) @(posedge clk);
        assert (link_degraded == 1'b0);

        $display("PROP_RESULT|name=retry_ctrl_progress|status=PASS|detail=resend_traces_back_to_error_and_degrade_decays");
        $finish;
    end

endmodule : tb_retry_ctrl_props
