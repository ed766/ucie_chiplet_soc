`timescale 1ns/1ps
`include "chiplet_protocol_assertions.svh"

module tb_dma_queue_props;

    localparam logic [1:0] PWR_RUN = 2'd0;
    localparam logic [7:0] ADDR_CTRL = 8'h00;
    localparam logic [7:0] ADDR_SRC_BASE = 8'h08;
    localparam logic [7:0] ADDR_DST_BASE = 8'h0c;
    localparam logic [7:0] ADDR_LEN_WORDS = 8'h10;
    localparam logic [7:0] ADDR_TAG = 8'h14;
    localparam logic [7:0] ADDR_IRQ_EN = 8'h18;
    localparam logic [7:0] ADDR_COMP_POP = 8'h44;
    localparam logic [1:0] COMP_STATUS_RUNTIME_ERROR = 2'b10;
    localparam logic [1:0] COMP_STATUS_SUBMIT_REJECT = 2'b11;
    localparam logic [3:0] ERR_TIMEOUT = 4'd4;

    logic clk;
    logic rst_n;
    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic cfg_ready;
    logic irq_done;
    logic [63:0] tx_stream_data;
    logic tx_stream_valid;
    logic tx_stream_ready;
    logic [63:0] rx_stream_data;
    logic rx_stream_valid;
    logic rx_stream_ready;
    logic loopback_enable;
    int unsigned accepted_count_q;
    int unsigned completion_count_q;

    dma_offload_ctrl #(
        .DATA_WIDTH(64),
        .SRAM_DEPTH(256),
        .DMA_TIMEOUT_CYCLES(8),
        .SUBMIT_QUEUE_DEPTH(4),
        .COMP_QUEUE_DEPTH(4),
        .BANKS(2),
        .PARITY_ENABLE(1'b1)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .power_state     (PWR_RUN),
        .cfg_valid       (cfg_valid),
        .cfg_write       (cfg_write),
        .cfg_addr        (cfg_addr),
        .cfg_wdata       (cfg_wdata),
        .cfg_rdata       (cfg_rdata),
        .cfg_ready       (cfg_ready),
        .irq_done        (irq_done),
        .tx_stream_data  (tx_stream_data),
        .tx_stream_valid (tx_stream_valid),
        .tx_stream_ready (tx_stream_ready),
        .rx_stream_data  (rx_stream_data),
        .rx_stream_valid (rx_stream_valid),
        .rx_stream_ready (rx_stream_ready),
        .dma_mode_active (),
        .dma_busy_monitor(),
        .dma_done_monitor(),
        .dma_error_monitor(),
        .irq_done_monitor(),
        .dma_tag_monitor ()
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_stream_valid <= 1'b0;
            rx_stream_data <= '0;
        end else begin
            rx_stream_valid <= loopback_enable && tx_stream_valid && tx_stream_ready;
            rx_stream_data <= tx_stream_data;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accepted_count_q <= 0;
            completion_count_q <= 0;
        end else begin
            if (dut.submit_accept_event_q) begin
                accepted_count_q <= accepted_count_q + 1;
            end
            if (dut.comp_push_event_q && (dut.comp_push_status_q != 2'b11)) begin
                completion_count_q <= completion_count_q + 1;
            end
        end
    end

    `CHIPLET_ASSERT_DMA_QUEUE_COUNTS_BOUNDED(
        p_queue_count_bounded,
        clk,
        rst_n,
        dut.submit_count_q,
        4,
        dut.comp_count_q,
        4
    )
    `CHIPLET_ASSERT_DMA_COMPLETION_HAS_ACCEPT(
        p_completion_has_prior_accept,
        clk,
        rst_n,
        dut.comp_push_event_q,
        dut.comp_push_status_q != 2'b11,
        accepted_count_q,
        completion_count_q
    )
    `CHIPLET_ASSERT_DMA_COMPLETION_COUNT_NOT_AHEAD(
        p_completion_count_not_ahead,
        clk,
        rst_n,
        accepted_count_q,
        completion_count_q
    )
    `CHIPLET_ASSERT_IRQ_LEVEL_WHILE_PENDING(
        p_irq_when_enabled_completion_pending,
        clk,
        rst_n,
        (dut.comp_count_q != 0) && (dut.irq_en_q != 0) && (dut.irq_status_q != 0),
        irq_done
    )
    `CHIPLET_ASSERT_DMA_RETIRE_STABLE_WHILE_STALLED(
        p_retire_record_stable_while_stalled,
        clk,
        rst_n,
        dut.comp_full_stall_q,
        dut.retire_tag_q,
        dut.retire_status_q,
        dut.retire_err_code_q,
        dut.retire_words_q
    )
    `CHIPLET_ASSERT_DMA_FRONT_STABLE_UNTIL_POP(
        p_completion_front_stable_until_pop,
        clk,
        rst_n,
        dut.comp_count_q != 0,
        dut.comp_pop_event_q,
        dut.comp_tag_q[dut.comp_head_q],
        dut.comp_status_q[dut.comp_head_q],
        dut.comp_words_q[dut.comp_head_q]
    )
    `CHIPLET_ASSERT_DMA_SUBMIT_REJECT_ZERO_WORDS(
        p_submit_reject_words_zero,
        clk,
        rst_n,
        dut.comp_push_event_q,
        dut.comp_push_status_q,
        dut.comp_push_words_q,
        COMP_STATUS_SUBMIT_REJECT
    )
    `CHIPLET_ASSERT_DMA_RUNTIME_WORDS_BOUNDED(
        p_runtime_words_not_past_len,
        clk,
        rst_n,
        dut.comp_push_event_q,
        dut.comp_push_status_q,
        dut.comp_push_words_q,
        dut.active_len_words_q,
        COMP_STATUS_RUNTIME_ERROR
    )

    function automatic logic [63:0] source_word(input int unsigned index);
        return 64'h1000_0000_0000_0000 | 64'(index);
    endfunction

    task automatic preload_source(input int unsigned index);
        int unsigned bank;
        int unsigned row;
        logic [63:0] word;
        begin
            bank = index[0];
            row = index[7:1];
            word = source_word(index);
            dut.src_bank_mem[bank][row] = word;
            dut.src_bank_parity[bank][row] = ^word;
            dut.src_invalid_bank_mask_q[bank] = 1'b0;
        end
    endtask

    task automatic csr_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_write = 1'b1;
            cfg_addr = addr;
            cfg_wdata = data;
            @(posedge clk);
            cfg_valid = 1'b0;
            cfg_write = 1'b0;
            cfg_addr = '0;
            cfg_wdata = '0;
        end
    endtask

    task automatic enqueue_desc(
        input logic [7:0] src_base,
        input logic [7:0] dst_base,
        input logic [8:0] len_words,
        input logic [15:0] tag
    );
        begin
            csr_write(ADDR_SRC_BASE, src_base);
            csr_write(ADDR_DST_BASE, dst_base);
            csr_write(ADDR_LEN_WORDS, len_words);
            csr_write(ADDR_TAG, tag);
            csr_write(ADDR_CTRL, 32'd1);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cfg_valid = 1'b0;
        cfg_write = 1'b0;
        cfg_addr = '0;
        cfg_wdata = '0;
        tx_stream_ready = 1'b1;
        loopback_enable = 1'b1;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        preload_source(8);
        preload_source(9);
        csr_write(ADDR_IRQ_EN, 32'd3);
        enqueue_desc(8, 40, 9'd2, 16'h1001);
        wait (dut.comp_push_event_q);
        repeat (2) @(posedge clk);
        assert (irq_done);
        csr_write(ADDR_COMP_POP, 32'd1);

        preload_source(12);
        preload_source(13);
        loopback_enable = 1'b0;
        enqueue_desc(12, 44, 9'd2, 16'h1002);
        wait (dut.comp_push_event_q);
        assert (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR);
        assert (dut.comp_push_err_code_q == ERR_TIMEOUT);

        $display("PROP_RESULT|name=dma_queue_completion_props|status=PASS|detail=accept_precedes_completion_queue_bound_irq_and_timeout");
        $finish;
    end

endmodule : tb_dma_queue_props
