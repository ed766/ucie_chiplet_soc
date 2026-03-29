`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_icache_opt;
  logic clk=0, rst_n=0; always #5 clk=~clk; initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end
  logic [31:0] addr; logic req; logic [127:0] line; logic hit;
  icache_opt dut(.clk(clk), .rst_n(rst_n), .addr(addr), .req(req), .line(line), .hit(hit));
  initial begin
    req=0; addr=32'h1000; @(posedge rst_n);
    @(posedge clk); req=1; @(posedge clk); req=0; `ASSERT_PROP(hit==0, "First miss");
    @(posedge clk); req=1; @(posedge clk); req=0; `ASSERT_PROP(hit==1, "Second hit");
    $display("tb_icache_opt PASS"); $finish;
  end
endmodule
