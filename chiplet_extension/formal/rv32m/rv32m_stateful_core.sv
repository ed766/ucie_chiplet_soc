// Core-control BMC with an explicit muldiv contract abstraction, not arithmetic proof.
module rv32m_stateful_core(input logic clk);
  (* anyseq *) logic rst_n, instr_valid, irq_ext, irq_timer;
  (* anyseq *) logic [2:0] op, instruction_class;
  (* anyseq *) logic [4:0] rs1, rs2, rd;
  logic initialized=0;
  logic [31:0] instr;
  logic rvfi_valid, rvfi_intr;
  logic [31:0] rvfi_insn, rvfi_mcause;
  logic [4:0] rvfi_rd_addr, rvfi_rs1_addr;
  always_comb begin
    case(instruction_class)
      0: instr={7'd1,rs2,rs1,op,rd,7'h33};
      1: instr={12'h880,5'd0,3'd0,rd,7'h13}; // seed GPRs, including both IRQ enable bits
      2: instr=32'h30409073; // CSRW mie,x1: external and timer enables
      3: instr=32'h30046073; // CSRRSI mstatus,8
      4: instr=32'h30200073; // MRET
      default: instr=32'h00000013;
    endcase
  end
  rv32_core #(.ENABLE_M(1),.ENABLE_TRAPS(1),.DATA_MEM_WORDS(1)) dut(
    .clk,.rst_n,.instr,.instr_valid,.irq_ext,.irq_timer,
    .rvfi_valid,.rvfi_intr,.rvfi_insn,.rvfi_mcause,.rvfi_rd_addr,.rvfi_rs1_addr,
    .prdata(32'b0),.pready(1'b1),.pslverr(1'b0)
  );
  always_ff @(posedge clk) begin
    initialized<=1;
    if(!initialized)assume(!rst_n);
    if(rst_n) begin
      cover(rvfi_valid && rvfi_insn[31:25]==1 && rvfi_insn[6:0]==7'h33 && rvfi_rd_addr!=0);
      cover(rvfi_valid && rvfi_insn[31:25]==1 && rvfi_insn[6:0]==7'h33 && rvfi_rd_addr!=0 && rvfi_rd_addr==rvfi_rs1_addr);
      cover(rvfi_valid && rvfi_intr && rvfi_mcause==32'h8000000b);
      cover(rvfi_valid && rvfi_intr && rvfi_mcause==32'h80000007);
      cover(rvfi_valid && rvfi_insn==32'h30200073);
    end
    // Inputs remain unrestricted after initial reset: repeated requests,
    // nonzero destination/source aliases, interrupts and reset cancellation.
  end
endmodule
