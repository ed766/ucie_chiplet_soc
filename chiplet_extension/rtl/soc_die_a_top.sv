// Die A top-level: ties RV32 complex model to the UCIe adapter and PHY.
// Role: stream -> FLIT -> lane pipeline for outbound traffic plus return-path depacketize/scoreboard.
module soc_die_a_top #(
    parameter int DATA_WIDTH = 64,
    parameter int FLIT_WIDTH = 256,
    parameter int LANES = 16
) (
    input  logic                   clk,
    input  logic                   rst_n,
    output logic [LANES-1:0]       lane_tx_data,
    output logic                   lane_tx_valid,
    output logic                   lane_link_enable,
    output logic                   lane_link_training,
    output logic                   lane_lane_clk,
    input  logic [LANES-1:0]       lane_rx_data,
    input  logic                   lane_rx_valid,
    input  logic                   lane_lane_fault,
    output logic [DATA_WIDTH-1:0]  plaintext_monitor,
    output logic [DATA_WIDTH-1:0]  ciphertext_monitor,
    output logic                   crypto_error_flag
);

    localparam int CREDIT_INIT = 128;

    // Adapter-side lane signals (before the PHY/channel).
    logic [LANES-1:0] lane_adapter_tx_data;
    logic             lane_adapter_tx_valid;
    logic             lane_adapter_link_enable;
    logic             lane_adapter_link_training;
    logic             lane_adapter_lane_clk;
    logic [LANES-1:0] lane_adapter_rx_data;
    logic             lane_adapter_rx_valid;
    logic             lane_adapter_lane_fault;

    // Stream between compute system and packetizer.
    logic [DATA_WIDTH-1:0] tx_stream_data;
    logic                  tx_stream_valid;
    logic                  tx_stream_ready;
    logic [DATA_WIDTH-1:0] rx_stream_data;
    logic                  rx_stream_valid;
    logic                  rx_stream_ready;

    // FLIT level signals.
    logic [FLIT_WIDTH-1:0] flit_tx_payload;
    logic                  flit_tx_valid;
    logic                  flit_tx_ready;
    logic [FLIT_WIDTH-1:0] flit_rx_payload;
    logic                  flit_rx_valid;
    logic                  flit_rx_ready;
    logic                  depacketizer_crc_error;

    // Credit management.
    logic [15:0] credit_available;
    logic [15:0] credit_consumed;
    logic [15:0] credit_return;

    // Link state management.
    logic resend_request;
    logic link_ready;
    logic link_up;

    // Traffic source + AES mirror for expected ciphertext.
    die_a_system #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_die_a_system (
        .clk             (clk),
        .rst_n           (rst_n),
        .tx_stream_data  (tx_stream_data),
        .tx_stream_valid (tx_stream_valid),
        .tx_stream_ready (tx_stream_ready),
        .rx_stream_data  (rx_stream_data),
        .rx_stream_valid (rx_stream_valid),
        .rx_stream_ready (rx_stream_ready),
        .aon_power_good  (),
        .crypto_error    (crypto_error_flag)
    );

    // Packetize words into CRC-protected FLITs.
    flit_packetizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_packetizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (tx_stream_data),
        .data_valid (tx_stream_valid),
        .data_ready (tx_stream_ready),
        .flit_out   (flit_tx_payload),
        .flit_valid (flit_tx_valid),
        .flit_ready (flit_tx_ready)
    );

    // Credits limit how many FLITs can be injected.
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
        .training_done    (lane_adapter_rx_valid),
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

    // Reassemble lane beats into FLITs and return credits.
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

    // Recover words from incoming FLITs and flag CRC errors.
    flit_depacketizer #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_depacketizer (
        .clk        (clk),
        .rst_n      (rst_n),
        .flit_in    (flit_rx_payload),
        .flit_valid (flit_rx_valid),
        .flit_ready (flit_rx_ready),
        .data_out   (rx_stream_data),
        .data_valid (rx_stream_valid),
        .data_ready (rx_stream_ready),
        .crc_error  (depacketizer_crc_error)
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

    // Monitor registers for debug visibility.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            plaintext_monitor  <= '0;
            ciphertext_monitor <= '0;
        end else begin
            if (tx_stream_valid && tx_stream_ready) begin
                plaintext_monitor <= tx_stream_data;
            end
            if (rx_stream_valid && rx_stream_ready) begin
                ciphertext_monitor <= rx_stream_data;
            end
        end
    end

endmodule : soc_die_a_top
