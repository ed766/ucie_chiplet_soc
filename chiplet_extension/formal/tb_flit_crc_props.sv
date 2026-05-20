`timescale 1ns/1ps

module tb_flit_crc_props;

    logic clk;
    logic rst_n;
    logic [63:0] data_in;
    logic data_valid;
    logic data_ready;
    logic [71:0] flit_out;
    logic flit_valid;
    logic flit_ready;
    logic [71:0] flit_corrupt;
    logic [63:0] data_out;
    logic data_valid_out;
    logic data_ready_out;
    logic crc_error;
    logic scoreboard_commit;

    flit_packetizer #(
        .FLIT_WIDTH(72),
        .DATA_WIDTH(64),
        .CRC_WIDTH(8)
    ) u_pkt (
        .clk       (clk),
        .rst_n     (rst_n),
        .data_in   (data_in),
        .data_valid(data_valid),
        .data_ready(data_ready),
        .flit_out  (flit_out),
        .flit_valid(flit_valid),
        .flit_ready(flit_ready)
    );

    flit_depacketizer #(
        .FLIT_WIDTH(72),
        .DATA_WIDTH(64),
        .CRC_WIDTH(8)
    ) u_dep (
        .clk       (clk),
        .rst_n     (rst_n),
        .flit_in   (flit_corrupt),
        .flit_valid(flit_valid),
        .flit_ready(),
        .data_out  (data_out),
        .data_valid(data_valid_out),
        .data_ready(data_ready_out),
        .crc_error (crc_error)
    );

    assign scoreboard_commit = data_valid_out && data_ready_out && !crc_error;

    always #5 clk = ~clk;

    property p_crc_failed_packet_not_committed;
        @(posedge clk) disable iff (!rst_n)
            data_valid_out && crc_error |-> !scoreboard_commit;
    endproperty

    assert property (p_crc_failed_packet_not_committed);

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        data_in = 64'h1234_5678_90ab_cdef;
        data_valid = 1'b0;
        flit_ready = 1'b0;
        flit_corrupt = '0;
        data_ready_out = 1'b1;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        data_valid = 1'b1;
        wait (flit_valid);
        flit_corrupt = flit_out ^ 72'd1;
        data_valid = 1'b0;
        flit_ready = 1'b1;
        @(posedge clk);
        flit_ready = 1'b0;

        wait (data_valid_out);
        assert (crc_error);
        assert (!scoreboard_commit);

        $display("PROP_RESULT|name=flit_crc_reject_props|status=PASS|detail=crc_failed_packet_blocked_from_scoreboard_commit");
        $finish;
    end

endmodule : tb_flit_crc_props
