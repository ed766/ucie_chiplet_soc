`timescale 1ns/1ps
`include "chiplet_protocol_assertions.svh"

module tb_power_ctrl_props;

    localparam logic [1:0] PWR_RUN = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP = 2'd3;

    logic clk;
    logic rst_n;
    logic [1:0] power_state;
    logic sw_pd_a_traffic;
    logic sw_pd_a_dma;
    logic sw_pd_a_link;
    logic sw_pd_b_crypto;
    logic sw_pd_b_link;
    logic sw_pd_channel;
    logic iso_pd_a_traffic_n;
    logic iso_pd_a_dma_n;
    logic iso_pd_a_link_n;
    logic iso_pd_b_crypto_n;
    logic iso_pd_b_link_n;
    logic iso_pd_channel_n;
    logic save_dma_sleep;
    logic restore_dma_sleep;
    logic save_dma_mem;
    logic restore_dma_mem;
    logic restore_seen_q;
    logic restore_any_seen_q;
    logic sleep_seen_q;
    logic post_sleep_completion_event_q;
    logic [5:0] sw_vec;
    logic [5:0] iso_n_vec;

    chiplet_power_ctrl dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .power_state         (power_state),
        .sw_pd_a_traffic     (sw_pd_a_traffic),
        .sw_pd_a_dma         (sw_pd_a_dma),
        .sw_pd_a_link        (sw_pd_a_link),
        .sw_pd_b_crypto      (sw_pd_b_crypto),
        .sw_pd_b_link        (sw_pd_b_link),
        .sw_pd_channel       (sw_pd_channel),
        .iso_pd_a_traffic_n  (iso_pd_a_traffic_n),
        .iso_pd_a_dma_n      (iso_pd_a_dma_n),
        .iso_pd_a_link_n     (iso_pd_a_link_n),
        .iso_pd_b_crypto_n   (iso_pd_b_crypto_n),
        .iso_pd_b_link_n     (iso_pd_b_link_n),
        .iso_pd_channel_n    (iso_pd_channel_n),
        .save_dma_sleep      (save_dma_sleep),
        .restore_dma_sleep   (restore_dma_sleep),
        .save_dma_mem        (save_dma_mem),
        .restore_dma_mem     (restore_dma_mem)
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            restore_seen_q <= 1'b0;
            restore_any_seen_q <= 1'b0;
            sleep_seen_q <= 1'b0;
        end else if (power_state == PWR_SLEEP) begin
            restore_seen_q <= 1'b0;
            restore_any_seen_q <= 1'b0;
            sleep_seen_q <= 1'b1;
        end else if (power_state == PWR_DEEP_SLEEP) begin
            restore_any_seen_q <= 1'b0;
        end else if (restore_dma_sleep) begin
            restore_seen_q <= 1'b1;
            restore_any_seen_q <= 1'b1;
            sleep_seen_q <= 1'b0;
        end else if (restore_dma_mem) begin
            restore_any_seen_q <= 1'b1;
        end
    end

    assign sw_vec = {
        sw_pd_a_traffic,
        sw_pd_a_dma,
        sw_pd_a_link,
        sw_pd_b_crypto,
        sw_pd_b_link,
        sw_pd_channel
    };
    assign iso_n_vec = {
        iso_pd_a_traffic_n,
        iso_pd_a_dma_n,
        iso_pd_a_link_n,
        iso_pd_b_crypto_n,
        iso_pd_b_link_n,
        iso_pd_channel_n
    };

    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_a_traffic, clk, rst_n, iso_pd_a_traffic_n, sw_pd_a_traffic)
    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_a_dma, clk, rst_n, iso_pd_a_dma_n, sw_pd_a_dma)
    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_a_link, clk, rst_n, iso_pd_a_link_n, sw_pd_a_link)
    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_b_crypto, clk, rst_n, iso_pd_b_crypto_n, sw_pd_b_crypto)
    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_b_link, clk, rst_n, iso_pd_b_link_n, sw_pd_b_link)
    `CHIPLET_ASSERT_ISO_SAFE_FOR_SWITCH(p_iso_safe_channel, clk, rst_n, iso_pd_channel_n, sw_pd_channel)
    `CHIPLET_ASSERT_VALID_PST_COMBO(
        p_sleep_restore_only_after_sleep,
        clk,
        rst_n,
        (!restore_dma_sleep || (sleep_seen_q && (power_state == PWR_RUN)))
    )
    `CHIPLET_ASSERT_EVENT_AFTER_RESTORE(
        p_resume_completion_after_restore,
        clk,
        rst_n,
        post_sleep_completion_event_q,
        restore_seen_q
    )
    `CHIPLET_ASSERT_VALID_PST_COMBO(
        p_no_deisolated_off_domain,
        clk,
        rst_n,
        ((!iso_pd_a_traffic_n || sw_pd_a_traffic) &&
         (!iso_pd_a_dma_n || sw_pd_a_dma) &&
         (!iso_pd_a_link_n || sw_pd_a_link) &&
         (!iso_pd_b_crypto_n || sw_pd_b_crypto) &&
         (!iso_pd_b_link_n || sw_pd_b_link) &&
         (!iso_pd_channel_n || sw_pd_channel))
    )
    `CHIPLET_ASSERT_VALID_PST_COMBO(
        p_iso_before_switch_off,
        clk,
        rst_n,
        (((($past(sw_vec) & ~sw_vec) & iso_n_vec) == 6'b000000))
    )
    `CHIPLET_ASSERT_VALID_PST_COMBO(
        p_switch_on_before_restore,
        clk,
        rst_n,
        (!(restore_dma_sleep || restore_dma_mem) || sw_pd_a_dma)
    )
    `CHIPLET_ASSERT_VALID_PST_COMBO(
        p_restore_before_deiso,
        clk,
        rst_n,
        (!(!$past(iso_pd_a_dma_n) && iso_pd_a_dma_n) ||
         restore_any_seen_q || restore_dma_sleep || restore_dma_mem)
    )

    initial begin
        bit saw_save;
        bit saw_restore;
        bit saw_mem_save;
        bit saw_mem_restore;
        clk = 1'b0;
        rst_n = 1'b0;
        power_state = PWR_RUN;
        post_sleep_completion_event_q = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        @(posedge clk);
        #1;
        assert (sw_pd_a_traffic && sw_pd_a_dma && sw_pd_a_link && sw_pd_b_crypto && sw_pd_b_link && sw_pd_channel);

        @(negedge clk);
        power_state = PWR_CRYPTO_ONLY;
        repeat (3) @(posedge clk);
        #1;
        assert (!sw_pd_a_traffic && sw_pd_a_dma && sw_pd_b_crypto);

        @(negedge clk);
        power_state = PWR_RUN;
        repeat (3) @(posedge clk);
        @(negedge clk);
        power_state = PWR_SLEEP;
        saw_save = 1'b0;
        #1;
        saw_save |= save_dma_sleep && save_dma_mem;
        repeat (3) begin
            @(posedge clk);
            #1;
            saw_save |= save_dma_sleep && save_dma_mem;
        end
        assert (saw_save);
        @(negedge clk);
        power_state = PWR_RUN;
        saw_restore = 1'b0;
        #1;
        saw_restore |= restore_dma_sleep && restore_dma_mem;
        repeat (3) begin
            @(posedge clk);
            #1;
            saw_restore |= restore_dma_sleep && restore_dma_mem;
        end
        assert (saw_restore);
        @(negedge clk);
        post_sleep_completion_event_q = 1'b1;
        @(negedge clk);
        post_sleep_completion_event_q = 1'b0;

        @(negedge clk);
        power_state = PWR_DEEP_SLEEP;
        saw_mem_save = 1'b0;
        #1;
        saw_mem_save |= !save_dma_sleep && save_dma_mem;
        repeat (3) begin
            @(posedge clk);
            #1;
            saw_mem_save |= !save_dma_sleep && save_dma_mem;
        end
        assert (saw_mem_save);
        @(negedge clk);
        power_state = PWR_RUN;
        saw_mem_restore = 1'b0;
        #1;
        saw_mem_restore |= !restore_dma_sleep && restore_dma_mem;
        repeat (3) begin
            @(posedge clk);
            #1;
            saw_mem_restore |= !restore_dma_sleep && restore_dma_mem;
        end
        assert (saw_mem_restore);

        $display("PROP_RESULT|name=chiplet_power_ctrl_props|status=PASS|detail=pst_isolation_and_retention_controls");
        $finish;
    end

endmodule : tb_power_ctrl_props
