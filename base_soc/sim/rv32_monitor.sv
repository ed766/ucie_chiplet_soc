module rv32_monitor(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      commit_valid,
  input  logic [31:0]               commit_instr,
  input  logic [31:0]               commit_pc,
  input  logic [31:0]               commit_next_pc,
  input  logic                      wb_valid,
  input  logic [4:0]                wb_rd,
  input  logic [31:0]               wb_data,
  input  logic                      mem_valid,
  input  logic                      mem_write,
  input  logic [31:0]               mem_addr,
  input  logic [31:0]               mem_wdata,
  input  logic [31:0]               mem_rdata,
  input  logic                      branch_taken,
  input  logic                      illegal_instr,
  input  logic                      halted,
  output logic                      txn_valid,
  output rv32_tb_pkg::rv32_trace_txn_t txn
);
  import rv32_tb_pkg::*;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      txn_valid <= 1'b0;
      txn <= '0;
    end else begin
      txn_valid <= commit_valid;
      if (commit_valid) begin
        txn.instr         <= commit_instr;
        txn.pc            <= commit_pc;
        txn.next_pc       <= commit_next_pc;
        txn.wb_valid      <= wb_valid;
        txn.wb_rd         <= wb_rd;
        txn.wb_data       <= wb_data;
        txn.mem_valid     <= mem_valid;
        txn.mem_write     <= mem_write;
        txn.mem_addr      <= mem_addr;
        txn.mem_wdata     <= mem_wdata;
        txn.mem_rdata     <= mem_rdata;
        txn.branch_taken  <= branch_taken;
        txn.illegal_instr <= illegal_instr;
        txn.halted        <= halted;
      end
    end
  end
endmodule
