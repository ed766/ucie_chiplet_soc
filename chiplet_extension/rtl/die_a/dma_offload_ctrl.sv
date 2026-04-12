// Queued DMA-style crypto offload controller for Die A.
// Role: expose a staged CSR submission model with an internal submit queue
// and completion FIFO while reusing the existing UCIe datapath.
module dma_offload_ctrl #(
    parameter int DATA_WIDTH = 64,
    parameter int SRAM_DEPTH = 256,
    parameter int DMA_TIMEOUT_CYCLES = 1024,
    parameter int QUEUE_DEPTH = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [1:0]            power_state,
    input  logic                  cfg_valid,
    input  logic                  cfg_write,
    input  logic [7:0]            cfg_addr,
    input  logic [31:0]           cfg_wdata,
    output logic [31:0]           cfg_rdata,
    output logic                  cfg_ready,
    output logic                  irq_done,
    output logic [DATA_WIDTH-1:0] tx_stream_data,
    output logic                  tx_stream_valid,
    input  logic                  tx_stream_ready,
    input  logic [DATA_WIDTH-1:0] rx_stream_data,
    input  logic                  rx_stream_valid,
    output logic                  rx_stream_ready,
    output logic                  dma_mode_active,
    output logic                  dma_busy_monitor,
    output logic                  dma_done_monitor,
    output logic                  dma_error_monitor,
    output logic                  irq_done_monitor,
    output logic [15:0]           dma_tag_monitor
);

    localparam logic [1:0] PWR_RUN         = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP       = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP  = 2'd3;

    localparam logic [7:0] ADDR_CTRL            = 8'h00;
    localparam logic [7:0] ADDR_STATUS          = 8'h04;
    localparam logic [7:0] ADDR_SRC_BASE        = 8'h08;
    localparam logic [7:0] ADDR_DST_BASE        = 8'h0c;
    localparam logic [7:0] ADDR_LEN_WORDS       = 8'h10;
    localparam logic [7:0] ADDR_TAG             = 8'h14;
    localparam logic [7:0] ADDR_IRQ_EN          = 8'h18;
    localparam logic [7:0] ADDR_IRQ_STATUS      = 8'h1c;
    localparam logic [7:0] ADDR_SCRATCH_IDX     = 8'h20;
    localparam logic [7:0] ADDR_SCRATCH_SEL     = 8'h24;
    localparam logic [7:0] ADDR_SCRATCH_LO      = 8'h28;
    localparam logic [7:0] ADDR_SCRATCH_HI      = 8'h2c;
    localparam logic [7:0] ADDR_SUBMIT_Q_STATUS = 8'h30;
    localparam logic [7:0] ADDR_COMP_Q_STATUS   = 8'h34;
    localparam logic [7:0] ADDR_COMP_TAG        = 8'h38;
    localparam logic [7:0] ADDR_COMP_STATUS     = 8'h3c;
    localparam logic [7:0] ADDR_COMP_WORDS      = 8'h40;
    localparam logic [7:0] ADDR_COMP_POP        = 8'h44;
    localparam logic [7:0] ADDR_ACTIVE_TAG      = 8'h48;
    localparam logic [7:0] ADDR_ACTIVE_STATUS   = 8'h4c;
    localparam logic [7:0] ADDR_SUBMIT_RESULT   = 8'h50;
    localparam logic [7:0] ADDR_REJECT_OVF_CNT  = 8'h54;
    localparam logic [7:0] ADDR_MEM_OP_CTRL     = 8'h58;
    localparam logic [7:0] ADDR_MEM_OP_STATUS   = 8'h5c;
    localparam logic [7:0] ADDR_MEM_ERR_STATUS  = 8'h60;
    localparam logic [7:0] ADDR_MEM_ERR_COUNT   = 8'h64;
    localparam logic [7:0] ADDR_RET_CFG         = 8'h68;
    localparam logic [7:0] ADDR_RET_STATUS      = 8'h6c;
    localparam logic [7:0] ADDR_RET_VALID       = 8'h70;
    localparam logic [7:0] ADDR_MEM_CONFLICT    = 8'h74;
    localparam logic [7:0] ADDR_MEM_WAIT        = 8'h78;
    localparam logic [7:0] ADDR_MEM_INJECT_ADDR = 8'h7c;
    localparam logic [7:0] ADDR_MEM_INJECT_CTRL = 8'h80;
    localparam logic [7:0] ADDR_MEM_INJECT_STAT = 8'h84;

    localparam logic [3:0] ERR_NONE           = 4'd0;
    localparam logic [3:0] ERR_ODD_LEN        = 4'd1;
    localparam logic [3:0] ERR_RANGE          = 4'd2;
    localparam logic [3:0] ERR_QUEUE_FULL     = 4'd3;
    localparam logic [3:0] ERR_TIMEOUT        = 4'd4;
    localparam logic [3:0] ERR_SUBMIT_BLOCKED = 4'd5;
    localparam logic [3:0] ERR_MEM_PARITY     = 4'd6;
    localparam logic [3:0] ERR_MEM_INVALID    = 4'd7;

    localparam logic [1:0] COMP_STATUS_RSVD          = 2'b00;
    localparam logic [1:0] COMP_STATUS_SUCCESS       = 2'b01;
    localparam logic [1:0] COMP_STATUS_RUNTIME_ERROR = 2'b10;
    localparam logic [1:0] COMP_STATUS_SUBMIT_REJECT = 2'b11;

    localparam logic [2:0] DMA_IDLE         = 3'd0;
    localparam logic [2:0] DMA_LAUNCH       = 3'd1;
    localparam logic [2:0] DMA_SEND         = 3'd2;
    localparam logic [2:0] DMA_WAIT_RETURN  = 3'd3;
    localparam logic [2:0] DMA_RETIRE_STALL = 3'd4;

    localparam logic [2:0] ERR_KIND_NONE                 = 3'd0;
    localparam logic [2:0] ERR_KIND_PARITY_MAINT         = 3'd1;
    localparam logic [2:0] ERR_KIND_PARITY_DMA_SRC       = 3'd2;
    localparam logic [2:0] ERR_KIND_RETENTION_INVALID_RD = 3'd3;

    localparam int BANKS = 2;
    localparam int BANK_DEPTH = SRAM_DEPTH / BANKS;
    localparam int BANK_ROW_W = $clog2(BANK_DEPTH);
    localparam int PTR_WIDTH     = (QUEUE_DEPTH <= 1) ? 1 : $clog2(QUEUE_DEPTH);
    localparam int COUNT_WIDTH   = $clog2(QUEUE_DEPTH + 1);
    localparam int TIMEOUT_WIDTH = $clog2(DMA_TIMEOUT_CYCLES + 1);

    logic [DATA_WIDTH-1:0] src_bank_mem [0:BANKS-1][0:BANK_DEPTH-1];
    logic                  src_bank_parity [0:BANKS-1][0:BANK_DEPTH-1];
    logic [DATA_WIDTH-1:0] dst_bank_mem [0:BANKS-1][0:BANK_DEPTH-1];
    logic                  dst_bank_parity [0:BANKS-1][0:BANK_DEPTH-1];

    logic [7:0] staged_src_base_q;
    logic [7:0] staged_dst_base_q;
    logic [8:0] staged_len_words_q;
    logic [15:0] staged_tag_q;
    logic [1:0] irq_en_q;
    logic [1:0] irq_status_q;
    logic [7:0] scratch_index_q;
    logic scratch_sel_q;
    logic [DATA_WIDTH-1:0] scratch_data_q;
    logic dma_mode_active_q;

    logic [7:0] submit_src_base_q   [0:QUEUE_DEPTH-1];
    logic [7:0] submit_dst_base_q   [0:QUEUE_DEPTH-1];
    logic [8:0] submit_len_words_q  [0:QUEUE_DEPTH-1];
    logic [15:0] submit_tag_q       [0:QUEUE_DEPTH-1];
    logic [PTR_WIDTH-1:0] submit_head_q;
    logic [PTR_WIDTH-1:0] submit_tail_q;
    logic [COUNT_WIDTH-1:0] submit_count_q;

    logic [15:0] comp_tag_q         [0:QUEUE_DEPTH-1];
    logic [1:0]  comp_status_q      [0:QUEUE_DEPTH-1];
    logic [3:0]  comp_err_code_q    [0:QUEUE_DEPTH-1];
    logic [8:0]  comp_words_q       [0:QUEUE_DEPTH-1];
    logic [PTR_WIDTH-1:0] comp_head_q;
    logic [PTR_WIDTH-1:0] comp_tail_q;
    logic [COUNT_WIDTH-1:0] comp_count_q;

    logic submit_accepted_q;
    logic submit_rejected_q;
    logic [3:0] submit_reject_err_code_q;
    logic [15:0] submit_reject_tag_q;
    logic [31:0] reject_overflow_count_q;

    logic active_valid_q;
    logic [7:0] active_src_base_q;
    logic [7:0] active_dst_base_q;
    logic [8:0] active_len_words_q;
    logic [15:0] active_tag_q;
    logic [8:0] send_count_q;
    logic [8:0] recv_count_q;
    logic [TIMEOUT_WIDTH-1:0] timeout_q;
    logic [2:0] state_q;
    logic comp_full_stall_q;

    logic [15:0] retire_tag_q;
    logic [1:0] retire_status_q;
    logic [3:0] retire_err_code_q;
    logic [8:0] retire_words_q;
    logic [3:0] last_err_code_q;

    logic [1:0] src_sleep_retain_bank_mask_q;
    logic [1:0] dst_sleep_retain_bank_mask_q;
    logic [1:0] src_deep_retain_bank_mask_q;
    logic [1:0] dst_deep_retain_bank_mask_q;
    logic lp_entry_seen_q;
    logic wake_apply_seen_q;
    logic src_corruption_seen_q;
    logic dst_corruption_seen_q;
    logic [1:0] last_low_power_state_q;
    logic [1:0] last_power_state_q;
    logic [1:0] src_invalid_bank_mask_q;
    logic [1:0] dst_invalid_bank_mask_q;

    logic mem_op_busy_q;
    logic mem_op_done_q;
    logic mem_op_wait_conflict_q;
    logic mem_op_parity_error_q;
    logic mem_op_invalid_read_seen_q;
    logic mem_op_reject_busy_q;
    logic mem_op_write_reject_dma_active_q;
    logic mem_op_is_write_q;
    logic mem_op_is_dst_q;
    logic [7:0] mem_op_addr_q;
    logic [DATA_WIDTH-1:0] mem_op_wdata_q;

    logic mem_inject_busy_q;
    logic mem_inject_done_q;
    logic mem_inject_reject_busy_q;
    logic mem_inject_target_dst_q;
    logic mem_inject_invert_parity_q;
    logic [7:0] mem_inject_addr_q;

    logic [15:0] src_parity_errors_q;
    logic [15:0] dst_parity_errors_q;
    logic [15:0] src_conflicts_q;
    logic [15:0] dst_conflicts_q;
    logic [15:0] src_wait_cycles_q;
    logic [15:0] dst_wait_cycles_q;

    logic [7:0] last_mem_err_addr_q;
    logic last_mem_err_is_dst_q;
    logic last_mem_err_on_dma_q;
    logic last_mem_err_bank_id_q;
    logic [2:0] last_mem_err_kind_q;

    // Exposed to the bench through hierarchical references.
    logic submit_accept_event_q;
    logic submit_reject_event_q;
    logic comp_push_event_q;
    logic comp_pop_event_q;
    logic [15:0] comp_push_tag_q;
    logic [1:0] comp_push_status_q;
    logic [3:0] comp_push_err_code_q;
    logic [8:0] comp_push_words_q;
    logic [15:0] comp_pop_tag_q;
    logic [1:0] comp_pop_status_q;
    logic [3:0] comp_pop_err_code_q;
    logic [8:0] comp_pop_words_q;

    logic [7:0] tx_index;
    logic tx_fire;
    logic rx_fire;
    logic submit_empty;
    logic submit_full;
    logic comp_empty;
    logic comp_full;
    logic [PTR_WIDTH-1:0] submit_head_next;
    logic [PTR_WIDTH-1:0] submit_tail_next;
    logic [PTR_WIDTH-1:0] comp_head_next;
    logic [PTR_WIDTH-1:0] comp_tail_next;
    logic [8:0] next_send_count;
    logic [8:0] next_recv_count;
    logic tx_src_bank;
    logic [BANK_ROW_W-1:0] tx_src_row;
    logic [DATA_WIDTH-1:0] tx_word;
    logic tx_word_parity_bad;
    logic tx_word_invalid;
    logic can_progress_dma;

    function automatic logic parity_bit(input logic [DATA_WIDTH-1:0] data);
        parity_bit = ^data;
    endfunction

    function automatic logic [15:0] sat_inc16(input logic [15:0] value);
        if (value == 16'hffff) begin
            return value;
        end
        return value + 16'd1;
    endfunction

    function automatic logic [DATA_WIDTH-1:0] poison_word(input logic [7:0] addr);
        poison_word = 64'hDEAD_0000_0000_0000 ^ DATA_WIDTH'(addr);
    endfunction

    function automatic logic [7:0] bank_word_addr(input int row_idx, input int bank_id);
        bank_word_addr = 8'((row_idx << 1) | bank_id);
    endfunction

    task automatic write_mem_word(
        input logic is_dst,
        input logic bank,
        input logic [BANK_ROW_W-1:0] row,
        input logic [DATA_WIDTH-1:0] data
    );
        begin
            if (is_dst) begin
                dst_bank_mem[bank][row] = data;
                dst_bank_parity[bank][row] = parity_bit(data);
            end else begin
                src_bank_mem[bank][row] = data;
                src_bank_parity[bank][row] = parity_bit(data);
            end
        end
    endtask

    task automatic update_mem_error(
        input logic [7:0] addr,
        input logic is_dst,
        input logic on_dma,
        input logic bank_id,
        input logic [2:0] kind
    );
        begin
            last_mem_err_addr_q <= addr;
            last_mem_err_is_dst_q <= is_dst;
            last_mem_err_on_dma_q <= on_dma;
            last_mem_err_bank_id_q <= bank_id;
            last_mem_err_kind_q <= kind;
        end
    endtask

    task automatic push_completion(
        input logic [15:0] tag,
        input logic [1:0] status,
        input logic [3:0] err_code,
        input logic [8:0] words
    );
        begin
            comp_tag_q[comp_tail_q] <= tag;
            comp_status_q[comp_tail_q] <= status;
            comp_err_code_q[comp_tail_q] <= err_code;
            comp_words_q[comp_tail_q] <= words;
            comp_tail_q <= comp_tail_next;
            comp_count_q <= comp_count_q + COUNT_WIDTH'(1);
            comp_push_event_q <= 1'b1;
            comp_push_tag_q <= tag;
            comp_push_status_q <= status;
            comp_push_err_code_q <= err_code;
            comp_push_words_q <= words;
        end
    endtask

    assign cfg_ready = 1'b1;
    assign submit_empty = (submit_count_q == COUNT_WIDTH'(0));
    assign submit_full = (submit_count_q == COUNT_WIDTH'(QUEUE_DEPTH));
    assign comp_empty = (comp_count_q == COUNT_WIDTH'(0));
    assign comp_full = (comp_count_q == COUNT_WIDTH'(QUEUE_DEPTH));
    assign submit_head_next = (submit_head_q == PTR_WIDTH'(QUEUE_DEPTH - 1)) ? '0 : (submit_head_q + 1'b1);
    assign submit_tail_next = (submit_tail_q == PTR_WIDTH'(QUEUE_DEPTH - 1)) ? '0 : (submit_tail_q + 1'b1);
    assign comp_head_next = (comp_head_q == PTR_WIDTH'(QUEUE_DEPTH - 1)) ? '0 : (comp_head_q + 1'b1);
    assign comp_tail_next = (comp_tail_q == PTR_WIDTH'(QUEUE_DEPTH - 1)) ? '0 : (comp_tail_q + 1'b1);
    assign tx_index = active_src_base_q + send_count_q[7:0];
    assign tx_src_bank = tx_index[0];
    assign tx_src_row = tx_index[7:1];
    assign tx_word = src_bank_mem[tx_src_bank][tx_src_row];
    assign tx_word_parity_bad = (src_bank_parity[tx_src_bank][tx_src_row] != parity_bit(tx_word));
    assign tx_word_invalid = src_invalid_bank_mask_q[tx_src_bank];
    assign tx_stream_data = tx_word;
    assign can_progress_dma = (power_state == PWR_RUN);
    assign tx_stream_valid = active_valid_q &&
                             can_progress_dma &&
                             (state_q == DMA_SEND) &&
                             (send_count_q < active_len_words_q) &&
                             !tx_word_parity_bad &&
                             !tx_word_invalid;
    assign tx_fire = tx_stream_valid && tx_stream_ready;
    assign rx_stream_ready = active_valid_q &&
                             can_progress_dma &&
                             ((state_q == DMA_LAUNCH) || (state_q == DMA_SEND) || (state_q == DMA_WAIT_RETURN));
    assign rx_fire = rx_stream_valid && rx_stream_ready;
    assign irq_done = (irq_status_q[0] && irq_en_q[0]) || (irq_status_q[1] && irq_en_q[1]);
    assign dma_mode_active = dma_mode_active_q;
    assign dma_busy_monitor = active_valid_q;
    assign irq_done_monitor = irq_done;
    assign dma_tag_monitor = active_valid_q ? active_tag_q : 16'd0;
    assign next_send_count = send_count_q + 9'd1;
    assign next_recv_count = recv_count_q + 9'd1;

    always_comb begin
        case (cfg_addr)
            ADDR_STATUS: begin
                cfg_rdata = {23'd0,
                             (reject_overflow_count_q != 0),
                             comp_full_stall_q,
                             last_err_code_q,
                             irq_status_q[1],
                             irq_status_q[0],
                             active_valid_q};
            end
            ADDR_SRC_BASE: cfg_rdata = {24'd0, staged_src_base_q};
            ADDR_DST_BASE: cfg_rdata = {24'd0, staged_dst_base_q};
            ADDR_LEN_WORDS: cfg_rdata = {23'd0, staged_len_words_q};
            ADDR_TAG: cfg_rdata = {16'd0, staged_tag_q};
            ADDR_IRQ_EN: cfg_rdata = {30'd0, irq_en_q};
            ADDR_IRQ_STATUS: cfg_rdata = {30'd0, irq_status_q};
            ADDR_SCRATCH_IDX: cfg_rdata = {24'd0, scratch_index_q};
            ADDR_SCRATCH_SEL: cfg_rdata = {31'd0, scratch_sel_q};
            ADDR_SCRATCH_LO: cfg_rdata = scratch_data_q[31:0];
            ADDR_SCRATCH_HI: cfg_rdata = scratch_data_q[63:32];
            ADDR_SUBMIT_Q_STATUS: cfg_rdata = {23'd0, submit_count_q, submit_tail_q, submit_head_q, submit_full, submit_empty};
            ADDR_COMP_Q_STATUS: cfg_rdata = {23'd0, comp_count_q, comp_tail_q, comp_head_q, comp_full, comp_empty};
            ADDR_COMP_TAG: cfg_rdata = comp_empty ? 32'd0 : {16'd0, comp_tag_q[comp_head_q]};
            ADDR_COMP_STATUS: cfg_rdata = comp_empty ? 32'd0 : {26'd0, comp_status_q[comp_head_q], comp_err_code_q[comp_head_q]};
            ADDR_COMP_WORDS: cfg_rdata = comp_empty ? 32'd0 : {23'd0, comp_words_q[comp_head_q]};
            ADDR_ACTIVE_TAG: cfg_rdata = active_valid_q ? {16'd0, active_tag_q} : 32'd0;
            ADDR_ACTIVE_STATUS: cfg_rdata = {21'd0, comp_count_q, submit_count_q, comp_full_stall_q, active_valid_q, state_q};
            ADDR_SUBMIT_RESULT: begin
                cfg_rdata = {10'd0, submit_reject_tag_q, submit_reject_err_code_q, submit_rejected_q, submit_accepted_q};
            end
            ADDR_REJECT_OVF_CNT: cfg_rdata = reject_overflow_count_q;
            ADDR_MEM_OP_STATUS: begin
                cfg_rdata = {25'd0,
                             mem_op_write_reject_dma_active_q,
                             mem_op_reject_busy_q,
                             mem_op_invalid_read_seen_q,
                             mem_op_parity_error_q,
                             mem_op_wait_conflict_q,
                             mem_op_done_q,
                             mem_op_busy_q};
            end
            ADDR_MEM_ERR_STATUS: begin
                cfg_rdata = {18'd0,
                             last_mem_err_kind_q,
                             last_mem_err_bank_id_q,
                             last_mem_err_on_dma_q,
                             last_mem_err_is_dst_q,
                             last_mem_err_addr_q};
            end
            ADDR_MEM_ERR_COUNT: cfg_rdata = {dst_parity_errors_q, src_parity_errors_q};
            ADDR_RET_CFG: begin
                cfg_rdata = {24'd0,
                             dst_deep_retain_bank_mask_q,
                             src_deep_retain_bank_mask_q,
                             dst_sleep_retain_bank_mask_q,
                             src_sleep_retain_bank_mask_q};
            end
            ADDR_RET_STATUS: begin
                cfg_rdata = {26'd0,
                             last_low_power_state_q,
                             dst_corruption_seen_q,
                             src_corruption_seen_q,
                             wake_apply_seen_q,
                             lp_entry_seen_q};
            end
            ADDR_RET_VALID: begin
                cfg_rdata = {28'd0, dst_invalid_bank_mask_q, src_invalid_bank_mask_q};
            end
            ADDR_MEM_CONFLICT: cfg_rdata = {dst_conflicts_q, src_conflicts_q};
            ADDR_MEM_WAIT: cfg_rdata = {dst_wait_cycles_q, src_wait_cycles_q};
            ADDR_MEM_INJECT_ADDR: cfg_rdata = {24'd0, mem_inject_addr_q};
            ADDR_MEM_INJECT_STAT: begin
                cfg_rdata = {29'd0, mem_inject_reject_busy_q, mem_inject_done_q, mem_inject_busy_q};
            end
            default: cfg_rdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin : dma_seq
        if (!rst_n) begin
            active_valid_q <= 1'b0;
            active_src_base_q <= '0;
            active_dst_base_q <= '0;
            active_len_words_q <= '0;
            active_tag_q <= '0;
            send_count_q <= '0;
            recv_count_q <= '0;
            timeout_q <= '0;
            state_q <= DMA_IDLE;
            comp_full_stall_q <= 1'b0;
            retire_tag_q <= '0;
            retire_status_q <= COMP_STATUS_RSVD;
            retire_err_code_q <= ERR_NONE;
            retire_words_q <= '0;
            staged_src_base_q <= '0;
            staged_dst_base_q <= '0;
            staged_len_words_q <= '0;
            staged_tag_q <= '0;
            irq_en_q <= '0;
            irq_status_q <= '0;
            scratch_index_q <= '0;
            scratch_sel_q <= 1'b0;
            scratch_data_q <= '0;
            dma_mode_active_q <= 1'b0;
            submit_head_q <= '0;
            submit_tail_q <= '0;
            submit_count_q <= '0;
            comp_head_q <= '0;
            comp_tail_q <= '0;
            comp_count_q <= '0;
            submit_accepted_q <= 1'b0;
            submit_rejected_q <= 1'b0;
            submit_reject_err_code_q <= ERR_NONE;
            submit_reject_tag_q <= '0;
            reject_overflow_count_q <= '0;
            last_err_code_q <= ERR_NONE;
            dma_done_monitor <= 1'b0;
            dma_error_monitor <= 1'b0;
            submit_accept_event_q <= 1'b0;
            submit_reject_event_q <= 1'b0;
            comp_push_event_q <= 1'b0;
            comp_pop_event_q <= 1'b0;
            comp_push_tag_q <= '0;
            comp_push_status_q <= COMP_STATUS_RSVD;
            comp_push_err_code_q <= ERR_NONE;
            comp_push_words_q <= '0;
            comp_pop_tag_q <= '0;
            comp_pop_status_q <= COMP_STATUS_RSVD;
            comp_pop_err_code_q <= ERR_NONE;
            comp_pop_words_q <= '0;
            src_sleep_retain_bank_mask_q <= 2'b11;
            dst_sleep_retain_bank_mask_q <= 2'b11;
            src_deep_retain_bank_mask_q <= 2'b00;
            dst_deep_retain_bank_mask_q <= 2'b00;
            lp_entry_seen_q <= 1'b0;
            wake_apply_seen_q <= 1'b0;
            src_corruption_seen_q <= 1'b0;
            dst_corruption_seen_q <= 1'b0;
            last_low_power_state_q <= PWR_RUN;
            last_power_state_q <= PWR_RUN;
            src_invalid_bank_mask_q <= 2'b00;
            dst_invalid_bank_mask_q <= 2'b00;
            mem_op_busy_q <= 1'b0;
            mem_op_done_q <= 1'b0;
            mem_op_wait_conflict_q <= 1'b0;
            mem_op_parity_error_q <= 1'b0;
            mem_op_invalid_read_seen_q <= 1'b0;
            mem_op_reject_busy_q <= 1'b0;
            mem_op_write_reject_dma_active_q <= 1'b0;
            mem_op_is_write_q <= 1'b0;
            mem_op_is_dst_q <= 1'b0;
            mem_op_addr_q <= '0;
            mem_op_wdata_q <= '0;
            mem_inject_busy_q <= 1'b0;
            mem_inject_done_q <= 1'b0;
            mem_inject_reject_busy_q <= 1'b0;
            mem_inject_target_dst_q <= 1'b0;
            mem_inject_invert_parity_q <= 1'b0;
            mem_inject_addr_q <= '0;
            src_parity_errors_q <= '0;
            dst_parity_errors_q <= '0;
            src_conflicts_q <= '0;
            dst_conflicts_q <= '0;
            src_wait_cycles_q <= '0;
            dst_wait_cycles_q <= '0;
            last_mem_err_addr_q <= '0;
            last_mem_err_is_dst_q <= 1'b0;
            last_mem_err_on_dma_q <= 1'b0;
            last_mem_err_bank_id_q <= 1'b0;
            last_mem_err_kind_q <= ERR_KIND_NONE;
            for (int bank = 0; bank < BANKS; bank++) begin
                for (int row = 0; row < BANK_DEPTH; row++) begin
                    src_bank_mem[bank][row] = '0;
                    src_bank_parity[bank][row] = 1'b0;
                    dst_bank_mem[bank][row] = '0;
                    dst_bank_parity[bank][row] = 1'b0;
                end
            end
            for (int qidx = 0; qidx < QUEUE_DEPTH; qidx++) begin
                submit_src_base_q[qidx] = '0;
                submit_dst_base_q[qidx] = '0;
                submit_len_words_q[qidx] = '0;
                submit_tag_q[qidx] = '0;
                comp_tag_q[qidx] = '0;
                comp_status_q[qidx] = COMP_STATUS_RSVD;
                comp_err_code_q[qidx] = ERR_NONE;
                comp_words_q[qidx] = '0;
            end
        end else begin
            logic ctrl_start_req;
            logic ctrl_soft_reset_req;
            logic comp_pop_req;
            logic mem_op_start_req;
            logic mem_op_write_req;
            logic mem_inject_start_req;
            logic mem_inject_target_dst_req;
            logic mem_inject_invert_req;
            logic [3:0] submit_err_code;
            logic [8:0] staged_src_sum;
            logic [8:0] staged_dst_sum;
            logic [7:0] mem_addr;
            logic mem_bank;
            logic [BANK_ROW_W-1:0] mem_row;
            logic mem_conflict;
            logic [DATA_WIDTH-1:0] mem_read_word;
            logic mem_read_parity_bad;
            logic mem_read_invalid;

            dma_done_monitor <= 1'b0;
            dma_error_monitor <= 1'b0;
            submit_accept_event_q <= 1'b0;
            submit_reject_event_q <= 1'b0;
            comp_push_event_q <= 1'b0;
            comp_pop_event_q <= 1'b0;
            comp_push_tag_q <= '0;
            comp_push_status_q <= COMP_STATUS_RSVD;
            comp_push_err_code_q <= ERR_NONE;
            comp_push_words_q <= '0;
            comp_pop_tag_q <= '0;
            comp_pop_status_q <= COMP_STATUS_RSVD;
            comp_pop_err_code_q <= ERR_NONE;
            comp_pop_words_q <= '0;
            mem_inject_done_q <= 1'b0;

            ctrl_start_req = 1'b0;
            ctrl_soft_reset_req = 1'b0;
            comp_pop_req = 1'b0;
            mem_op_start_req = 1'b0;
            mem_op_write_req = 1'b0;
            mem_inject_start_req = 1'b0;
            mem_inject_target_dst_req = 1'b0;
            mem_inject_invert_req = 1'b0;
            submit_err_code = ERR_NONE;
            staged_src_sum = {1'b0, staged_src_base_q} + staged_len_words_q;
            staged_dst_sum = {1'b0, staged_dst_base_q} + staged_len_words_q;
            mem_addr = mem_op_addr_q;
            mem_bank = mem_addr[0];
            mem_row = mem_addr[7:1];
            mem_conflict = 1'b0;
            mem_read_word = '0;
            mem_read_parity_bad = 1'b0;
            mem_read_invalid = 1'b0;

            if (last_power_state_q != power_state) begin
                if ((power_state == PWR_SLEEP) || (power_state == PWR_DEEP_SLEEP)) begin
                    lp_entry_seen_q <= 1'b1;
                    last_low_power_state_q <= power_state;
                end
                if ((last_power_state_q == PWR_SLEEP || last_power_state_q == PWR_DEEP_SLEEP) &&
                    (power_state == PWR_RUN)) begin
                    wake_apply_seen_q <= 1'b1;
                    if (last_power_state_q == PWR_SLEEP) begin
                        for (int bank = 0; bank < BANKS; bank++) begin
                            if (!src_sleep_retain_bank_mask_q[bank]) begin
                                src_invalid_bank_mask_q[bank] <= 1'b1;
                                src_corruption_seen_q <= 1'b1;
                                for (int row = 0; row < BANK_DEPTH; row++) begin
                                    src_bank_mem[bank][row] = poison_word(bank_word_addr(row, bank));
                                    src_bank_parity[bank][row] = parity_bit(poison_word(bank_word_addr(row, bank)));
                                end
                            end
                            if (!dst_sleep_retain_bank_mask_q[bank]) begin
                                dst_invalid_bank_mask_q[bank] <= 1'b1;
                                dst_corruption_seen_q <= 1'b1;
                                for (int row = 0; row < BANK_DEPTH; row++) begin
                                    dst_bank_mem[bank][row] = poison_word(bank_word_addr(row, bank));
                                    dst_bank_parity[bank][row] = parity_bit(poison_word(bank_word_addr(row, bank)));
                                end
                            end
                        end
                    end else begin
                        for (int bank = 0; bank < BANKS; bank++) begin
                            if (!src_deep_retain_bank_mask_q[bank]) begin
                                src_invalid_bank_mask_q[bank] <= 1'b1;
                                src_corruption_seen_q <= 1'b1;
                                for (int row = 0; row < BANK_DEPTH; row++) begin
                                    src_bank_mem[bank][row] = poison_word(bank_word_addr(row, bank));
                                    src_bank_parity[bank][row] = parity_bit(poison_word(bank_word_addr(row, bank)));
                                end
                            end
                            if (!dst_deep_retain_bank_mask_q[bank]) begin
                                dst_invalid_bank_mask_q[bank] <= 1'b1;
                                dst_corruption_seen_q <= 1'b1;
                                for (int row = 0; row < BANK_DEPTH; row++) begin
                                    dst_bank_mem[bank][row] = poison_word(bank_word_addr(row, bank));
                                    dst_bank_parity[bank][row] = parity_bit(poison_word(bank_word_addr(row, bank)));
                                end
                            end
                        end
                    end
                end
                last_power_state_q <= power_state;
            end

            if (power_state == PWR_DEEP_SLEEP) begin
                active_valid_q <= 1'b0;
                active_src_base_q <= '0;
                active_dst_base_q <= '0;
                active_len_words_q <= '0;
                active_tag_q <= '0;
                send_count_q <= '0;
                recv_count_q <= '0;
                timeout_q <= '0;
                state_q <= DMA_IDLE;
                comp_full_stall_q <= 1'b0;
                retire_tag_q <= '0;
                retire_status_q <= COMP_STATUS_RSVD;
                retire_err_code_q <= ERR_NONE;
                retire_words_q <= '0;
                staged_src_base_q <= '0;
                staged_dst_base_q <= '0;
                staged_len_words_q <= '0;
                staged_tag_q <= '0;
                irq_status_q <= '0;
                submit_head_q <= '0;
                submit_tail_q <= '0;
                submit_count_q <= '0;
                comp_head_q <= '0;
                comp_tail_q <= '0;
                comp_count_q <= '0;
                last_err_code_q <= ERR_NONE;
                mem_op_busy_q <= 1'b0;
                mem_op_done_q <= 1'b0;
                mem_op_wait_conflict_q <= 1'b0;
                mem_op_parity_error_q <= 1'b0;
                mem_op_invalid_read_seen_q <= 1'b0;
                mem_op_reject_busy_q <= 1'b0;
                mem_op_write_reject_dma_active_q <= 1'b0;
                mem_inject_busy_q <= 1'b0;
                mem_inject_done_q <= 1'b0;
                mem_inject_reject_busy_q <= 1'b0;
            end else begin
                if (cfg_valid) begin
                    dma_mode_active_q <= 1'b1;
                    if (cfg_write) begin
                        case (cfg_addr)
                            ADDR_CTRL: begin
                                ctrl_start_req = cfg_wdata[0];
                                ctrl_soft_reset_req = cfg_wdata[1];
                            end
                            ADDR_SRC_BASE: staged_src_base_q <= cfg_wdata[7:0];
                            ADDR_DST_BASE: staged_dst_base_q <= cfg_wdata[7:0];
                            ADDR_LEN_WORDS: staged_len_words_q <= cfg_wdata[8:0];
                            ADDR_TAG: staged_tag_q <= cfg_wdata[15:0];
                            ADDR_IRQ_EN: irq_en_q <= cfg_wdata[1:0];
                            ADDR_IRQ_STATUS: irq_status_q <= irq_status_q & ~cfg_wdata[1:0];
                            ADDR_SCRATCH_IDX: scratch_index_q <= cfg_wdata[7:0];
                            ADDR_SCRATCH_SEL: scratch_sel_q <= cfg_wdata[0];
                            ADDR_SCRATCH_LO: scratch_data_q[31:0] <= cfg_wdata;
                            ADDR_SCRATCH_HI: scratch_data_q[63:32] <= cfg_wdata;
                            ADDR_COMP_POP: comp_pop_req = cfg_wdata[0];
                            ADDR_MEM_OP_CTRL: begin
                                mem_op_start_req = cfg_wdata[0];
                                mem_op_write_req = cfg_wdata[1];
                            end
                            ADDR_RET_CFG: begin
                                src_sleep_retain_bank_mask_q <= cfg_wdata[1:0];
                                dst_sleep_retain_bank_mask_q <= cfg_wdata[3:2];
                                src_deep_retain_bank_mask_q <= cfg_wdata[5:4];
                                dst_deep_retain_bank_mask_q <= cfg_wdata[7:6];
                            end
                            ADDR_MEM_INJECT_ADDR: mem_inject_addr_q <= cfg_wdata[7:0];
                            ADDR_MEM_INJECT_CTRL: begin
                                mem_inject_start_req = cfg_wdata[0];
                                mem_inject_target_dst_req = cfg_wdata[1];
                                mem_inject_invert_req = cfg_wdata[2];
                            end
                            default: begin end
                        endcase
                    end
                end

                if (ctrl_soft_reset_req) begin
                    active_valid_q <= 1'b0;
                    active_src_base_q <= '0;
                    active_dst_base_q <= '0;
                    active_len_words_q <= '0;
                    active_tag_q <= '0;
                    send_count_q <= '0;
                    recv_count_q <= '0;
                    timeout_q <= '0;
                    state_q <= DMA_IDLE;
                    comp_full_stall_q <= 1'b0;
                    retire_tag_q <= '0;
                    retire_status_q <= COMP_STATUS_RSVD;
                    retire_err_code_q <= ERR_NONE;
                    retire_words_q <= '0;
                    irq_status_q <= '0;
                    submit_head_q <= '0;
                    submit_tail_q <= '0;
                    submit_count_q <= '0;
                    comp_head_q <= '0;
                    comp_tail_q <= '0;
                    comp_count_q <= '0;
                    last_err_code_q <= ERR_NONE;
                    submit_accepted_q <= 1'b0;
                    submit_rejected_q <= 1'b0;
                    submit_reject_err_code_q <= ERR_NONE;
                    submit_reject_tag_q <= '0;
                    mem_op_busy_q <= 1'b0;
                    mem_op_done_q <= 1'b0;
                    mem_op_wait_conflict_q <= 1'b0;
                    mem_op_parity_error_q <= 1'b0;
                    mem_op_invalid_read_seen_q <= 1'b0;
                    mem_op_reject_busy_q <= 1'b0;
                    mem_op_write_reject_dma_active_q <= 1'b0;
                    mem_inject_busy_q <= 1'b0;
                    mem_inject_done_q <= 1'b0;
                    mem_inject_reject_busy_q <= 1'b0;
                end else begin
                    if (comp_pop_req && !comp_empty) begin
                        comp_pop_event_q <= 1'b1;
                        comp_pop_tag_q <= comp_tag_q[comp_head_q];
                        comp_pop_status_q <= comp_status_q[comp_head_q];
                        comp_pop_err_code_q <= comp_err_code_q[comp_head_q];
                        comp_pop_words_q <= comp_words_q[comp_head_q];
                        comp_head_q <= comp_head_next;
                        comp_count_q <= comp_count_q - COUNT_WIDTH'(1);
                    end

                    if (mem_inject_start_req) begin
                        if (mem_op_busy_q || mem_inject_busy_q) begin
                            mem_inject_reject_busy_q <= 1'b1;
                        end else begin
                            mem_inject_busy_q <= 1'b1;
                            mem_inject_done_q <= 1'b0;
                            mem_inject_reject_busy_q <= 1'b0;
                            mem_inject_target_dst_q <= mem_inject_target_dst_req;
                            mem_inject_invert_parity_q <= mem_inject_invert_req;
                        end
                    end
                    if (mem_inject_busy_q) begin
                        logic inj_bank;
                        logic [BANK_ROW_W-1:0] inj_row;
                        inj_bank = mem_inject_addr_q[0];
                        inj_row = mem_inject_addr_q[7:1];
                        if (mem_inject_target_dst_q) begin
                            dst_bank_parity[inj_bank][inj_row] <= dst_bank_parity[inj_bank][inj_row] ^ mem_inject_invert_parity_q;
                        end else begin
                            src_bank_parity[inj_bank][inj_row] <= src_bank_parity[inj_bank][inj_row] ^ mem_inject_invert_parity_q;
                        end
                        mem_inject_busy_q <= 1'b0;
                        mem_inject_done_q <= 1'b1;
                    end

                    if (mem_op_start_req) begin
                        if (mem_op_busy_q) begin
                            mem_op_reject_busy_q <= 1'b1;
                        end else if (mem_op_write_req && active_valid_q) begin
                            mem_op_write_reject_dma_active_q <= 1'b1;
                        end else begin
                            mem_op_busy_q <= 1'b1;
                            mem_op_done_q <= 1'b0;
                            mem_op_wait_conflict_q <= 1'b0;
                            mem_op_parity_error_q <= 1'b0;
                            mem_op_invalid_read_seen_q <= 1'b0;
                            mem_op_reject_busy_q <= 1'b0;
                            mem_op_write_reject_dma_active_q <= 1'b0;
                            mem_op_is_write_q <= mem_op_write_req;
                            mem_op_is_dst_q <= scratch_sel_q;
                            mem_op_addr_q <= scratch_index_q;
                            mem_op_wdata_q <= scratch_data_q;
                        end
                    end

                    if (mem_op_busy_q) begin
                        if (power_state == PWR_SLEEP) begin
                            // Pause in sleep.
                        end else if (power_state == PWR_DEEP_SLEEP) begin
                            mem_op_busy_q <= 1'b0;
                            mem_op_done_q <= 1'b0;
                        end else begin
                            mem_addr = mem_op_addr_q;
                            mem_bank = mem_addr[0];
                            mem_row = mem_addr[7:1];
                            mem_conflict = 1'b0;
                            if (!mem_op_is_dst_q &&
                                active_valid_q &&
                                ((state_q == DMA_LAUNCH) || (state_q == DMA_SEND)) &&
                                (tx_src_bank == mem_bank)) begin
                                mem_conflict = 1'b1;
                            end
                            if (mem_op_is_dst_q && rx_fire &&
                                (((active_dst_base_q + recv_count_q[7:0]) & 8'h01) == {7'b0, mem_bank})) begin
                                mem_conflict = 1'b1;
                            end

                            if (mem_conflict) begin
                                mem_op_wait_conflict_q <= 1'b1;
                                if (mem_op_is_dst_q) begin
                                    dst_conflicts_q <= sat_inc16(dst_conflicts_q);
                                    dst_wait_cycles_q <= sat_inc16(dst_wait_cycles_q);
                                end else begin
                                    src_conflicts_q <= sat_inc16(src_conflicts_q);
                                    src_wait_cycles_q <= sat_inc16(src_wait_cycles_q);
                                end
                            end else begin
                                mem_read_word = mem_op_is_dst_q ? dst_bank_mem[mem_bank][mem_row] : src_bank_mem[mem_bank][mem_row];
                                mem_read_parity_bad = (mem_op_is_dst_q ? dst_bank_parity[mem_bank][mem_row] : src_bank_parity[mem_bank][mem_row]) != parity_bit(mem_read_word);
                                mem_read_invalid = mem_op_is_dst_q ? dst_invalid_bank_mask_q[mem_bank] : src_invalid_bank_mask_q[mem_bank];

                                if (mem_op_is_write_q) begin
                                    write_mem_word(mem_op_is_dst_q, mem_bank, mem_row, mem_op_wdata_q);
                                    if (mem_op_is_dst_q) begin
                                        dst_invalid_bank_mask_q[mem_bank] <= 1'b0;
                                    end else begin
                                        src_invalid_bank_mask_q[mem_bank] <= 1'b0;
                                    end
                                    mem_op_busy_q <= 1'b0;
                                    mem_op_done_q <= 1'b1;
                                end else begin
                                    scratch_data_q <= mem_read_word;
                                    if (mem_read_parity_bad) begin
`ifndef UCIE_BUG_MEM_PARITY_SKIP
                                        mem_op_parity_error_q <= 1'b1;
                                        if (mem_op_is_dst_q) begin
                                            dst_parity_errors_q <= sat_inc16(dst_parity_errors_q);
                                        end else begin
                                            src_parity_errors_q <= sat_inc16(src_parity_errors_q);
                                        end
                                        update_mem_error(mem_op_addr_q, mem_op_is_dst_q, 1'b0, mem_bank, ERR_KIND_PARITY_MAINT);
`endif
                                    end else if (mem_read_invalid) begin
                                        mem_op_invalid_read_seen_q <= 1'b1;
                                        update_mem_error(mem_op_addr_q, mem_op_is_dst_q, 1'b0, mem_bank, ERR_KIND_RETENTION_INVALID_RD);
                                    end
                                    mem_op_busy_q <= 1'b0;
                                    mem_op_done_q <= 1'b1;
                                end
                            end
                        end
                    end

                    if (ctrl_start_req) begin
                        submit_accepted_q <= 1'b0;
                        submit_rejected_q <= 1'b0;
                        submit_reject_err_code_q <= ERR_NONE;
                        submit_reject_tag_q <= staged_tag_q;

                        if (power_state == PWR_CRYPTO_ONLY) begin
                            submit_err_code = ERR_SUBMIT_BLOCKED;
                        end else if ((staged_len_words_q == 0) || staged_len_words_q[0]) begin
                            submit_err_code = ERR_ODD_LEN;
                        end else if ((staged_src_sum > 9'(SRAM_DEPTH)) || (staged_dst_sum > 9'(SRAM_DEPTH))) begin
                            submit_err_code = ERR_RANGE;
                        end else if (submit_full) begin
                            submit_err_code = ERR_QUEUE_FULL;
                        end else begin
                            submit_src_base_q[submit_tail_q] <= staged_src_base_q;
                            submit_dst_base_q[submit_tail_q] <= staged_dst_base_q;
                            submit_len_words_q[submit_tail_q] <= staged_len_words_q;
                            submit_tag_q[submit_tail_q] <= staged_tag_q;
                            submit_tail_q <= submit_tail_next;
                            submit_count_q <= submit_count_q + COUNT_WIDTH'(1);
                            submit_accepted_q <= 1'b1;
                            submit_accept_event_q <= 1'b1;
                        end

                        if (submit_err_code != ERR_NONE) begin
                            submit_rejected_q <= 1'b1;
                            submit_reject_err_code_q <= submit_err_code;
                            submit_reject_event_q <= 1'b1;
                            if (!comp_full) begin
                                push_completion(staged_tag_q, COMP_STATUS_SUBMIT_REJECT, submit_err_code, '0);
                                dma_error_monitor <= 1'b1;
                                irq_status_q[1] <= 1'b1;
                                last_err_code_q <= submit_err_code;
                            end else if (reject_overflow_count_q != 32'hffff_ffff) begin
                                reject_overflow_count_q <= reject_overflow_count_q + 32'd1;
                            end
                        end
                    end

                    if (active_valid_q && can_progress_dma) begin
                        if ((state_q == DMA_SEND) && (send_count_q < active_len_words_q) &&
                            (tx_word_parity_bad || tx_word_invalid)) begin
                            if (!comp_full) begin
                                push_completion(active_tag_q,
                                                COMP_STATUS_RUNTIME_ERROR,
                                                tx_word_parity_bad ? ERR_MEM_PARITY : ERR_MEM_INVALID,
                                                recv_count_q);
                                if (tx_word_parity_bad) begin
                                    src_parity_errors_q <= sat_inc16(src_parity_errors_q);
                                    update_mem_error(tx_index, 1'b0, 1'b1, tx_src_bank, ERR_KIND_PARITY_DMA_SRC);
                                end else begin
                                    update_mem_error(tx_index, 1'b0, 1'b1, tx_src_bank, ERR_KIND_RETENTION_INVALID_RD);
                                end
                                dma_error_monitor <= 1'b1;
                                irq_status_q[1] <= 1'b1;
                                last_err_code_q <= tx_word_parity_bad ? ERR_MEM_PARITY : ERR_MEM_INVALID;
                                active_valid_q <= 1'b0;
                                active_src_base_q <= '0;
                                active_dst_base_q <= '0;
                                active_len_words_q <= '0;
                                active_tag_q <= '0;
                                send_count_q <= '0;
                                recv_count_q <= '0;
                                timeout_q <= '0;
                                state_q <= DMA_IDLE;
                            end else begin
                                comp_full_stall_q <= 1'b1;
                                state_q <= DMA_RETIRE_STALL;
                                retire_tag_q <= active_tag_q;
                                retire_status_q <= COMP_STATUS_RUNTIME_ERROR;
                                retire_err_code_q <= tx_word_parity_bad ? ERR_MEM_PARITY : ERR_MEM_INVALID;
                                retire_words_q <= recv_count_q;
                            end
                        end else begin
                            if (state_q != DMA_RETIRE_STALL) begin
                                if (rx_fire) begin
                                    timeout_q <= '0;
                                end else if (timeout_q != TIMEOUT_WIDTH'(DMA_TIMEOUT_CYCLES)) begin
                                    timeout_q <= timeout_q + TIMEOUT_WIDTH'(1);
                                end
                            end

                            if ((state_q != DMA_RETIRE_STALL) && (timeout_q == TIMEOUT_WIDTH'(DMA_TIMEOUT_CYCLES))) begin
                                if (!comp_full) begin
                                    push_completion(active_tag_q, COMP_STATUS_RUNTIME_ERROR, ERR_TIMEOUT, recv_count_q);
                                    dma_error_monitor <= 1'b1;
                                    irq_status_q[1] <= 1'b1;
                                    last_err_code_q <= ERR_TIMEOUT;
                                    active_valid_q <= 1'b0;
                                    active_src_base_q <= '0;
                                    active_dst_base_q <= '0;
                                    active_len_words_q <= '0;
                                    active_tag_q <= '0;
                                    send_count_q <= '0;
                                    recv_count_q <= '0;
                                    timeout_q <= '0;
                                    state_q <= DMA_IDLE;
                                end else begin
                                    comp_full_stall_q <= 1'b1;
                                    state_q <= DMA_RETIRE_STALL;
                                    retire_tag_q <= active_tag_q;
                                    retire_status_q <= COMP_STATUS_RUNTIME_ERROR;
                                    retire_err_code_q <= ERR_TIMEOUT;
                                    retire_words_q <= recv_count_q;
                                end
                            end else begin
                                case (state_q)
                                    DMA_LAUNCH: state_q <= DMA_SEND;
                                    DMA_SEND: begin
                                        if (tx_fire) begin
                                            send_count_q <= next_send_count;
                                            if (next_send_count >= active_len_words_q) begin
                                                state_q <= DMA_WAIT_RETURN;
                                            end
                                        end
                                        if (rx_fire) begin
                                            logic dst_bank;
                                            logic [BANK_ROW_W-1:0] dst_row;
                                            logic [7:0] dst_addr;
                                            dst_addr = active_dst_base_q + recv_count_q[7:0];
                                            dst_bank = dst_addr[0];
                                            dst_row = dst_addr[7:1];
                                            write_mem_word(1'b1, dst_bank, dst_row, rx_stream_data);
                                            dst_invalid_bank_mask_q[dst_bank] <= 1'b0;
`ifdef UCIE_BUG_DMA_DONE_EARLY
                                            if ((active_len_words_q > 1) &&
                                                (next_recv_count == (active_len_words_q - 9'd1))) begin
`else
                                            if (next_recv_count >= active_len_words_q) begin
`endif
                                                if (!comp_full) begin
                                                    push_completion(active_tag_q, COMP_STATUS_SUCCESS, ERR_NONE, next_recv_count);
                                                    dma_done_monitor <= 1'b1;
                                                    irq_status_q[0] <= 1'b1;
                                                    last_err_code_q <= ERR_NONE;
                                                    active_valid_q <= 1'b0;
                                                    active_src_base_q <= '0;
                                                    active_dst_base_q <= '0;
                                                    active_len_words_q <= '0;
                                                    active_tag_q <= '0;
                                                    send_count_q <= '0;
                                                    recv_count_q <= '0;
                                                    timeout_q <= '0;
                                                    state_q <= DMA_IDLE;
                                                end else begin
                                                    recv_count_q <= next_recv_count;
                                                    comp_full_stall_q <= 1'b1;
                                                    state_q <= DMA_RETIRE_STALL;
                                                    retire_tag_q <= active_tag_q;
                                                    retire_status_q <= COMP_STATUS_SUCCESS;
                                                    retire_err_code_q <= ERR_NONE;
                                                    retire_words_q <= next_recv_count;
                                                end
                                            end else begin
                                                recv_count_q <= next_recv_count;
                                            end
                                        end
                                    end
                                    DMA_WAIT_RETURN: begin
                                        if (rx_fire) begin
                                            logic dst_bank;
                                            logic [BANK_ROW_W-1:0] dst_row;
                                            logic [7:0] dst_addr;
                                            dst_addr = active_dst_base_q + recv_count_q[7:0];
                                            dst_bank = dst_addr[0];
                                            dst_row = dst_addr[7:1];
                                            write_mem_word(1'b1, dst_bank, dst_row, rx_stream_data);
                                            dst_invalid_bank_mask_q[dst_bank] <= 1'b0;
`ifdef UCIE_BUG_DMA_DONE_EARLY
                                            if ((active_len_words_q > 1) &&
                                                (next_recv_count == (active_len_words_q - 9'd1))) begin
`else
                                            if (next_recv_count >= active_len_words_q) begin
`endif
                                                if (!comp_full) begin
                                                    push_completion(active_tag_q, COMP_STATUS_SUCCESS, ERR_NONE, next_recv_count);
                                                    dma_done_monitor <= 1'b1;
                                                    irq_status_q[0] <= 1'b1;
                                                    last_err_code_q <= ERR_NONE;
                                                    active_valid_q <= 1'b0;
                                                    active_src_base_q <= '0;
                                                    active_dst_base_q <= '0;
                                                    active_len_words_q <= '0;
                                                    active_tag_q <= '0;
                                                    send_count_q <= '0;
                                                    recv_count_q <= '0;
                                                    timeout_q <= '0;
                                                    state_q <= DMA_IDLE;
                                                end else begin
                                                    recv_count_q <= next_recv_count;
                                                    comp_full_stall_q <= 1'b1;
                                                    state_q <= DMA_RETIRE_STALL;
                                                    retire_tag_q <= active_tag_q;
                                                    retire_status_q <= COMP_STATUS_SUCCESS;
                                                    retire_err_code_q <= ERR_NONE;
                                                    retire_words_q <= next_recv_count;
                                                end
                                            end else begin
                                                recv_count_q <= next_recv_count;
                                            end
                                        end
                                    end
                                    DMA_RETIRE_STALL: begin
                                        if (!comp_full) begin
                                            push_completion(retire_tag_q, retire_status_q, retire_err_code_q, retire_words_q);
                                            if (retire_status_q == COMP_STATUS_SUCCESS) begin
                                                dma_done_monitor <= 1'b1;
                                                irq_status_q[0] <= 1'b1;
                                                last_err_code_q <= ERR_NONE;
                                            end else begin
                                                dma_error_monitor <= 1'b1;
                                                irq_status_q[1] <= 1'b1;
                                                last_err_code_q <= retire_err_code_q;
                                            end
                                            active_valid_q <= 1'b0;
                                            active_src_base_q <= '0;
                                            active_dst_base_q <= '0;
                                            active_len_words_q <= '0;
                                            active_tag_q <= '0;
                                            send_count_q <= '0;
                                            recv_count_q <= '0;
                                            timeout_q <= '0;
                                            state_q <= DMA_IDLE;
                                            comp_full_stall_q <= 1'b0;
                                            retire_tag_q <= '0;
                                            retire_status_q <= COMP_STATUS_RSVD;
                                            retire_err_code_q <= ERR_NONE;
                                            retire_words_q <= '0;
                                        end
                                    end
                                    default: begin end
                                endcase
                            end
                        end
                    end

                    if (!active_valid_q && can_progress_dma && !comp_full_stall_q && !submit_empty) begin
                        active_valid_q <= 1'b1;
                        active_src_base_q <= submit_src_base_q[submit_head_q];
                        active_dst_base_q <= submit_dst_base_q[submit_head_q];
                        active_len_words_q <= submit_len_words_q[submit_head_q];
                        active_tag_q <= submit_tag_q[submit_head_q];
                        send_count_q <= '0;
                        recv_count_q <= '0;
                        timeout_q <= '0;
                        state_q <= DMA_LAUNCH;
                        submit_head_q <= submit_head_next;
                        submit_count_q <= submit_count_q - COUNT_WIDTH'(1);
                    end
                end
            end
        end
    end

endmodule : dma_offload_ctrl
