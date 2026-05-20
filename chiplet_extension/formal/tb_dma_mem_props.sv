`timescale 1ns/1ps
`include "chiplet_protocol_assertions.svh"

module tb_dma_mem_props;

    localparam logic [1:0] PWR_RUN = 2'd0;
    localparam logic [7:0] ADDR_CTRL = 8'h00;
    localparam logic [7:0] ADDR_SRC_BASE = 8'h08;
    localparam logic [7:0] ADDR_DST_BASE = 8'h0c;
    localparam logic [7:0] ADDR_LEN_WORDS = 8'h10;
    localparam logic [7:0] ADDR_TAG = 8'h14;
    localparam logic [7:0] ADDR_SCRATCH_IDX = 8'h20;
    localparam logic [7:0] ADDR_SCRATCH_SEL = 8'h24;
    localparam logic [7:0] ADDR_MEM_OP_CTRL = 8'h58;
    localparam logic [1:0] COMP_STATUS_RUNTIME_ERROR = 2'b10;
    localparam logic [3:0] ERR_MEM_PARITY = 4'd6;
    localparam logic [3:0] ERR_MEM_INVALID = 4'd7;
    localparam logic [2:0] ERR_KIND_PARITY_MAINT = 3'd1;
    localparam logic [2:0] ERR_KIND_PARITY_DMA_SRC = 3'd2;

    logic clk;
    logic rst_n;
    logic cfg_valid;
    logic cfg_write;
    logic [7:0] cfg_addr;
    logic [31:0] cfg_wdata;
    logic [31:0] cfg_rdata;
    logic cfg_ready;
    logic irq_done;
    logic [63:0] tx_stream_data;
    logic tx_stream_valid;
    logic tx_stream_ready;
    logic [63:0] rx_stream_data;
    logic rx_stream_valid;
    logic rx_stream_ready;
    logic mem_op_done_d;
    logic mem_op_parity_done_event;

    dma_offload_ctrl #(
        .DATA_WIDTH(64),
        .SRAM_DEPTH(256),
        .DMA_TIMEOUT_CYCLES(32),
        .SUBMIT_QUEUE_DEPTH(4),
        .COMP_QUEUE_DEPTH(4),
        .BANKS(2),
        .PARITY_ENABLE(1'b1)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .power_state     (PWR_RUN),
        .cfg_valid       (cfg_valid),
        .cfg_write       (cfg_write),
        .cfg_addr        (cfg_addr),
        .cfg_wdata       (cfg_wdata),
        .cfg_rdata       (cfg_rdata),
        .cfg_ready       (cfg_ready),
        .irq_done        (irq_done),
        .tx_stream_data  (tx_stream_data),
        .tx_stream_valid (tx_stream_valid),
        .tx_stream_ready (tx_stream_ready),
        .rx_stream_data  (rx_stream_data),
        .rx_stream_valid (rx_stream_valid),
        .rx_stream_ready (rx_stream_ready),
        .dma_mode_active (),
        .dma_busy_monitor(),
        .dma_done_monitor(),
        .dma_error_monitor(),
        .irq_done_monitor(),
        .dma_tag_monitor ()
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_op_done_d <= 1'b0;
        end else begin
            mem_op_done_d <= dut.mem_op_done_q;
        end
    end

    assign mem_op_parity_done_event =
        dut.mem_op_done_q && !mem_op_done_d && dut.mem_op_parity_error_q;

    `CHIPLET_ASSERT_MEM_PARITY_STATUS(
        p_parity_read_sets_status,
        clk,
        rst_n,
        mem_op_parity_done_event,
        dut.last_mem_err_kind_q,
        ERR_KIND_PARITY_MAINT
    )
    `CHIPLET_ASSERT_MEM_INVALID_DMA_ABORT(
        p_invalid_dma_source_aborts,
        clk,
        rst_n,
        dut.comp_push_event_q &&
            (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR) &&
            (dut.comp_push_err_code_q == ERR_MEM_INVALID),
        dut.comp_push_err_code_q,
        ERR_MEM_INVALID
    )
    `CHIPLET_ASSERT_MEM_PARITY_DMA_CODE(
        p_parity_dma_source_uses_mem_parity_code,
        clk,
        rst_n,
        dut.comp_push_event_q &&
            (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR) &&
            (dut.last_mem_err_kind_q == ERR_KIND_PARITY_DMA_SRC),
        dut.comp_push_err_code_q,
        ERR_MEM_PARITY
    )
    `CHIPLET_ASSERT_MEM_FAULT_NO_DEST_COMMIT(
        p_faulting_source_reports_zero_words,
        clk,
        rst_n,
        dut.comp_push_event_q &&
            (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR) &&
            ((dut.comp_push_err_code_q == ERR_MEM_INVALID) ||
             (dut.comp_push_err_code_q == ERR_MEM_PARITY)),
        dut.comp_push_words_q != 0
    )

    task automatic csr_write(input logic [7:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_write = 1'b1;
            cfg_addr = addr;
            cfg_wdata = data;
            @(posedge clk);
            cfg_valid = 1'b0;
            cfg_write = 1'b0;
            cfg_addr = '0;
            cfg_wdata = '0;
        end
    endtask

    task automatic enqueue_desc(input logic [7:0] src_base, input logic [7:0] dst_base);
        begin
            csr_write(ADDR_SRC_BASE, src_base);
            csr_write(ADDR_DST_BASE, dst_base);
            csr_write(ADDR_LEN_WORDS, 9'd2);
            csr_write(ADDR_TAG, 16'h5501);
            csr_write(ADDR_CTRL, 32'd1);
        end
    endtask

    initial begin
        logic [63:0] word;
        int unsigned bank;
        int unsigned row;

        clk = 1'b0;
        rst_n = 1'b0;
        cfg_valid = 1'b0;
        cfg_write = 1'b0;
        cfg_addr = '0;
        cfg_wdata = '0;
        tx_stream_ready = 1'b1;
        rx_stream_valid = 1'b0;
        rx_stream_data = '0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        word = 64'hCAFE_BABE_1234_5678;
        dut.dst_bank_mem[0][45] = word;
        dut.dst_bank_parity[0][45] = ~(^word);
        csr_write(ADDR_SCRATCH_IDX, 32'd90);
        csr_write(ADDR_SCRATCH_SEL, 32'd1);
        csr_write(ADDR_MEM_OP_CTRL, 32'd1);
        wait (dut.mem_op_done_q);
        assert (dut.mem_op_parity_error_q);
        assert (dut.dst_parity_errors_q != 0);

        word = 64'h1000_0000_0000_0020;
        bank = 0;
        row = 16;
        dut.src_bank_mem[bank][row] = word;
        dut.src_bank_parity[bank][row] = ~(^word);
        dut.src_invalid_bank_mask_q[bank] = 1'b0;
        dut.src_bank_mem[1][16] = 64'h1000_0000_0000_0021;
        dut.src_bank_parity[1][16] = ^dut.src_bank_mem[1][16];
        dut.src_invalid_bank_mask_q[1] = 1'b0;
        enqueue_desc(8'd32, 8'd112);
        wait (dut.comp_push_event_q);
        assert (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR);
        assert (dut.comp_push_err_code_q == ERR_MEM_PARITY);
        repeat (2) @(posedge clk);

        word = 64'h1000_0000_0000_0028;
        bank = 0;
        row = 20;
        dut.src_bank_mem[bank][row] = word;
        dut.src_bank_parity[bank][row] = ^word;
        dut.src_bank_mem[1][20] = 64'h1000_0000_0000_0029;
        dut.src_bank_parity[1][20] = ^dut.src_bank_mem[1][20];
        dut.src_invalid_bank_mask_q[0] = 1'b1;
        enqueue_desc(8'd40, 8'd120);
        wait (dut.comp_push_event_q);
        assert (dut.comp_push_status_q == COMP_STATUS_RUNTIME_ERROR);
        assert (dut.comp_push_err_code_q == ERR_MEM_INVALID);

        $display("PROP_RESULT|name=dma_memory_integrity_props|status=PASS|detail=parity_reported_and_invalid_source_aborts");
        $finish;
    end

endmodule : tb_dma_mem_props
