`timescale 1ns/1ps

module credit_checker #(
    parameter int CREDIT_WIDTH = 16,
    parameter int MAX_CREDITS  = 256
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    tx_valid,
    input  logic                    tx_ready,
    input  logic [CREDIT_WIDTH-1:0] credit_init,
    input  logic [CREDIT_WIDTH-1:0] credit_available,
    input  logic [CREDIT_WIDTH-1:0] credit_consumed,
    input  logic [CREDIT_WIDTH-1:0] credit_return
);

    localparam int EXT_WIDTH = CREDIT_WIDTH + 1;

    logic [CREDIT_WIDTH-1:0] expected_q;
    logic [CREDIT_WIDTH-1:0] expected_d;

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
            expected_q <= credit_init;
        end else begin
            if (tx_valid && tx_ready && credit_available == 0) begin
                $error("CREDIT_NO_SEND_WITHOUT_CREDIT: accepted flit with zero credits");
            end
            if (credit_available > MAX_CREDITS[CREDIT_WIDTH-1:0]) begin
                $error("CREDIT_BOUNDS: credit_available=%0d exceeds max=%0d", credit_available, MAX_CREDITS);
            end
            if (credit_available !== expected_q) begin
                $error("CREDIT_EXPECTED_MATCH: expected=%0d observed=%0d", expected_q, credit_available);
            end
            expected_q <= expected_d;
        end
    end

endmodule : credit_checker
