module rv32_driver(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        instr_ready,
  output logic        instr_valid,
  output logic [31:0] instr
);
  import rv32_tb_pkg::*;

  initial begin
    instr_valid = 1'b0;
    instr = rv32_nop();
  end

  task automatic send_instruction(input logic [31:0] instr_word);
    begin
      while (!rst_n) begin
        @(posedge clk);
      end
      while (!instr_ready) begin
        @(posedge clk);
      end
      @(negedge clk);
      instr = instr_word;
      instr_valid = 1'b1;
      @(posedge clk);
      @(negedge clk);
      instr_valid = 1'b0;
      instr = rv32_nop();
    end
  endtask
endmodule
