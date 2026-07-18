// Minimal always-on machine timer used by firmware and low-power wake tests.
module apb_machine_timer #(
    parameter logic [31:0] MMIO_BASE = 32'h0000_01a0
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
    output logic        irq_timer,
    output logic [63:0] mtime,
    output logic [63:0] mtimecmp
);

    logic completed_q;
    logic addr_valid;

    assign addr_valid = (paddr[1:0] == 2'b00) &&
                        (paddr >= MMIO_BASE) && (paddr <= MMIO_BASE + 32'h0c);
    assign pready = psel && penable && !completed_q;
    assign pslverr = pready && !addr_valid;
    assign irq_timer = (mtimecmp != 64'hffff_ffff_ffff_ffff) && (mtime >= mtimecmp);

    always_comb begin
        unique case (paddr - MMIO_BASE)
            32'h00: prdata = mtime[31:0];
            32'h04: prdata = mtime[63:32];
            32'h08: prdata = mtimecmp[31:0];
            32'h0c: prdata = mtimecmp[63:32];
            default: prdata = 32'hdead_beef;
        endcase
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            mtime <= '0;
            mtimecmp <= 64'hffff_ffff_ffff_ffff;
            completed_q <= 1'b0;
        end else begin
            mtime <= mtime + 1'b1;
            if (psel && penable && !completed_q) begin
                completed_q <= 1'b1;
                if (pwrite && addr_valid) begin
                    unique case (paddr - MMIO_BASE)
                        32'h00: mtime[31:0] <= pwdata;
                        32'h04: mtime[63:32] <= pwdata;
                        32'h08: mtimecmp[31:0] <= pwdata;
                        32'h0c: mtimecmp[63:32] <= pwdata;
                        default: begin end
                    endcase
                end
            end
            if (!psel) completed_q <= 1'b0;
        end
    end

endmodule : apb_machine_timer
