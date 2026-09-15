`timescale 1ns/1ps
module tb_rv32m_core;
  logic clk=0, rst_n=0, instr_valid=0, instr_ready;
  logic [31:0] instr=32'h13;
  logic commit_valid, wb_valid, halted, illegal_instr, rvfi_valid;
  logic [4:0] wb_rd;
  logic [31:0] wb_data;
  logic [63:0] rvfi_order;
  logic [31:0] observed [0:31];
  integer retire_count=0;
  always #5 clk=~clk;

  rv32_core #(.ENABLE_M(1'b1), .ENABLE_TRAPS(1'b1)) dut (
    .clk, .rst_n, .instr_valid, .instr_ready, .instr,
    .irq_ext(1'b0), .irq_timer(1'b0),
    .prdata('0), .pready(1'b1), .pslverr(1'b0),
    .commit_valid, .wb_valid, .wb_rd, .wb_data,
    .illegal_instr, .halted, .rvfi_valid, .rvfi_order,
    .rvfi_mscratch(), .rvfi_mscratch_state(), .rvfi_mtval()
  );

  function automatic logic [31:0] addi(input int rd,input int rs1,input int imm);
    addi={imm[11:0],rs1[4:0],3'b000,rd[4:0],7'h13};
  endfunction
  function automatic logic [31:0] mop(input int op,input int rd,input int rs1,input int rs2);
    mop={7'b0000001,rs2[4:0],rs1[4:0],op[2:0],rd[4:0],7'h33};
  endfunction
  function automatic logic [31:0] csrr(input int rd,input int csr);
    csrr={csr[11:0],5'd0,3'b010,rd[4:0],7'h73};
  endfunction
  task automatic issue(input logic [31:0] value);
    begin
      while(!instr_ready) @(posedge clk);
      @(negedge clk);instr=value;instr_valid=1;
      @(posedge clk);@(negedge clk);instr_valid=0;
    end
  endtask

  always @(posedge clk) begin
    if (wb_valid) observed[wb_rd]<=wb_data;
    if (rvfi_valid) begin
      if (rvfi_order!==retire_count) $fatal(1,"RVFI order mismatch");
      retire_count<=retire_count+1;
    end
  end

  initial begin
    for(integer i=0;i<32;i++) observed[i]=0;
    repeat(3)@(posedge clk);rst_n=1;
    issue(addi(1,0,-7));
    issue(addi(2,0,3));
    issue(mop(4,3,1,2));
    issue(mop(6,4,1,2));
    issue(mop(0,5,1,2));
    issue(mop(1,6,1,2));
    issue(csrr(7,12'h301));
    issue(32'h0010_0073);
    wait(halted);
    if(observed[3]!==32'hffff_fffe) $fatal(1,"DIV core result");
    if(observed[4]!==32'hffff_ffff) $fatal(1,"REM core result");
    if(observed[5]!==32'hffff_ffeb) $fatal(1,"MUL core result");
    if(observed[6]!==32'hffff_ffff) $fatal(1,"MULH core result");
    if(observed[7]!==32'h4000_1100) $fatal(1,"misa.M not reported: %08x", observed[7]);
    if(illegal_instr) $fatal(1,"legal M instruction reported illegal");
    $display("RV32M_CORE_SUMMARY|status=PASS|retired=%0d|misa=%08x",retire_count,observed[7]);
    $finish;
  end
  initial begin repeat(1000)@(posedge clk);$fatal(1,"RV32M core timeout");end
endmodule
