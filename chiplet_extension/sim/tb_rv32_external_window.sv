`timescale 1ns/1ps
module tb_rv32_external_window;
  logic clk=0, rst_n=0, instr_valid=0, instr_ready;
  logic [31:0] instr=32'h13;
  logic [31:0] paddr, pwdata, prdata;
  logic psel, penable, pwrite, pready=0, pslverr=0;
  logic wb_valid, halted, rvfi_valid;
  logic [4:0] wb_rd;
  logic [31:0] wb_data;
  integer waits=0, transfers=0;
  logic [31:0] observed_load;
  always #5 clk=~clk;

  rv32_core #(
    .MMIO_BASE(32'h4000_0000), .MMIO_END(32'h4000_2fff),
    .EXT_MEM_BASE(32'h1000_0000), .EXT_MEM_END(32'h3000_ffff),
    .ENABLE_TRAPS(1'b1), .EBREAK_TEST_HALT(1'b1)
  ) dut (
    .clk, .rst_n, .instr_valid, .instr_ready, .instr,
    .irq_ext(1'b0), .irq_timer(1'b0), .paddr, .psel, .penable,
    .pwrite, .pwdata, .prdata, .pready, .pslverr,
    .wb_valid, .wb_rd, .wb_data, .halted, .rvfi_valid,
    .rvfi_mscratch(), .rvfi_mscratch_state(), .rvfi_mtval()
  );

  task automatic issue(input logic [31:0] value);
    while(!instr_ready) @(posedge clk);
    @(negedge clk); instr=value; instr_valid=1;
    @(posedge clk); @(negedge clk); instr_valid=0;
  endtask

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      pready<=0; waits<=0; transfers<=0; prdata<=32'h1122_3344;
    end else begin
      pready<=0;
      if(psel && penable && !pready) begin
        if(waits==2) begin
          pready<=1; waits<=0; transfers<=transfers+1;
        end else waits<=waits+1;
      end
      if(wb_valid && wb_rd==2) observed_load<=wb_data;
    end
  end

  initial begin
    repeat(3) @(posedge clk); rst_n=1;
    issue(32'h1000_00b7); // lui x1,0x10000
    issue(32'h0000_a103); // lw x2,0(x1)
    if(instr_ready) $fatal(1,"load retired before external response");
    wait(instr_ready);
    issue(32'h0020_a223); // sw x2,4(x1)
    wait(instr_ready);
    issue(32'h0010_0073);
    wait(halted);
    if(transfers!=2) $fatal(1,"expected two external transfers, got %0d",transfers);
    if(observed_load!==32'h1122_3344) $fatal(1,"external load mismatch");
    if(paddr!==32'h1000_0004 || pwdata!==32'h1122_3344)
      $fatal(1,"external store payload mismatch");
    $display("RV32_EXTERNAL_WINDOW|status=PASS|transfers=%0d|wait_depth=2",transfers);
    $finish;
  end
  initial begin repeat(300) @(posedge clk); $fatal(1,"external window timeout"); end
endmodule
