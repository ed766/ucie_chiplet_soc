// APB slave adapter for the chiplet DMA CSR interface.
module apb_dma_csr_bridge #(
    parameter logic [31:0] MMIO_BASE = 32'h0000_0100,
    parameter logic [31:0] MMIO_LAST = 32'h0000_0184
) (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,
    input  logic [3:0]  wait_cycles,
    input  logic        access_enable,

    output logic        cfg_valid,
    output logic        cfg_write,
    output logic [7:0]  cfg_addr,
    output logic [31:0] cfg_wdata,
    input  logic [31:0] cfg_rdata,
    input  logic        cfg_ready
);

    logic [31:0] addr_q;
    logic [31:0] wdata_q;
    logic        write_q;
    logic        active_q;
    logic        completed_q;
    logic [3:0]  wait_q;
    logic        addr_valid;

    assign addr_valid = (addr_q[1:0] == 2'b00) &&
                        (addr_q >= MMIO_BASE) && (addr_q <= MMIO_LAST);
    assign pready = access_enable && active_q && psel && penable && !completed_q &&
                    (wait_q == 0) && (!addr_valid || cfg_ready);
    assign pslverr = pready && !addr_valid;
    assign prdata = addr_valid ? cfg_rdata : 32'hdead_beef;

    assign cfg_valid = pready && addr_valid;
    assign cfg_write = write_q;
    assign cfg_addr = addr_q[7:0];
    assign cfg_wdata = wdata_q;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            addr_q <= '0;
            wdata_q <= '0;
            write_q <= 1'b0;
            active_q <= 1'b0;
            completed_q <= 1'b0;
            wait_q <= '0;
        end else begin
            if (psel && !penable && !active_q) begin
                addr_q <= paddr;
                wdata_q <= pwdata;
                write_q <= pwrite;
                active_q <= 1'b1;
                completed_q <= 1'b0;
                wait_q <= wait_cycles;
            end else if (access_enable && active_q && psel && penable && !completed_q) begin
                if (wait_q != 0) begin
                    wait_q <= wait_q - 1'b1;
                end else if (!addr_valid || cfg_ready) begin
                    completed_q <= 1'b1;
                end
            end

            if (!psel) begin
                active_q <= 1'b0;
                completed_q <= 1'b0;
                wait_q <= '0;
            end
        end
    end

endmodule : apb_dma_csr_bridge
