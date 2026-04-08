`timescale 1ns/1ps

module e2e_ref_scoreboard #(
    parameter int DATA_WIDTH = 64,
    parameter int DEPTH = 1024
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  rx_valid,
    input  logic                  rx_ready,
    input  logic [DATA_WIDTH-1:0] rx_data,
    output int unsigned           observed_count,
    output int unsigned           mismatch_count,
    output int unsigned           expected_empty_count,
    output logic                  update_event,
    output logic                  mismatch_event,
    output logic                  expected_empty_event
);

    logic [DATA_WIDTH-1:0] expected_mem [0:DEPTH-1];
    int unsigned           loaded_words_q;
    int unsigned           head_q;

    task automatic load_reference(input string path);
        int fd;
        int code;
        int idx;
        logic [DATA_WIDTH-1:0] word;
        string line;

        for (idx = 0; idx < DEPTH; idx++) begin
            expected_mem[idx] = '0;
        end
        loaded_words_q = 0;

        fd = $fopen(path, "r");
        if (fd == 0) begin
            $fatal(1, "Failed to open REF_CSV '%s'", path);
        end

        code = $fgets(line, fd);
        while (!$feof(fd)) begin
            line = "";
            code = $fgets(line, fd);
            if (code != 0 && $sscanf(line, "%d,%h", idx, word) == 2) begin
                if (idx >= DEPTH) begin
                    $fatal(1, "REF_CSV depth exceeded: idx=%0d depth=%0d", idx, DEPTH);
                end
                expected_mem[idx] = word;
                if (loaded_words_q <= idx) begin
                    loaded_words_q = idx + 1;
                end
            end
        end
        $fclose(fd);
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_q <= 0;
            observed_count <= 0;
            mismatch_count <= 0;
            expected_empty_count <= 0;
            update_event <= 1'b0;
            mismatch_event <= 1'b0;
            expected_empty_event <= 1'b0;
        end else begin
            update_event <= 1'b0;
            mismatch_event <= 1'b0;
            expected_empty_event <= 1'b0;

            if (rx_valid && rx_ready) begin
                observed_count <= observed_count + 1;
                update_event <= 1'b1;
                if (head_q >= loaded_words_q) begin
                    expected_empty_count <= expected_empty_count + 1;
                    expected_empty_event <= 1'b1;
                end else begin
                    if (rx_data !== expected_mem[head_q]) begin
                        mismatch_count <= mismatch_count + 1;
                        mismatch_event <= 1'b1;
                    end
                    head_q <= head_q + 1;
                end
            end
        end
    end

endmodule : e2e_ref_scoreboard
