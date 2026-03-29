`timescale 1ns/1ps
`include "sva_macros.svh"

module credit_checker #(
    parameter int CREDIT_WIDTH = 16,
    parameter int MAX_CREDITS  = 256,
    parameter int CREDIT_INIT  = 128
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     tx_valid,
    input  logic                     tx_ready,
    input  logic [CREDIT_WIDTH-1:0]  credit_available,
    input  logic [CREDIT_WIDTH-1:0]  credit_consumed,
    input  logic [CREDIT_WIDTH-1:0]  credit_return
);

    localparam int EXT_WIDTH = CREDIT_WIDTH + 1;

    logic [CREDIT_WIDTH-1:0] expected_q, expected_d;

    function automatic logic [CREDIT_WIDTH-1:0] saturate(input logic signed [EXT_WIDTH:0] val);
        logic [CREDIT_WIDTH-1:0] result;
        if (val < 0) begin
            result = '0;
        end else if (val > MAX_CREDITS) begin
            result = MAX_CREDITS[CREDIT_WIDTH-1:0];
        end else begin
            result = val[CREDIT_WIDTH-1:0];
        end
        saturate = result;
    endfunction

    always_comb begin
        logic signed [EXT_WIDTH:0] signed_val;
        signed_val = $signed({1'b0, expected_q})
                   - $signed({1'b0, credit_consumed})
                   + $signed({1'b0, credit_return});
        expected_d = saturate(signed_val);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_q <= CREDIT_INIT[CREDIT_WIDTH-1:0];
        end else begin
            expected_q <= expected_d;
        end
    end

    // Never accept a flit when credits are exhausted.
    `ASSERT_PROP("CREDIT_NO_SEND_WITHOUT_CREDIT",
        @(posedge clk) disable iff (!rst_n)
        (tx_valid && tx_ready) |-> (credit_available != 0)
    )

    // Credit counter should stay within configured bounds.
    `ASSERT_PROP("CREDIT_BOUNDS",
        @(posedge clk) disable iff (!rst_n)
        credit_available <= MAX_CREDITS[CREDIT_WIDTH-1:0]
    )

    // Internal model must match credit manager output.
    `ASSERT_PROP("CREDIT_EXPECTED_MATCH",
        @(posedge clk) disable iff (!rst_n)
        credit_available == expected_q
    )

endmodule : credit_checker
