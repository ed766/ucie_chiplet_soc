module rv32_firmware_assertions (
    input logic clk,
    input logic rst_n,
    input logic [31:0] x0_value,
    input logic retire,
    input logic wb_valid,
    input logic psel,
    input logic penable,
    input logic pready,
    input logic pslverr,
    input logic rvfi_valid,
    input logic [63:0] rvfi_order,
    input logic [31:0] rvfi_insn,
    input logic rvfi_trap,
    input logic rvfi_intr,
    input logic [31:0] rvfi_pc_rdata,
    input logic [31:0] rvfi_pc_wdata,
    input logic [31:0] rvfi_rs1_rdata,
    input logic [4:0] rvfi_rd_addr,
    input logic [31:0] rvfi_rd_wdata,
    input logic [31:0] rvfi_mem_addr,
    input logic [3:0] rvfi_mem_rmask,
    input logic [3:0] rvfi_mem_wmask,
    input logic [31:0] rvfi_mstatus,
    input logic [31:0] rvfi_mie,
    input logic [31:0] rvfi_mscratch,
    input logic [31:0] rvfi_mepc,
    input logic [31:0] rvfi_mcause,
    input logic irq_external,
    input logic irq_timer,
    input logic wfi_sleep
);
    default clocking cb @(posedge clk); endclocking

    logic [31:0] expected_mscratch_q;

    function automatic logic [3:0] expected_mask(
        input logic [2:0] funct3,
        input logic [1:0] offset
    );
        logic [3:0] base;
        begin
            unique case (funct3)
                3'b000, 3'b100: base = 4'b0001;
                3'b001, 3'b101: base = 4'b0011;
                3'b010:         base = 4'b1111;
                default:        base = 4'b0000;
            endcase
            expected_mask = base << offset;
        end
    endfunction

    a_rv32_x0_constant: assert property (disable iff (!rst_n) x0_value == 32'b0);
    a_rv32_retire_pc_aligned: assert property (disable iff (!rst_n) rvfi_valid |->
        (rvfi_pc_rdata[1:0] == 2'b00 && rvfi_pc_wdata[1:0] == 2'b00));
    a_rv32_trap_target_aligned: assert property (disable iff (!rst_n) (rvfi_valid && rvfi_trap) |->
        rvfi_pc_wdata[1:0] == 2'b00);
    a_rv32_no_retire_while_apb_wait: assert property (disable iff (!rst_n) (psel && penable && !pready) |-> !retire);
    a_rv32_mmio_error_no_writeback: assert property (disable iff (!rst_n) (psel && penable && pready && pslverr) |=> !wb_valid);
    a_rv32_interrupt_at_boundary: assert property (disable iff (!rst_n) rvfi_intr |-> (rvfi_valid && !rvfi_trap));
    a_rv32_order_increments: assert property (disable iff (!rst_n) (rvfi_valid && $past(rvfi_valid)) |->
        rvfi_order == $past(rvfi_order) + 1'b1);
    a_rv32_mret_returns_mepc: assert property (disable iff (!rst_n) (rvfi_valid && rvfi_insn == 32'h3020_0073) |->
        rvfi_pc_wdata == rvfi_mepc);
    a_rv32_apb_completion_is_single_pulse: assert property (disable iff (!rst_n) (psel && penable && pready) |=> !penable);
    a_rv32_interrupt_cause_implemented: assert property (disable iff (!rst_n) (rvfi_valid && rvfi_intr) |=>
        $past(rvfi_mcause) inside {32'h8000_0007, 32'h8000_000b});
    a_rv32_sync_trap_cause_supported: assert property (disable iff (!rst_n) (rvfi_valid && rvfi_trap) |=>
        $past(rvfi_mcause) inside {32'd0, 32'd2, 32'd3, 32'd4, 32'd5, 32'd6, 32'd7, 32'd11});
    a_rv32_trap_records_fault_pc: assert property (disable iff (!rst_n) (rvfi_valid && rvfi_trap) |=>
        $past(rvfi_mepc) == $past(rvfi_pc_rdata));

    a_rv32_load_mask_matches_width: assert property (disable iff (!rst_n)
        (rvfi_valid && !rvfi_trap && rvfi_insn[6:0] == 7'b0000011) |->
        rvfi_mem_rmask == expected_mask(rvfi_insn[14:12], rvfi_mem_addr[1:0]));
    a_rv32_store_mask_matches_width: assert property (disable iff (!rst_n)
        (rvfi_valid && !rvfi_trap && rvfi_insn[6:0] == 7'b0100011) |->
        rvfi_mem_wmask == expected_mask(rvfi_insn[14:12], rvfi_mem_addr[1:0]));
    a_rv32_trap_suppresses_register_write: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_trap) |-> (rvfi_rd_addr == 0 && rvfi_rd_wdata == 0));
    a_rv32_interrupt_suppresses_instruction_effect: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_intr) |->
        (rvfi_rd_addr == 0 && rvfi_mem_rmask == 0 && rvfi_mem_wmask == 0));
    a_rv32_apb_wait_blocks_architectural_event: assert property (disable iff (!rst_n)
        (psel && penable && !pready) |-> !(rvfi_valid || rvfi_intr));
    a_rv32_zero_destination_has_zero_data: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_rd_addr == 0) |-> rvfi_rd_wdata == 0);
    a_rv32_csr_state_is_implemented_subset: assert property (disable iff (!rst_n) rvfi_valid |->
        ((rvfi_mstatus & ~32'h0000_0088) == 0 && (rvfi_mie & ~32'h0000_0880) == 0));
    a_rv32_mmio_completion_cannot_repeat: assert property (disable iff (!rst_n)
        (psel && penable && pready) |=> !(psel && penable && pready));
    a_rv32_mmio_error_retires_precise_trap: assert property (disable iff (!rst_n)
        (psel && penable && pready && pslverr) |=>
        (rvfi_valid && rvfi_trap && rvfi_rd_addr == 0));
    a_rv32_mret_has_saved_interrupt_state: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_insn == 32'h3020_0073 && rvfi_mcause[31]) |->
        rvfi_mstatus[7]);
    a_rv32_reset_clears_architectural_event: assert property (
        !rst_n |-> !(rvfi_valid || retire || wb_valid));
    a_rv32_timer_interrupt_has_pending_source: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_intr && rvfi_mcause == 32'h8000_0007) |-> irq_timer);
    a_rv32_external_interrupt_priority: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_intr && irq_external && irq_timer) |-> rvfi_mcause == 32'h8000_000b);
    a_rv32_wfi_blocks_retirement: assert property (disable iff (!rst_n)
        (wfi_sleep && !(irq_external || irq_timer)) |->
        ((!retire && !rvfi_valid) ||
         (retire && rvfi_valid && rvfi_insn == 32'h1050_0073)));
    a_rv32_wfi_retire_precedes_sleep: assert property (disable iff (!rst_n)
        (rvfi_valid && rvfi_insn == 32'h1050_0073) |=> (wfi_sleep || rvfi_intr));

    a_mscratch_reset_zero: assert property (!rst_n |-> rvfi_mscratch == 32'b0);

    always_ff @(posedge clk or negedge rst_n) begin : check_mscratch_semantics
        logic [31:0] source;
        logic [31:0] updated;
        logic [1:0] mode;
        if (!rst_n) begin
            expected_mscratch_q <= '0;
        end else if (rvfi_valid) begin
            a_mscratch_write_semantics: assert (rvfi_mscratch == expected_mscratch_q);
            if (!rvfi_trap && rvfi_insn[6:0] == 7'b1110011 &&
                rvfi_insn[31:20] == 12'h340 && rvfi_insn[14:12] != 3'b000) begin
                if (rvfi_rd_addr != 0)
                    a_mscratch_read_returns_old_value: assert (rvfi_rd_wdata == expected_mscratch_q);
                source = rvfi_insn[14] ? {27'b0, rvfi_insn[19:15]} : rvfi_rs1_rdata;
                mode = rvfi_insn[13:12];
                unique case (mode)
                    2'b01: updated = source;
                    2'b10: updated = expected_mscratch_q | source;
                    2'b11: updated = expected_mscratch_q & ~source;
                    default: updated = expected_mscratch_q;
                endcase
                if (mode == 2'b01 || source != 0) expected_mscratch_q <= updated;
            end
        end
    end

endmodule : rv32_firmware_assertions
