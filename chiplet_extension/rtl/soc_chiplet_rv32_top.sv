// Firmware-driven integration top: RV32 APB master controls the chiplet DMA.
module soc_chiplet_rv32_top #(
    parameter int DATA_WIDTH = 64,
    parameter int FLIT_WIDTH = 264,
    parameter int LANES = 16,
    parameter int ROM_WORDS = 256,
    parameter int CPU_DATA_MEM_WORDS = 64,
    parameter bit CPU_ENABLE_TRAPS = 1'b0
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [1:0]            power_state,
    input  logic                  dma_mode_force,
    input  logic [3:0]            apb_wait_cycles,
    output logic                  cpu_halted,
    output logic                  cpu_bus_error,
    output logic                  cpu_commit_valid,
    output logic [31:0]           cpu_commit_pc,
    output logic [31:0]           cpu_commit_instr,
    output logic [31:0]           cpu_commit_next_pc,
    output logic                  cpu_retire,
    output logic                  cpu_mem_valid,
    output logic                  cpu_mem_write,
    output logic [31:0]           cpu_mem_addr,
    output logic [31:0]           cpu_mem_wdata,
    output logic [31:0]           cpu_mem_rdata,
    output logic                  cpu_rvfi_valid,
    output logic [63:0]           cpu_rvfi_order,
    output logic [31:0]           cpu_rvfi_insn,
    output logic                  cpu_rvfi_trap,
    output logic                  cpu_rvfi_intr,
    output logic [31:0]           cpu_rvfi_pc_rdata,
    output logic [31:0]           cpu_rvfi_pc_wdata,
    output logic [4:0]            cpu_rvfi_rs1_addr,
    output logic [4:0]            cpu_rvfi_rs2_addr,
    output logic [31:0]           cpu_rvfi_rs1_rdata,
    output logic [31:0]           cpu_rvfi_rs2_rdata,
    output logic [4:0]            cpu_rvfi_rd_addr,
    output logic [31:0]           cpu_rvfi_rd_wdata,
    output logic [31:0]           cpu_rvfi_mem_addr,
    output logic [3:0]            cpu_rvfi_mem_rmask,
    output logic [3:0]            cpu_rvfi_mem_wmask,
    output logic [31:0]           cpu_rvfi_mem_rdata,
    output logic [31:0]           cpu_rvfi_mem_wdata,
    output logic [31:0]           cpu_rvfi_mstatus,
    output logic [31:0]           cpu_rvfi_mie,
    output logic [31:0]           cpu_rvfi_mtvec,
    output logic [31:0]           cpu_rvfi_mepc,
    output logic [31:0]           cpu_rvfi_mcause,
    output logic [31:0]           cpu_paddr,
    output logic                  cpu_psel,
    output logic                  cpu_penable,
    output logic                  cpu_pwrite,
    output logic [31:0]           cpu_pwdata,
    output logic                  cpu_pready,
    output logic                  cpu_pslverr,
    output logic                  irq_done,
    output logic [DATA_WIDTH-1:0] plaintext_monitor,
    output logic [DATA_WIDTH-1:0] ciphertext_monitor,
    output logic                  dma_busy_monitor,
    output logic                  dma_done_monitor,
    output logic                  dma_error_monitor,
    output logic [15:0]           dma_tag_monitor
);

    logic instr_valid;
    logic instr_ready;
    logic [31:0] instr;
    logic wb_valid;
    logic [4:0] wb_rd;
    logic [31:0] wb_data;
    logic branch_taken;
    logic illegal_instr;
    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic cfg_ready;
    logic [DATA_WIDTH-1:0] die_b_ciphertext_monitor;
    logic crypto_error_flag;
    logic irq_done_monitor;
    logic mmio_access_enable_q;
    logic [1:0] mmio_wake_guard_q;
    logic [1:0] last_power_state_q;
    logic verification_irq_force = 1'b0;
    logic cpu_irq_ext;

    assign cpu_irq_ext = irq_done | verification_irq_force;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmio_access_enable_q <= 1'b1;
            mmio_wake_guard_q <= '0;
            last_power_state_q <= 2'd0;
        end else begin
            if ((power_state == 2'd2) || (power_state == 2'd3)) begin
                mmio_access_enable_q <= 1'b0;
                mmio_wake_guard_q <= '0;
            end else if ((last_power_state_q == 2'd2) || (last_power_state_q == 2'd3)) begin
                mmio_access_enable_q <= 1'b0;
                mmio_wake_guard_q <= 2'd2;
            end else if (mmio_wake_guard_q != 0) begin
                mmio_wake_guard_q <= mmio_wake_guard_q - 1'b1;
                if (mmio_wake_guard_q == 1) mmio_access_enable_q <= 1'b1;
            end else begin
                mmio_access_enable_q <= 1'b1;
            end
            last_power_state_q <= power_state;
        end
    end

    rv32_rom_feeder #(
        .ROM_WORDS(ROM_WORDS)
    ) u_firmware (
        .clk(clk),
        .rst_n(rst_n),
        .instr_ready(instr_ready),
        .instr_valid(instr_valid),
        .instr(instr),
        .commit_valid(cpu_commit_valid),
        .commit_next_pc(cpu_commit_next_pc),
        .halted(cpu_halted)
    );

    rv32_core #(
        .MMIO_BASE(32'h0000_0100),
        .MMIO_END (32'h0000_01ff),
        .DATA_MEM_WORDS(CPU_DATA_MEM_WORDS),
        .ENABLE_TRAPS(CPU_ENABLE_TRAPS)
    ) u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .instr_valid(instr_valid),
        .instr_ready(instr_ready),
        .instr(instr),
        .irq_ext(cpu_irq_ext),
        .paddr(cpu_paddr),
        .psel(cpu_psel),
        .penable(cpu_penable),
        .pwrite(cpu_pwrite),
        .pwdata(cpu_pwdata),
        .prdata(cpu_mem_rdata),
        .pready(cpu_pready),
        .pslverr(cpu_pslverr),
        .commit_valid(cpu_commit_valid),
        .commit_instr(cpu_commit_instr),
        .commit_pc(cpu_commit_pc),
        .commit_next_pc(cpu_commit_next_pc),
        .wb_valid(wb_valid),
        .wb_rd(wb_rd),
        .wb_data(wb_data),
        .mem_valid(cpu_mem_valid),
        .mem_write(cpu_mem_write),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_rdata(),
        .branch_taken(branch_taken),
        .illegal_instr(illegal_instr),
        .bus_error(cpu_bus_error),
        .retire(cpu_retire),
        .halted(cpu_halted),
        .rvfi_valid(cpu_rvfi_valid),
        .rvfi_order(cpu_rvfi_order),
        .rvfi_insn(cpu_rvfi_insn),
        .rvfi_trap(cpu_rvfi_trap),
        .rvfi_intr(cpu_rvfi_intr),
        .rvfi_pc_rdata(cpu_rvfi_pc_rdata),
        .rvfi_pc_wdata(cpu_rvfi_pc_wdata),
        .rvfi_rs1_addr(cpu_rvfi_rs1_addr),
        .rvfi_rs2_addr(cpu_rvfi_rs2_addr),
        .rvfi_rs1_rdata(cpu_rvfi_rs1_rdata),
        .rvfi_rs2_rdata(cpu_rvfi_rs2_rdata),
        .rvfi_rd_addr(cpu_rvfi_rd_addr),
        .rvfi_rd_wdata(cpu_rvfi_rd_wdata),
        .rvfi_mem_addr(cpu_rvfi_mem_addr),
        .rvfi_mem_rmask(cpu_rvfi_mem_rmask),
        .rvfi_mem_wmask(cpu_rvfi_mem_wmask),
        .rvfi_mem_rdata(cpu_rvfi_mem_rdata),
        .rvfi_mem_wdata(cpu_rvfi_mem_wdata),
        .rvfi_mstatus(cpu_rvfi_mstatus),
        .rvfi_mie(cpu_rvfi_mie),
        .rvfi_mtvec(cpu_rvfi_mtvec),
        .rvfi_mepc(cpu_rvfi_mepc),
        .rvfi_mcause(cpu_rvfi_mcause)
    );

    apb_dma_csr_bridge u_apb_csr (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(cpu_paddr),
        .psel(cpu_psel),
        .penable(cpu_penable),
        .pwrite(cpu_pwrite),
        .pwdata(cpu_pwdata),
        .prdata(cpu_mem_rdata),
        .pready(cpu_pready),
        .pslverr(cpu_pslverr),
        .wait_cycles(apb_wait_cycles),
        .access_enable(mmio_access_enable_q),
        .cfg_valid(cfg_valid),
        .cfg_write(cfg_write),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .cfg_ready(cfg_ready)
    );

    soc_chiplet_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FLIT_WIDTH(FLIT_WIDTH),
        .LANES(LANES)
    ) u_chiplet (
        .clk(clk),
        .rst_n(rst_n),
        .power_state(power_state),
        .dma_mode_force(dma_mode_force),
        .cfg_valid(cfg_valid),
        .cfg_write(cfg_write),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .cfg_ready(cfg_ready),
        .irq_done(irq_done),
        .plaintext_monitor(plaintext_monitor),
        .ciphertext_monitor(ciphertext_monitor),
        .die_b_ciphertext_monitor(die_b_ciphertext_monitor),
        .crypto_error_flag(crypto_error_flag),
        .dma_busy_monitor(dma_busy_monitor),
        .dma_done_monitor(dma_done_monitor),
        .dma_error_monitor(dma_error_monitor),
        .irq_done_monitor(irq_done_monitor),
        .dma_tag_monitor(dma_tag_monitor)
    );

endmodule : soc_chiplet_rv32_top
