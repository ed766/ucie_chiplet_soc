`timescale 1ns/1ps

module tb_axi_lite_csr_wrapper;
    localparam logic [1:0] AXI_RESP_OKAY  = 2'b00;
    localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam logic [31:0] DMA_CTRL_ADDR = 32'h00;
    localparam logic [31:0] DMA_SRC_BASE_ADDR = 32'h08;
    localparam logic [31:0] DMA_DST_BASE_ADDR = 32'h0c;
    localparam logic [31:0] DMA_LEN_ADDR = 32'h10;
    localparam logic [31:0] DMA_TAG_ADDR = 32'h14;
    localparam logic [31:0] DMA_SUBMIT_STATUS_ADDR = 32'h30;
    localparam logic [31:0] DMA_SUBMIT_RESULT_ADDR = 32'h50;

    logic clk;
    logic rst_n;

    logic [31:0] awaddr;
    logic awvalid;
    logic awready;
    logic [31:0] wdata;
    logic [3:0] wstrb;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [31:0] araddr;
    logic arvalid;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic cfg_ready;

    integer errors;
    integer assertion_failures;
    integer csr_write_accepts;
    integer csr_read_accepts;
    logic [31:0] csr_mem [0:63];
    logic doorbell_seen;

    bit cov_basic_rw;
    bit cov_doorbell;
    bit cov_write_simultaneous;
    bit cov_write_aw_first;
    bit cov_write_w_first;
    bit cov_back_to_back;
    bit cov_b_backpressure;
    bit cov_r_backpressure;
    bit cov_write_wait_state;
    bit cov_read_wait_state;
    bit cov_partial_wstrb;
    bit cov_out_of_range;
    bit cov_unaligned;
    bit cov_read_while_write_pending;
    bit cov_reset_pending_write;
    bit cov_reset_pending_read;
    bit cov_resp_okay;
    bit cov_resp_slverr;

    logic prev_awvalid;
    logic prev_awready;
    logic [31:0] prev_awaddr;
    logic prev_wvalid;
    logic prev_wready;
    logic [31:0] prev_wdata;
    logic [3:0] prev_wstrb;
    logic prev_arvalid;
    logic prev_arready;
    logic [31:0] prev_araddr;
    logic prev_bvalid;
    logic prev_bready;
    logic [1:0] prev_bresp;
    logic prev_rvalid;
    logic prev_rready;
    logic [31:0] prev_rdata;
    logic [1:0] prev_rresp;

    axi_lite_csr_bridge u_bridge (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),
        .cfg_valid(cfg_valid),
        .cfg_write(cfg_write),
        .cfg_addr(cfg_addr),
        .cfg_wdata(cfg_wdata),
        .cfg_rdata(cfg_rdata),
        .cfg_ready(cfg_ready)
    );

    assign cfg_rdata = csr_mem[cfg_addr[7:2]];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            doorbell_seen <= 1'b0;
            csr_write_accepts <= 0;
            csr_read_accepts <= 0;
            for (int i = 0; i < 64; i++) begin
                csr_mem[i] <= 32'h0;
            end
        end else begin
            if (cfg_valid && cfg_ready && cfg_write) begin
                csr_write_accepts <= csr_write_accepts + 1;
                csr_mem[cfg_addr[7:2]] <= cfg_wdata;
                if (cfg_addr == DMA_CTRL_ADDR[7:0] && cfg_wdata[0]) begin
                    doorbell_seen <= 1'b1;
                    csr_mem[DMA_SUBMIT_RESULT_ADDR[7:2]] <= 32'h0000_0001;
                    csr_mem[DMA_SUBMIT_STATUS_ADDR[7:2]] <= 32'h0000_0040;
                end
            end
            if (cfg_valid && cfg_ready && !cfg_write) begin
                csr_read_accepts <= csr_read_accepts + 1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_awvalid <= 1'b0;
            prev_awready <= 1'b0;
            prev_awaddr <= '0;
            prev_wvalid <= 1'b0;
            prev_wready <= 1'b0;
            prev_wdata <= '0;
            prev_wstrb <= '0;
            prev_arvalid <= 1'b0;
            prev_arready <= 1'b0;
            prev_araddr <= '0;
            prev_bvalid <= 1'b0;
            prev_bready <= 1'b0;
            prev_bresp <= '0;
            prev_rvalid <= 1'b0;
            prev_rready <= 1'b0;
            prev_rdata <= '0;
            prev_rresp <= '0;
        end else begin
            if (prev_awvalid && !prev_awready && awvalid && awaddr !== prev_awaddr) begin
                record_assertion_failure("awaddr_stable_while_backpressured");
            end
            if (prev_wvalid && !prev_wready && wvalid &&
                (wdata !== prev_wdata || wstrb !== prev_wstrb)) begin
                record_assertion_failure("wdata_wstrb_stable_while_backpressured");
            end
            if (prev_arvalid && !prev_arready && arvalid && araddr !== prev_araddr) begin
                record_assertion_failure("araddr_stable_while_backpressured");
            end
            if (prev_bvalid && !prev_bready &&
                (!bvalid || bresp !== prev_bresp)) begin
                record_assertion_failure("bresp_stable_while_bready_low");
            end
            if (prev_rvalid && !prev_rready &&
                (!rvalid || rdata !== prev_rdata || rresp !== prev_rresp)) begin
                record_assertion_failure("rdata_rresp_stable_while_rready_low");
            end

            prev_awvalid <= awvalid;
            prev_awready <= awready;
            prev_awaddr <= awaddr;
            prev_wvalid <= wvalid;
            prev_wready <= wready;
            prev_wdata <= wdata;
            prev_wstrb <= wstrb;
            prev_arvalid <= arvalid;
            prev_arready <= arready;
            prev_araddr <= araddr;
            prev_bvalid <= bvalid;
            prev_bready <= bready;
            prev_bresp <= bresp;
            prev_rvalid <= rvalid;
            prev_rready <= rready;
            prev_rdata <= rdata;
            prev_rresp <= rresp;
        end
    end

    task automatic record_assertion_failure(input string name);
        begin
            $error("AXI assertion failed: %s", name);
            assertion_failures++;
            errors++;
        end
    endtask

    task automatic reset_dut();
        begin
            rst_n = 1'b1;
            awaddr = '0;
            awvalid = 1'b0;
            wdata = '0;
            wstrb = 4'hf;
            wvalid = 1'b0;
            bready = 1'b0;
            araddr = '0;
            arvalid = 1'b0;
            rready = 1'b0;
            cfg_ready = 1'b1;
            #1;
            rst_n = 1'b0;
            repeat (4) @(posedge clk);
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
        end
    endtask

    task automatic note_resp(input logic [1:0] resp);
        begin
            if (resp == AXI_RESP_OKAY) begin
                cov_resp_okay = 1'b1;
            end
            if (resp == AXI_RESP_SLVERR) begin
                cov_resp_slverr = 1'b1;
            end
        end
    endtask

    task automatic expect_resp(input logic [1:0] actual, input logic [1:0] expected, input string label);
        begin
            note_resp(actual);
            if (actual !== expected) begin
                $error("%s response mismatch: got %0d expected %0d", label, actual, expected);
                errors++;
            end
        end
    endtask

    task automatic expect_data(input logic [31:0] actual, input logic [31:0] expected, input string label);
        begin
            if (actual !== expected) begin
                $error("%s data mismatch: got 0x%08x expected 0x%08x", label, actual, expected);
                errors++;
            end
        end
    endtask

    task automatic wait_cycles(input int cycles);
        begin
            repeat (cycles) @(posedge clk);
        end
    endtask

    task automatic release_cfg_after(input int cycles);
        begin
            wait_cycles(cycles);
            cfg_ready = 1'b1;
        end
    endtask

    task automatic axi_write_custom(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb,
        input int aw_first_delay,
        input int w_first_delay,
        input int bready_delay,
        input int cfg_wait_cycles,
        output logic [1:0] resp
    );
        int timeout;
        bit aw_sampled;
        bit w_sampled;
        begin
            if (cfg_wait_cycles > 0) begin
                cfg_ready = 1'b0;
                fork
                    release_cfg_after(cfg_wait_cycles);
                join_none
            end else begin
                cfg_ready = 1'b1;
            end

            bready = 1'b0;
            @(posedge clk);
            #1;
            @(negedge clk);
            awaddr = addr;
            wdata = data;
            wstrb = strb;
            if (w_first_delay > 0) begin
                cov_write_aw_first = 1'b1;
                awvalid = 1'b1;
                timeout = 0;
                while (awvalid && timeout < 40) begin
                    aw_sampled = awvalid && awready;
                    @(posedge clk);
                    #1;
                    if (aw_sampled) begin
                        awvalid = 1'b0;
                    end
                    timeout++;
                    if (awvalid) begin
                        @(negedge clk);
                    end
                end
                if (awvalid) begin
                    $fatal(1, "AXI AW-first address handshake timeout at 0x%08x", addr);
                end
                wait_cycles(w_first_delay);
                wvalid = 1'b1;
            end else if (aw_first_delay > 0) begin
                cov_write_w_first = 1'b1;
                wvalid = 1'b1;
                timeout = 0;
                while (wvalid && timeout < 40) begin
                    w_sampled = wvalid && wready;
                    @(posedge clk);
                    #1;
                    if (w_sampled) begin
                        wvalid = 1'b0;
                    end
                    timeout++;
                    if (wvalid) begin
                        @(negedge clk);
                    end
                end
                if (wvalid) begin
                    $fatal(1, "AXI W-first data handshake timeout at 0x%08x", addr);
                end
                wait_cycles(aw_first_delay);
                awvalid = 1'b1;
            end else begin
                awvalid = 1'b1;
                wvalid = 1'b1;
                cov_write_simultaneous = 1'b1;
            end

            timeout = 0;
            while ((awvalid || wvalid) && timeout < 40) begin
                aw_sampled = awvalid && awready;
                w_sampled = wvalid && wready;
                @(posedge clk);
                #1;
                if (aw_sampled) begin
                    awvalid = 1'b0;
                end
                if (w_sampled) begin
                    wvalid = 1'b0;
                end
                timeout++;
                if (awvalid || wvalid) begin
                    @(negedge clk);
                end
            end
            if (awvalid || wvalid) begin
                $fatal(1, "AXI write address/data handshake timeout at 0x%08x awvalid=%0b awready=%0b wvalid=%0b wready=%0b bvalid=%0b rst_n=%0b",
                       addr, awvalid, awready, wvalid, wready, bvalid, rst_n);
            end

            bready = 1'b0;
            timeout = 0;
            while (!bvalid && timeout < 80) begin
                @(posedge clk);
                #1;
                timeout++;
            end
            if (!bvalid) begin
                $fatal(1, "AXI write response timeout at 0x%08x", addr);
            end
            if (bready_delay > 0) begin
                cov_b_backpressure = 1'b1;
                wait_cycles(bready_delay);
            end
            resp = bresp;
            bready = 1'b1;
            @(posedge clk);
            #1;
            bready = 1'b0;
            cfg_ready = 1'b1;
        end
    endtask

    task automatic axi_read_custom(
        input logic [31:0] addr,
        input int rready_delay,
        input int cfg_wait_cycles,
        output logic [31:0] data,
        output logic [1:0] resp
    );
        int timeout;
        bit ar_sampled;
        begin
            if (cfg_wait_cycles > 0) begin
                cfg_ready = 1'b0;
                fork
                    release_cfg_after(cfg_wait_cycles);
                join_none
            end else begin
                cfg_ready = 1'b1;
            end

            rready = 1'b0;
            @(posedge clk);
            #1;
            @(negedge clk);
            araddr = addr;
            arvalid = 1'b1;
            timeout = 0;
            while (arvalid && timeout < 40) begin
                ar_sampled = arvalid && arready;
                @(posedge clk);
                #1;
                if (ar_sampled) begin
                    arvalid = 1'b0;
                end
                timeout++;
                if (arvalid) begin
                    @(negedge clk);
                end
            end
            if (arvalid) begin
                $fatal(1, "AXI read address handshake timeout at 0x%08x", addr);
            end
            rready = 1'b0;
            timeout = 0;
            while (!rvalid && timeout < 80) begin
                @(posedge clk);
                #1;
                timeout++;
            end
            if (!rvalid) begin
                $fatal(1, "AXI read response timeout at 0x%08x", addr);
            end
            if (rready_delay > 0) begin
                cov_r_backpressure = 1'b1;
                wait_cycles(rready_delay);
            end
            data = rdata;
            resp = rresp;
            rready = 1'b1;
            @(posedge clk);
            #1;
            rready = 1'b0;
            cfg_ready = 1'b1;
        end
    endtask

    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data, output logic [1:0] resp);
        begin
            axi_write_custom(addr, data, 4'hf, 0, 0, 0, 0, resp);
        end
    endtask

    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
        begin
            axi_read_custom(addr, 0, 0, data, resp);
        end
    endtask

    task automatic check_no_csr_write(input int before_count, input string label);
        begin
            if (csr_write_accepts != before_count) begin
                $error("%s unexpectedly changed accepted CSR write count", label);
                errors++;
            end
        end
    endtask

    task automatic scenario_basic_and_doorbell();
        logic [1:0] resp;
        logic [31:0] data;
        begin
            axi_write(DMA_SRC_BASE_ADDR, 32'd8, resp);
            expect_resp(resp, AXI_RESP_OKAY, "SRC_BASE write");
            axi_write(DMA_DST_BASE_ADDR, 32'd128, resp);
            expect_resp(resp, AXI_RESP_OKAY, "DST_BASE write");
            axi_write(DMA_LEN_ADDR, 32'd4, resp);
            expect_resp(resp, AXI_RESP_OKAY, "LEN write");
            axi_write(DMA_TAG_ADDR, 32'h0000_0042, resp);
            expect_resp(resp, AXI_RESP_OKAY, "TAG write");
            axi_read(DMA_TAG_ADDR, data, resp);
            expect_resp(resp, AXI_RESP_OKAY, "TAG read");
            expect_data(data, 32'h0000_0042, "TAG readback");
            cov_basic_rw = 1'b1;

            axi_write(DMA_CTRL_ADDR, 32'h0000_0001, resp);
            expect_resp(resp, AXI_RESP_OKAY, "doorbell write");
            if (!doorbell_seen) begin
                $error("AXI-Lite doorbell write did not reach cfg interface");
                errors++;
            end
            axi_read(DMA_SUBMIT_RESULT_ADDR, data, resp);
            expect_resp(resp, AXI_RESP_OKAY, "submit result read");
            if (data[0] !== 1'b1) begin
                $error("AXI-Lite doorbell did not produce accepted submit result: 0x%08x", data);
                errors++;
            end
            cov_doorbell = 1'b1;
        end
    endtask

    task automatic scenario_split_and_backpressure();
        logic [1:0] resp;
        logic [31:0] data;
        begin
            axi_write_custom(DMA_TAG_ADDR, 32'h0000_00a1, 4'hf, 0, 3, 0, 0, resp);
            expect_resp(resp, AXI_RESP_OKAY, "AW-before-W split write");
            axi_write_custom(DMA_TAG_ADDR, 32'h0000_00b2, 4'hf, 3, 0, 0, 0, resp);
            expect_resp(resp, AXI_RESP_OKAY, "W-before-AW split write");
            axi_write_custom(DMA_TAG_ADDR, 32'h0000_00c3, 4'hf, 0, 0, 3, 0, resp);
            expect_resp(resp, AXI_RESP_OKAY, "B channel delayed ready write");
            axi_read_custom(DMA_TAG_ADDR, 3, 0, data, resp);
            expect_resp(resp, AXI_RESP_OKAY, "R channel delayed ready read");
            expect_data(data, 32'h0000_00c3, "R channel delayed ready readback");
            cov_back_to_back = 1'b1;
        end
    endtask

    task automatic scenario_wait_states();
        logic [1:0] resp;
        logic [31:0] data;
        int before_writes;
        int before_reads;
        begin
            before_writes = csr_write_accepts;
            axi_write_custom(DMA_TAG_ADDR, 32'h0000_00d4, 4'hf, 0, 0, 0, 4, resp);
            expect_resp(resp, AXI_RESP_OKAY, "write cfg_ready wait-state");
            if (csr_write_accepts != before_writes + 1) begin
                $error("Write wait-state produced %0d CSR write accepts, expected one",
                       csr_write_accepts - before_writes);
                errors++;
            end
            cov_write_wait_state = 1'b1;

            before_reads = csr_read_accepts;
            axi_read_custom(DMA_TAG_ADDR, 0, 4, data, resp);
            expect_resp(resp, AXI_RESP_OKAY, "read cfg_ready wait-state");
            expect_data(data, 32'h0000_00d4, "read wait-state data");
            if (csr_read_accepts != before_reads + 1) begin
                $error("Read wait-state produced %0d CSR read accepts, expected one",
                       csr_read_accepts - before_reads);
                errors++;
            end
            cov_read_wait_state = 1'b1;
        end
    endtask

    task automatic scenario_invalid_accesses();
        logic [1:0] resp;
        logic [31:0] data;
        int before_count;
        begin
            axi_read(32'h0000_0100, data, resp);
            expect_resp(resp, AXI_RESP_SLVERR, "out-of-range read");
            before_count = csr_write_accepts;
            axi_write(32'h0000_0100, 32'h1111_2222, resp);
            expect_resp(resp, AXI_RESP_SLVERR, "out-of-range write");
            check_no_csr_write(before_count, "out-of-range write");
            cov_out_of_range = 1'b1;

            axi_read(32'h0000_0002, data, resp);
            expect_resp(resp, AXI_RESP_SLVERR, "unaligned read");
            before_count = csr_write_accepts;
            axi_write(32'h0000_0002, 32'h1234_5678, resp);
            expect_resp(resp, AXI_RESP_SLVERR, "unaligned write");
            check_no_csr_write(before_count, "unaligned write");
            cov_unaligned = 1'b1;

            before_count = csr_write_accepts;
            axi_write_custom(DMA_TAG_ADDR, 32'hdead_beef, 4'h3, 0, 0, 0, 0, resp);
            expect_resp(resp, AXI_RESP_SLVERR, "partial strobe write");
            check_no_csr_write(before_count, "partial strobe write");
            cov_partial_wstrb = 1'b1;
        end
    endtask

    task automatic scenario_read_while_write_pending();
        logic [1:0] resp;
        logic [31:0] data;
        int timeout;
        begin
            cfg_ready = 1'b0;
            @(negedge clk);
            awaddr = DMA_TAG_ADDR;
            awvalid = 1'b1;
            wdata = 32'h0000_00e5;
            wstrb = 4'hf;
            wvalid = 1'b1;
            bready = 1'b0;
            timeout = 0;
            while (!(awready && wready) && timeout < 20) begin
                @(negedge clk);
                timeout++;
            end
            if (!(awready && wready)) begin
                $fatal(1, "Pending-write setup failed to observe AW/W ready");
            end
            @(posedge clk);
            #1;
            awvalid = 1'b0;
            wvalid = 1'b0;
            @(negedge clk);
            araddr = DMA_TAG_ADDR;
            arvalid = 1'b1;
            @(posedge clk);
            #1;
            if (arready) begin
                $error("Read was accepted while write response was pending on cfg_ready");
                errors++;
            end
            arvalid = 1'b0;
            cov_read_while_write_pending = 1'b1;
            cfg_ready = 1'b1;
            timeout = 0;
            while (!bvalid && timeout < 40) begin
                @(posedge clk);
                #1;
                timeout++;
            end
            if (!bvalid) begin
                $fatal(1, "Pending write did not complete after cfg_ready release");
            end
            resp = bresp;
            bready = 1'b1;
            @(posedge clk);
            bready = 1'b0;
            expect_resp(resp, AXI_RESP_OKAY, "pending write completion");
            axi_read(DMA_TAG_ADDR, data, resp);
            expect_resp(resp, AXI_RESP_OKAY, "post-pending read");
            expect_data(data, 32'h0000_00e5, "post-pending readback");
        end
    endtask

    task automatic scenario_reset_recovery();
        int timeout;
        begin
            reset_dut();
            cfg_ready = 1'b0;
            @(negedge clk);
            awaddr = DMA_TAG_ADDR;
            awvalid = 1'b1;
            wdata = 32'h0000_00f6;
            wstrb = 4'hf;
            wvalid = 1'b1;
            bready = 1'b0;
            timeout = 0;
            while (!(awready && wready) && timeout < 20) begin
                @(negedge clk);
                timeout++;
            end
            if (!(awready && wready)) begin
                $fatal(1, "Pending write reset setup failed");
            end
            @(posedge clk);
            #1;
            awvalid = 1'b0;
            wvalid = 1'b0;
            rst_n = 1'b0;
            wait_cycles(3);
            if (bvalid || rvalid) begin
                $error("Pending write reset did not clear AXI response state");
                errors++;
            end
            cfg_ready = 1'b1;
            rst_n = 1'b1;
            wait_cycles(2);
            cov_reset_pending_write = 1'b1;

            @(negedge clk);
            cfg_ready = 1'b0;
            araddr = DMA_TAG_ADDR;
            arvalid = 1'b1;
            rready = 1'b0;
            timeout = 0;
            while (!arready && timeout < 20) begin
                @(negedge clk);
                timeout++;
            end
            if (!arready) begin
                $fatal(1, "Pending read reset setup failed");
            end
            @(posedge clk);
            #1;
            arvalid = 1'b0;
            rst_n = 1'b0;
            wait_cycles(3);
            if (rvalid || bvalid) begin
                $error("Pending read reset did not clear AXI response state");
                errors++;
            end
            cfg_ready = 1'b1;
            rst_n = 1'b1;
            wait_cycles(2);
            rready = 1'b0;
            cov_reset_pending_read = 1'b1;
        end
    endtask

    function automatic int coverage_hits();
        coverage_hits = int'(cov_basic_rw) +
                        int'(cov_doorbell) +
                        int'(cov_write_simultaneous) +
                        int'(cov_write_aw_first) +
                        int'(cov_write_w_first) +
                        int'(cov_back_to_back) +
                        int'(cov_b_backpressure) +
                        int'(cov_r_backpressure) +
                        int'(cov_write_wait_state) +
                        int'(cov_read_wait_state) +
                        int'(cov_partial_wstrb) +
                        int'(cov_out_of_range) +
                        int'(cov_unaligned) +
                        int'(cov_read_while_write_pending) +
                        int'(cov_reset_pending_write) +
                        int'(cov_reset_pending_read) +
                        int'(cov_resp_okay) +
                        int'(cov_resp_slverr);
    endfunction

    task automatic emit_cov(input string name, input bit hit);
        begin
            $display("AXIL_COV|name=%s|hit=%0d", name, hit ? 1 : 0);
        end
    endtask

    task automatic emit_report();
        begin
            emit_cov("basic_rw", cov_basic_rw);
            emit_cov("doorbell", cov_doorbell);
            emit_cov("write_simultaneous", cov_write_simultaneous);
            emit_cov("write_aw_first", cov_write_aw_first);
            emit_cov("write_w_first", cov_write_w_first);
            emit_cov("back_to_back", cov_back_to_back);
            emit_cov("b_backpressure", cov_b_backpressure);
            emit_cov("r_backpressure", cov_r_backpressure);
            emit_cov("write_wait_state", cov_write_wait_state);
            emit_cov("read_wait_state", cov_read_wait_state);
            emit_cov("partial_wstrb_slverr", cov_partial_wstrb);
            emit_cov("out_of_range_slverr", cov_out_of_range);
            emit_cov("unaligned_slverr", cov_unaligned);
            emit_cov("read_while_write_pending", cov_read_while_write_pending);
            emit_cov("reset_pending_write", cov_reset_pending_write);
            emit_cov("reset_pending_read", cov_reset_pending_read);
            emit_cov("resp_okay", cov_resp_okay);
            emit_cov("resp_slverr", cov_resp_slverr);
            $display("AXIL_ASSERTIONS|count=6|failures=%0d", assertion_failures);
        end
    endtask

    initial begin
        repeat (4000) @(posedge clk);
        $fatal(1, "AXI-Lite CSR wrapper test timed out");
    end

    initial begin
        errors = 0;
        assertion_failures = 0;
        cov_basic_rw = 1'b0;
        cov_doorbell = 1'b0;
        cov_write_simultaneous = 1'b0;
        cov_write_aw_first = 1'b0;
        cov_write_w_first = 1'b0;
        cov_back_to_back = 1'b0;
        cov_b_backpressure = 1'b0;
        cov_r_backpressure = 1'b0;
        cov_write_wait_state = 1'b0;
        cov_read_wait_state = 1'b0;
        cov_partial_wstrb = 1'b0;
        cov_out_of_range = 1'b0;
        cov_unaligned = 1'b0;
        cov_read_while_write_pending = 1'b0;
        cov_reset_pending_write = 1'b0;
        cov_reset_pending_read = 1'b0;
        cov_resp_okay = 1'b0;
        cov_resp_slverr = 1'b0;

        reset_dut();
        scenario_basic_and_doorbell();
        scenario_split_and_backpressure();
        scenario_wait_states();
        scenario_invalid_accesses();
        scenario_read_while_write_pending();
        scenario_reset_recovery();
        emit_report();

        if (errors == 0 && coverage_hits() == 18) begin
            $display("AXIL_RESULT|status=PASS|detail=axi_lite_protocol_edges|coverage=%0d/18|assertions=6|assertion_failures=%0d",
                     coverage_hits(), assertion_failures);
            $finish;
        end else begin
            $display("AXIL_RESULT|status=FAIL|detail=axi_lite_protocol_edges|errors=%0d|coverage=%0d/18|assertion_failures=%0d",
                     errors, coverage_hits(), assertion_failures);
            $fatal(1, "AXI-Lite CSR wrapper test failed");
        end
    end

endmodule : tb_axi_lite_csr_wrapper
