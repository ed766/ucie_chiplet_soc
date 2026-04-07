// Top-level wrapper that connects both chiplets through the behavioral channel.
// Role: integration point for the UCIe-style link; exposes plaintext/ciphertext monitors.
module soc_chiplet_top #(
    parameter int DATA_WIDTH = 64,
    parameter int FLIT_WIDTH = 264,
    parameter int LANES = 16
) (
    input  logic                   clk,
    input  logic                   rst_n,
    output logic [DATA_WIDTH-1:0]  plaintext_monitor,
    output logic [DATA_WIDTH-1:0]  ciphertext_monitor,
    output logic [DATA_WIDTH-1:0]  die_b_ciphertext_monitor,
    output logic                   crypto_error_flag
);

    // Lane wires for each die; the channel model cross-connects these paths.
    logic [LANES-1:0] lane_die_a_tx_data;
    logic             lane_die_a_tx_valid;
    logic             lane_die_a_link_enable;
    logic             lane_die_a_link_training;
    logic             lane_die_a_lane_clk;
    logic [LANES-1:0] lane_die_a_rx_data;
    logic             lane_die_a_rx_valid;
    logic             lane_die_a_lane_fault;

    logic [LANES-1:0] lane_die_b_tx_data;
    logic             lane_die_b_tx_valid;
    logic             lane_die_b_link_enable;
    logic             lane_die_b_link_training;
    logic             lane_die_b_lane_clk;
    logic [LANES-1:0] lane_die_b_rx_data;
    logic             lane_die_b_rx_valid;
    logic             lane_die_b_lane_fault;

    // Die A produces plaintext and checks returned ciphertext.
    soc_die_a_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FLIT_WIDTH(FLIT_WIDTH),
        .LANES     (LANES)
    ) u_die_a (
        .clk                 (clk),
        .rst_n               (rst_n),
        .lane_tx_data        (lane_die_a_tx_data),
        .lane_tx_valid       (lane_die_a_tx_valid),
        .lane_link_enable    (lane_die_a_link_enable),
        .lane_link_training  (lane_die_a_link_training),
        .lane_lane_clk       (lane_die_a_lane_clk),
        .lane_rx_data        (lane_die_a_rx_data),
        .lane_rx_valid       (lane_die_a_rx_valid),
        .lane_lane_fault     (lane_die_a_lane_fault),
        .plaintext_monitor   (plaintext_monitor),
        .ciphertext_monitor  (ciphertext_monitor),
        .crypto_error_flag   (crypto_error_flag)
    );

    // Die B consumes plaintext, runs AES, and returns ciphertext.
    soc_die_b_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FLIT_WIDTH(FLIT_WIDTH),
        .LANES     (LANES)
    ) u_die_b (
        .clk                (clk),
        .rst_n              (rst_n),
        .lane_tx_data       (lane_die_b_tx_data),
        .lane_tx_valid      (lane_die_b_tx_valid),
        .lane_link_enable   (lane_die_b_link_enable),
        .lane_link_training (lane_die_b_link_training),
        .lane_lane_clk      (lane_die_b_lane_clk),
        .lane_rx_data       (lane_die_b_rx_data),
        .lane_rx_valid      (lane_die_b_rx_valid),
        .lane_lane_fault    (lane_die_b_lane_fault),
        .ciphertext_monitor (die_b_ciphertext_monitor)
    );

    // Behavioral channel links the two dice and injects skew/faults.
    channel_model #(
        .LANES         (LANES),
        .REACH_MM      (15),
        .SKEW_STAGES   (3),
        .CROSSTALK_SENSITIVITY (4)
    ) u_channel (
        .clk             (clk),
        .rst_n           (rst_n),
        .lane_a_tx_data  (lane_die_a_tx_data),
        .lane_a_tx_valid (lane_die_a_tx_valid),
        .lane_a_rx_data  (lane_die_a_rx_data),
        .lane_a_rx_valid (lane_die_a_rx_valid),
        .lane_a_lane_fault(lane_die_a_lane_fault),
        .lane_b_tx_data  (lane_die_b_tx_data),
        .lane_b_tx_valid (lane_die_b_tx_valid),
        .lane_b_rx_data  (lane_die_b_rx_data),
        .lane_b_rx_valid (lane_die_b_rx_valid),
        .lane_b_lane_fault(lane_die_b_lane_fault)
    );

endmodule : soc_chiplet_top
