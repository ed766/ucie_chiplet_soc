`timescale 1ns/1ps
module tb_rv32_ebreak_trap;
    logic clk = 0, rst_n = 0, instr_valid = 0;
    logic instr_ready, rvfi_valid, rvfi_trap;
    logic [31:0] rvfi_mcause, rvfi_pc_wdata;
    always #5 clk = ~clk;

    rv32_core #(.ENABLE_TRAPS(1'b1), .EBREAK_TEST_HALT(1'b0)) dut (
        .clk(clk), .rst_n(rst_n), .instr_valid(instr_valid), .instr_ready(instr_ready),
        .instr(32'h0010_0073), .irq_ext(1'b0), .irq_timer(1'b0),
        .prdata('0), .pready(1'b1), .pslverr(1'b0),
        .rvfi_valid(rvfi_valid), .rvfi_trap(rvfi_trap), .rvfi_mcause(rvfi_mcause),
        .rvfi_mscratch(),
        .rvfi_mscratch_state(),
        .rvfi_pc_wdata(rvfi_pc_wdata)
    );

    initial begin
        repeat (3) @(posedge clk); rst_n = 1;
        @(negedge clk); instr_valid = 1;
        do @(posedge clk); while (!instr_ready);
        @(negedge clk); instr_valid = 0;
        do @(posedge clk); while (!rvfi_valid);
        if (!rvfi_trap || rvfi_mcause != 32'd3 || rvfi_pc_wdata != 32'h300) begin
            $error("EBREAK trap mismatch trap=%0d cause=%08x target=%08x", rvfi_trap, rvfi_mcause, rvfi_pc_wdata);
            $fatal(1);
        end
        $display("RV32_EBREAK_TRAP_PASS");
        $finish;
    end
endmodule
