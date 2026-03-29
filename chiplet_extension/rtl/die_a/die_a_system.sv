// Compute chiplet model that generates plaintext and validates returned ciphertext with AES-128.
// Role: produces traffic and keeps an expected-cipher FIFO for scoreboarding.
module die_a_system #(
    parameter int DATA_WIDTH = 64
) (
    input  logic                  clk,
    input  logic                  rst_n,
    output logic [DATA_WIDTH-1:0] tx_stream_data,
    output logic                  tx_stream_valid,
    input  logic                  tx_stream_ready,
    input  logic [DATA_WIDTH-1:0] rx_stream_data,
    input  logic                  rx_stream_valid,
    output logic                  rx_stream_ready,
    output logic                  aon_power_good,
    output logic                  crypto_error
);

    localparam int BLOCK_WIDTH     = 128;
    localparam int WORDS_PER_BLOCK = BLOCK_WIDTH / DATA_WIDTH;
    localparam logic [127:0] AES_KEY = 128'h00112233445566778899aabbccddeeff;
    localparam int EXPECT_FIFO_DEPTH = 32;
    localparam int EXPECT_FIFO_PTR_WIDTH = $clog2(EXPECT_FIFO_DEPTH);
    localparam int EXPECT_FIFO_COUNT_WIDTH = EXPECT_FIFO_PTR_WIDTH + 1;

`ifndef SYNTHESIS
`ifndef YOSYS
    initial begin
        if (BLOCK_WIDTH % DATA_WIDTH != 0) begin
            $error("DATA_WIDTH (%0d) must divide %0d for AES aggregation", DATA_WIDTH, BLOCK_WIDTH);
        end
    end
`endif
`endif

    // Monotonic plaintext generator.
    logic [DATA_WIDTH-1:0] counter_q;
    logic                  error_flag_q;

    // Buffer for assembling a 128-bit AES block from 64-bit words.
    logic [BLOCK_WIDTH-1:0] sb_block_buffer_q;
    logic [$clog2(WORDS_PER_BLOCK+1)-1:0] sb_word_count_q;
    logic sb_block_pending_q;

    // AES mirror used to compute expected ciphertext.
    logic sb_aes_ready;
    logic sb_aes_done;
    logic [BLOCK_WIDTH-1:0] sb_cipher_block;
    logic sb_aes_start;

    // FIFO of expected ciphertext words for scoreboarding.
    logic [DATA_WIDTH-1:0] expected_fifo_mem [0:EXPECT_FIFO_DEPTH-1];
    logic [EXPECT_FIFO_PTR_WIDTH-1:0] expected_fifo_head_q;
    logic [EXPECT_FIFO_PTR_WIDTH-1:0] expected_fifo_tail_q;
    logic [EXPECT_FIFO_COUNT_WIDTH-1:0] expected_fifo_count_q;

    assign aon_power_good  = 1'b1;
    assign tx_stream_data  = counter_q;
    assign tx_stream_valid = !sb_block_pending_q;
    assign rx_stream_ready = 1'b1;
    assign crypto_error    = error_flag_q;
    assign sb_aes_start    = sb_block_pending_q && sb_aes_ready;

    aes128_iterative u_aes_ref (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (sb_aes_start),
        .key      (AES_KEY),
        .block_in (sb_block_buffer_q),
        .ready    (sb_aes_ready),
        .done     (sb_aes_done),
        .block_out(sb_cipher_block)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_q        <= '0;
            error_flag_q     <= 1'b0;
            sb_block_buffer_q<= '0;
            sb_word_count_q  <= '0;
            sb_block_pending_q <= 1'b0;
            expected_fifo_head_q <= '0;
            expected_fifo_tail_q <= '0;
            expected_fifo_count_q<= '0;
            for (int idx = 0; idx < EXPECT_FIFO_DEPTH; idx++) begin
                expected_fifo_mem[idx] <= '0;
            end
        end else begin
            logic accept_word;
            int push_count;
            int pop_count;
            int fifo_count_int;
            int head_int;
            int tail_int;
            int new_count;

            // Phase 1: accept new plaintext words and build AES blocks.
            accept_word = tx_stream_valid && tx_stream_ready;
            push_count = 0;
            pop_count  = 0;
            fifo_count_int = int'(expected_fifo_count_q);
            head_int = int'(expected_fifo_head_q);
            tail_int = int'(expected_fifo_tail_q);

            if (accept_word) begin
                sb_block_buffer_q[DATA_WIDTH*sb_word_count_q +: DATA_WIDTH] <= counter_q;
                if (int'(sb_word_count_q) == (WORDS_PER_BLOCK-1)) begin
                    sb_word_count_q   <= '0;
                    sb_block_pending_q<= 1'b1;
                end else begin
                    sb_word_count_q <= sb_word_count_q + 1'b1;
                end
                counter_q <= counter_q + 1'b1;
            end

            if (sb_block_pending_q && sb_aes_start) begin
                sb_block_pending_q <= 1'b0;
            end

            // Phase 2: push expected ciphertext into FIFO when AES completes.
            if (sb_aes_done) begin
                push_count = WORDS_PER_BLOCK;
                if ((fifo_count_int + push_count) > EXPECT_FIFO_DEPTH) begin
                    error_flag_q <= 1'b1;
                    push_count = 0;
                end else begin
                    for (int i = 0; i < WORDS_PER_BLOCK; i++) begin
                        int insert_index;
                        insert_index = tail_int + i;
                        if (insert_index >= EXPECT_FIFO_DEPTH) begin
                            insert_index -= EXPECT_FIFO_DEPTH;
                        end
                        expected_fifo_mem[insert_index] <= sb_cipher_block[DATA_WIDTH*i +: DATA_WIDTH];
                    end
                    tail_int = tail_int + push_count;
                    if (tail_int >= EXPECT_FIFO_DEPTH) begin
                        tail_int -= EXPECT_FIFO_DEPTH;
                    end
                end
            end

            // Phase 3: compare returned ciphertext against expected FIFO.
            if (rx_stream_valid && rx_stream_ready) begin
                if (fifo_count_int == 0) begin
                    error_flag_q <= 1'b1;
                end else begin
                    logic [DATA_WIDTH-1:0] expected_value;
                    expected_value = expected_fifo_mem[head_int];
                    if (rx_stream_data !== expected_value) begin
                        error_flag_q <= 1'b1;
                    end
                    pop_count = 1;
                    head_int = head_int + pop_count;
                    if (head_int >= EXPECT_FIFO_DEPTH) begin
                        head_int -= EXPECT_FIFO_DEPTH;
                    end
                end
            end

            if (push_count != 0 || pop_count != 0) begin
                new_count = fifo_count_int + push_count - pop_count;
                if (new_count < 0) begin
                    new_count = 0;
                end else if (new_count > EXPECT_FIFO_DEPTH) begin
                    new_count = EXPECT_FIFO_DEPTH;
                end
                expected_fifo_count_q <= new_count[EXPECT_FIFO_COUNT_WIDTH-1:0];
            end

            expected_fifo_head_q <= head_int[EXPECT_FIFO_PTR_WIDTH-1:0];
            expected_fifo_tail_q <= tail_int[EXPECT_FIFO_PTR_WIDTH-1:0];
        end
    end

endmodule : die_a_system
