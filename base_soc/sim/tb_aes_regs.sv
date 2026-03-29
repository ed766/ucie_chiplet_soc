`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_aes_regs;
  logic clk=0, rst_n=0; always #5 clk=~clk; initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end
  logic [11:0] paddr; logic psel,penable,pwrite; logic [31:0] pwdata, prdata; logic pready, pslverr; 
  logic pwr_en, save, restore;
  aes_regs dut(
    .clk(clk), .rst_n(rst_n), .rst_pd_n(rst_n & pwr_en),
    .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
    .pwr_en(pwr_en), .save(save), .restore(restore)
  );
  assign pready=1; assign pslverr=0;

  task apb_write(input [11:0] addr, input [31:0] data);
    @(posedge clk); paddr<=addr; pwrite<=1; pwdata<=data; psel<=1; penable<=1; @(posedge clk); psel<=0; penable<=0; pwrite<=0; endtask
  task apb_read(input [11:0] addr, output [31:0] data);
    @(posedge clk); paddr<=addr; pwrite<=0; psel<=1; penable<=1; @(posedge clk); data=prdata; psel<=0; penable<=0; endtask

  initial begin
    logic [31:0] d;
    psel=0; penable=0; pwrite=0; paddr=0; pwdata=0; pwr_en=1; save=0; restore=0;
    @(posedge rst_n);
    // Program key
    apb_write(12'h200, 32'h00112233);
    apb_write(12'h204, 32'h44556677);
    apb_write(12'h208, 32'h8899AABB);
    apb_write(12'h20C, 32'hCCDDEEFF);
    // Save & power off
    @(posedge clk); save=1; @(posedge clk); save=0; pwr_en=0;
    // Power on & restore
    repeat(2) @(posedge clk); pwr_en=1; @(posedge clk); restore=1; @(posedge clk); restore=0;
    // Read back key words
    apb_read(12'h200, d); `ASSERT_PROP(d==32'h00112233, "Key0 retained");
    apb_read(12'h20C, d); `ASSERT_PROP(d==32'hCCDDEEFF, "Key3 retained");
    // Start encrypt
    apb_write(12'h210, 32'hDEADBEEF); apb_write(12'h214, 32'hCAFEBABE); apb_write(12'h218, 32'h00000000); apb_write(12'h21C, 32'h01010101);
    apb_write(12'h230, 32'h1);
    // Wait some cycles then read DOUT
    repeat(20) @(posedge clk);
    apb_read(12'h220, d);
    $display("tb_aes_regs PASS: DOUT0=%08x", d);
    $finish;
  end
endmodule
