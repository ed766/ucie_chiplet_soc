// Crypto chiplet that aggregates 64-bit words into AES-128 blocks and encrypts them.
// Role: forms blocks, runs AES, and queues ciphertext for the return path.
module die_b_system #(
    parameter int DATA_WIDTH = 64
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] plaintext_data,
    input  logic                  plaintext_valid,
    output logic                  plaintext_ready,
    output logic [DATA_WIDTH-1:0] ciphertext_data,
    output logic                  ciphertext_valid,
    input  logic                  ciphertext_ready,
    output logic                  aon_power_good
);

    localparam int BLOCK_WIDTH   = 128;
    localparam int WORDS_PER_BLOCK = BLOCK_WIDTH / DATA_WIDTH;
    localparam logic [127:0] AES_KEY = 128'h00112233445566778899aabbccddeeff;
    localparam int CIPHER_FIFO_DEPTH = 32;
    localparam int CIPHER_FIFO_PTR_WIDTH = $clog2(CIPHER_FIFO_DEPTH);
    localparam int CIPHER_FIFO_COUNT_WIDTH = CIPHER_FIFO_PTR_WIDTH + 1;
    localparam int CIPHER_FIFO_THRESHOLD = CIPHER_FIFO_DEPTH - WORDS_PER_BLOCK;

`ifndef SYNTHESIS
`ifndef YOSYS
    initial begin
        if (BLOCK_WIDTH % DATA_WIDTH != 0) begin
            $error("DATA_WIDTH (%0d) must divide %0d for AES aggregation", DATA_WIDTH, BLOCK_WIDTH);
        end
    end
`endif
`endif

    // Buffer for assembling a 128-bit AES block from incoming words.
    logic [BLOCK_WIDTH-1:0] block_buffer_q;
    logic [$clog2(WORDS_PER_BLOCK+1)-1:0] word_count_q;
    logic block_pending_q;

    // AES engine control and output block.
    logic aes_ready;
    logic aes_done;
    logic [BLOCK_WIDTH-1:0] aes_cipher_block;
    logic aes_start;

    // FIFO of ciphertext words for the return path.
    logic [DATA_WIDTH-1:0] cipher_fifo_mem [0:CIPHER_FIFO_DEPTH-1];
    logic [CIPHER_FIFO_PTR_WIDTH-1:0] cipher_fifo_head_q;
    logic [CIPHER_FIFO_PTR_WIDTH-1:0] cipher_fifo_tail_q;
    logic [CIPHER_FIFO_COUNT_WIDTH-1:0] cipher_fifo_count_q;

    assign aon_power_good  = 1'b1;
    assign plaintext_ready = (!block_pending_q) && (int'(cipher_fifo_count_q) <= CIPHER_FIFO_THRESHOLD);
    assign ciphertext_valid = (cipher_fifo_count_q != '0);
    assign ciphertext_data  = ciphertext_valid ? cipher_fifo_mem[cipher_fifo_head_q] : '0;
    assign aes_start        = block_pending_q && aes_ready;

    aes128_iterative u_aes (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (aes_start),
        .key      (AES_KEY),
        .block_in (block_buffer_q),
        .ready    (aes_ready),
        .done     (aes_done),
        .block_out(aes_cipher_block)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_buffer_q <= '0;
            word_count_q   <= '0;
            block_pending_q<= 1'b0;
            cipher_fifo_head_q <= '0;
            cipher_fifo_tail_q <= '0;
            cipher_fifo_count_q<= '0;
            for (int idx = 0; idx < CIPHER_FIFO_DEPTH; idx++) begin
                cipher_fifo_mem[idx] <= '0;
            end
        end else begin
            int push_count;
            int pop_count;
            int fifo_count_int;
            int head_int;
            int tail_int;
            int new_count;

            push_count = 0;
            pop_count  = 0;
            fifo_count_int = int'(cipher_fifo_count_q);
            head_int = int'(cipher_fifo_head_q);
            tail_int = int'(cipher_fifo_tail_q);

            // Phase 1: accept plaintext words and build AES blocks.
            if (plaintext_valid && plaintext_ready) begin
                block_buffer_q[DATA_WIDTH*word_count_q +: DATA_WIDTH] <= plaintext_data;
                if (int'(word_count_q) == (WORDS_PER_BLOCK-1)) begin
                    word_count_q    <= '0;
                    block_pending_q <= 1'b1;
                end else begin
                    word_count_q <= word_count_q + 1'b1;
                end
            end

            if (block_pending_q && aes_start) begin
                block_pending_q <= 1'b0;
            end

            // Phase 2: drain ciphertext FIFO when the return path is ready.
            if (ciphertext_ready && ciphertext_valid) begin
                pop_count = 1;
                head_int = head_int + pop_count;
                if (head_int >= CIPHER_FIFO_DEPTH) begin
                    head_int -= CIPHER_FIFO_DEPTH;
                end
            end

            // Phase 3: push ciphertext words into FIFO when AES completes.
            if (aes_done) begin
                push_count = WORDS_PER_BLOCK;
                if ((fifo_count_int + push_count) > CIPHER_FIFO_DEPTH) begin
                    push_count = 0;
                end else begin
                    for (int i = 0; i < WORDS_PER_BLOCK; i++) begin
                        int insert_index;
                        insert_index = tail_int + i;
                        if (insert_index >= CIPHER_FIFO_DEPTH) begin
                            insert_index -= CIPHER_FIFO_DEPTH;
                        end
                        cipher_fifo_mem[insert_index] <= aes_cipher_block[DATA_WIDTH*i +: DATA_WIDTH];
                    end
                    tail_int = tail_int + push_count;
                    if (tail_int >= CIPHER_FIFO_DEPTH) begin
                        tail_int -= CIPHER_FIFO_DEPTH;
                    end
                end
            end

            if (push_count != 0 || pop_count != 0) begin
                new_count = fifo_count_int + push_count - pop_count;
                if (new_count < 0) begin
                    new_count = 0;
                end else if (new_count > CIPHER_FIFO_DEPTH) begin
                    new_count = CIPHER_FIFO_DEPTH;
                end
                cipher_fifo_count_q <= new_count[CIPHER_FIFO_COUNT_WIDTH-1:0];
            end

            cipher_fifo_head_q <= head_int[CIPHER_FIFO_PTR_WIDTH-1:0];
            cipher_fifo_tail_q <= tail_int[CIPHER_FIFO_PTR_WIDTH-1:0];
        end
    end

endmodule : die_b_system
