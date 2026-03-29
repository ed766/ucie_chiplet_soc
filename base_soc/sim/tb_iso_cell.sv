`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_iso_cell;
  logic iso_n; logic [3:0] in,out;
  iso_cell #(.WIDTH(4)) dut(.iso_n(iso_n), .in(in), .out(out));
  initial begin
    iso_n=1; in=4'hA; #1; `ASSERT_PROP(out==in, "Pass-through when iso_n=1");
    iso_n=0; in=4'hF; #1; `ASSERT_PROP(out==4'h0, "Clamped when iso_n=0");
    $display("tb_iso_cell PASS"); $finish;
  end
endmodule
