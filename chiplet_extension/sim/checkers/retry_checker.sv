`timescale 1ns/1ps

module retry_checker #(
    parameter int FLIT_WIDTH = 264,
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
    int unsigned           resend_window_q;
    int unsigned           progress_window_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_flit_q <= '0;
            have_last_q <= 1'b0;
            expect_resend_q <= 1'b0;
            resend_window_q <= 0;
            progress_window_q <= 0;
        end else begin
            if (crc_error) begin
                expect_resend_q <= 1'b1;
                resend_window_q <= RESEND_WINDOW;
            end else if (expect_resend_q && resend_window_q != 0) begin
                resend_window_q <= resend_window_q - 1;
                if (resend_window_q == 1) begin
                    $error("RETRY_RESEND_WINDOW: resend request missing within %0d cycles", RESEND_WINDOW);
                    expect_resend_q <= 1'b0;
                end
            end

            if (resend_request) begin
                expect_resend_q <= 1'b0;
                resend_window_q <= 0;
                progress_window_q <= RESEND_WINDOW;
            end else if (progress_window_q != 0) begin
                progress_window_q <= progress_window_q - 1;
                if (tx_fire) begin
                    progress_window_q <= 0;
                end else if (progress_window_q == 1) begin
                    $error("RETRY_PROGRESS: no tx_fire observed within %0d cycles after resend", RESEND_WINDOW);
                end
            end

            if (tx_fire) begin
                if (progress_window_q != 0) begin
                    if (have_last_q && tx_flit !== last_flit_q) begin
                        $error("Retry payload mismatch: expected %h got %h", last_flit_q, tx_flit);
                    end
                    progress_window_q <= 0;
                end else begin
                    last_flit_q <= tx_flit;
                    have_last_q <= 1'b1;
                end
            end
        end
    end

endmodule : retry_checker
