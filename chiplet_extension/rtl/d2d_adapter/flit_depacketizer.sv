// Reconstructs payload words from incoming FLITs and validates CRC-8 fields.
// Role: receive-side deframing for the UCIe-style adapter.
module flit_depacketizer #(
    parameter int FLIT_WIDTH = 256,
    parameter int DATA_WIDTH = 64,
    parameter int CRC_WIDTH  = 8
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [FLIT_WIDTH-1:0] flit_in,
    input  logic                  flit_valid,
    output logic                  flit_ready,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  data_valid,
    input  logic                  data_ready,
    output logic                  crc_error
);

    localparam int PAYLOAD_WIDTH = FLIT_WIDTH - CRC_WIDTH;
    localparam int WORDS_PER_FLIT = PAYLOAD_WIDTH / DATA_WIDTH;
    localparam int WORD_COUNT_WIDTH = $clog2(WORDS_PER_FLIT + 1);
    localparam logic [WORD_COUNT_WIDTH-1:0] WORDS_PER_FLIT_VALUE = WORD_COUNT_WIDTH'(WORDS_PER_FLIT);
    localparam logic [WORD_COUNT_WIDTH-1:0] WORD_COUNT_ONE       = WORD_COUNT_WIDTH'(1);

`ifndef SYNTHESIS
`ifndef YOSYS
    // Keep the parameter validation for sim-only builds; yosys flows used for PnR lack $error.
    initial begin
        if (PAYLOAD_WIDTH <= 0 || PAYLOAD_WIDTH % DATA_WIDTH != 0) begin
            $error("FLIT_WIDTH (%0d) must exceed CRC_WIDTH (%0d) and be a multiple of DATA_WIDTH (%0d)",
                   FLIT_WIDTH, CRC_WIDTH, DATA_WIDTH);
        end
    end
`endif
`endif

    localparam logic [CRC_WIDTH-1:0] CRC_POLY = {{(CRC_WIDTH-8){1'b0}}, 8'h07};

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

    logic [PAYLOAD_WIDTH-1:0] payload_d, payload_q;
    logic [WORD_COUNT_WIDTH-1:0] words_left_d, words_left_q;
    logic hold_d, hold_q;
    logic crc_error_d, crc_error_q;
    logic [PAYLOAD_WIDTH-1:0] received_payload;
    logic [CRC_WIDTH-1:0]     received_crc;

    // hold_q means a FLIT has been accepted and words are being streamed out.
    assign data_valid = hold_q;
    assign data_out   = payload_q[DATA_WIDTH-1:0];
    assign flit_ready = !hold_q;
    assign crc_error  = crc_error_q;

    assign received_crc     = flit_in[FLIT_WIDTH-1 -: CRC_WIDTH];
    assign received_payload = flit_in[PAYLOAD_WIDTH-1:0];

    always_comb begin
        payload_d    = payload_q;
        words_left_d = words_left_q;
        hold_d       = hold_q;
        crc_error_d  = crc_error_q;

        if (flit_valid && flit_ready) begin
            payload_d    = received_payload;
            words_left_d = WORDS_PER_FLIT_VALUE;
            hold_d       = 1'b1;
            crc_error_d  = (crc8(received_payload) != received_crc);
        end else if (hold_q && data_ready) begin
            if (words_left_q == WORD_COUNT_ONE) begin
                hold_d       = 1'b0;
                words_left_d = '0;
                payload_d    = '0;
                crc_error_d  = 1'b0;
            end else begin
                payload_d    = payload_q >> DATA_WIDTH;
                words_left_d = words_left_q - WORD_COUNT_ONE;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            payload_q    <= '0;
            words_left_q <= '0;
            hold_q       <= 1'b0;
            crc_error_q  <= 1'b0;
        end else begin
            payload_q    <= payload_d;
            words_left_q <= words_left_d;
            hold_q       <= hold_d;
            crc_error_q  <= crc_error_d;
        end
    end

endmodule : flit_depacketizer
