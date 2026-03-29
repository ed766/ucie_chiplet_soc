`timescale 1ns/1ps
`include "sva_macros.svh"
module tb_apb_bridge;
  logic clk=0, rst_n=0;
  always #5 clk = ~clk;
  initial begin rst_n=0; repeat(5) @(posedge clk); rst_n=1; end

  // DUT
  logic [31:0] m_paddr, m_pwdata, m_prdata; logic m_psel, m_penable, m_pwrite, m_pready, m_pslverr;
  logic s0_psel,s0_penable,s0_pwrite; logic [11:0] s0_paddr; logic [31:0] s0_pwdata, s0_prdata; logic s0_pready,s0_pslverr;
  logic s1_psel,s1_penable,s1_pwrite; logic [11:0] s1_paddr; logic [31:0] s1_pwdata, s1_prdata; logic s1_pready,s1_pslverr;
  logic s2_psel,s2_penable,s2_pwrite; logic [11:0] s2_paddr; logic [31:0] s2_pwdata, s2_prdata; logic s2_pready,s2_pslverr;

  apb_bridge dut(
    .clk(clk), .rst_n(rst_n),
    .m_paddr(m_paddr), .m_psel(m_psel), .m_penable(m_penable), .m_pwrite(m_pwrite), .m_pwdata(m_pwdata), .m_prdata(m_prdata), .m_pready(m_pready), .m_pslverr(m_pslverr),
    .s0_psel(s0_psel), .s0_penable(s0_penable), .s0_pwrite(s0_pwrite), .s0_paddr(s0_paddr), .s0_pwdata(s0_pwdata), .s0_prdata(s0_prdata), .s0_pready(s0_pready), .s0_pslverr(s0_pslverr),
    .s1_psel(s1_psel), .s1_penable(s1_penable), .s1_pwrite(s1_pwrite), .s1_paddr(s1_paddr), .s1_pwdata(s1_pwdata), .s1_prdata(s1_prdata), .s1_pready(s1_pready), .s1_pslverr(s1_pslverr),
    .s2_psel(s2_psel), .s2_penable(s2_penable), .s2_pwrite(s2_pwrite), .s2_paddr(s2_paddr), .s2_pwdata(s2_pwdata), .s2_prdata(s2_prdata), .s2_pready(s2_pready), .s2_pslverr(s2_pslverr)
  );
  // Simple slaves: ready=1, prdata=address code
  assign s0_pready=1; assign s1_pready=1; assign s2_pready=1;
  assign s0_pslverr=0; assign s1_pslverr=0; assign s2_pslverr=0;
  assign s0_prdata=32'hAAAA0000 | {20'b0,s0_paddr};
  assign s1_prdata=32'hBBBB0000 | {20'b0,s1_paddr};
  assign s2_prdata=32'hCCCC0000 | {20'b0,s2_paddr};

  task apb_read(input [31:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      m_paddr<=addr; m_pwrite<=0; m_pwdata<=32'h0; m_psel<=1; m_penable<=1;
      @(posedge clk);
      data = m_prdata;
      m_psel<=0; m_penable<=0;
    end
  endtask

  initial begin
    logic [31:0] d;
    m_psel=0; m_penable=0; m_pwrite=0; m_paddr=0; m_pwdata=0;
    @(posedge rst_n);
    #1;
    apb_read(32'h00000004, d); `ASSERT_PROP(d[31:28]==4'hA, "S0 decode");
    apb_read(32'h00000104, d); `ASSERT_PROP(d[31:28]==4'hB, "S1 decode");
    apb_read(32'h00000210, d); `ASSERT_PROP(d[31:28]==4'hC, "S2 decode");
    apb_read(32'h00000400, d); `ASSERT_PROP(m_pslverr==1'b1, "Unmapped error");
    $display("tb_apb_bridge PASS");
    $finish;
  end
endmodule
