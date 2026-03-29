`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_aes128_iterative;
  logic clk=0, rst_n=0; always #5 clk=~clk; initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end
  logic start, ready, done; logic [127:0] key, din, dout;
  aes128_iterative dut(.clk(clk), .rst_n(rst_n), .start(start), .key(key), .block_in(din), .ready(ready), .done(done), .block_out(dout));
  initial begin
    start=0; key=128'h0123456789ABCDEF_FEDCBA9876543210; din=128'h0011223344556677_8899AABBCCDDEEFF;
    @(posedge rst_n); @(posedge clk);
    `ASSERT_PROP(ready==1, "Ready idle");
    start=1; @(posedge clk); start=0;
    wait(done==1); @(posedge clk);
    `ASSERT_PROP(ready==1, "Ready after done");
    `ASSERT_PROP(dout!=din, "Output changed (placeholder AES)");
    $display("tb_aes128_iterative PASS"); $finish;
  end
endmodule
