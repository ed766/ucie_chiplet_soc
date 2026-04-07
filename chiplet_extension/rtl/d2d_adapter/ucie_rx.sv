// Behavioral UCIe receive adapter: de-serializes FLITs and returns credits.
// Role: reassembles FLITs from lane beats and returns credits to the sender.
module ucie_rx #(
    parameter int LANES = 16,
    parameter int FLIT_WIDTH = 264
) (
    input  logic                   clk,
    input  logic                   rst_n,
    output logic [FLIT_WIDTH-1:0]  flit_out,
    output logic                   flit_valid,
    input  logic                   flit_ready,
    output logic                   crc_error,
    output logic [15:0]            credit_return,
    input  logic                   link_up,
    input  logic                   lane_rx_valid,
    input  logic [LANES-1:0]       lane_rx_data,
    input  logic                   lane_lane_fault
);

    localparam int BEATS_PER_FLIT   = (FLIT_WIDTH + LANES - 1) / LANES;
    localparam int BEAT_COUNTER_WID = $clog2(BEATS_PER_FLIT + 1);

    logic [FLIT_WIDTH-1:0] flit_buffer_d, flit_buffer_q;
    logic [BEAT_COUNTER_WID-1:0] beat_index_d, beat_index_q;
    logic hold_flit_d, hold_flit_q;

    assign flit_out      = flit_buffer_q;
    assign flit_valid    = hold_flit_q;
    // Return one credit per FLIT consumed by downstream logic.
    assign credit_return = (flit_ready && hold_flit_q) ? 16'd1 : 16'd0;
    assign crc_error     = lane_lane_fault;

    always_comb begin
        // Shift in lane beats until a full FLIT is assembled.
        flit_buffer_d = flit_buffer_q;
        beat_index_d  = beat_index_q;
        hold_flit_d   = hold_flit_q;

        if (!link_up) begin
            beat_index_d = '0;
            if (!hold_flit_q) begin
                flit_buffer_d = '0;
            end
        end else begin
            if (lane_rx_valid && !hold_flit_q) begin
                flit_buffer_d[(beat_index_q * LANES) +: LANES] = lane_rx_data;
                if (beat_index_q == BEAT_COUNTER_WID'(BEATS_PER_FLIT - 1)) begin
                    hold_flit_d  = 1'b1;
                    beat_index_d = '0;
                end else begin
                    beat_index_d = beat_index_q + 1'b1;
                end
            end
        end

        if (hold_flit_q && flit_ready) begin
            hold_flit_d  = 1'b0;
            flit_buffer_d = '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flit_buffer_q <= '0;
            beat_index_q  <= '0;
            hold_flit_q   <= 1'b0;
        end else begin
            flit_buffer_q <= flit_buffer_d;
            beat_index_q  <= beat_index_d;
            hold_flit_q   <= hold_flit_d;
        end
    end

endmodule : ucie_rx
