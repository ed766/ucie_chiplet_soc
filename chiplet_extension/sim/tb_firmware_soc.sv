`timescale 1ns/1ps

`include "scoreboard/dma_mem_ref_scoreboard.sv"

module tb_firmware_soc;
    localparam logic [1:0] PWR_RUN = 2'd0;
    localparam logic [1:0] PWR_CRYPTO_ONLY = 2'd1;
    localparam logic [1:0] PWR_SLEEP = 2'd2;
    localparam logic [1:0] PWR_DEEP_SLEEP = 2'd3;
    localparam logic [1:0] COMP_SUCCESS = 2'd1;
    localparam logic [1:0] COMP_RUNTIME_ERROR = 2'd2;
    localparam logic [1:0] COMP_SUBMIT_REJECT = 2'd3;

    logic clk = 1'b0;
    logic rst_n;
    logic [1:0] power_state;
    logic dma_mode_force;
    logic [3:0] apb_wait_cycles;
    logic cpu_halted;
    logic cpu_bus_error;
    logic cpu_commit_valid;
    logic [31:0] cpu_commit_pc;
    logic [31:0] cpu_commit_instr;
    logic [31:0] cpu_commit_next_pc;
    logic cpu_retire;
    logic cpu_mem_valid;
    logic cpu_mem_write;
    logic [31:0] cpu_mem_addr;
    logic [31:0] cpu_mem_wdata;
    logic [31:0] cpu_mem_rdata;
    logic [31:0] cpu_paddr;
    logic cpu_psel;
    logic cpu_penable;
    logic cpu_pwrite;
    logic [31:0] cpu_pwdata;
    logic cpu_pready;
    logic cpu_pslverr;
    logic irq_done;
    logic [63:0] plaintext_monitor;
    logic [63:0] ciphertext_monitor;
    logic dma_busy_monitor;
    logic dma_done_monitor;
    logic dma_error_monitor;
    logic [15:0] dma_tag_monitor;

    string test_name;
    string coverage_path;
    string reference_path;
    string trace_path;
    integer errors;
    integer cycles;
    integer mmio_reads;
    integer mmio_writes;
    integer wait_cycles_seen;
    integer wait_read_cycles;
    integer wait_write_cycles;
    integer bus_errors_seen;
    integer range_errors_seen;
    integer unaligned_errors_seen;
    integer irq_poll_reads;
    integer irq_high_cycles;
    integer doorbells_seen;
    integer completion_pops;
    integer submit_accepts;
    integer submit_rejects;
    integer queue_full_rejects;
    integer blocked_rejects;
    integer completion_pushes;
    integer successful_completions;
    integer runtime_error_completions;
    integer reject_completions;
    integer timeout_completions;
    integer parity_completions;
    integer invalid_completions;
    integer destination_writes;
    integer software_completion_reads;
    integer completion_order_errors;
    integer assertion_failures;
    integer sleep_hold;
    integer deep_sleep_hold;
    integer reset_hold;
    bit sleep_applied;
    bit deep_sleep_applied;
    bit reset_applied;
    bit reset_recovery_seen;
    bit restore_seen;
    bit prior_doorbell;
    bit irq_masked_pending_seen;
    bit irq_pending_then_enable_seen;
    bit irq_cleared_seen;
    bit comp_full_stall_seen;
    bit wait_without_retire_seen;
    bit link_hold_active;
    bit return_suppress_active;
    logic prev_psel;
    logic prev_penable;
    logic prev_pready;
    logic prev_pwrite;
    logic prev_cfg_valid;
    logic [31:0] prev_paddr;
    logic [31:0] prev_pwdata;
    logic prev_irq_done;
    logic prev_comp_full_stall;
    logic [15:0] prev_comp_front_tag;
    logic [1:0] prev_comp_front_status;
    logic [3:0] prev_comp_front_err;
    logic [8:0] prev_comp_front_words;
    logic stall_front_snapshot_valid;
    logic [15:0] stalled_front_tag;
    logic [1:0] stalled_front_status;
    logic [3:0] stalled_front_err;
    logic [8:0] stalled_front_words;
    logic [15:0] accepted_tags [0:15];
    logic [15:0] submitted_tags [0:15];
    logic [15:0] firmware_staged_tag;
    integer accepted_tag_count;
    integer accepted_completion_count;
    integer submitted_tag_count;
    integer accepted_submit_check_count;
    integer submission_correlation_errors;
    integer trace_fd;

    int unsigned ref_observed_count;
    int unsigned ref_mismatch_count;
    logic ref_update_event;
    logic ref_mismatch_event;

    always #5 clk = ~clk;

    soc_chiplet_rv32_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .power_state(power_state),
        .dma_mode_force(dma_mode_force),
        .apb_wait_cycles(apb_wait_cycles),
        .cpu_halted(cpu_halted),
        .cpu_bus_error(cpu_bus_error),
        .cpu_commit_valid(cpu_commit_valid),
        .cpu_commit_pc(cpu_commit_pc),
        .cpu_commit_instr(cpu_commit_instr),
        .cpu_commit_next_pc(cpu_commit_next_pc),
        .cpu_retire(cpu_retire),
        .cpu_mem_valid(cpu_mem_valid),
        .cpu_mem_write(cpu_mem_write),
        .cpu_mem_addr(cpu_mem_addr),
        .cpu_mem_wdata(cpu_mem_wdata),
        .cpu_mem_rdata(cpu_mem_rdata),
        .cpu_paddr(cpu_paddr),
        .cpu_psel(cpu_psel),
        .cpu_penable(cpu_penable),
        .cpu_pwrite(cpu_pwrite),
        .cpu_pwdata(cpu_pwdata),
        .cpu_pready(cpu_pready),
        .cpu_pslverr(cpu_pslverr),
        .irq_done(irq_done),
        .plaintext_monitor(plaintext_monitor),
        .ciphertext_monitor(ciphertext_monitor),
        .dma_busy_monitor(dma_busy_monitor),
        .dma_done_monitor(dma_done_monitor),
        .dma_error_monitor(dma_error_monitor),
        .dma_tag_monitor(dma_tag_monitor)
    );

    dma_mem_ref_scoreboard u_ref (
        .observed_count(ref_observed_count),
        .mismatch_count(ref_mismatch_count),
        .update_event(ref_update_event),
        .mismatch_event(ref_mismatch_event)
    );

    function automatic logic [63:0] source_word(input int unsigned addr);
        source_word = 64'h1000_0000_0000_0000 | 64'(addr);
    endfunction

    function automatic bit tag_was_accepted(input logic [15:0] tag);
        tag_was_accepted = 1'b0;
        for (int idx = 0; idx < accepted_tag_count; idx++) begin
            if (accepted_tags[idx] == tag) tag_was_accepted = 1'b1;
        end
    endfunction

    task automatic preload_source_memory();
        for (int addr = 0; addr < 32; addr++) begin
            dut.u_chiplet.u_die_a.u_dma.src_bank_mem[addr[0]][addr >> 1] = source_word(addr);
            dut.u_chiplet.u_die_a.u_dma.src_bank_parity[addr[0]][addr >> 1] = ^source_word(addr);
        end
    endtask

    task automatic compare_destination(input int unsigned first, input int unsigned count);
        logic [63:0] observed;
        for (int addr = first; addr < first + count; addr++) begin
            observed = dut.u_chiplet.u_die_a.u_dma.dst_bank_mem[addr[0]][addr >> 1];
            u_ref.compare_word(addr, observed);
        end
    endtask

    task automatic record_assertion_failure(input string name);
        $display("FIRMWARE_ASSERTION_FAILED|name=%s|cycle=%0d", name, cycles);
        assertion_failures++;
        errors++;
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            prev_psel = 1'b0;
            prev_penable = 1'b0;
            prev_pready = 1'b0;
            prev_pwrite = 1'b0;
            prev_cfg_valid = 1'b0;
            prev_paddr = '0;
            prev_pwdata = '0;
            prev_irq_done = 1'b0;
            prev_comp_full_stall = 1'b0;
            prev_comp_front_tag = '0;
            prev_comp_front_status = '0;
            prev_comp_front_err = '0;
            prev_comp_front_words = '0;
            stall_front_snapshot_valid = 1'b0;
            stalled_front_tag = '0;
            stalled_front_status = '0;
            stalled_front_err = '0;
            stalled_front_words = '0;
        end else begin
            if (cpu_penable && !cpu_psel) begin
                record_assertion_failure("apb_enable_requires_select");
            end
            if (cpu_psel && cpu_penable && !(prev_psel && !prev_penable || prev_psel && prev_penable)) begin
                record_assertion_failure("apb_access_requires_setup");
            end
            if (dut.u_apb_csr.cfg_valid &&
                (!(cpu_psel && cpu_penable && cpu_pready) || cpu_pslverr || prev_cfg_valid)) begin
                record_assertion_failure("apb_one_csr_operation_per_transfer");
            end
            if (prev_psel && prev_penable && !prev_pready) begin
                if (!(cpu_psel && cpu_penable) || cpu_paddr != prev_paddr ||
                    cpu_pwrite != prev_pwrite || (cpu_pwrite && cpu_pwdata != prev_pwdata)) begin
                    record_assertion_failure("apb_control_stable_during_wait");
                end
            end
            if (cpu_retire && cpu_mem_valid && cpu_mem_addr >= 32'h100 &&
                !(prev_psel && prev_penable && prev_pready)) begin
                record_assertion_failure("rv32_mmio_retire_requires_pready");
            end
            if (dut.u_chiplet.u_die_a.u_dma.submit_accept_event_q && !prior_doorbell) begin
                record_assertion_failure("doorbell_precedes_descriptor_accept");
            end
            if (cpu_pslverr && dut.u_apb_csr.cfg_valid) begin
                record_assertion_failure("mmio_error_cannot_mutate_dma");
            end
            if (sleep_applied && cpu_psel && cpu_penable && cpu_pready && !cpu_pwrite &&
                cpu_paddr == 32'h138 && cpu_mem_rdata != 0 &&
                !restore_seen && !dut.u_chiplet.u_pwr_ctrl.restore_dma_sleep) begin
                record_assertion_failure("restore_precedes_software_completion");
            end

            if (cpu_psel && cpu_penable && !cpu_pready) begin
                wait_cycles_seen++;
                if (cpu_pwrite) wait_write_cycles++; else wait_read_cycles++;
                wait_without_retire_seen = 1'b1;
            end
            if (cpu_psel && cpu_penable && cpu_pready) begin
                if (cpu_pwrite) mmio_writes++; else mmio_reads++;
                if (!cpu_pwrite && cpu_paddr == 32'h11c) irq_poll_reads++;
                if (cpu_pwrite && cpu_paddr == 32'h114) firmware_staged_tag = cpu_pwdata[15:0];
                if (!cpu_pwrite && cpu_paddr == 32'h14c && cpu_mem_rdata[4]) begin
                    comp_full_stall_seen = 1'b1;
                    stall_front_snapshot_valid = 1'b1;
                    stalled_front_tag = dut.u_chiplet.u_die_a.u_dma.comp_tag_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                    stalled_front_status = dut.u_chiplet.u_die_a.u_dma.comp_status_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                    stalled_front_err = dut.u_chiplet.u_die_a.u_dma.comp_err_code_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                    stalled_front_words = dut.u_chiplet.u_die_a.u_dma.comp_words_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                end
                if (cpu_pwrite && cpu_paddr == 32'h100 && cpu_pwdata[0]) begin
                    doorbells_seen++;
                    prior_doorbell = 1'b1;
                    submitted_tags[submitted_tag_count] = firmware_staged_tag;
                    submitted_tag_count++;
                end
                if (cpu_pwrite && cpu_paddr == 32'h144 && cpu_pwdata[0]) completion_pops++;
                if (!cpu_pwrite && cpu_paddr == 32'h138 && cpu_mem_rdata != 0) begin
                    software_completion_reads++;
                    if (!tag_was_accepted(cpu_mem_rdata[15:0]) &&
                        dut.u_chiplet.u_die_a.u_dma.comp_status_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q] != COMP_SUBMIT_REJECT) begin
                        record_assertion_failure("software_completion_has_accepted_descriptor");
                    end
                end
            end
            if (cpu_retire && cpu_mem_valid && cpu_mem_write && cpu_mem_addr == 0 &&
                cpu_mem_wdata[4] && cpu_mem_wdata[2:0] == 3'd4) begin
                comp_full_stall_seen = 1'b1;
                stall_front_snapshot_valid = 1'b1;
                stalled_front_tag = dut.u_chiplet.u_die_a.u_dma.comp_tag_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                stalled_front_status = dut.u_chiplet.u_die_a.u_dma.comp_status_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                stalled_front_err = dut.u_chiplet.u_die_a.u_dma.comp_err_code_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
                stalled_front_words = dut.u_chiplet.u_die_a.u_dma.comp_words_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
            end
            if (cpu_bus_error) begin
                bus_errors_seen++;
                if (cpu_mem_addr[1:0] != 0) unaligned_errors_seen++;
                else range_errors_seen++;
            end
            if (irq_done) irq_high_cycles++;
            if ((dut.u_chiplet.u_die_a.u_dma.irq_status_q != 0) &&
                (dut.u_chiplet.u_die_a.u_dma.irq_en_q == 0)) begin
                irq_masked_pending_seen = 1'b1;
            end
            if (irq_done && irq_masked_pending_seen) irq_pending_then_enable_seen = 1'b1;
            if ((irq_high_cycles > 0) && !irq_done) irq_cleared_seen = 1'b1;

            if (dut.u_chiplet.u_die_a.u_dma.submit_accept_event_q) begin
                if ((accepted_submit_check_count >= submitted_tag_count) ||
                    (dut.u_chiplet.u_die_a.u_dma.staged_tag_q != submitted_tags[accepted_submit_check_count])) begin
                    submission_correlation_errors++;
                    record_assertion_failure("firmware_accept_matches_submitted_tag");
                end
                accepted_submit_check_count++;
                accepted_tags[accepted_tag_count] = dut.u_chiplet.u_die_a.u_dma.staged_tag_q;
                accepted_tag_count++;
                submit_accepts++;
            end
            if (dut.u_chiplet.u_die_a.u_dma.submit_reject_event_q) begin
                submit_rejects++;
                if (dut.u_chiplet.u_die_a.u_dma.submit_reject_err_code_q == 4'd3) queue_full_rejects++;
                if (dut.u_chiplet.u_die_a.u_dma.submit_reject_err_code_q == 4'd5) blocked_rejects++;
            end
            if (dut.u_chiplet.u_die_a.u_dma.comp_push_event_q) begin
                completion_pushes++;
                case (dut.u_chiplet.u_die_a.u_dma.comp_push_status_q)
                    COMP_SUCCESS: successful_completions++;
                    COMP_RUNTIME_ERROR: begin
                        runtime_error_completions++;
                        case (dut.u_chiplet.u_die_a.u_dma.comp_push_err_code_q)
                            4'd4: timeout_completions++;
                            4'd6: parity_completions++;
                            4'd7: invalid_completions++;
                            default: begin end
                        endcase
                    end
                    COMP_SUBMIT_REJECT: reject_completions++;
                    default: begin end
                endcase
                if (dut.u_chiplet.u_die_a.u_dma.comp_push_status_q != COMP_SUBMIT_REJECT) begin
                    if ((accepted_completion_count >= accepted_tag_count) ||
                        (dut.u_chiplet.u_die_a.u_dma.comp_push_tag_q != accepted_tags[accepted_completion_count])) begin
                        completion_order_errors++;
                        record_assertion_failure("firmware_completion_order_matches_acceptance");
                    end
                    accepted_completion_count++;
                end
            end
            if (dut.u_chiplet.u_die_a.u_dma.rx_fire) destination_writes++;
            if (stall_front_snapshot_valid && (completion_pops == 0) &&
                ((dut.u_chiplet.u_die_a.u_dma.comp_tag_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q] != stalled_front_tag) ||
                 (dut.u_chiplet.u_die_a.u_dma.comp_status_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q] != stalled_front_status) ||
                 (dut.u_chiplet.u_die_a.u_dma.comp_err_code_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q] != stalled_front_err) ||
                 (dut.u_chiplet.u_die_a.u_dma.comp_words_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q] != stalled_front_words))) begin
                record_assertion_failure("firmware_completion_front_stable_while_stalled");
            end
            if (dut.u_chiplet.u_pwr_ctrl.restore_dma_sleep) restore_seen = 1'b1;

            prev_psel = cpu_psel;
            prev_penable = cpu_penable;
            prev_pready = cpu_pready;
            prev_pwrite = cpu_pwrite;
            prev_cfg_valid = dut.u_apb_csr.cfg_valid;
            prev_paddr = cpu_paddr;
            prev_pwdata = cpu_pwdata;
            prev_irq_done = irq_done;
            prev_comp_full_stall = dut.u_chiplet.u_die_a.u_dma.comp_full_stall_q;
            prev_comp_front_tag = dut.u_chiplet.u_die_a.u_dma.comp_tag_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
            prev_comp_front_status = dut.u_chiplet.u_die_a.u_dma.comp_status_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
            prev_comp_front_err = dut.u_chiplet.u_die_a.u_dma.comp_err_code_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
            prev_comp_front_words = dut.u_chiplet.u_die_a.u_dma.comp_words_q[dut.u_chiplet.u_die_a.u_dma.comp_head_q];
        end
    end

    always @(negedge clk) begin
        if (test_name == "apb_reset_mid_wait") begin
            if (!reset_applied && rst_n && cpu_psel && cpu_penable && !cpu_pready) begin
                rst_n = 1'b0;
                reset_applied = 1'b1;
                reset_hold = 4;
            end else if (reset_applied && !rst_n && reset_hold > 0) begin
                reset_hold--;
                if (reset_hold == 0) begin
                    preload_source_memory();
                    rst_n = 1'b1;
                    reset_recovery_seen = 1'b1;
                end
            end
        end

        if (rst_n) begin
            if (test_name == "sleep_resume") begin
                if (!sleep_applied && doorbells_seen > 0) begin
                    power_state = PWR_SLEEP;
                    sleep_applied = 1'b1;
                    sleep_hold = 24;
                end else if (sleep_hold > 0) begin
                    sleep_hold--;
                    if (sleep_hold == 0) power_state = PWR_RUN;
                end
            end

            if (test_name == "deep_sleep_invalid_source") begin
                if (!deep_sleep_applied && cycles >= 12) begin
                    power_state = PWR_DEEP_SLEEP;
                    deep_sleep_applied = 1'b1;
                    deep_sleep_hold = 24;
                end else if (deep_sleep_hold > 0) begin
                    deep_sleep_hold--;
                    if (deep_sleep_hold == 0) power_state = PWR_RUN;
                end
            end

            if ((test_name == "queue_full_reject") && !link_hold_active && submit_accepts > 0) begin
                force dut.u_chiplet.u_die_a.tx_stream_ready = 1'b0;
                link_hold_active = 1'b1;
            end

            if ((test_name == "timeout_error") && !return_suppress_active && submit_accepts > 0) begin
                force dut.u_chiplet.u_die_a.dma_rx_stream_valid = 1'b0;
                return_suppress_active = 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        cycles++;
        if (trace_fd != 0) begin
            $fwrite(trace_fd, "%0d,%0h,%0h,%0d,%0d,%0d,%0d,%0h,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    cycles, cpu_commit_pc, cpu_commit_instr, cpu_commit_valid,
                    cpu_psel, cpu_penable, cpu_pready, cpu_paddr, cpu_pwrite,
                    dut.u_chiplet.u_die_a.u_dma.submit_accept_event_q,
                    dut.u_chiplet.u_die_a.u_dma.comp_push_event_q, irq_done, cpu_halted,
                    power_state, dut.u_chiplet.u_pwr_ctrl.restore_dma_sleep,
                    dut.mmio_access_enable_q);
        end
    end

    task automatic write_coverage(input bit pass);
        integer fd;
        fd = $fopen(coverage_path, "w");
        if (fd == 0) $fatal(1, "Cannot open firmware coverage output %s", coverage_path);
        $fwrite(fd, "coverage_point,hit,value\n");
        $fwrite(fd, "apb_read,%0d,%0d\n", mmio_reads > 0, mmio_reads);
        $fwrite(fd, "apb_write,%0d,%0d\n", mmio_writes > 0, mmio_writes);
        $fwrite(fd, "apb_zero_wait,%0d,%0d\n", (apb_wait_cycles == 0) && ((mmio_reads + mmio_writes) > 0), mmio_reads + mmio_writes);
        $fwrite(fd, "apb_wait_read,%0d,%0d\n", wait_read_cycles > 0, wait_read_cycles);
        $fwrite(fd, "apb_wait_write,%0d,%0d\n", wait_write_cycles > 0, wait_write_cycles);
        $fwrite(fd, "apb_range_error,%0d,%0d\n", range_errors_seen > 0, range_errors_seen);
        $fwrite(fd, "apb_unaligned_error,%0d,%0d\n", unaligned_errors_seen > 0, unaligned_errors_seen);
        $fwrite(fd, "apb_reset_recovery,%0d,%0d\n", reset_applied && rst_n, reset_applied && rst_n);
        $fwrite(fd, "fw_polling,%0d,%0d\n", irq_poll_reads > 1, irq_poll_reads);
        $fwrite(fd, "fw_doorbell,%0d,%0d\n", doorbells_seen > 0, doorbells_seen);
        $fwrite(fd, "fw_completion_read,%0d,%0d\n", software_completion_reads > 0, software_completion_reads);
        $fwrite(fd, "fw_completion_pop,%0d,%0d\n", completion_pops > 0, completion_pops);
        $fwrite(fd, "fw_irq_masked,%0d,%0d\n", irq_masked_pending_seen, irq_masked_pending_seen);
        $fwrite(fd, "fw_irq_pending_enable,%0d,%0d\n", irq_masked_pending_seen && (irq_high_cycles > 0), irq_high_cycles);
        $fwrite(fd, "fw_ordered_tags,%0d,%0d\n", (accepted_completion_count > 1) && (completion_order_errors == 0), accepted_completion_count);
        $fwrite(fd, "fw_bus_error,%0d,%0d\n", bus_errors_seen > 0, bus_errors_seen);
        $fwrite(fd, "dma_success,%0d,%0d\n", successful_completions > 0, successful_completions);
        $fwrite(fd, "dma_two_in_order,%0d,%0d\n", (successful_completions > 1) && (completion_order_errors == 0), successful_completions);
        $fwrite(fd, "dma_queue_full_reject,%0d,%0d\n", queue_full_rejects > 0, queue_full_rejects);
        $fwrite(fd, "dma_blocked_reject,%0d,%0d\n", blocked_rejects > 0, blocked_rejects);
        $fwrite(fd, "dma_timeout,%0d,%0d\n", timeout_completions > 0, timeout_completions);
        $fwrite(fd, "dma_parity_error,%0d,%0d\n", parity_completions > 0, parity_completions);
        $fwrite(fd, "dma_invalid_error,%0d,%0d\n", invalid_completions > 0, invalid_completions);
        $fwrite(fd, "cross_run_success,%0d,%0d\n", (power_state == PWR_RUN) && (successful_completions > 0), successful_completions);
        $fwrite(fd, "cross_run_timeout,%0d,%0d\n", timeout_completions > 0, timeout_completions);
        $fwrite(fd, "cross_run_parity,%0d,%0d\n", parity_completions > 0, parity_completions);
        $fwrite(fd, "cross_crypto_reject,%0d,%0d\n", (test_name == "crypto_only_reject") && (blocked_rejects > 0), blocked_rejects);
        $fwrite(fd, "cross_sleep_resume,%0d,%0d\n", (test_name == "sleep_resume") && restore_seen && (successful_completions > 0), restore_seen);
        $fwrite(fd, "cross_deep_invalid,%0d,%0d\n", (test_name == "deep_sleep_invalid_source") && deep_sleep_applied && (invalid_completions > 0), invalid_completions);
        $fwrite(fd, "cross_wait_no_retire,%0d,%0d\n", (wait_cycles_seen > 0) && (assertion_failures == 0), wait_cycles_seen);
        $fwrite(fd, "scenario_%s,%0d,1\n", test_name, pass);
        $fclose(fd);
    endtask

    initial begin
        bit pass;
        test_name = "dma_smoke";
        coverage_path = "reports/firmware_coverage.csv";
        reference_path = "";
        trace_path = "";
        void'($value$plusargs("TEST=%s", test_name));
        void'($value$plusargs("COVER_OUT=%s", coverage_path));
        void'($value$plusargs("REF_CSV=%s", reference_path));
        void'($value$plusargs("TRACE_OUT=%s", trace_path));

        errors = 0;
        cycles = 0;
        mmio_reads = 0;
        mmio_writes = 0;
        wait_cycles_seen = 0;
        wait_read_cycles = 0;
        wait_write_cycles = 0;
        bus_errors_seen = 0;
        range_errors_seen = 0;
        unaligned_errors_seen = 0;
        irq_poll_reads = 0;
        irq_high_cycles = 0;
        doorbells_seen = 0;
        completion_pops = 0;
        submit_accepts = 0;
        submit_rejects = 0;
        queue_full_rejects = 0;
        blocked_rejects = 0;
        completion_pushes = 0;
        successful_completions = 0;
        runtime_error_completions = 0;
        reject_completions = 0;
        timeout_completions = 0;
        parity_completions = 0;
        invalid_completions = 0;
        destination_writes = 0;
        software_completion_reads = 0;
        completion_order_errors = 0;
        assertion_failures = 0;
        sleep_hold = 0;
        deep_sleep_hold = 0;
        reset_hold = 0;
        sleep_applied = 1'b0;
        deep_sleep_applied = 1'b0;
        reset_applied = 1'b0;
        reset_recovery_seen = 1'b0;
        restore_seen = 1'b0;
        prior_doorbell = 1'b0;
        irq_masked_pending_seen = 1'b0;
        irq_pending_then_enable_seen = 1'b0;
        irq_cleared_seen = 1'b0;
        comp_full_stall_seen = 1'b0;
        stall_front_snapshot_valid = 1'b0;
        wait_without_retire_seen = 1'b0;
        link_hold_active = 1'b0;
        return_suppress_active = 1'b0;
        accepted_tag_count = 0;
        accepted_completion_count = 0;
        submitted_tag_count = 0;
        accepted_submit_check_count = 0;
        submission_correlation_errors = 0;
        firmware_staged_tag = '0;
        for (int idx = 0; idx < 16; idx++) begin
            accepted_tags[idx] = '0;
            submitted_tags[idx] = '0;
        end
        trace_fd = 0;
        rst_n = 1'b0;
        power_state = (test_name == "crypto_only_reject") ? PWR_CRYPTO_ONLY : PWR_RUN;
        dma_mode_force = 1'b1;
        apb_wait_cycles = ((test_name == "apb_wait_error") ||
                           (test_name == "apb_reset_mid_wait")) ? 4'd3 : 4'd0;

        if (trace_path != "") begin
            trace_fd = $fopen(trace_path, "w");
            $fwrite(trace_fd, "cycle,commit_pc,commit_instr,commit_valid,psel,penable,pready,paddr,pwrite,submit_accept,completion_push,irq,halted,power_state,restore_dma_sleep,mmio_access_enable\n");
        end
        if (reference_path != "") u_ref.load_reference(reference_path); else u_ref.clear_reference();

        repeat (10) @(posedge clk);
        @(negedge clk);
        preload_source_memory();
        rst_n = 1'b1;

        while (!cpu_halted && cycles < 100000) @(posedge clk);
        if (!cpu_halted) begin
            errors++;
            $error("Firmware scenario %s timed out", test_name);
        end
        repeat (8) @(posedge clk);
        if (link_hold_active) begin
            release dut.u_chiplet.u_die_a.tx_stream_ready;
            link_hold_active = 1'b0;
        end
        if (return_suppress_active) begin
            release dut.u_chiplet.u_die_a.dma_rx_stream_valid;
            return_suppress_active = 1'b0;
        end

        case (test_name)
            "dma_smoke": begin
                if (dut.u_cpu.data_mem_q[0] != 32'h101) errors++;
                if (dut.u_cpu.data_mem_q[1] != 32'h10) errors++;
                if (dut.u_cpu.data_mem_q[2] != 32'd4) errors++;
                compare_destination(32, 4);
            end
            "dma_back_to_back": begin
                if (dut.u_cpu.data_mem_q[0] != 32'h101 || dut.u_cpu.data_mem_q[1] != 32'h102) errors++;
                compare_destination(32, 4);
                compare_destination(40, 4);
            end
            "crypto_only_reject": begin
                if (!dut.u_cpu.data_mem_q[0][1] || dut.u_cpu.data_mem_q[0][5:2] != 4'd5) errors++;
                if (submit_accepts != 0) errors++;
            end
            "apb_wait_error": begin
                if (wait_cycles_seen == 0 || bus_errors_seen != 2 ||
                    range_errors_seen != 1 || unaligned_errors_seen != 1) errors++;
            end
            "sleep_resume": begin
                if (dut.u_cpu.data_mem_q[0] != 32'h177 || !sleep_applied || !restore_seen) errors++;
                compare_destination(48, 8);
            end
            "irq_pending_then_enable": begin
                if (!dut.u_cpu.data_mem_q[0][0] || !dut.u_cpu.data_mem_q[1][0] ||
                    dut.u_cpu.data_mem_q[2] != 32'h201 || !irq_masked_pending_seen ||
                    irq_high_cycles == 0 || irq_done || dut.u_chiplet.u_die_a.u_dma.irq_status_q != 0) errors++;
                compare_destination(64, 4);
            end
            "queue_full_reject": begin
                if (!dut.u_cpu.data_mem_q[0][1] || dut.u_cpu.data_mem_q[0][5:2] != 4'd3 ||
                    dut.u_cpu.data_mem_q[1] != 32'h306 || dut.u_cpu.data_mem_q[2][5:0] != 6'h33 ||
                    submit_accepts != 5 || queue_full_rejects != 1 || destination_writes != 0) errors++;
            end
            "completion_fifo_stall": begin
                if (!dut.u_cpu.data_mem_q[0][4] || dut.u_cpu.data_mem_q[0][2:0] != 3'd4 ||
                    dut.u_cpu.data_mem_q[1] != 32'h401 ||
                    dut.u_cpu.data_mem_q[2] != 32'h402 || dut.u_cpu.data_mem_q[3] != 32'h403 ||
                    dut.u_cpu.data_mem_q[4] != 32'h404 || dut.u_cpu.data_mem_q[5] != 32'h405) begin
                    record_assertion_failure("firmware_completion_front_stable_while_stalled");
                end
                if (submit_accepts != 5 || successful_completions != 5 || completion_pops != 5) errors++;
                compare_destination(96, 20);
            end
            "timeout_error": begin
                if (dut.u_cpu.data_mem_q[0][5:0] != 6'h24 || dut.u_cpu.data_mem_q[1] != 0 ||
                    timeout_completions != 1 || destination_writes != 0) errors++;
            end
            "parity_source_error": begin
                if (dut.u_cpu.data_mem_q[0][5:0] != 6'h26 || parity_completions != 1 ||
                    destination_writes != 0 || dut.u_cpu.data_mem_q[1][13:11] != 3'd2) errors++;
            end
            "deep_sleep_invalid_source": begin
                if (dut.u_cpu.data_mem_q[0][5:0] != 6'h27 || invalid_completions != 1 ||
                    destination_writes != 0 || !deep_sleep_applied || dut.u_cpu.data_mem_q[1][1:0] == 0) errors++;
            end
            "apb_reset_mid_wait": begin
                if (!reset_applied || !rst_n || dut.u_cpu.data_mem_q[0] != 32'h181 ||
                    doorbells_seen != 1 || submit_accepts != 1 || successful_completions != 1 ||
                    bus_errors_seen != 0) errors++;
                compare_destination(120, 4);
            end
            default: begin
                errors++;
                $error("Unknown firmware scenario %s", test_name);
            end
        endcase

        if (ref_mismatch_count != 0) errors += ref_mismatch_count;
        pass = (errors == 0);
        write_coverage(pass);
        if (trace_fd != 0) $fclose(trace_fd);
        $display("FIRMWARE_RESULT|test=%s|status=%s|cycles=%0d|mmio_reads=%0d|mmio_writes=%0d|wait=%0d|bus_errors=%0d|doorbells=%0d|accepts=%0d|rejects=%0d|completions=%0d|success=%0d|runtime_errors=%0d|assertion_failures=%0d|mem_mismatch=%0d",
                 test_name, pass ? "PASS" : "FAIL", cycles, mmio_reads, mmio_writes,
                 wait_cycles_seen, bus_errors_seen, doorbells_seen, submit_accepts, submit_rejects,
                 completion_pushes, successful_completions, runtime_error_completions,
                 assertion_failures, ref_mismatch_count);
        $display("FIRMWARE_STATE|mem0=%08x|mem1=%08x|mem2=%08x|mem3=%08x|mem4=%08x|mem5=%08x|irq_masked=%0d|irq_enabled_pending=%0d|irq_cleared=%0d|irq_high_cycles=%0d|irq_en=%0d|irq_status=%0d|stall_seen=%0d|reset_recovered=%0d",
                 dut.u_cpu.data_mem_q[0], dut.u_cpu.data_mem_q[1], dut.u_cpu.data_mem_q[2],
                 dut.u_cpu.data_mem_q[3], dut.u_cpu.data_mem_q[4], dut.u_cpu.data_mem_q[5],
                 irq_masked_pending_seen, irq_pending_then_enable_seen, irq_cleared_seen, irq_high_cycles,
                 dut.u_chiplet.u_die_a.u_dma.irq_en_q, dut.u_chiplet.u_die_a.u_dma.irq_status_q,
                 comp_full_stall_seen, reset_recovery_seen);
        if (!pass) $fatal(1, "Firmware scenario %s failed with %0d errors", test_name, errors);
        $finish;
    end

endmodule : tb_firmware_soc
