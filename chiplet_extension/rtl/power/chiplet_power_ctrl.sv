// Internal power-control sideband generator for chiplet UPF binding.
// The functional proxy model still uses power_state directly; these signals
// provide explicit switch/isolation/retention controls for declarative UPF.
module chiplet_power_ctrl #(
    parameter int unsigned ISO_BEFORE_OFF_CYCLES = 1,
    parameter int unsigned RESTORE_BEFORE_DEISO_CYCLES = 1
) (
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

    localparam int unsigned DOMAIN_COUNT = 6;
    localparam int unsigned D_A_TRAFFIC  = 5;
    localparam int unsigned D_A_DMA      = 4;
    localparam int unsigned D_A_LINK     = 3;
    localparam int unsigned D_B_CRYPTO   = 2;
    localparam int unsigned D_B_LINK     = 1;
    localparam int unsigned D_CHANNEL    = 0;

    localparam logic [1:0] SEQ_IDLE         = 2'd0;
    localparam logic [1:0] SEQ_ISO_BEFORE_OFF = 2'd1;
    localparam logic [1:0] SEQ_RESTORE_BEFORE_DEISO = 2'd2;

    logic [1:0] power_state_q;
    logic [1:0] seq_state_q;
    logic [DOMAIN_COUNT-1:0] sw_q;
    logic [DOMAIN_COUNT-1:0] iso_n_q;
    logic [DOMAIN_COUNT-1:0] seq_target_sw_q;
    int unsigned seq_count_q;

    logic [DOMAIN_COUNT-1:0] target_sw;
    logic [DOMAIN_COUNT-1:0] turning_off;
    logic [DOMAIN_COUNT-1:0] turning_on;
    logic entering_sleep;
    logic entering_deep_sleep;
    logic waking_to_run_from_sleep;
    logic waking_to_run_from_deep;

    function automatic logic [DOMAIN_COUNT-1:0] switch_vector(input logic [1:0] state);
        case (state)
            PWR_RUN:         switch_vector = 6'b111111;
            PWR_CRYPTO_ONLY: switch_vector = 6'b011111;
            default:         switch_vector = 6'b000000;
        endcase
    endfunction

    assign target_sw = switch_vector(power_state);
    assign turning_off = sw_q & ~target_sw;
    assign turning_on = ~sw_q & target_sw;
    assign entering_sleep = (power_state_q != PWR_SLEEP) && (power_state == PWR_SLEEP);
    assign entering_deep_sleep = (power_state_q != PWR_SLEEP) &&
                                 (power_state_q != PWR_DEEP_SLEEP) &&
                                 (power_state == PWR_DEEP_SLEEP);
    assign waking_to_run_from_sleep = (power_state_q == PWR_SLEEP) &&
                                      (power_state == PWR_RUN);
    assign waking_to_run_from_deep = (power_state_q == PWR_DEEP_SLEEP) &&
                                     (power_state == PWR_RUN);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_state_q <= PWR_RUN;
            seq_state_q <= SEQ_IDLE;
            seq_target_sw_q <= 6'b111111;
            seq_count_q <= 0;
            sw_q <= 6'b111111;
            iso_n_q <= 6'b111111;
            save_dma_sleep <= 1'b0;
            restore_dma_sleep <= 1'b0;
            save_dma_mem <= 1'b0;
            restore_dma_mem <= 1'b0;
        end else begin
            save_dma_sleep <= 1'b0;
            restore_dma_sleep <= 1'b0;
            save_dma_mem <= 1'b0;
            restore_dma_mem <= 1'b0;

            if (entering_sleep) begin
                save_dma_sleep <= 1'b1;
                save_dma_mem <= 1'b1;
            end else if (entering_deep_sleep) begin
                save_dma_mem <= 1'b1;
            end

            case (seq_state_q)
                SEQ_IDLE: begin
                    seq_target_sw_q <= target_sw;
                    if (|turning_off) begin
                        // Isolation asserts before the corresponding switch is disabled.
                        iso_n_q <= iso_n_q & ~turning_off;
                        seq_state_q <= SEQ_ISO_BEFORE_OFF;
                        seq_count_q <= ISO_BEFORE_OFF_CYCLES;
                    end else if (|turning_on) begin
                        // Power is restored before retention restore and de-isolation.
                        sw_q <= sw_q | turning_on;
                        if (waking_to_run_from_sleep) begin
                            restore_dma_sleep <= 1'b1;
                            restore_dma_mem <= 1'b1;
                        end else if (waking_to_run_from_deep) begin
                            restore_dma_mem <= 1'b1;
                        end
                        seq_state_q <= SEQ_RESTORE_BEFORE_DEISO;
                        seq_count_q <= RESTORE_BEFORE_DEISO_CYCLES;
                    end else begin
                        sw_q <= target_sw;
                        iso_n_q <= target_sw;
                    end
                end

                SEQ_ISO_BEFORE_OFF: begin
                    if (seq_count_q > 1) begin
                        seq_count_q <= seq_count_q - 1;
                    end else begin
                        sw_q <= seq_target_sw_q;
                        iso_n_q <= seq_target_sw_q;
                        seq_count_q <= 0;
                        seq_state_q <= SEQ_IDLE;
                    end
                end

                default: begin
                    if (seq_count_q > 1) begin
                        seq_count_q <= seq_count_q - 1;
                    end else begin
                        iso_n_q <= seq_target_sw_q;
                        seq_count_q <= 0;
                        seq_state_q <= SEQ_IDLE;
                    end
                end
            endcase
            power_state_q <= power_state;
        end
    end

    // Switch policy mirrors the proxy power-state contract after sequencing.
    assign sw_pd_a_traffic = sw_q[D_A_TRAFFIC];
    assign sw_pd_a_dma     = sw_q[D_A_DMA];
    assign sw_pd_a_link    = sw_q[D_A_LINK];
    assign sw_pd_b_crypto  = sw_q[D_B_CRYPTO];
    assign sw_pd_b_link    = sw_q[D_B_LINK];
    assign sw_pd_channel   = sw_q[D_CHANNEL];

    // Isolation controls are active-low.
    assign iso_pd_a_traffic_n = iso_n_q[D_A_TRAFFIC];
    assign iso_pd_a_dma_n     = iso_n_q[D_A_DMA];
    assign iso_pd_a_link_n    = iso_n_q[D_A_LINK];
    assign iso_pd_b_crypto_n  = iso_n_q[D_B_CRYPTO];
    assign iso_pd_b_link_n    = iso_n_q[D_B_LINK];
    assign iso_pd_channel_n   = iso_n_q[D_CHANNEL];

endmodule : chiplet_power_ctrl
