// Dual-clock power-of-two FIFO with Gray-coded pointer synchronization.
module async_fifo_gray #(
    parameter int WIDTH = 16,
    parameter int DEPTH = 64
) (
    input  logic             wclk,
    input  logic             wrst_n,
    input  logic [WIDTH-1:0] w_data,
    input  logic             w_valid,
    output logic             w_ready,
    output logic             w_overflow,
    input  logic             rclk,
    input  logic             rrst_n,
    output logic [WIDTH-1:0] r_data,
    output logic             r_valid,
    input  logic             r_ready,
    output logic             r_underflow
);
    localparam int ADDR_W = $clog2(DEPTH);
    localparam int PTR_W = ADDR_W + 1;

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_W-1:0] wbin_q, wgray_q, rbin_q, rgray_q;
    (* async_reg = "true" *) logic [PTR_W-1:0] rgray_w1_q, rgray_w2_q;
    (* async_reg = "true" *) logic [PTR_W-1:0] wgray_r1_q, wgray_r2_q;
    logic [PTR_W-1:0] wbin_next, wgray_next, rbin_next, rgray_next;
    logic full_next, full_q, empty;

    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0) begin
            $error("async_fifo_gray DEPTH must be a power of two >= 4");
        end
    end

    assign wbin_next = wbin_q + (w_valid && w_ready);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;
    assign rbin_next = rbin_q + (r_valid && r_ready);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
`ifdef ASYNC_FIFO_BUG_FULL
    assign full_next = (wgray_next == rgray_w2_q);
`else
    assign full_next = (wgray_next == {~rgray_w2_q[PTR_W-1:PTR_W-2], rgray_w2_q[PTR_W-3:0]});
`endif
    assign empty = (rgray_q == wgray_r2_q);
    assign w_ready = !full_q;
    assign r_valid = !empty;
    assign r_data = mem[rbin_q[ADDR_W-1:0]];

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin_q <= '0;
            wgray_q <= '0;
            full_q <= 1'b0;
            rgray_w1_q <= '0;
            rgray_w2_q <= '0;
            w_overflow <= 1'b0;
        end else begin
            rgray_w1_q <= rgray_q;
            rgray_w2_q <= rgray_w1_q;
            full_q <= full_next;
            w_overflow <= w_valid && !w_ready;
            if (w_valid && w_ready) begin
                mem[wbin_q[ADDR_W-1:0]] <= w_data;
                wbin_q <= wbin_next;
                wgray_q <= wgray_next;
            end
        end
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin_q <= '0;
            rgray_q <= '0;
            wgray_r1_q <= '0;
            wgray_r2_q <= '0;
            r_underflow <= 1'b0;
        end else begin
            wgray_r1_q <= wgray_q;
            wgray_r2_q <= wgray_r1_q;
            r_underflow <= r_ready && !r_valid;
            if (r_valid && r_ready) begin
                rbin_q <= rbin_next;
                rgray_q <= rgray_next;
            end
        end
    end
endmodule
