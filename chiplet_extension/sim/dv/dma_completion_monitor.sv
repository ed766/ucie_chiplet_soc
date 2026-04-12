`timescale 1ns/1ps

module dma_completion_monitor (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        submit_accept_event,
    input  logic        submit_reject_event,
    input  logic        comp_push_event,
    input  logic        comp_pop_event,
    input  logic        irq_done,
    input  logic        active_valid,
    input  logic [15:0] active_tag,
    input  logic [2:0]  active_state,
    input  logic [8:0]  words_launched,
    input  logic [8:0]  words_retired,
    input  logic [1:0]  comp_push_status,
    input  logic [3:0]  comp_push_err_code,
    input  logic [15:0] comp_push_tag,
    input  logic [8:0]  comp_push_words,
    output int unsigned submit_accepted_count,
    output int unsigned submit_rejected_count,
    output int unsigned completion_push_count,
    output int unsigned completion_pop_count,
    output int unsigned desc_completed_count,
    output int unsigned irq_count,
    output int unsigned error_count,
    output logic        start_event,
    output logic        done_event,
    output logic        error_event,
    output logic        pop_event,
    output logic [15:0] last_tag,
    output logic [2:0]  last_state,
    output logic [8:0]  last_words_launched,
    output logic [8:0]  last_words_retired,
    output logic [3:0]  last_err_code,
    output logic [1:0]  last_completion_status
);

    localparam logic [1:0] COMP_STATUS_SUCCESS       = 2'b01;
    localparam logic [1:0] COMP_STATUS_RUNTIME_ERROR = 2'b10;
    localparam logic [1:0] COMP_STATUS_SUBMIT_REJECT = 2'b11;

    logic irq_done_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            submit_accepted_count <= 0;
            submit_rejected_count <= 0;
            completion_push_count <= 0;
            completion_pop_count <= 0;
            desc_completed_count <= 0;
            irq_count <= 0;
            error_count <= 0;
            start_event <= 1'b0;
            done_event <= 1'b0;
            error_event <= 1'b0;
            pop_event <= 1'b0;
            last_tag <= '0;
            last_state <= '0;
            last_words_launched <= '0;
            last_words_retired <= '0;
            last_err_code <= '0;
            last_completion_status <= 2'b00;
            irq_done_q <= 1'b0;
        end else begin
            start_event <= 1'b0;
            done_event <= 1'b0;
            error_event <= 1'b0;
            pop_event <= 1'b0;

            if (submit_accept_event) begin
                submit_accepted_count <= submit_accepted_count + 1;
                start_event <= 1'b1;
                last_tag <= active_valid ? active_tag : last_tag;
                last_state <= active_state;
                last_words_launched <= words_launched;
                last_words_retired <= words_retired;
                last_err_code <= 4'd0;
            end

            if (submit_reject_event) begin
                submit_rejected_count <= submit_rejected_count + 1;
            end

            if (comp_push_event) begin
                completion_push_count <= completion_push_count + 1;
                last_tag <= comp_push_tag;
                last_state <= active_state;
                last_words_launched <= words_launched;
                last_words_retired <= comp_push_words;
                last_err_code <= comp_push_err_code;
                last_completion_status <= comp_push_status;
                if (comp_push_status == COMP_STATUS_SUCCESS) begin
                    desc_completed_count <= desc_completed_count + 1;
                    done_event <= 1'b1;
                end else if ((comp_push_status == COMP_STATUS_RUNTIME_ERROR) ||
                             (comp_push_status == COMP_STATUS_SUBMIT_REJECT)) begin
                    error_count <= error_count + 1;
                    error_event <= 1'b1;
                end
            end

            if (comp_pop_event) begin
                completion_pop_count <= completion_pop_count + 1;
                pop_event <= 1'b1;
            end

            if (!irq_done_q && irq_done) begin
                irq_count <= irq_count + 1;
            end

            irq_done_q <= irq_done;
        end
    end

endmodule : dma_completion_monitor
