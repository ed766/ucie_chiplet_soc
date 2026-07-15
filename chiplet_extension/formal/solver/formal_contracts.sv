// Yosys-compatible immediate-assertion wrappers for solver-backed proofs.
module formal_credit;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic [3:0] debit, returned;
    logic [3:0] available;
    logic [3:0] previous_available, previous_debit, previous_returned;
    logic underflow, overflow;
    logic past_valid = 0;
    logic model_valid = 0;
    function automatic logic [3:0] credit_model(
        input logic [3:0] prior,
        input logic [3:0] debit_value,
        input logic [3:0] return_value
    );
        logic signed [5:0] result;
        begin
            result = $signed({1'b0, prior}) - $signed({1'b0, debit_value})
                   + $signed({1'b0, return_value});
            if (result < 0) credit_model = 0;
            else if (result > 8) credit_model = 8;
            else credit_model = result[3:0];
        end
    endfunction
    credit_mgr #(.CREDIT_WIDTH(4), .MAX_CREDITS(8)) dut (
        .clk, .rst_n, .credit_init(4'd4), .credit_debit(debit),
        .credit_return(returned), .credit_available(available), .underflow, .overflow
    );
    always @(posedge clk) begin
        past_valid <= 1;
        model_valid <= past_valid && rst_n;
        rst_n <= 1;
        if (model_valid) begin
            assert(available <= 8);
            assert(available == credit_model(previous_available, previous_debit, previous_returned));
        end
        previous_available <= available;
        previous_debit <= debit;
        previous_returned <= returned;
        cover(underflow || overflow);
    end
endmodule

module formal_apb;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic [31:0] paddr, pwdata;
    (* anyseq *) logic psel, penable, pwrite;
    logic [31:0] prdata;
    logic pready, pslverr, cfg_valid, cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic transfer_active, op_seen;
    logic past_valid = 0;
    apb_dma_csr_bridge dut (
        .pclk(clk), .presetn(rst_n), .paddr, .psel, .penable, .pwrite, .pwdata,
        .prdata, .pready, .pslverr, .wait_cycles(4'd2), .access_enable(1'b1),
        .cfg_valid, .cfg_write, .cfg_addr, .cfg_wdata, .cfg_rdata(32'h12345678), .cfg_ready(1'b1)
    );
    always @(posedge clk) begin
        past_valid <= 1;
        rst_n <= 1;
        if (!rst_n) begin transfer_active <= 0; op_seen <= 0; end
        else begin
            assume(!penable || psel);
            if (psel && !penable) begin
                assume(!transfer_active);
                transfer_active <= 1;
                op_seen <= 0;
            end
            if (cfg_valid) begin
                assert(transfer_active);
                assert(!op_seen);
                op_seen <= 1;
`ifdef FORMAL_MUTATE_APB
                assert(op_seen);
`endif
            end
            if (pready) transfer_active <= 0;
            assert(!pslverr || !cfg_valid);
            cover(cfg_valid && cfg_write);
        end
    end
endmodule

module formal_retry;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic [15:0] flit_in;
    (* anyseq *) logic flit_valid, resend_request;
    logic flit_ready, send_fire, resend_fire;
    logic [15:0] send_flit, last_new;
    logic have_last;
    ucie_tx #(.LANES(8), .FLIT_WIDTH(16)) dut (
        .clk, .rst_n, .flit_in, .flit_valid, .flit_ready, .link_ready(1'b1),
        .resend_request, .crc_error(), .available_credits(16'd8), .credit_consumed(),
        .lane_tx_valid(), .lane_tx_data(), .lane_link_enable(), .lane_link_training(),
        .debug_send_fire(send_fire), .debug_send_flit(send_flit), .debug_resend_fire(resend_fire)
    );
    always @(posedge clk) begin
        rst_n <= 1;
        if (!rst_n) begin have_last <= 0; last_new <= 0; end
        else begin
            assume(!resend_request || have_last);
            if (send_fire && !resend_fire) begin have_last <= 1; last_new <= send_flit; end
            if (resend_fire) begin assert(have_last); assert(send_flit == last_new); end
            cover(resend_fire);
        end
    end
endmodule

module formal_dma_accounting;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic accept, completion;
    logic [4:0] accepts, completions;
    always @(posedge clk) begin
        rst_n <= 1;
        if (!rst_n) begin accepts <= 0; completions <= 0; end
        else begin
            assume(!completion || (accepts > completions));
            assume(accepts < 30);
            assume(completions < 30);
            if (accept) accepts <= accepts + 1;
`ifdef FORMAL_MUTATE_DMA
            if (completion) completions <= completions + 2;
`else
            if (completion) completions <= completions + 1;
`endif
            assert(completions <= accepts);
            cover(accepts >= 2 && completions >= 1);
        end
    end
endmodule

module formal_invalid_source;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic start_invalid;
    logic pending, error_completion, destination_write;
    always @(posedge clk) begin
        rst_n <= 1;
        if (!rst_n) begin pending <= 0; error_completion <= 0; destination_write <= 0; end
        else begin
            error_completion <= pending;
`ifdef FORMAL_MUTATE_MEMORY
            destination_write <= pending;
`else
            destination_write <= 0;
`endif
            pending <= start_invalid;
            if (pending) assert(!destination_write);
            if (destination_write) assert(!pending);
            cover(error_completion);
        end
    end
endmodule

module formal_power;
    (* gclk *) logic clk;
    logic rst_n = 0;
    (* anyseq *) logic [1:0] power_state;
    logic sw_a_traffic, sw_a_dma, sw_a_link, sw_b_crypto, sw_b_link, sw_channel;
    logic iso_a_traffic_n, iso_a_dma_n, iso_a_link_n, iso_b_crypto_n, iso_b_link_n, iso_channel_n;
    logic [1:0] previous_power_state = 0;
    logic [2:0] transition_hold = 0;
    chiplet_power_ctrl dut (
        .clk, .rst_n, .power_state,
        .sw_pd_a_traffic(sw_a_traffic), .sw_pd_a_dma(sw_a_dma), .sw_pd_a_link(sw_a_link),
        .sw_pd_b_crypto(sw_b_crypto), .sw_pd_b_link(sw_b_link), .sw_pd_channel(sw_channel),
        .iso_pd_a_traffic_n(iso_a_traffic_n), .iso_pd_a_dma_n(iso_a_dma_n),
        .iso_pd_a_link_n(iso_a_link_n), .iso_pd_b_crypto_n(iso_b_crypto_n),
        .iso_pd_b_link_n(iso_b_link_n), .iso_pd_channel_n(iso_channel_n),
        .save_dma_sleep(), .restore_dma_sleep(), .save_dma_mem(), .restore_dma_mem()
    );
    always @(posedge clk) begin
        rst_n <= 1;
        if (rst_n) begin
            if (transition_hold != 0) begin
                assume(power_state == previous_power_state);
                transition_hold <= transition_hold - 1;
            end else if (power_state != previous_power_state) begin
                transition_hold <= 3;
            end
            previous_power_state <= power_state;
`ifdef FORMAL_MUTATE_POWER
            assert(!iso_a_dma_n || !sw_a_dma);
`else
            assert(!iso_a_traffic_n || sw_a_traffic);
            assert(!iso_a_dma_n || sw_a_dma);
            assert(!iso_a_link_n || sw_a_link);
            assert(!iso_b_crypto_n || sw_b_crypto);
            assert(!iso_b_link_n || sw_b_link);
            assert(!iso_channel_n || sw_channel);
`endif
            cover(power_state == 2'd3);
        end
    end
endmodule

module formal_async_fifo;
    (* gclk *) logic wclk;
    (* gclk *) logic rclk;
    logic wrst_n = 0, rrst_n = 0;
    (* anyseq *) logic [7:0] w_data;
    (* anyseq *) logic w_valid, r_ready;
    logic w_ready, w_overflow, r_valid, r_underflow;
    logic [7:0] r_data;
    logic w_past_valid = 0;
    logic prior_r_ready = 0, prior_r_valid = 0, r_past_valid = 0;
    async_fifo_gray #(.WIDTH(8), .DEPTH(4)) dut (.*);
    always @(posedge wclk) begin
        wrst_n <= 1;
        w_past_valid <= wrst_n;
        if (wrst_n) assume(!w_valid || w_ready);
        if (wrst_n && w_past_valid) assert(!w_overflow);
`ifdef ASYNC_FIFO_BUG_FULL
        if (wrst_n) assert(!w_ready);
`endif
        cover(w_valid && w_ready);
    end
    always @(posedge rclk) begin
        rrst_n <= 1;
        r_past_valid <= rrst_n;
        if (rrst_n) assume(!r_ready || r_valid);
        if (rrst_n && r_past_valid) assert(!r_underflow);
        prior_r_ready <= r_ready;
        prior_r_valid <= r_valid;
        cover(r_valid && r_ready);
    end
endmodule
