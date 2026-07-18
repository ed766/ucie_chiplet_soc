module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);
    `rvformal_rand_reg [31:0] instruction;
    `rvformal_rand_reg [31:0] peripheral_rdata;
    wire instruction_ready;
    wire legacy_valid, legacy_trap, legacy_intr, halted;
    wire [63:0] legacy_order;
    wire [31:0] legacy_insn, legacy_pc_rdata, legacy_pc_wdata;
    wire [4:0] legacy_rs1_addr, legacy_rs2_addr, legacy_rd_addr;
    wire [31:0] legacy_rs1_rdata, legacy_rs2_rdata, legacy_rd_wdata;
    wire [31:0] legacy_mem_addr, legacy_mem_rdata, legacy_mem_wdata;
    wire [3:0] legacy_mem_rmask, legacy_mem_wmask;

    rv32_core #(.EBREAK_TEST_HALT(1'b0)) core (
        .clk(clock), .rst_n(!reset), .instr_valid(1'b1), .instr_ready(instruction_ready),
        .instr(instruction), .irq_ext(1'b0), .irq_timer(1'b0),
        .prdata(peripheral_rdata), .pready(1'b1), .pslverr(1'b0),
        .rvfi_valid(legacy_valid), .rvfi_order(legacy_order), .rvfi_insn(legacy_insn),
        .rvfi_trap(legacy_trap), .rvfi_intr(legacy_intr), .rvfi_pc_rdata(legacy_pc_rdata),
        .rvfi_pc_wdata(legacy_pc_wdata), .rvfi_rs1_addr(legacy_rs1_addr),
        .rvfi_rs2_addr(legacy_rs2_addr), .rvfi_rs1_rdata(legacy_rs1_rdata),
        .rvfi_rs2_rdata(legacy_rs2_rdata), .rvfi_rd_addr(legacy_rd_addr),
        .rvfi_rd_wdata(legacy_rd_wdata), .rvfi_mem_addr(legacy_mem_addr),
        .rvfi_mem_rmask(legacy_mem_rmask), .rvfi_mem_wmask(legacy_mem_wmask),
        .rvfi_mem_rdata(legacy_mem_rdata), .rvfi_mem_wdata(legacy_mem_wdata),
        .rvfi_mscratch(), .rvfi_mscratch_state(), .halted(halted)
    );

    rvfi_standard_adapter adapter (
        .clk(clock), .rst_n(!reset), .legacy_valid(legacy_valid), .legacy_insn(legacy_insn),
        .legacy_trap(legacy_trap), .legacy_intr(legacy_intr), .legacy_pc_rdata(legacy_pc_rdata),
        .legacy_pc_wdata(legacy_pc_wdata), .legacy_rs1_addr(legacy_rs1_addr),
        .legacy_rs2_addr(legacy_rs2_addr), .legacy_rs1_rdata(legacy_rs1_rdata),
        .legacy_rs2_rdata(legacy_rs2_rdata), .legacy_rd_addr(legacy_rd_addr),
        .legacy_rd_wdata(legacy_rd_wdata), .legacy_mem_addr(legacy_mem_addr),
        .legacy_mem_rmask(legacy_mem_rmask), .legacy_mem_wmask(legacy_mem_wmask),
        .legacy_mem_rdata(legacy_mem_rdata), .legacy_mem_wdata(legacy_mem_wdata),
        .legacy_halt(halted), `RVFI_CONN
    );

    // The instruction source obeys the same hold-until-ready contract as the
    // ROM feeder used by simulation and compiled firmware.
    always @(posedge clock) begin
        if (!reset && !instruction_ready) assume($stable(instruction));
    end
endmodule
