// Two-flop synchronizer for single-bit asynchronous controls.
// This is reusable CDC collateral for open-source structural checks.
module cdc_sync_2ff #(
    parameter logic RESET_VALUE = 1'b0
) (
    input  logic clk_dst,
    input  logic rst_dst_n,
    input  logic async_in,
    output logic sync_out
);

    logic sync_meta_q;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_meta_q <= RESET_VALUE;
            sync_out    <= RESET_VALUE;
        end else begin
            sync_meta_q <= async_in;
            sync_out    <= sync_meta_q;
        end
    end

endmodule : cdc_sync_2ff
