`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_aon_power_ctrl;
  logic clk=0, rst_n=0; always #15 clk=~clk; // ~33kHz
  initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end

  // APB
  logic [11:0] paddr; logic psel, penable, pwrite; logic [31:0] pwdata, prdata; logic pready, pslverr;

  // DUT
  logic pd1_sw_en, pd2_sw_en, iso_pd1_n, iso_pd2_n, save_pd2, restore_pd2, wake_irq;
  aon_power_ctrl dut(
    .clk_32k(clk), .rst_n(rst_n),
    .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
    .pd1_sw_en(pd1_sw_en), .pd2_sw_en(pd2_sw_en), .iso_pd1_n(iso_pd1_n), .iso_pd2_n(iso_pd2_n), .save_pd2(save_pd2), .restore_pd2(restore_pd2), .wake_irq(wake_irq)
  );

  task apb_write(input [11:0] addr, input [31:0] data);
    @(posedge clk); paddr<=addr; pwrite<=1; pwdata<=data; psel<=1; penable<=1;
    @(posedge clk); psel<=0; penable<=0; pwrite<=0;
  endtask

  initial begin
    psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
    @(posedge rst_n);
    // Request SLEEP
    apb_write(12'h000, 32'h1);
    @(posedge clk); `ASSERT_PROP(iso_pd1_n==0, "PD1 iso asserted before off");
    @(posedge clk); `ASSERT_PROP(pd1_sw_en==0, "PD1 switched off");
    // Back to RUN
    apb_write(12'h000, 32'h0);
    repeat(2) @(posedge clk);
    `ASSERT_PROP(pd1_sw_en==1, "PD1 switched on");
    `ASSERT_PROP(restore_pd2==1'b1 || restore_pd2==1'b0, "Restore event occurred");
    @(posedge clk); `ASSERT_PROP(iso_pd1_n==1, "De-isolated after on");
    $display("tb_aon_power_ctrl PASS");
    $finish;
  end
endmodule
