// Credit manager implementing saturating accounting for UCIe-style flow control.
// Role: tracks available credits for FLIT transfer and flags under/overflow.
module credit_mgr #(
    parameter int CREDIT_WIDTH = 16,
    parameter int MAX_CREDITS  = 256
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [CREDIT_WIDTH-1:0]  credit_init,
    input  logic [CREDIT_WIDTH-1:0]  credit_debit,
    input  logic [CREDIT_WIDTH-1:0]  credit_return,
    output logic [CREDIT_WIDTH-1:0]  credit_available,
    output logic                     underflow,
    output logic                     overflow
);

    localparam int EXT_WIDTH = CREDIT_WIDTH + 1;

    logic [CREDIT_WIDTH-1:0] credit_q, credit_d;
    logic                    underflow_d, underflow_q;
    logic                    overflow_d, overflow_q;

    assign credit_available = credit_q;
    assign underflow        = underflow_q;
    assign overflow         = overflow_q;

    always_comb begin
        // Saturating arithmetic to prevent negative or over-full credit counts.
        logic signed [EXT_WIDTH:0] signed_val;
        logic [CREDIT_WIDTH-1:0] saturated_val;

        signed_val = $signed({1'b0, credit_q})
                   - $signed({1'b0, credit_debit})
                   + $signed({1'b0, credit_return});
`ifdef UCIE_BUG_CREDIT_OFF_BY_ONE
        if (credit_debit != 0) begin
            signed_val = signed_val - 1;
        end
`endif

        underflow_d = 1'b0;
        overflow_d  = 1'b0;

        if (signed_val < 0) begin
            saturated_val = '0;
            underflow_d    = (credit_debit != 0);
        end else if (signed_val > MAX_CREDITS) begin
            saturated_val = MAX_CREDITS[CREDIT_WIDTH-1:0];
            overflow_d    = 1'b1;
        end else begin
            saturated_val = signed_val[CREDIT_WIDTH-1:0];
        end

        credit_d = saturated_val;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_q    <= credit_init;
            underflow_q <= 1'b0;
            overflow_q  <= 1'b0;
        end else begin
            credit_q    <= credit_d;
            underflow_q <= underflow_d;
            overflow_q  <= overflow_d;
        end
    end

endmodule : credit_mgr
