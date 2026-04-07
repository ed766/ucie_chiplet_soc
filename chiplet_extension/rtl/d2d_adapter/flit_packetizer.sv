// Groups streaming payloads into fixed-size FLITs and appends CRC-8 protection.
// Role: transmit-side framing for the UCIe-style adapter.
module flit_packetizer #(
    parameter int FLIT_WIDTH = 264,
    parameter int DATA_WIDTH = 64,
    parameter int CRC_WIDTH  = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  data_valid,
    output logic                  data_ready,
    output logic [FLIT_WIDTH-1:0] flit_out,
    output logic                  flit_valid,
    input  logic                  flit_ready
);

    localparam int PAYLOAD_WIDTH = FLIT_WIDTH - CRC_WIDTH;
    localparam int WORDS_PER_FLIT = PAYLOAD_WIDTH / DATA_WIDTH;
    localparam int WORD_COUNT_WIDTH = $clog2(WORDS_PER_FLIT + 1);
    localparam logic [WORD_COUNT_WIDTH-1:0] WORDS_PER_FLIT_VALUE = WORD_COUNT_WIDTH'(WORDS_PER_FLIT);
    localparam logic [WORD_COUNT_WIDTH-1:0] WORD_COUNT_ONE       = WORD_COUNT_WIDTH'(1);
    localparam logic [WORD_COUNT_WIDTH-1:0] WORDS_PER_FLIT_LAST  = WORDS_PER_FLIT_VALUE - WORD_COUNT_ONE;

`ifndef SYNTHESIS
`ifndef YOSYS
    // Guard rails for simulation and lint configurations.
    initial begin
        if (PAYLOAD_WIDTH <= 0 || PAYLOAD_WIDTH % DATA_WIDTH != 0) begin
            $error("FLIT_WIDTH (%0d) must exceed CRC_WIDTH (%0d) and be a multiple of DATA_WIDTH (%0d)",
                   FLIT_WIDTH, CRC_WIDTH, DATA_WIDTH);
        end
    end
`endif
`endif

    logic [PAYLOAD_WIDTH-1:0] payload_d, payload_q;
    logic [WORD_COUNT_WIDTH-1:0] word_count_d, word_count_q;
    logic                              flit_hold_d, flit_hold_q;
    logic [FLIT_WIDTH-1:0]             flit_buffer_d, flit_buffer_q;
    logic [PAYLOAD_WIDTH-1:0]          assembled_payload;

    // flit_hold_q indicates a completed FLIT waiting to be accepted downstream.
    // Polynomial x^8 + x^2 + x + 1 (CRC-8-ATM)
`ifdef UCIE_BUG_CRC_POLY
    localparam logic [CRC_WIDTH-1:0] CRC_POLY = {{(CRC_WIDTH-8){1'b0}}, 8'h1D};
`else
    localparam logic [CRC_WIDTH-1:0] CRC_POLY = {{(CRC_WIDTH-8){1'b0}}, 8'h07};
`endif

    function automatic logic [CRC_WIDTH-1:0] crc8(input logic [PAYLOAD_WIDTH-1:0] data_bits);
        logic [CRC_WIDTH-1:0] crc;
        crc = '0;
        for (int i = PAYLOAD_WIDTH-1; i >= 0; i--) begin
            logic feedback;
            feedback = data_bits[i] ^ crc[CRC_WIDTH-1];
            crc = {crc[CRC_WIDTH-2:0], 1'b0};
            if (feedback) begin
                crc ^= CRC_POLY;
            end
        end
        crc8 = crc;
    endfunction

    // Data path controls: accept words until a FLIT is full, then stall.
    assign data_ready = (!flit_hold_q) && (word_count_q < WORDS_PER_FLIT_VALUE);
    assign flit_out   = flit_buffer_q;
    assign flit_valid = flit_hold_q;

    assign assembled_payload = {data_in, payload_q[PAYLOAD_WIDTH-1:DATA_WIDTH]};

    always_comb begin
        payload_d     = payload_q;
        word_count_d  = word_count_q;
        flit_hold_d   = flit_hold_q;
        flit_buffer_d = flit_buffer_q;

        if (data_valid && data_ready) begin
            payload_d = assembled_payload;
            if (word_count_q == WORDS_PER_FLIT_LAST) begin
                flit_buffer_d = {crc8(assembled_payload), assembled_payload};
                flit_hold_d   = 1'b1;
                payload_d     = '0;
                word_count_d  = '0;
            end else begin
                word_count_d = word_count_q + WORD_COUNT_ONE;
            end
        end

        if (flit_hold_q && flit_ready) begin
            flit_hold_d   = 1'b0;
            flit_buffer_d = '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload_q     <= '0;
            word_count_q  <= '0;
            flit_hold_q   <= 1'b0;
            flit_buffer_q <= '0;
        end else begin
            payload_q     <= payload_d;
            word_count_q  <= word_count_d;
            flit_hold_q   <= flit_hold_d;
            flit_buffer_q <= flit_buffer_d;
        end
    end

endmodule : flit_packetizer
