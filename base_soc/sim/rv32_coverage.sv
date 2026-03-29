module rv32_coverage(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        commit_valid,
  input  logic [31:0] commit_instr,
  input  logic        wb_valid,
  input  logic [4:0]  wb_rd,
  input  logic        mem_valid,
  input  logic        mem_write,
  input  logic        branch_taken,
  output int unsigned sample_count
);
  import rv32_tb_pkg::*;

  integer add_hits;
  integer sub_hits;
  integer addi_hits;
  integer beq_hits;
  integer lw_hits;
  integer sw_hits;
  integer ebreak_hits;
  integer unknown_hits;
  integer rs1_low_hits;
  integer rs1_mid_hits;
  integer rs1_high_hits;
  integer rd_low_hits;
  integer rd_mid_hits;
  integer rd_high_hits;
  integer branch_taken_hits;
  integer branch_not_taken_hits;
  integer mem_read_hits;
  integer mem_write_hits;

`ifdef RV32_ENABLE_COVERGROUPS
  covergroup rv32_cg with function sample(
    rv32_op_e op,
    logic [4:0] rs1,
    logic [4:0] rd,
    logic branch_taken_local
  );
    option.per_instance = 1;
    cp_op: coverpoint op {
      bins add    = {RV32_OP_ADD};
      bins sub    = {RV32_OP_SUB};
      bins addi   = {RV32_OP_ADDI};
      bins beq    = {RV32_OP_BEQ};
      bins lw     = {RV32_OP_LW};
      bins sw     = {RV32_OP_SW};
      bins ebreak = {RV32_OP_EBREAK};
      bins other  = {RV32_OP_UNKNOWN};
    }
    cp_rs1: coverpoint rs1 {
      bins low  = {[0:7]};
      bins mid  = {[8:15]};
      bins high = {[16:31]};
    }
    cp_rd: coverpoint rd {
      bins x0   = {0};
      bins low  = {[1:7]};
      bins mid  = {[8:15]};
      bins high = {[16:31]};
    }
    cp_branch: coverpoint branch_taken_local iff (op == RV32_OP_BEQ) {
      bins taken = {1'b1};
      bins not_taken = {1'b0};
    }
  endgroup

  rv32_cg cg = new();
`endif

  task automatic write_report(input string path);
    integer fd;
    begin
      fd = $fopen(path, "w");
      if (fd == 0) begin
        $display("[COV] Failed to open report file %s", path);
        return;
      end
      $fdisplay(fd, "metric,value");
      $fdisplay(fd, "sample_count,%0d", sample_count);
      $fdisplay(fd, "add_hits,%0d", add_hits);
      $fdisplay(fd, "sub_hits,%0d", sub_hits);
      $fdisplay(fd, "addi_hits,%0d", addi_hits);
      $fdisplay(fd, "beq_hits,%0d", beq_hits);
      $fdisplay(fd, "lw_hits,%0d", lw_hits);
      $fdisplay(fd, "sw_hits,%0d", sw_hits);
      $fdisplay(fd, "ebreak_hits,%0d", ebreak_hits);
      $fdisplay(fd, "unknown_hits,%0d", unknown_hits);
      $fdisplay(fd, "rs1_low_hits,%0d", rs1_low_hits);
      $fdisplay(fd, "rs1_mid_hits,%0d", rs1_mid_hits);
      $fdisplay(fd, "rs1_high_hits,%0d", rs1_high_hits);
      $fdisplay(fd, "rd_low_hits,%0d", rd_low_hits);
      $fdisplay(fd, "rd_mid_hits,%0d", rd_mid_hits);
      $fdisplay(fd, "rd_high_hits,%0d", rd_high_hits);
      $fdisplay(fd, "branch_taken_hits,%0d", branch_taken_hits);
      $fdisplay(fd, "branch_not_taken_hits,%0d", branch_not_taken_hits);
      $fdisplay(fd, "mem_read_hits,%0d", mem_read_hits);
      $fdisplay(fd, "mem_write_hits,%0d", mem_write_hits);
`ifdef RV32_ENABLE_COVERGROUPS
      $fdisplay(fd, "covergroup_percent,%0.2f", cg.get_inst_coverage());
`endif
      $fclose(fd);
    end
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    rv32_op_e op;
    logic [4:0] rs1;
    if (!rst_n) begin
      sample_count          <= 0;
      add_hits              <= 0;
      sub_hits              <= 0;
      addi_hits             <= 0;
      beq_hits              <= 0;
      lw_hits               <= 0;
      sw_hits               <= 0;
      ebreak_hits           <= 0;
      unknown_hits          <= 0;
      rs1_low_hits          <= 0;
      rs1_mid_hits          <= 0;
      rs1_high_hits         <= 0;
      rd_low_hits           <= 0;
      rd_mid_hits           <= 0;
      rd_high_hits          <= 0;
      branch_taken_hits     <= 0;
      branch_not_taken_hits <= 0;
      mem_read_hits         <= 0;
      mem_write_hits        <= 0;
    end else if (commit_valid) begin
      sample_count <= sample_count + 1;
      op = rv32_decode_op(commit_instr);
      rs1 = rv32_rs1(commit_instr);

      case (op)
        RV32_OP_ADD:    add_hits    <= add_hits + 1;
        RV32_OP_SUB:    sub_hits    <= sub_hits + 1;
        RV32_OP_ADDI:   addi_hits   <= addi_hits + 1;
        RV32_OP_BEQ:    beq_hits    <= beq_hits + 1;
        RV32_OP_LW:     lw_hits     <= lw_hits + 1;
        RV32_OP_SW:     sw_hits     <= sw_hits + 1;
        RV32_OP_EBREAK: ebreak_hits <= ebreak_hits + 1;
        default:        unknown_hits <= unknown_hits + 1;
      endcase

      if (rs1 <= 5'd7) begin
        rs1_low_hits <= rs1_low_hits + 1;
      end else if (rs1 <= 5'd15) begin
        rs1_mid_hits <= rs1_mid_hits + 1;
      end else begin
        rs1_high_hits <= rs1_high_hits + 1;
      end

      if (wb_valid) begin
        if (wb_rd <= 5'd7) begin
          rd_low_hits <= rd_low_hits + 1;
        end else if (wb_rd <= 5'd15) begin
          rd_mid_hits <= rd_mid_hits + 1;
        end else begin
          rd_high_hits <= rd_high_hits + 1;
        end
      end

      if (op == RV32_OP_BEQ) begin
        if (branch_taken) begin
          branch_taken_hits <= branch_taken_hits + 1;
        end else begin
          branch_not_taken_hits <= branch_not_taken_hits + 1;
        end
      end

      if (mem_valid && !mem_write) begin
        mem_read_hits <= mem_read_hits + 1;
      end
      if (mem_valid && mem_write) begin
        mem_write_hits <= mem_write_hits + 1;
      end

`ifdef RV32_ENABLE_COVERGROUPS
      cg.sample(op, rs1, wb_rd, branch_taken);
`endif
    end
  end
endmodule
