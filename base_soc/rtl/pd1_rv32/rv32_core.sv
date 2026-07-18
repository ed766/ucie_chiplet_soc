module rv32_core #(
  parameter logic [31:0] MMIO_BASE = 32'h0000_0100,
  parameter logic [31:0] MMIO_END  = 32'h0000_01ff,
  parameter int DATA_MEM_WORDS = 64,
  parameter logic [31:0] MAILBOX_ALIAS_BASE = 32'h0000_8000,
  parameter bit ENABLE_TRAPS = 1'b0,
  parameter bit EBREAK_TEST_HALT = 1'b1,
  parameter logic [31:0] RESET_MTVEC = 32'h0000_0300
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        instr_valid,
  output logic        instr_ready,
  input  logic [31:0] instr,
  input  logic        irq_ext,
  input  logic        irq_timer,
  output logic [31:0] paddr,
  output logic        psel,
  output logic        penable,
  output logic        pwrite,
  output logic [31:0] pwdata,
  input  logic [31:0] prdata,
  input  logic        pready,
  input  logic        pslverr,
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
  output logic        halted,
  // RVFI-style architectural retirement record used only by verification.
  output logic        rvfi_valid,
  output logic [63:0] rvfi_order,
  output logic [31:0] rvfi_insn,
  output logic        rvfi_trap,
  output logic        rvfi_intr,
  output logic [31:0] rvfi_pc_rdata,
  output logic [31:0] rvfi_pc_wdata,
  output logic [4:0]  rvfi_rs1_addr,
  output logic [4:0]  rvfi_rs2_addr,
  output logic [31:0] rvfi_rs1_rdata,
  output logic [31:0] rvfi_rs2_rdata,
  output logic [4:0]  rvfi_rd_addr,
  output logic [31:0] rvfi_rd_wdata,
  output logic [31:0] rvfi_mem_addr,
  output logic [3:0]  rvfi_mem_rmask,
  output logic [3:0]  rvfi_mem_wmask,
  output logic [31:0] rvfi_mem_rdata,
  output logic [31:0] rvfi_mem_wdata,
  output logic [31:0] rvfi_mstatus,
  output logic [31:0] rvfi_mie,
  output logic [31:0] rvfi_mtvec,
  output logic [31:0] rvfi_mscratch,
  output logic [31:0] rvfi_mscratch_state,
  output logic [31:0] rvfi_mepc,
  output logic [31:0] rvfi_mcause
);

  localparam logic [31:0] MSTATUS_MIE  = 32'h0000_0008;
  localparam logic [31:0] MSTATUS_MPIE = 32'h0000_0080;
  localparam logic [31:0] MIE_MTIE     = 32'h0000_0080;
  localparam logic [31:0] MIE_MEIE     = 32'h0000_0800;

  logic [31:0] regs_q [0:31];
  logic [31:0] data_mem_q [0:DATA_MEM_WORDS-1];
  logic [31:0] data_init_mem [0:DATA_MEM_WORDS-1];
  logic [31:0] pc_q;
  logic        pending_valid_q;
  logic [31:0] pending_instr_q;
  logic [31:0] pending_pc_q;
  logic        mmio_pending_q;
  logic [31:0] mmio_addr_q;
  logic [31:0] mmio_wdata_q;
  logic [4:0]  mmio_rd_q;
  logic        mmio_write_q;
  logic [2:0]  mmio_funct3_q;
  logic [31:0] mstatus_q;
  logic [31:0] mie_q;
  logic [31:0] mtvec_q;
  logic [31:0] mscratch_q;
  logic [31:0] mepc_q;
  logic [31:0] mcause_q;
  logic [63:0] mcycle_q;
  logic [63:0] minstret_q;
  logic        wfi_sleep_q;
  logic [63:0] order_q;
  integer idx;
`ifndef FORMAL
  string data_hex;
`endif

`ifdef FORMAL
  initial begin
    for (int init_idx = 0; init_idx < DATA_MEM_WORDS; init_idx++) begin
      data_init_mem[init_idx] = '0;
    end
  end
`else
  initial begin
    for (int init_idx = 0; init_idx < DATA_MEM_WORDS; init_idx++) begin
      data_init_mem[init_idx] = '0;
    end
    data_hex = "";
    void'($value$plusargs("DATA_HEX=%s", data_hex));
    if (data_hex != "") $readmemh(data_hex, data_init_mem);
  end
`endif

  function automatic logic [31:0] imm_i(input logic [31:0] value);
    imm_i = {{20{value[31]}}, value[31:20]};
  endfunction

  function automatic logic [31:0] imm_s(input logic [31:0] value);
    imm_s = {{20{value[31]}}, value[31:25], value[11:7]};
  endfunction

  function automatic logic [31:0] imm_b(input logic [31:0] value);
    imm_b = {{19{value[31]}}, value[31], value[7], value[30:25], value[11:8], 1'b0};
  endfunction

  function automatic logic [31:0] imm_u(input logic [31:0] value);
    imm_u = {value[31:12], 12'b0};
  endfunction

  function automatic logic [31:0] imm_j(input logic [31:0] value);
    imm_j = {{11{value[31]}}, value[31], value[19:12], value[20], value[30:21], 1'b0};
  endfunction

  function automatic logic [31:0] load_value(
    input logic [31:0] word,
    input logic [1:0] byte_offset,
    input logic [2:0] funct3
  );
    logic [31:0] shifted;
    begin
      shifted = word >> (byte_offset * 8);
      unique case (funct3)
`ifdef RV32_BUG_LOAD_SIGN_EXT
        3'b000: load_value = {24'b0, shifted[7:0]};
`else
        3'b000: load_value = {{24{shifted[7]}}, shifted[7:0]};
`endif
        3'b001: load_value = {{16{shifted[15]}}, shifted[15:0]};
        3'b010: load_value = word;
        3'b100: load_value = {24'b0, shifted[7:0]};
        3'b101: load_value = {16'b0, shifted[15:0]};
        default: load_value = '0;
      endcase
    end
  endfunction

  function automatic logic [3:0] access_mask(
    input logic [2:0] funct3,
    input logic [1:0] byte_offset
  );
    unique case (funct3)
`ifdef RV32_BUG_STORE_MASK_SHIFT
      3'b000, 3'b100: access_mask = 4'b0001 << (byte_offset + 1'b1);
`else
      3'b000, 3'b100: access_mask = 4'b0001 << byte_offset;
`endif
      3'b001, 3'b101: access_mask = 4'b0011 << byte_offset;
      default: access_mask = 4'b1111;
    endcase
  endfunction

  function automatic logic access_misaligned(
    input logic [2:0] funct3,
    input logic [1:0] byte_offset
  );
    unique case (funct3)
      3'b001, 3'b101: access_misaligned = byte_offset[0];
      3'b010: access_misaligned = |byte_offset;
      default: access_misaligned = 1'b0;
    endcase
  endfunction

  function automatic logic local_mem_address_valid(input logic [31:0] address);
    local_mem_address_valid = (address < DATA_MEM_WORDS * 4) ||
                              ((address >= MAILBOX_ALIAS_BASE) &&
                               (address < MAILBOX_ALIAS_BASE + DATA_MEM_WORDS * 4));
  endfunction

  function automatic int unsigned local_mem_index(input logic [31:0] address);
    local_mem_index = (address >= MAILBOX_ALIAS_BASE) ?
                      ((address - MAILBOX_ALIAS_BASE) >> 2) : (address >> 2);
  endfunction

  function automatic logic [31:0] csr_value(input logic [11:0] csr);
    unique case (csr)
      12'h300: csr_value = mstatus_q;
      12'h304: csr_value = mie_q;
      12'h305: csr_value = mtvec_q;
      12'h340: csr_value = mscratch_q;
      12'h341: csr_value = mepc_q;
      12'h342: csr_value = mcause_q;
      12'h344: csr_value = {20'b0, irq_ext, 3'b0, irq_timer, 7'b0};
      12'hb00: csr_value = mcycle_q[31:0];
      12'hb80: csr_value = mcycle_q[63:32];
      12'hb02: csr_value = minstret_q[31:0];
      12'hb82: csr_value = minstret_q[63:32];
      default: csr_value = '0;
    endcase
  endfunction

  task automatic set_rvfi_base(
    input logic [31:0] insn_value,
    input logic [31:0] pc_value,
    input logic [31:0] next_pc_value,
    input logic [31:0] rs1_value,
    input logic [31:0] rs2_value
  );
    begin
      rvfi_valid     <= 1'b1;
      rvfi_order     <= order_q;
      rvfi_insn      <= insn_value;
      rvfi_pc_rdata  <= pc_value;
      rvfi_pc_wdata  <= next_pc_value;
      rvfi_rs1_addr  <= insn_value[19:15];
      rvfi_rs2_addr  <= insn_value[24:20];
      rvfi_rs1_rdata <= rs1_value;
      rvfi_rs2_rdata <= rs2_value;
      rvfi_mstatus   <= mstatus_q;
      rvfi_mie       <= mie_q;
      rvfi_mtvec     <= mtvec_q;
      rvfi_mscratch  <= mscratch_q;
      rvfi_mepc      <= mepc_q;
      rvfi_mcause    <= mcause_q;
      order_q        <= order_q + 1'b1;
    end
  endtask

  assign instr_ready = rst_n && !halted && !wfi_sleep_q && !pending_valid_q && !mmio_pending_q;
  assign rvfi_mscratch_state = mscratch_q;

  always_ff @(posedge clk or negedge rst_n) begin : execute
    if (!rst_n) begin
      pc_q <= '0;
      pending_valid_q <= 1'b0;
      pending_instr_q <= 32'h0000_0013;
      pending_pc_q <= '0;
      mmio_pending_q <= 1'b0;
      mmio_addr_q <= '0;
      mmio_wdata_q <= '0;
      mmio_rd_q <= '0;
      mmio_write_q <= 1'b0;
      mmio_funct3_q <= 3'b010;
      mstatus_q <= '0;
      mie_q <= '0;
      mtvec_q <= RESET_MTVEC;
      mscratch_q <= '0;
      mepc_q <= '0;
      mcause_q <= '0;
      mcycle_q <= '0;
      minstret_q <= '0;
      wfi_sleep_q <= 1'b0;
      order_q <= '0;
      commit_valid <= 1'b0;
      commit_instr <= 32'h0000_0013;
      commit_pc <= '0;
      commit_next_pc <= '0;
      wb_valid <= 1'b0;
      wb_rd <= '0;
      wb_data <= '0;
      mem_valid <= 1'b0;
      mem_write <= 1'b0;
      mem_addr <= '0;
      mem_wdata <= '0;
      mem_rdata <= '0;
      branch_taken <= 1'b0;
      illegal_instr <= 1'b0;
      bus_error <= 1'b0;
      retire <= 1'b0;
      halted <= 1'b0;
      paddr <= '0;
      psel <= 1'b0;
      penable <= 1'b0;
      pwrite <= 1'b0;
      pwdata <= '0;
      rvfi_valid <= 1'b0;
      rvfi_order <= '0;
      rvfi_insn <= '0;
      rvfi_trap <= 1'b0;
      rvfi_intr <= 1'b0;
      rvfi_pc_rdata <= '0;
      rvfi_pc_wdata <= '0;
      rvfi_rs1_addr <= '0;
      rvfi_rs2_addr <= '0;
      rvfi_rs1_rdata <= '0;
      rvfi_rs2_rdata <= '0;
      rvfi_rd_addr <= '0;
      rvfi_rd_wdata <= '0;
      rvfi_mem_addr <= '0;
      rvfi_mem_rmask <= '0;
      rvfi_mem_wmask <= '0;
      rvfi_mem_rdata <= '0;
      rvfi_mem_wdata <= '0;
      rvfi_mstatus <= '0;
      rvfi_mie <= '0;
      rvfi_mtvec <= RESET_MTVEC;
      rvfi_mscratch <= '0;
      rvfi_mepc <= '0;
      rvfi_mcause <= '0;
      for (idx = 0; idx < 32; idx = idx + 1) regs_q[idx] <= '0;
      for (idx = 0; idx < DATA_MEM_WORDS; idx = idx + 1) data_mem_q[idx] = data_init_mem[idx];
    end else begin
      logic [31:0] rs1_value;
      logic [31:0] rs2_value;
      logic [31:0] result;
      logic [31:0] next_pc;
      logic [31:0] address;
      logic [31:0] memory_word;
      logic [31:0] merged_word;
      logic [31:0] shifted_store;
      logic [31:0] csr_old;
      logic [31:0] csr_new;
      logic [31:0] csr_source;
      logic [3:0] byte_mask;
      logic [6:0] opcode;
      logic [2:0] funct3;
      logic [6:0] funct7;
      logic [4:0] rd;
      logic [4:0] rs1;
      logic [4:0] rs2;
      logic legal;
      logic defer_retire;
      logic take_trap;
      logic [31:0] trap_cause;
      int unsigned mem_idx;

      commit_valid <= 1'b0;
      commit_instr <= '0;
      commit_pc <= '0;
      commit_next_pc <= '0;
      wb_valid <= 1'b0;
      wb_rd <= '0;
      wb_data <= '0;
      mem_valid <= 1'b0;
      mem_write <= 1'b0;
      mem_addr <= '0;
      mem_wdata <= '0;
      mem_rdata <= '0;
      branch_taken <= 1'b0;
      illegal_instr <= 1'b0;
      bus_error <= 1'b0;
      retire <= 1'b0;
      psel <= 1'b0;
      penable <= 1'b0;
      pwrite <= 1'b0;
      rvfi_valid <= 1'b0;
      rvfi_trap <= 1'b0;
      rvfi_intr <= 1'b0;
      rvfi_rd_addr <= '0;
      rvfi_rd_wdata <= '0;
      rvfi_mem_addr <= '0;
      rvfi_mem_rmask <= '0;
      rvfi_mem_wmask <= '0;
      rvfi_mem_rdata <= '0;
      rvfi_mem_wdata <= '0;
      mcycle_q <= mcycle_q + 1'b1;
      // Interrupt entry is represented by a legacy RVFI pseudo-event, not a
      // retired instruction, so it must not advance minstret.
      if (retire && !rvfi_intr) minstret_q <= minstret_q + 1'b1;

      if (wfi_sleep_q) begin
        if ((irq_ext === 1'b1) || (irq_timer === 1'b1)) begin
          wfi_sleep_q <= 1'b0;
          if (ENABLE_TRAPS && mstatus_q[3] &&
              (((irq_ext === 1'b1) && mie_q[11]) || ((irq_timer === 1'b1) && mie_q[7]))) begin
            mepc_q <= pc_q;
            mcause_q <= ((irq_ext === 1'b1) && mie_q[11]) ? 32'h8000_000b : 32'h8000_0007;
            mstatus_q[7] <= mstatus_q[3];
            mstatus_q[3] <= 1'b0;
            rvfi_intr <= 1'b1;
            set_rvfi_base(32'h0000_0013, pc_q, {mtvec_q[31:2], 2'b00}, '0, '0);
            rvfi_mepc <= pc_q;
            rvfi_mcause <= ((irq_ext === 1'b1) && mie_q[11]) ? 32'h8000_000b : 32'h8000_0007;
            commit_valid <= 1'b1;
            commit_instr <= 32'h0000_0013;
            commit_pc <= pc_q;
            commit_next_pc <= {mtvec_q[31:2], 2'b00};
            retire <= 1'b1;
            pc_q <= {mtvec_q[31:2], 2'b00};
          end
        end
      end else if (mmio_pending_q) begin
        psel <= 1'b1;
        pwrite <= mmio_write_q;
        paddr <= mmio_addr_q;
        pwdata <= mmio_wdata_q;
        penable <= 1'b1;
        if (pready) begin
          result = load_value(prdata, mmio_addr_q[1:0], mmio_funct3_q);
          bus_error <= pslverr;
          mem_valid <= 1'b1;
          mem_write <= mmio_write_q;
          mem_addr <= mmio_addr_q;
          mem_wdata <= mmio_wdata_q;
          mem_rdata <= prdata;
          if (pslverr && ENABLE_TRAPS) begin
            mepc_q <= pending_pc_q;
            mcause_q <= mmio_write_q ? 32'd7 : 32'd5;
            mstatus_q[7] <= mstatus_q[3];
            mstatus_q[3] <= 1'b0;
            pc_q <= {mtvec_q[31:2], 2'b00};
            commit_next_pc <= {mtvec_q[31:2], 2'b00};
            rvfi_trap <= 1'b1;
            set_rvfi_base(pending_instr_q, pending_pc_q, {mtvec_q[31:2], 2'b00},
                          regs_q[pending_instr_q[19:15]], regs_q[pending_instr_q[24:20]]);
            rvfi_mepc <= pending_pc_q;
            rvfi_mcause <= mmio_write_q ? 32'd7 : 32'd5;
          end else begin
            if (!mmio_write_q && !pslverr && (mmio_rd_q != 0)) begin
              regs_q[mmio_rd_q] <= result;
              wb_valid <= 1'b1;
              wb_rd <= mmio_rd_q;
              wb_data <= result;
              rvfi_rd_addr <= mmio_rd_q;
              rvfi_rd_wdata <= result;
            end
            pc_q <= pending_pc_q + 4;
            commit_next_pc <= pending_pc_q + 4;
            set_rvfi_base(pending_instr_q, pending_pc_q, pending_pc_q + 4,
                          regs_q[pending_instr_q[19:15]], regs_q[pending_instr_q[24:20]]);
          end
          commit_valid <= 1'b1;
          commit_instr <= pending_instr_q;
          commit_pc <= pending_pc_q;
          retire <= 1'b1;
          rvfi_mem_addr <= mmio_addr_q;
          rvfi_mem_rmask <= mmio_write_q ? 4'b0000 : access_mask(mmio_funct3_q, mmio_addr_q[1:0]);
          rvfi_mem_wmask <= mmio_write_q ? 4'b1111 : 4'b0000;
          rvfi_mem_rdata <= prdata;
          rvfi_mem_wdata <= mmio_wdata_q;
          pending_valid_q <= 1'b0;
`ifdef RV32_BUG_DUP_APB_COMPLETION
          mmio_pending_q <= 1'b1;
`else
          mmio_pending_q <= 1'b0;
`endif
          psel <= 1'b0;
          penable <= 1'b0;
        end
      end else if (pending_valid_q) begin
        opcode = pending_instr_q[6:0];
        funct3 = pending_instr_q[14:12];
        funct7 = pending_instr_q[31:25];
        rd = pending_instr_q[11:7];
        rs1 = pending_instr_q[19:15];
        rs2 = pending_instr_q[24:20];
        rs1_value = regs_q[rs1];
        rs2_value = regs_q[rs2];
        result = '0;
        next_pc = pending_pc_q + 4;
        address = '0;
        memory_word = '0;
        merged_word = '0;
        shifted_store = '0;
        csr_old = '0;
        csr_new = '0;
        csr_source = '0;
        byte_mask = '0;
        legal = 1'b1;
        defer_retire = 1'b0;
        take_trap = 1'b0;
        trap_cause = '0;
        mem_idx = 0;

        if (ENABLE_TRAPS && mstatus_q[3] &&
            (((irq_ext === 1'b1) && mie_q[11]) || ((irq_timer === 1'b1) && mie_q[7]))) begin
          mepc_q <= pending_pc_q;
          mcause_q <= ((irq_ext === 1'b1) && mie_q[11]) ? 32'h8000_000b : 32'h8000_0007;
          mstatus_q[7] <= mstatus_q[3];
          mstatus_q[3] <= 1'b0;
          next_pc = {mtvec_q[31:2], 2'b00};
          rvfi_intr <= 1'b1;
          set_rvfi_base(32'h0000_0013, pending_pc_q, next_pc, '0, '0);
          rvfi_mepc <= pending_pc_q;
          rvfi_mcause <= ((irq_ext === 1'b1) && mie_q[11]) ? 32'h8000_000b : 32'h8000_0007;
          commit_instr <= 32'h0000_0013;
          pending_valid_q <= 1'b0;
        end else begin
          unique case (opcode)
            7'b0110111: result = imm_u(pending_instr_q); // LUI
            7'b0010111: result = pending_pc_q + imm_u(pending_instr_q); // AUIPC
            7'b1101111: begin // JAL
              result = pending_pc_q + 4;
              next_pc = pending_pc_q + imm_j(pending_instr_q);
            end
            7'b1100111: begin // JALR
              legal = (funct3 == 3'b000);
              result = pending_pc_q + 4;
              next_pc = (rs1_value + imm_i(pending_instr_q)) & 32'hffff_fffe;
            end
            7'b1100011: begin
              unique case (funct3)
                3'b000: branch_taken <= (rs1_value == rs2_value);
                3'b001: branch_taken <= (rs1_value != rs2_value);
`ifdef RV32_BUG_SIGNED_BRANCH
                3'b100: branch_taken <= (rs1_value < rs2_value);
`else
                3'b100: branch_taken <= ($signed(rs1_value) < $signed(rs2_value));
`endif
                3'b101: branch_taken <= ($signed(rs1_value) >= $signed(rs2_value));
                3'b110: branch_taken <= (rs1_value < rs2_value);
                3'b111: branch_taken <= (rs1_value >= rs2_value);
                default: legal = 1'b0;
              endcase
              if (legal && ((funct3 == 3'b000 && rs1_value == rs2_value) ||
                            (funct3 == 3'b001 && rs1_value != rs2_value) ||
`ifdef RV32_BUG_SIGNED_BRANCH
                            (funct3 == 3'b100 && rs1_value < rs2_value) ||
`else
                            (funct3 == 3'b100 && $signed(rs1_value) < $signed(rs2_value)) ||
`endif
                            (funct3 == 3'b101 && $signed(rs1_value) >= $signed(rs2_value)) ||
                            (funct3 == 3'b110 && rs1_value < rs2_value) ||
                            (funct3 == 3'b111 && rs1_value >= rs2_value)))
                next_pc = pending_pc_q + imm_b(pending_instr_q);
            end
            7'b0010011: begin
              unique case (funct3)
                3'b000: result = rs1_value + imm_i(pending_instr_q);
                3'b010: result = {31'b0, $signed(rs1_value) < $signed(imm_i(pending_instr_q))};
                3'b011: result = {31'b0, rs1_value < imm_i(pending_instr_q)};
                3'b100: result = rs1_value ^ imm_i(pending_instr_q);
                3'b110: result = rs1_value | imm_i(pending_instr_q);
                3'b111: result = rs1_value & imm_i(pending_instr_q);
                3'b001: begin
                  legal = (funct7 == 7'b0000000);
                  result = rs1_value << pending_instr_q[24:20];
                end
                3'b101: begin
                  legal = (funct7 == 7'b0000000) || (funct7 == 7'b0100000);
                  result = funct7[5] ? $unsigned($signed(rs1_value) >>> pending_instr_q[24:20])
                                     : (rs1_value >> pending_instr_q[24:20]);
                end
                default: legal = 1'b0;
              endcase
            end
            7'b0110011: begin
              unique case ({funct7, funct3})
                {7'b0000000,3'b000}: result = rs1_value + rs2_value;
                {7'b0100000,3'b000}: result = rs1_value - rs2_value;
                {7'b0000000,3'b001}: result = rs1_value << rs2_value[4:0];
                {7'b0000000,3'b010}: result = {31'b0, $signed(rs1_value) < $signed(rs2_value)};
                {7'b0000000,3'b011}: result = {31'b0, rs1_value < rs2_value};
                {7'b0000000,3'b100}: result = rs1_value ^ rs2_value;
                {7'b0000000,3'b101}: result = rs1_value >> rs2_value[4:0];
                {7'b0100000,3'b101}: result = $unsigned($signed(rs1_value) >>> rs2_value[4:0]);
                {7'b0000000,3'b110}: result = rs1_value | rs2_value;
                {7'b0000000,3'b111}: result = rs1_value & rs2_value;
                default: legal = 1'b0;
              endcase
            end
            7'b0000011: begin // Loads
              legal = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                      (funct3 == 3'b010) || (funct3 == 3'b100) ||
                      (funct3 == 3'b101);
              address = rs1_value + imm_i(pending_instr_q);
              if (legal && ENABLE_TRAPS && access_misaligned(funct3, address[1:0])) begin
                take_trap = 1'b1;
                trap_cause = 32'd4;
              end else if (legal && (address >= MMIO_BASE) && (address <= MMIO_END)) begin
                defer_retire = 1'b1;
                mmio_pending_q <= 1'b1;
                mmio_addr_q <= address;
                mmio_wdata_q <= '0;
                mmio_rd_q <= rd;
                mmio_write_q <= 1'b0;
                mmio_funct3_q <= funct3;
                psel <= 1'b1;
                paddr <= address;
              end else if (legal && ENABLE_TRAPS && !local_mem_address_valid(address)) begin
                take_trap = 1'b1;
                trap_cause = 32'd5;
              end else if (legal) begin
                mem_idx = local_mem_index(address);
                memory_word = data_mem_q[mem_idx];
                result = load_value(memory_word, address[1:0], funct3);
                byte_mask = access_mask(funct3, address[1:0]);
                mem_valid <= 1'b1;
                mem_addr <= address;
                mem_rdata <= memory_word;
                rvfi_mem_addr <= address;
                rvfi_mem_rmask <= byte_mask;
                rvfi_mem_rdata <= memory_word;
              end
            end
            7'b0100011: begin // Stores
              legal = (funct3 == 3'b000) || (funct3 == 3'b001) ||
                      (funct3 == 3'b010);
              address = rs1_value + imm_s(pending_instr_q);
              if (legal && ENABLE_TRAPS && access_misaligned(funct3, address[1:0])) begin
                take_trap = 1'b1;
                trap_cause = 32'd6;
              end else if (legal && (address >= MMIO_BASE) && (address <= MMIO_END)) begin
                legal = (funct3 == 3'b010);
                if (legal) begin
                  defer_retire = 1'b1;
                  mmio_pending_q <= 1'b1;
                  mmio_addr_q <= address;
                  mmio_wdata_q <= rs2_value;
                  mmio_rd_q <= '0;
                  mmio_write_q <= 1'b1;
                  mmio_funct3_q <= funct3;
                  psel <= 1'b1;
                  pwrite <= 1'b1;
                  paddr <= address;
                  pwdata <= rs2_value;
                end
              end else if (legal && ENABLE_TRAPS && !local_mem_address_valid(address)) begin
                take_trap = 1'b1;
                trap_cause = 32'd7;
              end else if (legal) begin
                mem_idx = local_mem_index(address);
                memory_word = data_mem_q[mem_idx];
                byte_mask = access_mask(funct3, address[1:0]);
                merged_word = memory_word;
                shifted_store = rs2_value << ({30'b0, address[1:0]} * 8);
                for (int lane = 0; lane < 4; lane++)
                  if (byte_mask[lane]) merged_word[lane*8 +: 8] = shifted_store[lane*8 +: 8];
                data_mem_q[mem_idx] <= merged_word;
                mem_valid <= 1'b1;
                mem_write <= 1'b1;
                mem_addr <= address;
                mem_wdata <= rs2_value;
                rvfi_mem_addr <= address;
                rvfi_mem_wmask <= byte_mask;
                rvfi_mem_wdata <= rs2_value;
              end
            end
            7'b0001111: legal = (funct3 == 3'b000); // FENCE
            7'b1110011: begin
              if (pending_instr_q == 32'h0010_0073) begin
                if (EBREAK_TEST_HALT) begin
                  halted <= 1'b1;
                end else begin
                  take_trap = ENABLE_TRAPS;
                  trap_cause = 32'd3;
                  legal = !ENABLE_TRAPS;
                end
              end else if (pending_instr_q == 32'h1050_0073) begin
                legal = ENABLE_TRAPS;
                wfi_sleep_q <= ENABLE_TRAPS;
              end else if (pending_instr_q == 32'h3020_0073) begin
                legal = ENABLE_TRAPS;
`ifdef RV32_BUG_MRET_SKIP
                next_pc = mepc_q + 4;
`else
                next_pc = mepc_q;
`endif
`ifdef RV32_BUG_IRQ_RESTORE
                mstatus_q[3] <= 1'b0;
`else
                mstatus_q[3] <= mstatus_q[7];
`endif
                mstatus_q[7] <= 1'b1;
              end else if (pending_instr_q == 32'h0000_0073) begin
                take_trap = ENABLE_TRAPS;
                trap_cause = 32'd11;
                legal = !ENABLE_TRAPS;
              end else begin
                legal = ENABLE_TRAPS && (funct3 != 3'b000) &&
                        ((pending_instr_q[31:20] == 12'h300) ||
                         (pending_instr_q[31:20] == 12'h304) ||
                         (pending_instr_q[31:20] == 12'h305) ||
                         (pending_instr_q[31:20] == 12'h340) ||
                         (pending_instr_q[31:20] == 12'h341) ||
                         (pending_instr_q[31:20] == 12'h342) ||
                         (pending_instr_q[31:20] == 12'h344) ||
                         (pending_instr_q[31:20] == 12'hb00) ||
                         (pending_instr_q[31:20] == 12'hb80) ||
                         (pending_instr_q[31:20] == 12'hb02) ||
                         (pending_instr_q[31:20] == 12'hb82));
                if (legal) begin
                  csr_old = csr_value(pending_instr_q[31:20]);
                  csr_source = funct3[2] ? {27'b0, rs1} : rs1_value;
                  unique case (funct3[1:0])
                    2'b01: csr_new = csr_source;
                    2'b10: csr_new = csr_old | csr_source;
                    2'b11: csr_new = csr_old & ~csr_source;
                    default: begin csr_new = csr_old; legal = 1'b0; end
                  endcase
`ifdef RV32_BUG_CSR_ZERO_SOURCE
                  if ((funct3[1:0] == 2'b10) && (csr_source == 0)) csr_new = '0;
`endif
                  if (legal && ((funct3[1:0] == 2'b01) || (csr_source != 0)
`ifdef RV32_BUG_CSR_ZERO_SOURCE
                                || (funct3[1:0] == 2'b10)
`endif
                               )) begin
                    unique case (pending_instr_q[31:20])
                      12'h300: mstatus_q <= csr_new & (MSTATUS_MIE | MSTATUS_MPIE);
                      12'h304: mie_q <= csr_new & (MIE_MEIE | MIE_MTIE);
                      12'h305: mtvec_q <= {csr_new[31:2], 2'b00};
                      12'h340: begin
`ifndef RV32_BUG_MSCRATCH_WRITE_DROP
                        mscratch_q <= csr_new;
`endif
                      end
                      12'h341: mepc_q <= {csr_new[31:2], 2'b00};
                      12'h342: mcause_q <= csr_new;
                      12'h344: begin end
                      12'hb00: mcycle_q[31:0] <= csr_new;
                      12'hb80: mcycle_q[63:32] <= csr_new;
                      12'hb02: minstret_q[31:0] <= csr_new;
                      12'hb82: minstret_q[63:32] <= csr_new;
                      default: legal = 1'b0;
                    endcase
                  end
                  result = csr_old;
                end
              end
            end
            default: legal = 1'b0;
          endcase

          if (legal && !take_trap && ENABLE_TRAPS &&
              ((opcode == 7'b1101111) || (opcode == 7'b1100111) ||
               (opcode == 7'b1100011)) && next_pc[1]) begin
            take_trap = 1'b1;
            trap_cause = 32'd0;
          end

          if (!legal && !take_trap) begin
            illegal_instr <= 1'b1;
            if (ENABLE_TRAPS) begin
              take_trap = 1'b1;
              trap_cause = 32'd2;
            end
          end

`ifdef RV32_BUG_TRAP_CAUSE
          if (take_trap) trap_cause = trap_cause ^ 32'd1;
`endif
`ifdef RV32_BUG_ALU_RESULT
          if (legal && ((opcode == 7'b0010011) || (opcode == 7'b0110011))) result = result ^ 32'd1;
`endif
          if (take_trap) begin
            mepc_q <= pending_pc_q;
            mcause_q <= trap_cause;
            mstatus_q[7] <= mstatus_q[3];
            mstatus_q[3] <= 1'b0;
            next_pc = {mtvec_q[31:2], 2'b00};
            rvfi_trap <= 1'b1;
            rvfi_mepc <= pending_pc_q;
            rvfi_mcause <= trap_cause;
            if ((opcode == 7'b0000011) || (opcode == 7'b0100011)) rvfi_mem_addr <= address;
          end else if (legal && !defer_retire &&
                       ((opcode == 7'b0110111) || (opcode == 7'b0010111) ||
                        (opcode == 7'b1101111) || (opcode == 7'b1100111) ||
                        (opcode == 7'b0010011) || (opcode == 7'b0110011) ||
                        (opcode == 7'b0000011) || (opcode == 7'b1110011)) &&
                       (rd != 0) && !(opcode == 7'b1110011 && pending_instr_q == 32'h3020_0073)) begin
            regs_q[rd] <= result;
            wb_valid <= 1'b1;
            wb_rd <= rd;
            wb_data <= result;
            rvfi_rd_addr <= rd;
            rvfi_rd_wdata <= result;
          end

          if (!defer_retire) begin
            set_rvfi_base(pending_instr_q, pending_pc_q, next_pc, rs1_value, rs2_value);
            if (take_trap) begin
              rvfi_mepc <= pending_pc_q;
              rvfi_mcause <= trap_cause;
              if ((opcode == 7'b0000011) || (opcode == 7'b0100011)) rvfi_mem_addr <= address;
            end
            commit_instr <= pending_instr_q;
            pending_valid_q <= 1'b0;
          end
        end

        if (!defer_retire) begin
          commit_valid <= 1'b1;
          commit_pc <= pending_pc_q;
          commit_next_pc <= next_pc;
          retire <= 1'b1;
          pc_q <= next_pc;
          regs_q[0] <= '0;
        end
      end

      if (instr_valid && instr_ready) begin
        pending_valid_q <= 1'b1;
        pending_instr_q <= instr;
        pending_pc_q <= pc_q;
      end
    end
  end
endmodule
