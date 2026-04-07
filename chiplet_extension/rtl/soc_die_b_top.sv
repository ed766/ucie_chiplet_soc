// Die B top-level: crypto accelerator with return path over the UCIe link.
// Role: receive FLITs, run AES, and return ciphertext via the adapter/PHY stack.
module soc_die_b_top #(
    parameter int DATA_WIDTH = 64,
    parameter int FLIT_WIDTH = 264,
    parameter int LANES = 16
) (
    input  logic                  clk,
    input  logic                  rst_n,
    output logic [LANES-1:0]      lane_tx_data,
    output logic                  lane_tx_valid,
    output logic                  lane_link_enable,
    output logic                  lane_link_training,
    output logic                  lane_lane_clk,
    input  logic [LANES-1:0]      lane_rx_data,
    input  logic                  lane_rx_valid,
    input  logic                  lane_lane_fault,
    output logic [DATA_WIDTH-1:0] ciphertext_monitor
);

    localparam int CREDIT_INIT = 128;
    localparam int TRAIN_SETTLE_CYCLES = 16;

    // Adapter-side lane signals (before the PHY/channel).
    logic [LANES-1:0] lane_adapter_tx_data;
    logic             lane_adapter_tx_valid;
    logic             lane_adapter_link_enable;
    logic             lane_adapter_link_training;
    logic             lane_adapter_lane_clk;
    logic [LANES-1:0] lane_adapter_rx_data;
    logic             lane_adapter_rx_valid;
    logic             lane_adapter_lane_fault;

    // Incoming plaintext stream from Die A.
    logic [FLIT_WIDTH-1:0] flit_rx_payload;
    logic                  flit_rx_valid;
    logic                  flit_rx_ready;
    logic [DATA_WIDTH-1:0] plaintext_stream;
    logic                  plaintext_valid;
    logic                  plaintext_ready;

    // Outgoing ciphertext stream.
    logic [DATA_WIDTH-1:0] ciphertext_stream;
    logic                  ciphertext_valid;
    logic                  ciphertext_ready;
    logic [FLIT_WIDTH-1:0] flit_tx_payload;
    logic                  flit_tx_valid;
    logic                  flit_tx_ready;
    logic                  depacketizer_crc_error;

    // Credit management.
    logic [15:0] credit_available;
    logic [15:0] credit_consumed;
    logic [15:0] credit_return;

    // Link state.
    logic resend_request;
    logic link_ready;
    logic link_up;
    logic training_done;
    logic [$clog2(TRAIN_SETTLE_CYCLES+1)-1:0] training_timer_q;

    // Receive lane beats and rebuild FLITs.
    ucie_rx #(
        .LANES      (LANES),
        .FLIT_WIDTH (FLIT_WIDTH)
    ) u_rx (
        .clk           (clk),
        .rst_n         (rst_n),
        .flit_out      (flit_rx_payload),
        .flit_valid    (flit_rx_valid),
        .flit_ready    (flit_rx_ready),
        .crc_error     (),
        .credit_return (credit_return),
        .link_up       (link_up),
        .lane_rx_valid  (lane_adapter_rx_valid),
        .lane_rx_data   (lane_adapter_rx_data),
        .lane_lane_fault(lane_adapter_lane_fault)
    );

    // Unpack plaintext words from FLITs and check CRC.
    flit_depacketizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_depacketizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .flit_in    (flit_rx_payload),
        .flit_valid (flit_rx_valid),
        .flit_ready (flit_rx_ready),
        .data_out   (plaintext_stream),
        .data_valid (plaintext_valid),
        .data_ready (plaintext_ready),
        .crc_error  (depacketizer_crc_error)
    );

    // AES block builder + ciphertext FIFO.
    die_b_system #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_die_b_system (
        .clk              (clk),
        .rst_n            (rst_n),
        .plaintext_data   (plaintext_stream),
        .plaintext_valid  (plaintext_valid),
        .plaintext_ready  (plaintext_ready),
        .ciphertext_data  (ciphertext_stream),
        .ciphertext_valid (ciphertext_valid),
        .ciphertext_ready (ciphertext_ready),
        .aon_power_good   ()
    );

    // Packetize ciphertext words into FLITs.
    flit_packetizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_packetizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (ciphertext_stream),
        .data_valid (ciphertext_valid),
        .data_ready (ciphertext_ready),
        .flit_out   (flit_tx_payload),
        .flit_valid (flit_tx_valid),
        .flit_ready (flit_tx_ready)
    );

    // Credits gate outbound FLIT injection.
    credit_mgr u_credit_mgr (
        .clk              (clk),
        .rst_n            (rst_n),
        .credit_init      (CREDIT_INIT[15:0]),
        .credit_debit     (credit_consumed),
        .credit_return    (credit_return),
        .credit_available (credit_available),
        .underflow        (),
        .overflow         ()
    );

    // Link training/active state machine.
    link_fsm u_link_fsm (
        .clk              (clk),
        .rst_n            (rst_n),
        .start_training   (1'b1),
        .training_done    (training_done),
        .fault_detected   (lane_adapter_lane_fault),
        .retry_in_progress(resend_request),
        .link_ready       (link_ready),
        .link_up          (link_up),
        .degraded_mode    ()
    );

    // Retry escalation on CRC errors or lane faults.
    retry_ctrl u_retry_ctrl (
        .clk               (clk),
        .rst_n             (rst_n),
        .crc_error_detected(depacketizer_crc_error),
        .nack_received     (lane_adapter_lane_fault),
        .resend_request    (resend_request),
        .link_degraded     ()
    );

    // Serialize FLITs into lane-width beats.
    ucie_tx #(
        .LANES      (LANES),
        .FLIT_WIDTH (FLIT_WIDTH)
    ) u_tx (
        .clk              (clk),
        .rst_n            (rst_n),
        .flit_in          (flit_tx_payload),
        .flit_valid       (flit_tx_valid),
        .flit_ready       (flit_tx_ready),
        .link_ready       (link_ready),
        .resend_request   (resend_request),
        .crc_error        (),
        .available_credits(credit_available),
        .credit_consumed  (credit_consumed),
        .lane_tx_valid      (lane_adapter_tx_valid),
        .lane_tx_data       (lane_adapter_tx_data),
        .lane_link_enable   (lane_adapter_link_enable),
        .lane_link_training (lane_adapter_link_training)
    );

    // Behavioral PHY that adds pipeline latency, jitter, and injected faults.
    phy_behavioral #(
        .LANES           (LANES),
        .PIPELINE_STAGES (2)
    ) u_phy (
        .clk          (clk),
        .rst_n        (rst_n),
        .adapter_tx_data      (lane_adapter_tx_data),
        .adapter_tx_valid     (lane_adapter_tx_valid),
        .adapter_link_enable  (lane_adapter_link_enable),
        .adapter_link_training(lane_adapter_link_training),
        .adapter_lane_clk     (lane_adapter_lane_clk),
        .adapter_rx_data      (lane_adapter_rx_data),
        .adapter_rx_valid     (lane_adapter_rx_valid),
        .adapter_lane_fault   (lane_adapter_lane_fault),
        .channel_tx_data      (lane_tx_data),
        .channel_tx_valid     (lane_tx_valid),
        .channel_link_enable  (lane_link_enable),
        .channel_link_training(lane_link_training),
        .channel_lane_clk     (lane_lane_clk),
        .channel_rx_data      (lane_rx_data),
        .channel_rx_valid     (lane_rx_valid),
        .channel_lane_fault   (lane_lane_fault)
    );

    // Use the fabric clock as the lane clock in this behavioral model.
    assign lane_adapter_lane_clk = clk;
    assign training_done = lane_adapter_rx_valid || (training_timer_q == TRAIN_SETTLE_CYCLES[$bits(training_timer_q)-1:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            training_timer_q <= '0;
        end else if (link_up) begin
            training_timer_q <= '0;
        end else if (lane_adapter_rx_valid) begin
            training_timer_q <= TRAIN_SETTLE_CYCLES[$bits(training_timer_q)-1:0];
        end else if (training_timer_q != TRAIN_SETTLE_CYCLES[$bits(training_timer_q)-1:0]) begin
            training_timer_q <= training_timer_q + 1'b1;
        end
    end

    // Monitor ciphertext for debug.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ciphertext_monitor <= '0;
        end else if (ciphertext_valid && ciphertext_ready) begin
            ciphertext_monitor <= ciphertext_stream;
        end
    end

endmodule : soc_die_b_top
