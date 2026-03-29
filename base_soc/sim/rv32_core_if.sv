interface rv32_core_if(input logic clk);
  logic        rst_n;
  logic        instr_valid;
  logic        instr_ready;
  logic [31:0] instr;

  logic        commit_valid;
  logic [31:0] commit_instr;
  logic [31:0] commit_pc;
  logic [31:0] commit_next_pc;
  logic        wb_valid;
  logic [4:0]  wb_rd;
  logic [31:0] wb_data;
  logic        mem_valid;
  logic        mem_write;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic [31:0] mem_rdata;
  logic        branch_taken;
  logic        illegal_instr;
  logic        retire;
  logic        halted;

  modport dut (
    input  clk,
    input  rst_n,
    input  instr_valid,
    input  instr,
    output instr_ready,
    output commit_valid,
    output commit_instr,
    output commit_pc,
    output commit_next_pc,
    output wb_valid,
    output wb_rd,
    output wb_data,
    output mem_valid,
    output mem_write,
    output mem_addr,
    output mem_wdata,
    output mem_rdata,
    output branch_taken,
    output illegal_instr,
    output retire,
    output halted
  );

  modport drv (
    input  clk,
    input  rst_n,
    input  instr_ready,
    input  halted,
    output instr_valid,
    output instr
  );

  modport mon (
    input clk,
    input rst_n,
    input instr_valid,
    input instr_ready,
    input instr,
    input commit_valid,
    input commit_instr,
    input commit_pc,
    input commit_next_pc,
    input wb_valid,
    input wb_rd,
    input wb_data,
    input mem_valid,
    input mem_write,
    input mem_addr,
    input mem_wdata,
    input mem_rdata,
    input branch_taken,
    input illegal_instr,
    input retire,
    input halted
  );
endinterface
