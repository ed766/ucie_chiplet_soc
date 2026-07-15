`timescale 1ns/1ps
module tb_async_chiplet;
    int a_half = 5;
    int b_half = 5;
    int reset_skew = 0;
    logic clk_a = 0, clk_b = 0, rst_a_n = 0, rst_b_n = 0;
    logic [31:0] cfg_rdata;
    logic cfg_ready, irq_done, a2b_overflow, b2a_overflow;
    logic a2b_underflow, b2a_underflow;
    logic [63:0] plain, cipher_a, cipher_b;
    int a2b_writes, a2b_reads, b2a_writes, b2a_reads;

    soc_chiplet_async_top dut (
        .clk_a(clk_a), .rst_a_n(rst_a_n), .clk_b(clk_b), .rst_b_n(rst_b_n),
        .power_state(2'd0), .dma_mode_force(1'b0), .cfg_valid(1'b0), .cfg_write(1'b0),
        .cfg_addr('0), .cfg_wdata('0), .cfg_rdata(cfg_rdata), .cfg_ready(cfg_ready),
        .irq_done(irq_done), .plaintext_monitor(plain), .ciphertext_monitor(cipher_a),
        .die_b_ciphertext_monitor(cipher_b), .a2b_overflow(a2b_overflow), .b2a_overflow(b2a_overflow),
        .a2b_underflow(a2b_underflow), .b2a_underflow(b2a_underflow)
    );

    initial begin
        void'($value$plusargs("A_HALF=%d", a_half));
        forever #(a_half) clk_a = ~clk_a;
    end
    initial begin
        void'($value$plusargs("B_HALF=%d", b_half));
        #1; // Keep unrelated clock edges out of the same active-region slot.
        forever #(b_half) clk_b = ~clk_b;
    end

    always @(posedge clk_a) begin
        if (rst_a_n) begin
            if (dut.u_a2b_fifo.w_valid && dut.u_a2b_fifo.w_ready) a2b_writes++;
            if (dut.u_b2a_fifo.r_valid) b2a_reads++;
            assert (!a2b_overflow) else $fatal(1, "A2B FIFO overflow");
            assert (!b2a_underflow) else $fatal(1, "B2A FIFO underflow");
        end
    end
    always @(posedge clk_b) begin
        if (rst_b_n) begin
            if (dut.u_a2b_fifo.r_valid) a2b_reads++;
            if (dut.u_b2a_fifo.w_valid && dut.u_b2a_fifo.w_ready) b2a_writes++;
            assert (!b2a_overflow) else $fatal(1, "B2A FIFO overflow");
            assert (!a2b_underflow) else $fatal(1, "A2B FIFO underflow");
        end
    end

    initial begin
        void'($value$plusargs("RESET_SKEW=%d", reset_skew));
        a2b_writes = 0; a2b_reads = 0; b2a_writes = 0; b2a_reads = 0;
        repeat (5) @(posedge clk_a);
        rst_a_n = 1;
        repeat (reset_skew) @(posedge clk_b);
        rst_b_n = 1;
        repeat (8000) @(posedge clk_a);
        assert (a2b_writes > 0 && a2b_reads > 0) else $fatal(1, "No A2B traffic");
        assert (b2a_writes > 0 && b2a_reads > 0) else $fatal(1, "No B2A traffic");
        assert (a2b_reads <= a2b_writes) else $fatal(1, "A2B duplication");
        assert (b2a_reads <= b2a_writes) else $fatal(1, "B2A duplication");
        $display("ASYNC_RESULT|status=PASS|a_half=%0d|b_half=%0d|reset_skew=%0d|a2b=%0d/%0d|b2a=%0d/%0d",
                 a_half, b_half, reset_skew, a2b_reads, a2b_writes, b2a_reads, b2a_writes);
        $finish;
    end
endmodule
