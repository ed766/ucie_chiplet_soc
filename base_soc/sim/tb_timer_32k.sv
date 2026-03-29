`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_timer_32k;
  logic clk=0, rst_n=0;
  always #15 clk = ~clk;

  initial begin
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
  end

  // APB
  logic [11:0] paddr;
  logic psel, penable, pwrite;
  logic [31:0] pwdata, prdata;
  logic pready, pslverr;
  logic irq;

  timer_32k dut(
    .clk_32k(clk), .rst_n(rst_n),
    .paddr(paddr), .psel(psel), .penable(penable), .pwrite(pwrite),
    .pwdata(pwdata), .prdata(prdata), .pready(pready), .pslverr(pslverr),
    .irq(irq)
  );

  // --- APB two-phase tasks (SETUP -> ACCESS, wait PREADY) ---
  task automatic apb_write(input [11:0] addr, input [31:0] data);
    int wr_wait;
    // SETUP
    @(posedge clk);
    paddr  <= addr;
    pwdata <= data;
    pwrite <= 1;
    psel   <= 1;
    penable<= 0;
    // ACCESS
    @(posedge clk);
    penable<= 1;
    // Wait for completion (PSEL&PENABLE&PREADY) with timeout
    wr_wait = 0;
    while (!pready) begin
      @(posedge clk);
      wr_wait++;
      if (wr_wait > 1000) $fatal(1, "APB write timeout at addr 0x%0h", addr);
    end
    // TEARDOWN
    psel   <= 0;
    penable<= 0;
    pwrite <= 0;
  endtask

  task automatic apb_read(input [11:0] addr, output [31:0] data);
    int rd_wait;
    // SETUP
    @(posedge clk);
    paddr  <= addr;
    pwrite <= 0;
    psel   <= 1;
    penable<= 0;
    // ACCESS
    @(posedge clk);
    penable<= 1;
    // Wait for completion, sample PRDATA when PREADY (with timeout)
    rd_wait = 0;
    while (!pready) begin
      @(posedge clk);
      rd_wait++;
      if (rd_wait > 1000) $fatal(1, "APB read timeout at addr 0x%0h", addr);
    end
    data = prdata;
    // TEARDOWN
    psel   <= 0;
    penable<= 0;
  endtask

  // --- Watchdog so a bad handshake can’t wedge the job ---
  initial begin
    // 1 ms @ 1 ns units -> plenty for this TB
    #1_000_000 $fatal(1, "tb_timer_32k timeout");
  end

  initial begin
    int irqs = 0;
    // init bus
    psel=0; penable=0; pwrite=0; paddr='0; pwdata='0;
    @(posedge rst_n);
    // smaller reload for faster test; seed value for immediate countdown
    apb_write(12'h100, 32'd5);   // reload
    apb_write(12'h104, 32'd5);   // value
    apb_write(12'h108, 32'd1);   // enable
    repeat (64) begin
      @(posedge clk);
      if (irq) irqs++;
    end
    `ASSERT_PROP(irqs>0, "Timer IRQs seen");
    $display("tb_timer_32k PASS");
    $finish;
  end
endmodule
