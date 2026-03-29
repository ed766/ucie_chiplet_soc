`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_ret_ff;
  logic clk=0, rst_n=0; always #5 clk=~clk; initial begin rst_n=0; repeat(3) @(posedge clk); rst_n=1; end
  logic pwr_en, save, restore, d, we; logic q;
  ret_ff dut(.clk(clk), .rst_n(rst_n), .pwr_en(pwr_en), .save(save), .restore(restore), .d(d), .we(we), .q(q));
  initial begin
    pwr_en=1; save=0; restore=0; d=0; we=0; @(posedge rst_n);
    d=1; we=1; @(posedge clk); we=0; `ASSERT_PROP(q==1, "Captured 1");
    save=1; @(posedge clk); save=0; pwr_en=0; d=0; we=1; @(posedge clk); we=0; `ASSERT_PROP(q==1, "No write when power off");
    pwr_en=1; restore=1; @(posedge clk); restore=0; `ASSERT_PROP(q==1, "Restored 1");
    $display("tb_ret_ff PASS"); $finish;
  end
endmodule
