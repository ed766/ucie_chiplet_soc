module rv32_core #(
  parameter logic [31:0] MMIO_BASE = 32'h0000_0100,
  parameter logic [31:0] MMIO_END  = 32'h0000_01ff
) (
  input  logic        clk,
  input  logic        rst_n,
  // Lightweight instruction stream for verification
  input  logic        instr_valid,
  output logic        instr_ready,
  input  logic [31:0] instr,
  // Loads/stores in the MMIO window execute as APB transfers.
  output logic [31:0] paddr,
  output logic        psel,
  output logic        penable,
  output logic        pwrite,
  output logic [31:0] pwdata,
  input  logic [31:0] prdata,
  input  logic        pready,
  input  logic        pslverr,
  // Trace for the lightweight DV environment
  output logic        commit_valid,
  output logic [31:0] commit_instr,
  output logic [31:0] commit_pc,
  output logic [31:0] commit_next_pc,
  output logic        wb_valid,
  output logic [4:0]  wb_rd,
  output logic [31:0] wb_data,
  output logic        mem_valid,
  output logic        mem_write,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [31:0] mem_rdata,
  output logic        branch_taken,
  output logic        illegal_instr,
  output logic        bus_error,
  output logic        retire,
  output logic        halted
);

  localparam int DATA_MEM_WORDS = 64;

  typedef enum logic [3:0] {
    OP_UNKNOWN,
    OP_ADD,
    OP_SUB,
    OP_ADDI,
    OP_BEQ,
    OP_LW,
    OP_SW,
    OP_EBREAK
  } op_e;

  logic [31:0] regs_q [0:31];
  logic [31:0] data_mem_q [0:DATA_MEM_WORDS-1];
  logic [31:0] pc_q;
  logic        pending_valid_q;
  logic [31:0] pending_instr_q;
  logic [31:0] pending_pc_q;
  logic        mmio_pending_q;
  logic [31:0] mmio_addr_q;
  logic [31:0] mmio_wdata_q;
  logic [4:0]  mmio_rd_q;
  logic        mmio_write_q;
  integer      idx;

  function automatic logic [4:0] rs1_idx(input logic [31:0] instr_word);
    rs1_idx = instr_word[19:15];
  endfunction

  function automatic logic [4:0] rs2_idx(input logic [31:0] instr_word);
    rs2_idx = instr_word[24:20];
  endfunction

  function automatic logic [4:0] rd_idx(input logic [31:0] instr_word);
    rd_idx = instr_word[11:7];
  endfunction

  function automatic logic signed [31:0] imm_i(input logic [31:0] instr_word);
    imm_i = $signed({{20{instr_word[31]}}, instr_word[31:20]});
  endfunction

  function automatic logic signed [31:0] imm_s(input logic [31:0] instr_word);
    imm_s = $signed({{20{instr_word[31]}}, instr_word[31:25], instr_word[11:7]});
  endfunction

  function automatic logic signed [31:0] imm_b(input logic [31:0] instr_word);
    imm_b = $signed({{19{instr_word[31]}}, instr_word[31], instr_word[7],
                     instr_word[30:25], instr_word[11:8], 1'b0});
  endfunction

  function automatic op_e decode_op(input logic [31:0] instr_word);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    begin
      opcode = instr_word[6:0];
      funct3 = instr_word[14:12];
      funct7 = instr_word[31:25];
      decode_op = OP_UNKNOWN;
      unique case (opcode)
        7'b0110011: begin
          if ((funct3 == 3'b000) && (funct7 == 7'b0000000)) begin
            decode_op = OP_ADD;
          end else if ((funct3 == 3'b000) && (funct7 == 7'b0100000)) begin
            decode_op = OP_SUB;
          end
        end
        7'b0010011: begin
          if (funct3 == 3'b000) begin
            decode_op = OP_ADDI;
          end
        end
        7'b1100011: begin
          if (funct3 == 3'b000) begin
            decode_op = OP_BEQ;
          end
        end
        7'b0000011: begin
          if (funct3 == 3'b010) begin
            decode_op = OP_LW;
          end
        end
        7'b0100011: begin
          if (funct3 == 3'b010) begin
            decode_op = OP_SW;
          end
        end
        7'b1110011: begin
          if (instr_word == 32'h0010_0073) begin
            decode_op = OP_EBREAK;
          end
        end
        default: begin
          decode_op = OP_UNKNOWN;
        end
      endcase
    end
  endfunction

  assign instr_ready = rst_n && !halted && !pending_valid_q && !mmio_pending_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_q            <= '0;
      pending_valid_q <= 1'b0;
      pending_instr_q <= 32'h0000_0013;
      pending_pc_q    <= '0;
      mmio_pending_q  <= 1'b0;
      mmio_addr_q     <= '0;
      mmio_wdata_q    <= '0;
      mmio_rd_q       <= '0;
      mmio_write_q    <= 1'b0;
      commit_valid    <= 1'b0;
      commit_instr    <= 32'h0000_0013;
      commit_pc       <= '0;
      commit_next_pc  <= '0;
      wb_valid        <= 1'b0;
      wb_rd           <= '0;
      wb_data         <= '0;
      mem_valid       <= 1'b0;
      mem_write       <= 1'b0;
      mem_addr        <= '0;
      mem_wdata       <= '0;
      mem_rdata       <= '0;
      branch_taken    <= 1'b0;
      illegal_instr   <= 1'b0;
      bus_error       <= 1'b0;
      retire          <= 1'b0;
      halted          <= 1'b0;
      psel            <= 1'b0;
      penable         <= 1'b0;
      pwrite          <= 1'b0;
      paddr           <= '0;
      pwdata          <= '0;
      for (idx = 0; idx < 32; idx = idx + 1) begin
        regs_q[idx] <= '0;
      end
      for (idx = 0; idx < DATA_MEM_WORDS; idx = idx + 1) begin
        data_mem_q[idx] <= '0;
      end
    end else begin
      commit_valid  <= 1'b0;
      wb_valid      <= 1'b0;
      wb_rd         <= '0;
      wb_data       <= '0;
      mem_valid     <= 1'b0;
      mem_write     <= 1'b0;
      mem_addr      <= '0;
      mem_wdata     <= '0;
      mem_rdata     <= '0;
      branch_taken  <= 1'b0;
      illegal_instr <= 1'b0;
      bus_error     <= 1'b0;
      retire        <= 1'b0;
      psel          <= 1'b0;
      penable       <= 1'b0;
      pwrite        <= 1'b0;
      paddr         <= '0;
      pwdata        <= '0;

      if (mmio_pending_q) begin
        psel      <= 1'b1;
        pwrite    <= mmio_write_q;
        paddr     <= mmio_addr_q;
        pwdata    <= mmio_wdata_q;

        if (!penable) begin
          penable <= 1'b1;
        end else begin
          penable <= 1'b1;
          if (pready) begin
            commit_valid   <= 1'b1;
            commit_instr   <= pending_instr_q;
            commit_pc      <= pending_pc_q;
            commit_next_pc <= pending_pc_q + 32'd4;
            retire         <= 1'b1;
            mem_valid      <= 1'b1;
            mem_write      <= mmio_write_q;
            mem_addr       <= mmio_addr_q;
            mem_wdata      <= mmio_wdata_q;
            mem_rdata      <= prdata;
            bus_error      <= pslverr;
            if (!mmio_write_q && !pslverr && (mmio_rd_q != 5'd0)) begin
              wb_valid          <= 1'b1;
              wb_rd             <= mmio_rd_q;
              wb_data           <= prdata;
              regs_q[mmio_rd_q] <= prdata;
            end
            pc_q            <= pending_pc_q + 32'd4;
            regs_q[0]       <= '0;
            pending_valid_q <= 1'b0;
            mmio_pending_q  <= 1'b0;
            psel            <= 1'b0;
            penable         <= 1'b0;
          end
        end
      end else if (pending_valid_q) begin
        logic [31:0] rs1_val;
        logic [31:0] rs2_val;
        logic [31:0] result;
        logic [31:0] next_pc;
        logic [31:0] addr;
        int unsigned mem_idx;
        op_e op;
        logic defer_retire;

        rs1_val = regs_q[rs1_idx(pending_instr_q)];
        rs2_val = regs_q[rs2_idx(pending_instr_q)];
        result  = '0;
        next_pc = pending_pc_q + 32'd4;
        addr    = '0;
        mem_idx = '0;
        op      = decode_op(pending_instr_q);
        defer_retire = 1'b0;

        case (op)
          OP_ADD: begin
            result = rs1_val + rs2_val;
            if (rd_idx(pending_instr_q) != 5'd0) begin
              wb_valid <= 1'b1;
              wb_rd    <= rd_idx(pending_instr_q);
              wb_data  <= result;
              regs_q[rd_idx(pending_instr_q)] <= result;
            end
          end
          OP_SUB: begin
            result = rs1_val - rs2_val;
            if (rd_idx(pending_instr_q) != 5'd0) begin
              wb_valid <= 1'b1;
              wb_rd    <= rd_idx(pending_instr_q);
              wb_data  <= result;
              regs_q[rd_idx(pending_instr_q)] <= result;
            end
          end
          OP_ADDI: begin
            result = rs1_val + imm_i(pending_instr_q);
            if (rd_idx(pending_instr_q) != 5'd0) begin
              wb_valid <= 1'b1;
              wb_rd    <= rd_idx(pending_instr_q);
              wb_data  <= result;
              regs_q[rd_idx(pending_instr_q)] <= result;
            end
          end
          OP_BEQ: begin
            branch_taken <= (rs1_val == rs2_val);
            if (rs1_val == rs2_val) begin
              next_pc = pending_pc_q + imm_b(pending_instr_q);
            end
          end
          OP_LW: begin
            addr      = rs1_val + imm_i(pending_instr_q);
            if ((addr >= MMIO_BASE) && (addr <= MMIO_END)) begin
              defer_retire   = 1'b1;
              mmio_pending_q <= 1'b1;
              mmio_addr_q    <= addr;
              mmio_wdata_q   <= '0;
              mmio_rd_q      <= rd_idx(pending_instr_q);
              mmio_write_q   <= 1'b0;
              psel           <= 1'b1;
              pwrite         <= 1'b0;
              paddr          <= addr;
              pwdata         <= '0;
            end else begin
              mem_idx   = (addr >> 2) % DATA_MEM_WORDS;
              mem_valid <= 1'b1;
              mem_addr  <= addr;
              mem_rdata <= data_mem_q[mem_idx];
              if (rd_idx(pending_instr_q) != 5'd0) begin
                wb_valid <= 1'b1;
                wb_rd    <= rd_idx(pending_instr_q);
                wb_data  <= data_mem_q[mem_idx];
                regs_q[rd_idx(pending_instr_q)] <= data_mem_q[mem_idx];
              end
            end
          end
          OP_SW: begin
            addr      = rs1_val + imm_s(pending_instr_q);
            if ((addr >= MMIO_BASE) && (addr <= MMIO_END)) begin
              defer_retire   = 1'b1;
              mmio_pending_q <= 1'b1;
              mmio_addr_q    <= addr;
              mmio_wdata_q   <= rs2_val;
              mmio_rd_q      <= '0;
              mmio_write_q   <= 1'b1;
              psel           <= 1'b1;
              pwrite         <= 1'b1;
              paddr          <= addr;
              pwdata         <= rs2_val;
            end else begin
              mem_idx   = (addr >> 2) % DATA_MEM_WORDS;
              mem_valid <= 1'b1;
              mem_write <= 1'b1;
              mem_addr  <= addr;
              mem_wdata <= rs2_val;
              data_mem_q[mem_idx] <= rs2_val;
            end
          end
          OP_EBREAK: begin
            halted <= 1'b1;
          end
          default: begin
            illegal_instr <= 1'b1;
          end
        endcase

        if (!defer_retire) begin
          commit_valid    <= 1'b1;
          commit_instr    <= pending_instr_q;
          commit_pc       <= pending_pc_q;
          commit_next_pc  <= next_pc;
          retire          <= 1'b1;
          pc_q            <= next_pc;
          regs_q[0]       <= '0;
          pending_valid_q <= 1'b0;
        end
      end

      if (instr_valid && instr_ready) begin
        pending_valid_q <= 1'b1;
        pending_instr_q <= instr;
        pending_pc_q    <= pc_q;
      end
    end
  end
endmodule
