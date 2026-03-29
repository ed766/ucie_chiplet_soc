// Retry controller monitors CRC/NACK events and escalates degraded mode when persistent.
// Role: requests resends when errors appear and tracks repeated failures.
module retry_ctrl #(
    parameter int MAX_RETRIES = 4,
    parameter int RETRY_HOLDOFF_CYC = 64
) (
    input  logic clk,
    input  logic rst_n,
    input  logic crc_error_detected,
    input  logic nack_received,
    output logic resend_request,
    output logic link_degraded
);

    localparam int RETRY_CNT_W = $clog2(MAX_RETRIES + 1);
    localparam int HOLDOFF_W   = $clog2(RETRY_HOLDOFF_CYC + 1);

    logic [RETRY_CNT_W-1:0] retry_cnt_d, retry_cnt_q;
    logic [HOLDOFF_W-1:0]   holdoff_d, holdoff_q;
    logic                   resend_pulse_d, resend_pulse_q;

    assign resend_request = resend_pulse_q;
    assign link_degraded  = (retry_cnt_q == MAX_RETRIES[RETRY_CNT_W-1:0]);

    always_comb begin
        retry_cnt_d    = retry_cnt_q;
        holdoff_d      = holdoff_q;
        resend_pulse_d = 1'b0;

        // On error, request resend and reset holdoff; otherwise decay retry count.
        if (crc_error_detected || nack_received) begin
            resend_pulse_d = 1'b1;
            holdoff_d      = RETRY_HOLDOFF_CYC[HOLDOFF_W-1:0];
            if (retry_cnt_q != MAX_RETRIES[RETRY_CNT_W-1:0]) begin
                retry_cnt_d = retry_cnt_q + 1'b1;
            end
        end else begin
            if (holdoff_q != 0) begin
                holdoff_d = holdoff_q - 1'b1;
            end else if (retry_cnt_q != 0) begin
                retry_cnt_d = retry_cnt_q - 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            retry_cnt_q    <= '0;
            holdoff_q      <= '0;
            resend_pulse_q <= 1'b0;
        end else begin
            retry_cnt_q    <= retry_cnt_d;
            holdoff_q      <= holdoff_d;
            resend_pulse_q <= resend_pulse_d;
        end
    end

endmodule : retry_ctrl
