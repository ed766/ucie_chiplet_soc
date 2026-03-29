// UCIe lane interface connecting adapters, PHY, and channel behavioral models.
// Role: convenience bundle for lane/link signals (not used by the current top).
interface ucie_lane_if #(
    parameter int LANES = 16,
    parameter longint LANE_RATE = 64'd16_000_000_000
);
    // Forward path: adapter -> PHY -> channel
    logic lane_clk;         // forwarded clock (pre-serialized)
    logic link_enable;      // link enable flag
    logic link_training;    // training pattern indicator
    logic tx_valid;         // data valid for tx_data
    logic [LANES-1:0] tx_data;

    // Reverse path: channel -> PHY -> adapter
    logic rx_valid;         // sampled validity from far end
    logic [LANES-1:0] rx_data;
    logic lane_fault;       // sticky fault indication from channel/PHY
endinterface
