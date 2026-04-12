`timescale 1ns/1ps

module dma_csr_irq_checker (
    input logic        clk,
    input logic        rst_n,
    input logic        cfg_valid,
    input logic        cfg_write,
    input logic [7:0]  cfg_addr,
    input logic [31:0] cfg_wdata,
    input logic        irq_done,
    input logic [1:0]  irq_en,
    input logic [1:0]  irq_status,
    input logic        active_valid,
    input logic        comp_empty,
    input logic [15:0] comp_tag,
    input logic [7:0]  comp_status_word,
    input logic [8:0]  comp_words,
    input logic        comp_pop_event,
    input logic        comp_push_event,
    input logic [1:0]  comp_push_status,
    input logic [3:0]  comp_push_err_code,
    input logic [15:0] active_tag,
    input logic [2:0]  active_state,
    input logic [31:0] submit_result,
    input logic [31:0] reject_overflow_count,
    input logic [1:0]  power_state
);

    localparam logic [7:0] ADDR_IRQ_STATUS     = 8'h1c;
    localparam logic [7:0] ADDR_COMP_POP       = 8'h44;
    localparam logic [7:0] ADDR_SUBMIT_RESULT  = 8'h50;
    localparam logic [1:0] PWR_CRYPTO_ONLY     = 2'd1;

    logic [1:0] clear_pending_q;
    logic [15:0] stable_comp_tag_q;
    logic [7:0] stable_comp_status_q;
    logic [8:0] stable_comp_words_q;
    logic comp_valid_q;
    logic [31:0] prev_submit_result_q;
    logic [31:0] prev_reject_overflow_count_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_pending_q <= '0;
            stable_comp_tag_q <= '0;
            stable_comp_status_q <= '0;
            stable_comp_words_q <= '0;
            comp_valid_q <= 1'b0;
            prev_submit_result_q <= '0;
            prev_reject_overflow_count_q <= '0;
        end else begin
            clear_pending_q <= (cfg_valid && cfg_write && (cfg_addr == ADDR_IRQ_STATUS)) ? cfg_wdata[1:0] : 2'b00;

            if (!comp_empty && !comp_pop_event) begin
                if (comp_valid_q) begin
                    if (comp_tag !== stable_comp_tag_q) begin
                        $error("DMA_COMP_FRONT_UNSTABLE: completion tag changed before COMP_POP");
                    end
                    if (comp_status_word !== stable_comp_status_q) begin
                        $error("DMA_COMP_FRONT_UNSTABLE: completion status changed before COMP_POP");
                    end
                    if (comp_words !== stable_comp_words_q) begin
                        $error("DMA_COMP_FRONT_UNSTABLE: completion words changed before COMP_POP");
                    end
                end
                stable_comp_tag_q <= comp_tag;
                stable_comp_status_q <= comp_status_word;
                stable_comp_words_q <= comp_words;
                comp_valid_q <= 1'b1;
            end else if (comp_pop_event || comp_empty) begin
                comp_valid_q <= 1'b0;
            end

            if (cfg_valid && cfg_write && (cfg_addr == ADDR_COMP_POP) && cfg_wdata[0] && comp_empty && comp_pop_event) begin
                $error("DMA_COMP_POP_EMPTY: completion pop event fired while FIFO was empty");
            end

            if (irq_done !== ((irq_status[0] && irq_en[0]) || (irq_status[1] && irq_en[1]))) begin
                $error("DMA_IRQ_LEVEL_MISMATCH: irq_done is not derived from sticky pending bits");
            end

            if (clear_pending_q[0] && irq_status[0]) begin
                $error("DMA_IRQ_W1C_FAIL: done status did not clear after write-one-to-clear");
            end
            if (clear_pending_q[1] && irq_status[1]) begin
                $error("DMA_IRQ_W1C_FAIL: error status did not clear after write-one-to-clear");
            end

            if (!active_valid && (active_tag != 16'd0)) begin
                $error("DMA_ACTIVE_TAG_INVALID: ACTIVE_TAG is nonzero while active_valid is low");
            end

            if ((power_state == PWR_CRYPTO_ONLY) &&
                cfg_valid && cfg_write && (cfg_addr == 8'h00) && cfg_wdata[0] &&
                submit_result[0]) begin
                $error("DMA_CRYPTO_ONLY_ENQUEUE: descriptor accepted while CRYPTO_ONLY should block submits");
            end

            if ((reject_overflow_count < prev_reject_overflow_count_q) && rst_n) begin
                $error("DMA_REJECT_OVERFLOW_COUNT_ROLLBACK: reject overflow counter decreased unexpectedly");
            end

            if (comp_push_event && (comp_push_status == 2'b11) && (comp_push_err_code == 4'd0)) begin
                $error("DMA_SUBMIT_REJECT_ERRCODE: submit reject completion missing error code");
            end

            prev_submit_result_q <= submit_result;
            prev_reject_overflow_count_q <= reject_overflow_count;
        end
    end

endmodule : dma_csr_irq_checker
