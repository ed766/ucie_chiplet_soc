`timescale 1ns/1ps

module dma_mem_ref_scoreboard #(
    parameter int DATA_WIDTH = 64,
    parameter int DEPTH = 256
) (
    output int unsigned           observed_count,
    output int unsigned           mismatch_count,
    output logic                  update_event,
    output logic                  mismatch_event
);

    logic [DATA_WIDTH-1:0] expected_mem [0:DEPTH-1];

    task automatic clear_reference();
        for (int idx = 0; idx < DEPTH; idx++) begin
            expected_mem[idx] = '0;
        end
        observed_count = 0;
        mismatch_count = 0;
        update_event = 1'b0;
        mismatch_event = 1'b0;
    endtask

    task automatic load_reference(input string path);
        int fd;
        int code;
        int idx;
        logic [DATA_WIDTH-1:0] word;
        string line;

        clear_reference();
        fd = $fopen(path, "r");
        if (fd == 0) begin
            $fatal(1, "Failed to open DMA REF_CSV '%s'", path);
        end

        code = $fgets(line, fd);
        while (!$feof(fd)) begin
            line = "";
            code = $fgets(line, fd);
            if (code != 0 && $sscanf(line, "%d,%h", idx, word) == 2) begin
                if (idx >= DEPTH) begin
                    $fatal(1, "DMA REF_CSV depth exceeded: idx=%0d depth=%0d", idx, DEPTH);
                end
                expected_mem[idx] = word;
            end
        end
        $fclose(fd);
    endtask

    task automatic compare_word(
        input int unsigned addr,
        input logic [DATA_WIDTH-1:0] observed
    );
        update_event = 1'b1;
        mismatch_event = 1'b0;
        observed_count = observed_count + 1;
        if (addr >= DEPTH) begin
            mismatch_count = mismatch_count + 1;
            mismatch_event = 1'b1;
        end else if (observed !== expected_mem[addr]) begin
            mismatch_count = mismatch_count + 1;
            mismatch_event = 1'b1;
            $display("DMA_REF_MISMATCH addr=%0d observed=%h expected=%h", addr, observed, expected_mem[addr]);
        end
    endtask

endmodule : dma_mem_ref_scoreboard
