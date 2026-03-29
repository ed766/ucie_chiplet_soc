`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_boot_rom;
  logic clk=0; always #5 clk=~clk; logic en=1; logic [31:0] addr, rdata;
  boot_rom #(.DEPTH_WORDS(16)) dut(.clk(clk), .en(en), .addr(addr), .rdata(rdata));
  initial begin
    addr=0; repeat(3) @(posedge clk);
    addr=32'd0; @(posedge clk); `ASSERT_PROP(rdata==32'h00000013, "ROM default word");
    addr=32'd4; @(posedge clk); `ASSERT_PROP(rdata==32'h00000013, "ROM next word");
    $display("tb_boot_rom PASS"); $finish;
  end
endmodule
