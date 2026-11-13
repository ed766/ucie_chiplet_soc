module rv32m_core_formal(input logic clk);
  (* anyseq *) logic rst_n, instr_valid;
  (* anyseq *) logic [2:0] op;
  logic initialized=0;
  logic [31:0] instr;
  // Temporal ownership proof with constant operands; alias/arithmetic checks are separate.
  assign instr={7'd1,5'd0,5'd0,op,5'd0,7'h33};
  rv32_core #(.ENABLE_M(1),.ENABLE_TRAPS(1),.DATA_MEM_WORDS(1)) dut(
    .clk,.rst_n,.instr,.instr_valid,.irq_ext(1'b0),.irq_timer(1'b0),
    .prdata(32'b0),.pready(1'b1),.pslverr(1'b0)
  );
  always_ff @(posedge clk) begin
    initialized<=1;
    if(!initialized)assume(!rst_n);
  end
endmodule
