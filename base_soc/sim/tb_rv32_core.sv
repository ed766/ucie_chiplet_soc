`timescale 1ns/1ps

module tb_rv32_core;
  import rv32_tb_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  rv32_core_if rvif(clk);

  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  logic            mon_valid;
  rv32_trace_txn_t mon_txn;
  int unsigned     accepted_count;
  int unsigned     compared_count;
  int unsigned     mismatch_count;
  int unsigned     sample_count;
  int unsigned     seed;
  integer          requested_random;
  integer          idx;
  string           wave_file;

  rv32_driver drv(
    .clk(clk),
    .rst_n(rvif.rst_n),
    .instr_ready(rvif.instr_ready),
    .instr_valid(rvif.instr_valid),
    .instr(rvif.instr)
  );
  rv32_generator gen();
  rv32_monitor mon(
    .clk(clk),
    .rst_n(rvif.rst_n),
    .commit_valid(rvif.commit_valid),
    .commit_instr(rvif.commit_instr),
    .commit_pc(rvif.commit_pc),
    .commit_next_pc(rvif.commit_next_pc),
    .wb_valid(rvif.wb_valid),
    .wb_rd(rvif.wb_rd),
    .wb_data(rvif.wb_data),
    .mem_valid(rvif.mem_valid),
    .mem_write(rvif.mem_write),
    .mem_addr(rvif.mem_addr),
    .mem_wdata(rvif.mem_wdata),
    .mem_rdata(rvif.mem_rdata),
    .branch_taken(rvif.branch_taken),
    .illegal_instr(rvif.illegal_instr),
    .halted(rvif.halted),
    .txn_valid(mon_valid),
    .txn(mon_txn)
  );
  rv32_scoreboard sb(
    .clk(clk),
    .rst_n(rvif.rst_n),
    .instr_valid(rvif.instr_valid),
    .instr_ready(rvif.instr_ready),
    .instr(rvif.instr),
    .actual_valid(mon_valid),
    .actual_txn(mon_txn),
    .accepted_count(accepted_count),
    .compared_count(compared_count),
    .mismatch_count(mismatch_count)
  );
  rv32_assertions asrt(
    .clk(clk),
    .rst_n(rvif.rst_n),
    .instr_valid(rvif.instr_valid),
    .instr_ready(rvif.instr_ready),
    .instr(rvif.instr),
    .commit_valid(rvif.commit_valid),
    .commit_instr(rvif.commit_instr),
    .commit_pc(rvif.commit_pc),
    .commit_next_pc(rvif.commit_next_pc),
    .wb_valid(rvif.wb_valid),
    .wb_rd(rvif.wb_rd),
    .mem_valid(rvif.mem_valid),
    .branch_taken(rvif.branch_taken),
    .illegal_instr(rvif.illegal_instr)
  );
  rv32_coverage cov(
    .clk(clk),
    .rst_n(rvif.rst_n),
    .commit_valid(rvif.commit_valid),
    .commit_instr(rvif.commit_instr),
    .wb_valid(rvif.wb_valid),
    .wb_rd(rvif.wb_rd),
    .mem_valid(rvif.mem_valid),
    .mem_write(rvif.mem_write),
    .branch_taken(rvif.branch_taken),
    .sample_count(sample_count)
  );

  assign prdata = 32'h0;
  assign pready = 1'b1;
  assign pslverr = 1'b0;

  rv32_core dut (
    .clk         (clk),
    .rst_n       (rvif.rst_n),
    .instr_valid (rvif.instr_valid),
    .instr_ready (rvif.instr_ready),
    .instr       (rvif.instr),
    .paddr       (paddr),
    .psel        (psel),
    .penable     (penable),
    .pwrite      (pwrite),
    .pwdata      (pwdata),
    .prdata      (prdata),
    .pready      (pready),
    .pslverr     (pslverr),
    .commit_valid(rvif.commit_valid),
    .commit_instr(rvif.commit_instr),
    .commit_pc   (rvif.commit_pc),
    .commit_next_pc(rvif.commit_next_pc),
    .wb_valid    (rvif.wb_valid),
    .wb_rd       (rvif.wb_rd),
    .wb_data     (rvif.wb_data),
    .mem_valid   (rvif.mem_valid),
    .mem_write   (rvif.mem_write),
    .mem_addr    (rvif.mem_addr),
    .mem_wdata   (rvif.mem_wdata),
    .mem_rdata   (rvif.mem_rdata),
    .branch_taken(rvif.branch_taken),
    .illegal_instr(rvif.illegal_instr),
    .retire      (rvif.retire),
    .halted      (rvif.halted)
  );

  task automatic wait_for_halt();
    begin
      while (!rvif.halted) begin
        @(posedge clk);
      end
      repeat (4) @(posedge clk);
    end
  endtask

  initial begin
    if ($test$plusargs("WAVES")) begin
      if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
        wave_file = "rv32_core_wave.fst";
      end
      $dumpfile(wave_file);
      $dumpvars(0, tb_rv32_core);
    end
  end

  initial begin
    rvif.rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rvif.rst_n = 1'b1;
  end

  initial begin
    #2_000_000;
    $fatal(1, "tb_rv32_core timeout");
  end

  initial begin
    if (!$value$plusargs("SEED=%d", seed)) begin
      seed = 32'h5EED_CAFE;
    end
    if (!$value$plusargs("RAND_COUNT=%d", requested_random)) begin
      requested_random = 48;
    end

    gen.build_programs(seed, requested_random);

    @(posedge rvif.rst_n);
    for (idx = 0; idx < gen.directed_count; idx = idx + 1) begin
      drv.send_instruction(gen.directed_program[idx]);
    end
    for (idx = 0; idx < gen.random_count; idx = idx + 1) begin
      drv.send_instruction(gen.random_program[idx]);
    end

    wait_for_halt();

    sb.write_report("rv32_scoreboard.csv");
    cov.write_report("rv32_coverage.csv");

    if (accepted_count != compared_count) begin
      $fatal(1, "Not all accepted instructions were checked: accepted=%0d compared=%0d", accepted_count, compared_count);
    end
    if (mismatch_count != 0) begin
      $fatal(1, "Scoreboard mismatches observed: %0d", mismatch_count);
    end
    if (sample_count != compared_count) begin
      $fatal(1, "Coverage samples do not match retired instructions: samples=%0d compared=%0d", sample_count, compared_count);
    end

    $display("tb_rv32_core PASS seed=0x%08x accepted=%0d compared=%0d coverage_samples=%0d",
             seed, accepted_count, compared_count, sample_count);
    $finish;
  end
endmodule
