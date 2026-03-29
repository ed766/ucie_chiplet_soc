`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_power_switch;
  logic en; logic [7:0] in, out;
  power_switch #(.WIDTH(8)) dut(.en(en), .in(in), .out(out));
  initial begin
    en=1; in=8'hA5; #1; `ASSERT_PROP(out==in, "Pass-through when enabled");
    en=0; in=8'h3C; #1; `ASSERT_PROP(^out===1'bx || out!==out, "X when disabled");
    $display("tb_power_switch PASS"); $finish;
  end
endmodule
