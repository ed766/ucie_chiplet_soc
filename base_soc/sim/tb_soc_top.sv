`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_soc_top;
  logic clk=0, clk_32k=0, rst_n=0; always #5 clk=~clk; always #15 clk_32k=~clk_32k;
  initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end
  // Top-level APB
  logic [31:0] paddr, pwdata, prdata; logic psel, penable, pwrite, pready, pslverr;
  soc_top dut(.clk(clk), .clk_32k(clk_32k), .rst_n(rst_n), .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr));

  task apb_write(input [31:0] addr, input [31:0] data);
    @(posedge clk); paddr<=addr; pwrite<=1; pwdata<=data; psel<=1; penable<=1; @(posedge clk); psel<=0; penable<=0; pwrite<=0; endtask
  task apb_read(input [31:0] addr, output [31:0] data);
    @(posedge clk); paddr<=addr; pwrite<=0; psel<=1; penable<=1; @(posedge clk); data=prdata; psel<=0; penable<=0; endtask

  initial begin
    // Watchdog: prevent indefinite hang
    #5_000_000 $fatal(1, "tb_soc_top timeout");
  end

  initial begin
    logic [31:0] st;
    psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
    @(posedge rst_n);
    // RUN -> SLEEP (via control), then wake to RUN via timer IRQ
    apb_write(32'h0000_0000, 32'h1); // force_sleep
    // Program timer for quick wake
    apb_write(32'h0000_0100, 32'd3); // reload small
    apb_write(32'h0000_0108, 32'd1); // enable
    // Wait some slow cycles for IRQ and wake
    repeat(10) @(posedge clk_32k);
    // Read status: expect RUN
    apb_read(32'h0000_0004, st);
    `ASSERT_PROP(st[1:0]==2'd0, "PST back to RUN via timer wake");
    // Program AES key, start block
    apb_write(32'h0000_0200, 32'hCAFEBABE);
    apb_write(32'h0000_0210, 32'hDEADBEEF);
    apb_write(32'h0000_0230, 32'h1);
    repeat(50) @(posedge clk);
    $display("tb_soc_top PASS"); $finish;
  end
endmodule
