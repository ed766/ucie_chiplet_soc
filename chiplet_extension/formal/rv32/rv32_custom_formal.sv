module rv32_custom_formal;
    (* gclk *) logic clk;
    logic rst_n = 1'b0;
    logic past_valid = 1'b0;

    (* anyseq *) logic [31:0] next_instr;
    (* anyseq *) logic [31:0] prdata;
    (* anyseq *) logic pready;
    (* anyseq *) logic pslverr;
    (* anyseq *) logic irq_ext;
    (* anyseq *) logic irq_timer;

    logic [31:0] instr_q;
    logic instr_ready;
    logic [31:0] paddr, pwdata;
    logic psel, penable, pwrite;
    logic rvfi_valid, rvfi_trap, rvfi_intr;
    logic [63:0] rvfi_order;
    logic [31:0] rvfi_insn, rvfi_pc_rdata, rvfi_pc_wdata;
    logic [4:0] rvfi_rd_addr;
    logic [31:0] rvfi_rd_wdata, rvfi_rs1_rdata;
    logic [3:0] rvfi_mem_rmask, rvfi_mem_wmask;
    logic [31:0] rvfi_mstatus, rvfi_mie, rvfi_mscratch, rvfi_mscratch_state, rvfi_mepc, rvfi_mcause;
    logic csr_mstatus_read_pending, csr_mie_read_pending, csr_mscratch_read_pending;
    logic csr_mscratch_write_pending;
    logic [31:0] csr_mstatus_snapshot, csr_mie_snapshot, csr_mscratch_snapshot;
    logic [31:0] csr_mscratch_expected;

    rv32_core #(.DATA_MEM_WORDS(4), .ENABLE_TRAPS(1'b1), .EBREAK_TEST_HALT(1'b0)) dut (
        .clk, .rst_n, .instr_valid(1'b1), .instr_ready, .instr(instr_q),
        .irq_ext, .irq_timer, .paddr, .psel, .penable, .pwrite, .pwdata,
        .prdata, .pready, .pslverr,
        .rvfi_valid, .rvfi_order, .rvfi_insn, .rvfi_trap, .rvfi_intr,
        .rvfi_pc_rdata, .rvfi_pc_wdata, .rvfi_rs1_rdata, .rvfi_rd_addr, .rvfi_rd_wdata,
        .rvfi_mem_rmask, .rvfi_mem_wmask, .rvfi_mstatus, .rvfi_mie, .rvfi_mscratch,
        .rvfi_mscratch_state,
        .rvfi_mepc, .rvfi_mcause
    );

    always @(posedge clk) begin
        past_valid <= 1'b1;
        rst_n <= 1'b1;
        if (!rst_n || instr_ready) instr_q <= next_instr;

        if (!rst_n) begin
            csr_mstatus_read_pending <= 1'b0;
            csr_mie_read_pending <= 1'b0;
            csr_mscratch_read_pending <= 1'b0;
            csr_mscratch_write_pending <= 1'b0;
            csr_mstatus_snapshot <= '0;
            csr_mie_snapshot <= '0;
            csr_mscratch_snapshot <= '0;
            csr_mscratch_expected <= '0;
        end

        // The abstract APB environment may wait, but only terminates an active
        // access and keeps its response stable for the duration of a wait.
        assume(!pslverr || (psel && penable && pready));
        if (past_valid && $past(psel && penable && !pready)) begin
            assume($stable(prdata));
            assume($stable(pslverr));
        end

        if (past_valid && rst_n) begin
            // A stalled MMIO instruction is not an architectural boundary.
            if (psel && penable && !pready) assert(!rvfi_valid && !rvfi_intr);

            // Synchronous traps are precise: no register or memory side effect.
            if (rvfi_valid && rvfi_trap && !rvfi_intr) begin
                assert(rvfi_rd_addr == 0);
                assert(rvfi_rd_wdata == 0);
                // RVFI exposes the attempted masks for load/store access faults
                // (mcause 5/7), even though architectural state does not commit.
                assert(rvfi_mem_rmask == 0 || rvfi_mcause == 32'd5);
                assert(rvfi_mem_wmask == 0 || rvfi_mcause == 32'd7);
            end

            // MRET resumes at the saved exception PC.
            if (rvfi_valid && rvfi_insn == 32'h3020_0073)
                assert(rvfi_pc_wdata == rvfi_mepc);

            // CSRRS/CSRRC with rs1=x0 are reads. The exported CSR state at the
            // next ordinary retirement must equal the snapshot from this one.
            if (rvfi_valid && !rvfi_intr && csr_mstatus_read_pending)
                assert(rvfi_mstatus == csr_mstatus_snapshot);
            if (rvfi_valid && !rvfi_intr && csr_mie_read_pending)
                assert(rvfi_mie == csr_mie_snapshot);
            if (rvfi_valid && !rvfi_intr && csr_mscratch_read_pending)
                assert(rvfi_mscratch == csr_mscratch_snapshot);
            if (csr_mscratch_write_pending) begin
                assert(rvfi_mscratch_state == csr_mscratch_expected);
                csr_mscratch_write_pending <= 1'b0;
            end
            if (rvfi_valid) begin
                csr_mstatus_read_pending <= 1'b0;
                csr_mie_read_pending <= 1'b0;
                csr_mscratch_read_pending <= 1'b0;
            end
            if (rvfi_valid && rvfi_insn[6:0] == 7'b1110011 &&
                (rvfi_insn[14:12] == 3'b010 || rvfi_insn[14:12] == 3'b011) &&
                rvfi_insn[19:15] == 0) begin
                if (rvfi_insn[31:20] == 12'h300) begin
                    csr_mstatus_read_pending <= 1'b1;
                    csr_mstatus_snapshot <= rvfi_mstatus;
                end
                if (rvfi_insn[31:20] == 12'h304) begin
                    csr_mie_read_pending <= 1'b1;
                    csr_mie_snapshot <= rvfi_mie;
                end
                if (rvfi_insn[31:20] == 12'h340) begin
                    csr_mscratch_read_pending <= 1'b1;
                    csr_mscratch_snapshot <= rvfi_mscratch;
                end
            end
            if (rvfi_valid && !rvfi_trap && !rvfi_intr &&
                rvfi_insn[6:0] == 7'b1110011 && rvfi_insn[31:20] == 12'h340) begin
                case (rvfi_insn[14:12])
                    3'b001: begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= rvfi_rs1_rdata;
                    end
                    3'b010: if (rvfi_insn[19:15] != 0) begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= rvfi_mscratch | rvfi_rs1_rdata;
                    end
                    3'b011: if (rvfi_insn[19:15] != 0) begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= rvfi_mscratch & ~rvfi_rs1_rdata;
                    end
                    3'b101: begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= {27'b0, rvfi_insn[19:15]};
                    end
                    3'b110: if (rvfi_insn[19:15] != 0) begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= rvfi_mscratch | {27'b0, rvfi_insn[19:15]};
                    end
                    3'b111: if (rvfi_insn[19:15] != 0) begin
                        csr_mscratch_write_pending <= 1'b1;
                        csr_mscratch_expected <= rvfi_mscratch & ~{27'b0, rvfi_insn[19:15]};
                    end
                    default: begin end
                endcase
            end

            // The legacy trace emits a synthetic NOP interrupt-boundary event;
            // the standard-RVFI adapter suppresses it and annotates the first
            // handler retirement. Check the pseudo-event's precise state here.
            if (rvfi_valid && rvfi_intr) begin
                assert(rvfi_insn == 32'h0000_0013);
                assert(rvfi_rd_addr == 0 && rvfi_mem_rmask == 0 && rvfi_mem_wmask == 0);
                assert(rvfi_mepc == rvfi_pc_rdata);
                assert(rvfi_mcause == 32'h8000_000b || rvfi_mcause == 32'h8000_0007);
            end

            cover(rvfi_valid && rvfi_trap && !rvfi_intr);
            cover(rvfi_valid && rvfi_intr);
            cover(rvfi_valid && rvfi_insn == 32'h3020_0073);
            cover(psel && penable && !pready);
        end
    end
endmodule : rv32_custom_formal
