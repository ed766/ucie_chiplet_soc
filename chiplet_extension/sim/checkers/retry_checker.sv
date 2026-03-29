`timescale 1ns/1ps
`include "sva_macros.svh"

module retry_checker #(
    parameter int FLIT_WIDTH = 256,
    parameter int RESEND_WINDOW = 16
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  crc_error,
    input  logic                  resend_request,
    input  logic                  tx_fire,
    input  logic [FLIT_WIDTH-1:0] tx_flit,
    input  logic                  link_ready
);

    logic [FLIT_WIDTH-1:0] last_flit_q;
    logic                  have_last_q;
    logic                  expect_resend_q;

    // Require a resend request within a bounded window after a CRC error.
    `ASSERT_PROP("RETRY_RESEND_WINDOW",
        @(posedge clk) disable iff (!rst_n)
        crc_error |-> ##[1:RESEND_WINDOW] resend_request
    )

    // If resend is requested, expect traffic to resume within a bounded window.
    `ASSERT_PROP("RETRY_PROGRESS",
        @(posedge clk) disable iff (!rst_n)
        (resend_request && link_ready) |-> ##[1:RESEND_WINDOW] tx_fire
    )

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_flit_q      <= '0;
            have_last_q      <= 1'b0;
            expect_resend_q  <= 1'b0;
        end else begin
            if (tx_fire) begin
                if (expect_resend_q) begin
                    if (have_last_q && tx_flit !== last_flit_q) begin
                        $error("Retry payload mismatch: expected %h got %h", last_flit_q, tx_flit);
                    end
                    expect_resend_q <= 1'b0;
                end else begin
                    last_flit_q <= tx_flit;
                    have_last_q <= 1'b1;
                end
            end

            if (crc_error) begin
                expect_resend_q <= 1'b1;
            end
        end
    end

endmodule : retry_checker
