module rv32_generator;
  import rv32_tb_pkg::*;

  integer      directed_count;
  integer      random_count;
  logic [31:0] directed_program [0:RV32_MAX_PROGRAM_LEN-1];
  logic [31:0] random_program   [0:RV32_MAX_PROGRAM_LEN-1];

  function automatic int unsigned next_rand(ref int unsigned seed);
    seed = rv32_lcg_advance(seed);
    next_rand = seed;
  endfunction

  function automatic int unsigned next_range(
    ref int unsigned seed,
    input int unsigned low,
    input int unsigned high
  );
    int unsigned span;
    begin
      span = (high - low) + 1;
      next_range = low + (next_rand(seed) % span);
    end
  endfunction

  function automatic logic [4:0] next_reg_idx(
    ref int unsigned seed,
    input int unsigned low,
    input int unsigned high
  );
    int unsigned reg_idx;
    begin
      reg_idx = next_range(seed, low, high);
      next_reg_idx = reg_idx[4:0];
    end
  endfunction

  function automatic logic signed [11:0] next_simm12(ref int unsigned seed);
    integer raw;
    begin
      raw = next_range(seed, 0, 63);
      raw = raw - 32;
      next_simm12 = raw[11:0];
    end
  endfunction

  function automatic logic signed [11:0] next_word_offset(ref int unsigned seed);
    int unsigned word_idx;
    int unsigned byte_offset;
    begin
      word_idx = next_range(seed, 0, 7);
      byte_offset = word_idx << 2;
      next_word_offset = byte_offset[11:0];
    end
  endfunction

  function automatic logic signed [12:0] next_branch_imm(ref int unsigned seed);
    int unsigned branch_sel;
    begin
      branch_sel = next_range(seed, 0, 3);
      case (branch_sel)
        0: next_branch_imm = 13'sd8;
        1: next_branch_imm = 13'sd12;
        2: next_branch_imm = -13'sd8;
        default: next_branch_imm = -13'sd12;
      endcase
    end
  endfunction

  task automatic clear_programs();
    integer idx;
    begin
      for (idx = 0; idx < RV32_MAX_PROGRAM_LEN; idx = idx + 1) begin
        directed_program[idx] = rv32_nop();
        random_program[idx] = rv32_nop();
      end
    end
  endtask

  task automatic build_programs(
    input int unsigned seed_in,
    input integer requested_instrs
  );
    int unsigned seed;
    integer idx;
    int unsigned choice;
    logic [4:0] last_rd;
    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic signed [11:0] imm12;
    logic signed [12:0] branch_imm;
    logic signed [11:0] last_store_addr;
    begin
      clear_programs();

      directed_count = 0;
      directed_program[directed_count] = rv32_addi(5'd1, 5'd0, 12'sd10); directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_addi(5'd2, 5'd0, 12'sd3);  directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_add(5'd3, 5'd1, 5'd2);     directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_sub(5'd4, 5'd3, 5'd2);     directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_sw(5'd0, 5'd4, 12'sd0);    directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_lw(5'd5, 5'd0, 12'sd0);    directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_beq(5'd5, 5'd4, 13'sd8);   directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_beq(5'd1, 5'd2, 13'sd8);   directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_addi(5'd6, 5'd5, 12'sd1);  directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_sw(5'd0, 5'd6, 12'sd4);    directed_count = directed_count + 1;
      directed_program[directed_count] = rv32_lw(5'd7, 5'd0, 12'sd4);    directed_count = directed_count + 1;

      seed = seed_in;
      random_count = 0;
      last_rd = 5'd8;
      last_store_addr = 12'sd0;
      random_program[random_count] = rv32_addi(5'd7, 5'd0, 12'sd21); random_count = random_count + 1;
      random_program[random_count] = rv32_addi(5'd8, 5'd0, 12'sd4);  random_count = random_count + 1;

      for (idx = 0; (idx < requested_instrs) && (random_count < RV32_MAX_PROGRAM_LEN-1); idx = idx + 1) begin
        choice = next_range(seed, 0, 99);

        if (choice < 25) begin
          rd = next_reg_idx(seed, 1, 15);
          if (next_range(seed, 0, 99) < 65) begin
            rs1 = last_rd;
          end else begin
            rs1 = next_reg_idx(seed, 0, 15);
          end
          imm12 = next_simm12(seed);
          random_program[random_count] = rv32_addi(rd, rs1, imm12);
          last_rd = rd;
        end else if (choice < 50) begin
          rd = next_reg_idx(seed, 1, 15);
          rs1 = last_rd;
          if (next_range(seed, 0, 99) < 70) begin
            rs2 = last_rd;
          end else begin
            rs2 = next_reg_idx(seed, 0, 15);
          end
          if (next_range(seed, 0, 99) < 50) begin
            random_program[random_count] = rv32_add(rd, rs1, rs2);
          end else begin
            random_program[random_count] = rv32_sub(rd, rs1, rs2);
          end
          last_rd = rd;
        end else if (choice < 65) begin
          if (next_range(seed, 0, 99) < 70) begin
            rs2 = last_rd;
          end else begin
            rs2 = next_reg_idx(seed, 1, 15);
          end
          last_store_addr = next_word_offset(seed);
          random_program[random_count] = rv32_sw(5'd0, rs2, last_store_addr);
        end else if (choice < 80) begin
          rd = next_reg_idx(seed, 1, 15);
          if (next_range(seed, 0, 99) < 70) begin
            imm12 = last_store_addr;
          end else begin
            imm12 = next_word_offset(seed);
          end
          random_program[random_count] = rv32_lw(rd, 5'd0, imm12);
          last_rd = rd;
        end else if (choice < 95) begin
          rs1 = last_rd;
          if (next_range(seed, 0, 99) < 50) begin
            rs2 = last_rd;
          end else begin
            rs2 = next_reg_idx(seed, 0, 15);
            if (rs2 == last_rd) begin
              rs2 = 5'd0;
            end
          end
          branch_imm = next_branch_imm(seed);
          random_program[random_count] = rv32_beq(rs1, rs2, branch_imm);
        end else begin
          random_program[random_count] = rv32_nop();
        end

        random_count = random_count + 1;
      end

      random_program[random_count] = rv32_ebreak();
      random_count = random_count + 1;
    end
  endtask
endmodule
