// ROM-backed instruction source for the lightweight RV32 core.
module rv32_rom_feeder #(
    parameter int ROM_WORDS = 256,
    parameter string DEFAULT_HEX = "firmware/dma_smoke.hex"
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        instr_ready,
    output logic        instr_valid,
    output logic [31:0] instr,
    input  logic        commit_valid,
    input  logic [31:0] commit_next_pc,
    input  logic        halted
);

    logic [31:0] rom [0:ROM_WORDS-1];
    logic [31:0] fetch_pc_q;
    logic        wait_commit_q;
    string       firmware_hex;

    initial begin
        for (int idx = 0; idx < ROM_WORDS; idx++) begin
            rom[idx] = 32'h0010_0073;
        end
        firmware_hex = DEFAULT_HEX;
        void'($value$plusargs("FIRMWARE_HEX=%s", firmware_hex));
        $readmemh(firmware_hex, rom);
    end

    assign instr_valid = rst_n && !halted && !wait_commit_q;
    assign instr = rom[(fetch_pc_q >> 2) % ROM_WORDS];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetch_pc_q <= '0;
            wait_commit_q <= 1'b0;
        end else begin
            if (commit_valid) begin
                fetch_pc_q <= commit_next_pc;
                wait_commit_q <= 1'b0;
            end
            if (instr_valid && instr_ready) begin
                wait_commit_q <= 1'b1;
            end
        end
    end

endmodule : rv32_rom_feeder
