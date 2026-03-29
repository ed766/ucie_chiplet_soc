module rv32_assertions(
  input logic        clk,
  input logic        rst_n,
  input logic        instr_valid,
  input logic        instr_ready,
  input logic [31:0] instr,
  input logic        commit_valid,
  input logic [31:0] commit_instr,
  input logic [31:0] commit_pc,
  input logic [31:0] commit_next_pc,
  input logic        wb_valid,
  input logic [4:0]  wb_rd,
  input logic        mem_valid,
  input logic        branch_taken,
  input logic        illegal_instr
);
  import rv32_tb_pkg::*;

  logic accept_d1;
  logic accept_d2;
  logic hold_pending;
  logic [31:0] held_instr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      accept_d1    <= 1'b0;
      accept_d2    <= 1'b0;
      hold_pending <= 1'b0;
      held_instr   <= '0;
    end else begin
      if (accept_d2 && !commit_valid) begin
        $error("[ASSERT] Accepted instruction did not retire on schedule");
      end
      accept_d2 <= accept_d1;
      accept_d1 <= instr_valid && instr_ready;

      if (instr_valid && !instr_ready) begin
        if (hold_pending && (!instr_valid || (instr !== held_instr))) begin
          $error("[ASSERT] Driver changed valid/data while waiting for ready");
        end
        hold_pending <= 1'b1;
        held_instr <= instr;
      end else if (instr_ready) begin
        hold_pending <= 1'b0;
      end

      if (commit_valid && !branch_taken && !rv32_is_halt(commit_instr) && !illegal_instr &&
          (commit_next_pc != (commit_pc + 32'd4))) begin
        $error("[ASSERT] Non-branch instruction did not increment PC by four");
      end

      if (commit_valid && branch_taken &&
          (commit_next_pc != (commit_pc + rv32_imm_b(commit_instr)))) begin
        $error("[ASSERT] Taken branch target did not match decoded branch immediate");
      end

      if (wb_valid && (wb_rd == 5'd0)) begin
        $error("[ASSERT] Core reported a writeback to x0");
      end

      if (commit_valid && !rst_n) begin
        $error("[ASSERT] Commit observed during reset");
      end
      if (mem_valid && !rst_n) begin
        $error("[ASSERT] Memory side effect observed during reset");
      end
    end
  end
endmodule
