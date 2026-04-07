// Behavioral UCIe transmit adapter with credit-based flow control and FLIT serialization.
// Role: breaks a FLIT into lane-width beats and drives link/training signals.
module ucie_tx #(
    parameter int LANES = 16,
    parameter int FLIT_WIDTH = 264
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic [FLIT_WIDTH-1:0]  flit_in,
    input  logic                   flit_valid,
    output logic                   flit_ready,
    input  logic                   link_ready,
    input  logic                   resend_request,
    output logic                   crc_error,
    input  logic [15:0]            available_credits,
    output logic [15:0]            credit_consumed,
    output logic                   lane_tx_valid,
    output logic [LANES-1:0]       lane_tx_data,
    output logic                   lane_link_enable,
    output logic                   lane_link_training
);

    localparam int BEATS_PER_FLIT   = (FLIT_WIDTH + LANES - 1) / LANES;
    localparam int BEAT_COUNTER_WID = $clog2(BEATS_PER_FLIT + 1);

    logic [FLIT_WIDTH-1:0] shreg_d, shreg_q;
    logic [BEAT_COUNTER_WID-1:0] beat_cnt_d, beat_cnt_q;
    logic sending_d, sending_q;
    logic resend_pending_d, resend_pending_q;
    logic resend_active_d, resend_active_q;
    logic [FLIT_WIDTH-1:0] last_flit_d, last_flit_q;
    logic last_flit_valid_d, last_flit_valid_q;

    // Only accept a new FLIT when the link is ready and credits remain.
    // Only accept a new FLIT when the link is ready and credits remain.
    assign flit_ready = (!sending_q) && link_ready && (available_credits != 0) && !resend_pending_q;
    assign crc_error  = 1'b0;
    assign credit_consumed = ((flit_valid && flit_ready) || resend_active_q) ? 16'd1 : 16'd0;

    // Drive lane signals.
    assign lane_tx_valid      = sending_q;
    assign lane_tx_data       = sending_q ? shreg_q[LANES-1:0] : '0;
    assign lane_link_enable   = link_ready;
    assign lane_link_training = !link_ready;

    always_comb begin
        // Load a FLIT, then shift out LANES bits per cycle.
        shreg_d   = shreg_q;
        beat_cnt_d = beat_cnt_q;
        sending_d  = sending_q;
        resend_pending_d = resend_pending_q;
        resend_active_d  = resend_active_q;
        last_flit_d      = last_flit_q;
        last_flit_valid_d = last_flit_valid_q;

        if (resend_request && last_flit_valid_q) begin
            resend_pending_d = 1'b1;
        end

        if (!sending_q && resend_pending_q && link_ready && (available_credits != 0)) begin
`ifdef UCIE_BUG_RETRY_SEQ
            shreg_d = last_flit_q ^ {{(FLIT_WIDTH-1){1'b0}}, 1'b1};
`else
            shreg_d = last_flit_q;
`endif
            beat_cnt_d = BEAT_COUNTER_WID'(BEATS_PER_FLIT);
            sending_d  = 1'b1;
            resend_active_d  = 1'b1;
            resend_pending_d = 1'b0;
        end else if (flit_valid && flit_ready) begin
            shreg_d   = flit_in;
            beat_cnt_d = BEAT_COUNTER_WID'(BEATS_PER_FLIT);
            sending_d  = 1'b1;
            last_flit_d = flit_in;
            last_flit_valid_d = 1'b1;
        end else if (sending_q) begin
            shreg_d    = shreg_q >> LANES;
            if (beat_cnt_q == 1) begin
                beat_cnt_d = '0;
                sending_d  = 1'b0;
                resend_active_d = 1'b0;
            end else begin
                beat_cnt_d = beat_cnt_q - 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shreg_q   <= '0;
            beat_cnt_q <= '0;
            sending_q  <= 1'b0;
            resend_pending_q <= 1'b0;
            resend_active_q  <= 1'b0;
            last_flit_q      <= '0;
            last_flit_valid_q <= 1'b0;
        end else begin
            shreg_q   <= shreg_d;
            beat_cnt_q <= beat_cnt_d;
            sending_q  <= sending_d;
            resend_pending_q <= resend_pending_d;
            resend_active_q  <= resend_active_d;
            last_flit_q      <= last_flit_d;
            last_flit_valid_q <= last_flit_valid_d;
        end
    end

endmodule : ucie_tx
