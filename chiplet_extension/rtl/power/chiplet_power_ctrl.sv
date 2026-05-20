// Internal power-control sideband generator for chiplet UPF binding.
// The functional proxy model still uses power_state directly; these signals
// provide explicit switch/isolation/retention controls for declarative UPF.
module chiplet_power_ctrl (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [1:0] power_state,

    output logic       sw_pd_a_traffic,
    output logic       sw_pd_a_dma,
    output logic       sw_pd_a_link,
    output logic       sw_pd_b_crypto,
    output logic       sw_pd_b_link,
    output logic       sw_pd_channel,

    output logic       iso_pd_a_traffic_n,
    output logic       iso_pd_a_dma_n,
    output logic       iso_pd_a_link_n,
    output logic       iso_pd_b_crypto_n,
    output logic       iso_pd_b_link_n,
    output logic       iso_pd_channel_n,

    output logic       save_dma_sleep,
    output logic       restore_dma_sleep,
    output logic       save_dma_mem,
    output logic       restore_dma_mem
);

    localparam logic [1:0] PWR_RUN         = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP       = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP  = 2'd3;

    logic [1:0] power_state_q;

    logic run_state;
    logic crypto_only_state;
    logic sleep_state;
    logic deep_sleep_state;

    assign run_state         = (power_state == PWR_RUN);
    assign crypto_only_state = (power_state == PWR_CRYPTO_ONLY);
    assign sleep_state       = (power_state == PWR_SLEEP);
    assign deep_sleep_state  = (power_state == PWR_DEEP_SLEEP);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_state_q <= PWR_RUN;
        end else begin
            power_state_q <= power_state;
        end
    end

    // Switch policy mirrors the proxy power-state contract.
    assign sw_pd_a_traffic = run_state;
    assign sw_pd_a_dma     = run_state || crypto_only_state;
    assign sw_pd_a_link    = run_state || crypto_only_state;
    assign sw_pd_b_crypto  = run_state || crypto_only_state;
    assign sw_pd_b_link    = run_state || crypto_only_state;
    assign sw_pd_channel   = run_state || crypto_only_state;

    // Isolation controls are active-low: deasserted only when the domain is on.
    assign iso_pd_a_traffic_n = sw_pd_a_traffic;
    assign iso_pd_a_dma_n     = sw_pd_a_dma;
    assign iso_pd_a_link_n    = sw_pd_a_link;
    assign iso_pd_b_crypto_n  = sw_pd_b_crypto;
    assign iso_pd_b_link_n    = sw_pd_b_link;
    assign iso_pd_channel_n   = sw_pd_channel;

    assign save_dma_sleep    = rst_n && (power_state_q != PWR_SLEEP) &&
                               sleep_state;
    assign restore_dma_sleep = rst_n && (power_state_q == PWR_SLEEP) &&
                               run_state;

    // Memory retention intent covers both sleep and deep-sleep capable banks;
    // software-visible bank validity remains governed by the DMA RET_CFG CSRs.
    assign save_dma_mem      = rst_n && (power_state_q != PWR_SLEEP) &&
                               (power_state_q != PWR_DEEP_SLEEP) &&
                               (sleep_state || deep_sleep_state);
    assign restore_dma_mem   = rst_n && ((power_state_q == PWR_SLEEP) ||
                               (power_state_q == PWR_DEEP_SLEEP)) &&
                               run_state;

endmodule : chiplet_power_ctrl
