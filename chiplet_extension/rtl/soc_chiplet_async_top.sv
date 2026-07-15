// Optional multi-clock integration top. The default soc_chiplet_top remains unchanged.
module soc_chiplet_async_top #(
    parameter int DATA_WIDTH = 64,
    parameter int FLIT_WIDTH = 264,
    parameter int LANES = 16,
    parameter int FIFO_DEPTH = 64
) (
    input  logic                  clk_a,
    input  logic                  rst_a_n,
    input  logic                  clk_b,
    input  logic                  rst_b_n,
    input  logic [1:0]            power_state,
    input  logic                  dma_mode_force,
    input  logic                  cfg_valid,
    input  logic                  cfg_write,
    input  logic [7:0]            cfg_addr,
    input  logic [31:0]           cfg_wdata,
    output logic [31:0]           cfg_rdata,
    output logic                  cfg_ready,
    output logic                  irq_done,
    output logic [DATA_WIDTH-1:0] plaintext_monitor,
    output logic [DATA_WIDTH-1:0] ciphertext_monitor,
    output logic [DATA_WIDTH-1:0] die_b_ciphertext_monitor,
    output logic                  a2b_overflow,
    output logic                  b2a_overflow,
    output logic                  a2b_underflow,
    output logic                  b2a_underflow
);
    logic [LANES-1:0] a_tx_data, a_rx_data, b_tx_data, b_rx_data;
    logic a_tx_valid, a_rx_valid, b_tx_valid, b_rx_valid;
    logic a_fifo_ready, b_fifo_ready;
    logic a_link_enable, a_link_training, a_lane_clk;
    logic b_link_enable, b_link_training, b_lane_clk;

    soc_die_a_top #(.DATA_WIDTH(DATA_WIDTH), .FLIT_WIDTH(FLIT_WIDTH), .LANES(LANES)) u_die_a (
        .clk(clk_a), .rst_n(rst_a_n), .power_state(power_state), .dma_mode_force(dma_mode_force),
        .cfg_valid(cfg_valid), .cfg_write(cfg_write), .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata), .cfg_ready(cfg_ready), .irq_done(irq_done),
        .lane_tx_data(a_tx_data), .lane_tx_valid(a_tx_valid), .lane_link_enable(a_link_enable),
        .lane_link_training(a_link_training), .lane_lane_clk(a_lane_clk),
        .lane_rx_data(a_rx_data), .lane_rx_valid(a_rx_valid), .lane_lane_fault(1'b0),
        .plaintext_monitor(plaintext_monitor), .ciphertext_monitor(ciphertext_monitor),
        .crypto_error_flag(), .dma_busy_monitor(), .dma_done_monitor(), .dma_error_monitor(),
        .irq_done_monitor(), .dma_tag_monitor()
    );

    soc_die_b_top #(.DATA_WIDTH(DATA_WIDTH), .FLIT_WIDTH(FLIT_WIDTH), .LANES(LANES)) u_die_b (
        .clk(clk_b), .rst_n(rst_b_n), .lane_tx_data(b_tx_data), .lane_tx_valid(b_tx_valid),
        .lane_link_enable(b_link_enable), .lane_link_training(b_link_training), .lane_lane_clk(b_lane_clk),
        .lane_rx_data(b_rx_data), .lane_rx_valid(b_rx_valid), .lane_lane_fault(1'b0),
        .ciphertext_monitor(die_b_ciphertext_monitor)
    );

    async_fifo_gray #(.WIDTH(LANES), .DEPTH(FIFO_DEPTH)) u_a2b_fifo (
        .wclk(clk_a), .wrst_n(rst_a_n), .w_data(a_tx_data), .w_valid(a_tx_valid),
        .w_ready(a_fifo_ready), .w_overflow(a2b_overflow),
        .rclk(clk_b), .rrst_n(rst_b_n), .r_data(b_rx_data), .r_valid(b_rx_valid),
        .r_ready(b_rx_valid), .r_underflow(a2b_underflow)
    );
    async_fifo_gray #(.WIDTH(LANES), .DEPTH(FIFO_DEPTH)) u_b2a_fifo (
        .wclk(clk_b), .wrst_n(rst_b_n), .w_data(b_tx_data), .w_valid(b_tx_valid),
        .w_ready(b_fifo_ready), .w_overflow(b2a_overflow),
        .rclk(clk_a), .rrst_n(rst_a_n), .r_data(a_rx_data), .r_valid(a_rx_valid),
        .r_ready(a_rx_valid), .r_underflow(b2a_underflow)
    );
endmodule
