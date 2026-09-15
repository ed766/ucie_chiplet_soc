`timescale 1ns/1ps
module tb_rv32_muldiv;
  logic clk = 0;
  logic rst_n = 0;
  logic req_valid;
  logic req_ready;
  logic [2:0] req_op;
  logic [31:0] req_lhs, req_rhs;
  logic rsp_valid, rsp_ready;
  logic [31:0] rsp_result;

  always #5 clk = ~clk;

  rv32_muldiv dut (.*);

  function automatic logic [31:0] reference_result(
    input logic [2:0] op,input logic [31:0] lhs,input logic [31:0] rhs
  );
    logic signed [63:0] signed_product;
    logic [63:0] unsigned_product;
    logic signed [31:0] signed_lhs, signed_rhs;
    begin
      signed_lhs = lhs;signed_rhs = rhs;
      signed_product = signed_lhs * signed_rhs;
      unsigned_product = lhs * rhs;
      unique case(op)
        0: reference_result=unsigned_product[31:0];
        1: reference_result=signed_product[63:32];
        2: begin signed_product=signed_lhs * $signed({1'b0,rhs});reference_result=signed_product[63:32];end
        3: reference_result=unsigned_product[63:32];
        4: reference_result=$unsigned(signed_lhs/signed_rhs);
        5: reference_result=lhs/rhs;
        6: reference_result=$unsigned(signed_lhs%signed_rhs);
        7: reference_result=lhs%rhs;
      endcase
    end
  endfunction

  task automatic check_case(
    input string name,
    input logic [2:0] op,
    input logic [31:0] lhs,
    input logic [31:0] rhs,
    input logic [31:0] expected,
    input int hold_cycles = 0
  );
    int latency;
    logic [31:0] held_result;
    begin
      while (!req_ready) @(posedge clk);
      @(negedge clk);
      req_op = op;
      req_lhs = lhs;
      req_rhs = rhs;
      req_valid = 1;
      @(posedge clk);
      @(negedge clk);
      req_valid = 0;
      latency = 0;
      while (!rsp_valid && latency <= 36) begin
        @(posedge clk);
        latency++;
      end
      if (!rsp_valid) $fatal(1, "%s exceeded bounded completion", name);
      if (rsp_result !== expected)
        $fatal(1, "%s got %08x expected %08x", name, rsp_result, expected);
      held_result = rsp_result;
      repeat (hold_cycles) begin
        @(posedge clk);
        if (!rsp_valid || rsp_result !== held_result)
          $fatal(1, "%s response changed under backpressure", name);
      end
      @(negedge clk);
      rsp_ready = 1;
      @(posedge clk);
      @(negedge clk);
      rsp_ready = 0;
      $display("RV32M_TEST|%s|PASS|%0d", name, latency);
    end
  endtask

  initial begin
    req_valid = 0;
    req_op = 0;
    req_lhs = 0;
    req_rhs = 0;
    rsp_ready = 0;
    repeat (3) @(posedge clk);
    rst_n = 1;

    check_case("mul_basic", 0, 3, 7, 21);
    check_case("mul_low_wrap", 0, 32'hffff_ffff, 2, 32'hffff_fffe);
    check_case("mul_zero", 0, 0, 32'hdeadc0de, 0);
    check_case("mulh_signed", 1, 32'h8000_0000, 2, 32'hffff_ffff);
    check_case("mulh_positive", 1, 32'h7fff_ffff, 2, 0);
    check_case("mulhsu_mixed", 2, 32'hffff_fffe, 32'hffff_ffff, 32'hffff_fffe);
    check_case("mulhsu_positive", 2, 2, 32'hffff_ffff, 1);
    check_case("mulhu_max", 3, 32'hffff_ffff, 32'hffff_ffff, 32'hffff_fffe);
    check_case("div_signed", 4, -32'd7, 3, 32'hffff_fffe);
    check_case("div_signed_signs", 4, 7, -32'd3, 32'hffff_fffe);
    check_case("div_by_zero", 4, 7, 0, 32'hffff_ffff);
    check_case("div_overflow", 4, 32'h8000_0000, 32'hffff_ffff, 32'h8000_0000);
    check_case("divu_basic", 5, 7, 3, 2);
    check_case("divu_high", 5, 32'hffff_ffff, 2, 32'h7fff_ffff);
    check_case("divu_by_zero", 5, 7, 0, 32'hffff_ffff);
    check_case("rem_signed", 6, -32'd7, 3, 32'hffff_ffff);
    check_case("rem_signed_divisor", 6, 7, -32'd3, 1);
    check_case("rem_by_zero", 6, 32'h8123_4567, 0, 32'h8123_4567);
    check_case("rem_overflow", 6, 32'h8000_0000, 32'hffff_ffff, 0);
    check_case("remu_basic", 7, 7, 3, 1);
    check_case("remu_high", 7, 32'hffff_ffff, 16, 15);
    check_case("remu_by_zero", 7, 32'h8123_4567, 0, 32'h8123_4567);
    check_case("response_backpressure", 0, 9, 9, 81, 3);

    for (integer op=0;op<8;op++) begin
      check_case($sformatf("coverage_%0d_zero",op),op,0,3,reference_result(op,0,3));
      $display("RV32M_COVER|%0d|zero",op);
      check_case($sformatf("coverage_%0d_one",op),op,1,1,reference_result(op,1,1));
      $display("RV32M_COVER|%0d|one",op);
      check_case($sformatf("coverage_%0d_all_ones",op),op,32'hffff_ffff,3,reference_result(op,32'hffff_ffff,3));
      $display("RV32M_COVER|%0d|all_ones",op);
      check_case($sformatf("coverage_%0d_signed_min",op),op,32'h8000_0000,2,reference_result(op,32'h8000_0000,2));
      $display("RV32M_COVER|%0d|signed_min",op);
      check_case($sformatf("coverage_%0d_power_two",op),op,8,4,reference_result(op,8,4));
      $display("RV32M_COVER|%0d|power_two",op);
      check_case($sformatf("coverage_%0d_other",op),op,32'h1234_5678,37,reference_result(op,32'h1234_5678,37));
      $display("RV32M_COVER|%0d|other",op);
    end

    while (!req_ready) @(posedge clk);
    @(negedge clk);
    req_valid = 1;
    req_op = 5;
    req_lhs = 100;
    req_rhs = 9;
    @(posedge clk);
    @(negedge clk);
    req_valid = 0;
    repeat (5) @(posedge clk);
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (40) begin
      @(posedge clk);
      if (rsp_valid) $fatal(1, "reset produced stale response");
    end
    $display("RV32M_TEST|reset_cancellation|PASS|5");
    $display("RV32M_SUMMARY|72|72|PASS");
    $finish;
  end
  initial begin repeat(10000)@(posedge clk);$fatal(1,"RV32M unit timeout");end
endmodule
