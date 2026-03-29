module rv32_scoreboard(
  input  logic                         clk,
  input  logic                         rst_n,
  input  logic                         instr_valid,
  input  logic                         instr_ready,
  input  logic [31:0]                  instr,
  input  logic                         actual_valid,
  input  rv32_tb_pkg::rv32_trace_txn_t actual_txn,
  output int unsigned                  accepted_count,
  output int unsigned                  compared_count,
  output int unsigned                  mismatch_count
);
  import rv32_tb_pkg::*;

  logic [31:0] model_regs [0:31];
  logic [31:0] model_mem  [0:RV32_DATA_MEM_WORDS-1];
  logic [31:0] model_pc;
  logic        model_halted;

  rv32_trace_txn_t expected_fifo [0:RV32_MAX_PROGRAM_LEN-1];
  integer head_q;
  integer tail_q;
  integer depth_q;
  integer branch_count;
  integer load_count;
  integer store_count;
  integer illegal_count;

  function automatic logic txn_match(
    input rv32_trace_txn_t expected_txn,
    input rv32_trace_txn_t observed_txn
  );
    txn_match =
      (expected_txn.instr         === observed_txn.instr) &&
      (expected_txn.pc            === observed_txn.pc) &&
      (expected_txn.next_pc       === observed_txn.next_pc) &&
      (expected_txn.wb_valid      === observed_txn.wb_valid) &&
      (expected_txn.wb_rd         === observed_txn.wb_rd) &&
      (expected_txn.wb_data       === observed_txn.wb_data) &&
      (expected_txn.mem_valid     === observed_txn.mem_valid) &&
      (expected_txn.mem_write     === observed_txn.mem_write) &&
      (expected_txn.mem_addr      === observed_txn.mem_addr) &&
      (expected_txn.mem_wdata     === observed_txn.mem_wdata) &&
      (expected_txn.mem_rdata     === observed_txn.mem_rdata) &&
      (expected_txn.branch_taken  === observed_txn.branch_taken) &&
      (expected_txn.illegal_instr === observed_txn.illegal_instr) &&
      (expected_txn.halted        === observed_txn.halted);
  endfunction

  task automatic reset_model();
    integer idx;
    begin
      model_pc = '0;
      model_halted = 1'b0;
      for (idx = 0; idx < 32; idx = idx + 1) begin
        model_regs[idx] = '0;
      end
      for (idx = 0; idx < RV32_DATA_MEM_WORDS; idx = idx + 1) begin
        model_mem[idx] = '0;
      end
    end
  endtask

  task automatic predict_instruction(
    input  logic [31:0] instr_word,
    output rv32_trace_txn_t txn
  );
    logic [31:0] rs1_val;
    logic [31:0] rs2_val;
    logic [31:0] result;
    logic [31:0] addr;
    logic [31:0] next_pc;
    integer      mem_idx;
    rv32_op_e    op;
    begin
      txn = '0;
      txn.instr = instr_word;
      txn.pc = model_pc;

      rs1_val = model_regs[rv32_rs1(instr_word)];
      rs2_val = model_regs[rv32_rs2(instr_word)];
      result = '0;
      addr = '0;
      next_pc = model_pc + 32'd4;
      mem_idx = 0;
      op = rv32_decode_op(instr_word);

      case (op)
        RV32_OP_ADD: begin
          result = rs1_val + rs2_val;
          if (rv32_rd(instr_word) != 5'd0) begin
            model_regs[rv32_rd(instr_word)] = result;
            txn.wb_valid = 1'b1;
            txn.wb_rd = rv32_rd(instr_word);
            txn.wb_data = result;
          end
        end
        RV32_OP_SUB: begin
          result = rs1_val - rs2_val;
          if (rv32_rd(instr_word) != 5'd0) begin
            model_regs[rv32_rd(instr_word)] = result;
            txn.wb_valid = 1'b1;
            txn.wb_rd = rv32_rd(instr_word);
            txn.wb_data = result;
          end
        end
        RV32_OP_ADDI: begin
          result = rs1_val + rv32_imm_i(instr_word);
          if (rv32_rd(instr_word) != 5'd0) begin
            model_regs[rv32_rd(instr_word)] = result;
            txn.wb_valid = 1'b1;
            txn.wb_rd = rv32_rd(instr_word);
            txn.wb_data = result;
          end
        end
        RV32_OP_BEQ: begin
          txn.branch_taken = (rs1_val == rs2_val);
          if (txn.branch_taken) begin
            next_pc = model_pc + rv32_imm_b(instr_word);
          end
        end
        RV32_OP_LW: begin
          addr = rs1_val + rv32_imm_i(instr_word);
          mem_idx = (addr >> 2) % RV32_DATA_MEM_WORDS;
          txn.mem_valid = 1'b1;
          txn.mem_addr = addr;
          txn.mem_rdata = model_mem[mem_idx];
          if (rv32_rd(instr_word) != 5'd0) begin
            model_regs[rv32_rd(instr_word)] = model_mem[mem_idx];
            txn.wb_valid = 1'b1;
            txn.wb_rd = rv32_rd(instr_word);
            txn.wb_data = model_mem[mem_idx];
          end
        end
        RV32_OP_SW: begin
          addr = rs1_val + rv32_imm_s(instr_word);
          mem_idx = (addr >> 2) % RV32_DATA_MEM_WORDS;
          model_mem[mem_idx] = rs2_val;
          txn.mem_valid = 1'b1;
          txn.mem_write = 1'b1;
          txn.mem_addr = addr;
          txn.mem_wdata = rs2_val;
        end
        RV32_OP_EBREAK: begin
          model_halted = 1'b1;
        end
        default: begin
          txn.illegal_instr = 1'b1;
        end
      endcase

      model_regs[0] = '0;
      model_pc = next_pc;
      txn.next_pc = next_pc;
      txn.halted = model_halted;
    end
  endtask

  task automatic write_report(input string path);
    integer fd;
    begin
      fd = $fopen(path, "w");
      if (fd == 0) begin
        $display("[SB] Failed to open report file %s", path);
        return;
      end
      $fdisplay(fd, "metric,value");
      $fdisplay(fd, "accepted_count,%0d", accepted_count);
      $fdisplay(fd, "compared_count,%0d", compared_count);
      $fdisplay(fd, "mismatch_count,%0d", mismatch_count);
      $fdisplay(fd, "branch_count,%0d", branch_count);
      $fdisplay(fd, "load_count,%0d", load_count);
      $fdisplay(fd, "store_count,%0d", store_count);
      $fdisplay(fd, "illegal_count,%0d", illegal_count);
      $fclose(fd);
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    rv32_trace_txn_t expected_txn;
    integer next_head_q;
    integer next_tail_q;
    integer next_depth_q;
    if (!rst_n) begin
      reset_model();
      accepted_count <= 0;
      compared_count <= 0;
      mismatch_count <= 0;
      branch_count   <= 0;
      load_count     <= 0;
      store_count    <= 0;
      illegal_count  <= 0;
      head_q         <= 0;
      tail_q         <= 0;
      depth_q        <= 0;
    end else begin
      next_head_q = head_q;
      next_tail_q = tail_q;
      next_depth_q = depth_q;

      if (actual_valid) begin
        compared_count <= compared_count + 1;
        if (next_depth_q == 0) begin
          mismatch_count <= mismatch_count + 1;
          $error("[SB] Observed commit with no expected transaction queued");
        end else begin
          expected_txn = expected_fifo[next_head_q];
          if (!txn_match(expected_txn, actual_txn)) begin
            mismatch_count <= mismatch_count + 1;
            $display("[SB] Mismatch exp_op=%s act_op=%s exp_pc=0x%08x act_pc=0x%08x exp_wb=0x%08x act_wb=0x%08x exp_next=0x%08x act_next=0x%08x",
                     rv32_op_name(rv32_decode_op(expected_txn.instr)),
                     rv32_op_name(rv32_decode_op(actual_txn.instr)),
                     expected_txn.pc,
                     actual_txn.pc,
                     expected_txn.wb_data,
                     actual_txn.wb_data,
                     expected_txn.next_pc,
                     actual_txn.next_pc);
          end
          next_head_q = (next_head_q + 1) % RV32_MAX_PROGRAM_LEN;
          next_depth_q = next_depth_q - 1;
        end
      end

      if (instr_valid && instr_ready) begin
        predict_instruction(instr, expected_txn);
        accepted_count <= accepted_count + 1;
        expected_fifo[next_tail_q] <= expected_txn;
        next_tail_q = (next_tail_q + 1) % RV32_MAX_PROGRAM_LEN;
        next_depth_q = next_depth_q + 1;

        case (rv32_decode_op(instr))
          RV32_OP_BEQ: branch_count <= branch_count + 1;
          RV32_OP_LW:  load_count   <= load_count + 1;
          RV32_OP_SW:  store_count  <= store_count + 1;
          RV32_OP_UNKNOWN: illegal_count <= illegal_count + 1;
          default: begin end
        endcase
      end

      head_q <= next_head_q;
      tail_q <= next_tail_q;
      depth_q <= next_depth_q;
    end
  end
endmodule
