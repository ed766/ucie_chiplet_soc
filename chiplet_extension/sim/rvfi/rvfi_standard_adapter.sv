// Converts the core's legacy interrupt pseudo-event into standard RVFI form:
// the pseudo-event is suppressed and rvfi_intr marks the first handler retire.
module rvfi_standard_adapter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        legacy_valid,
    input  logic [31:0] legacy_insn,
    input  logic        legacy_trap,
    input  logic        legacy_intr,
    input  logic [31:0] legacy_pc_rdata,
    input  logic [31:0] legacy_pc_wdata,
    input  logic [4:0]  legacy_rs1_addr,
    input  logic [4:0]  legacy_rs2_addr,
    input  logic [31:0] legacy_rs1_rdata,
    input  logic [31:0] legacy_rs2_rdata,
    input  logic [4:0]  legacy_rd_addr,
    input  logic [31:0] legacy_rd_wdata,
    input  logic [31:0] legacy_mem_addr,
    input  logic [3:0]  legacy_mem_rmask,
    input  logic [3:0]  legacy_mem_wmask,
    input  logic [31:0] legacy_mem_rdata,
    input  logic [31:0] legacy_mem_wdata,
    input  logic        legacy_halt,
    output logic        rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [1:0]  rvfi_mode,
    output logic [1:0]  rvfi_ixl,
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
    output logic [31:0] rvfi_mem_wdata
);
    logic pending_intr_q;

    assign rvfi_mode = 2'b11;
    assign rvfi_ixl = 2'b01;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvfi_valid <= 1'b0;
            rvfi_order <= '0;
            rvfi_intr <= 1'b0;
            pending_intr_q <= 1'b0;
        end else begin
            rvfi_valid <= 1'b0;
            rvfi_intr <= 1'b0;
            if (legacy_valid && legacy_intr) begin
                pending_intr_q <= 1'b1;
            end else if (legacy_valid) begin
                rvfi_valid <= 1'b1;
                rvfi_intr <= pending_intr_q;
                pending_intr_q <= 1'b0;
                rvfi_order <= rvfi_order + 1'b1;
                rvfi_insn <= legacy_insn;
                rvfi_trap <= legacy_trap;
                rvfi_halt <= legacy_halt;
                rvfi_pc_rdata <= legacy_pc_rdata;
                rvfi_pc_wdata <= legacy_pc_wdata;
                rvfi_rs1_addr <= legacy_rs1_addr;
                rvfi_rs2_addr <= legacy_rs2_addr;
                rvfi_rs1_rdata <= legacy_rs1_rdata;
                rvfi_rs2_rdata <= legacy_rs2_rdata;
                rvfi_rd_addr <= legacy_rd_addr;
                rvfi_rd_wdata <= legacy_rd_wdata;
                rvfi_mem_addr <= legacy_mem_addr;
                rvfi_mem_rmask <= legacy_mem_rmask;
                rvfi_mem_wmask <= legacy_mem_wmask;
                rvfi_mem_rdata <= legacy_mem_rdata;
                rvfi_mem_wdata <= legacy_mem_wdata;
            end
        end
    end
endmodule : rvfi_standard_adapter
