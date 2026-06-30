// Toggle-based pulse synchronizer for one-cycle source-domain events.
// Source pulses must be separated enough for the destination clock to sample
// the toggled level; the testbench exercises this contract.
module cdc_pulse_sync (
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_src,

    input  logic clk_dst,
    input  logic rst_dst_n,
    output logic pulse_dst
);

    logic toggle_src_q;
    logic toggle_dst_meta_q;
    logic toggle_dst_q;
    logic toggle_dst_prev_q;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            toggle_src_q <= 1'b0;
        end else if (pulse_src) begin
            toggle_src_q <= ~toggle_src_q;
        end
    end

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            toggle_dst_meta_q <= 1'b0;
            toggle_dst_q      <= 1'b0;
            toggle_dst_prev_q <= 1'b0;
            pulse_dst         <= 1'b0;
        end else begin
            toggle_dst_meta_q <= toggle_src_q;
            toggle_dst_q      <= toggle_dst_meta_q;
            toggle_dst_prev_q <= toggle_dst_q;
            pulse_dst         <= toggle_dst_q ^ toggle_dst_prev_q;
        end
    end

endmodule : cdc_pulse_sync
