`timescale 1ns/1ps

module tb_cdc_reset;
    logic clk_src;
    logic clk_dst;
    logic rst_src_n;
    logic rst_dst_n;
    logic async_level;
    logic sync_level;
    logic pulse_src;
    logic pulse_dst;

    int errors;
    int src_pulses;
    int dst_pulses;

    cdc_sync_2ff u_level_sync (
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .async_in(async_level),
        .sync_out(sync_level)
    );

    cdc_pulse_sync u_pulse_sync (
        .clk_src(clk_src),
        .rst_src_n(rst_src_n),
        .pulse_src(pulse_src),
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .pulse_dst(pulse_dst)
    );

    initial begin
        clk_src = 1'b0;
        forever #3 clk_src = ~clk_src;
    end

    initial begin
        clk_dst = 1'b0;
        forever #5 clk_dst = ~clk_dst;
    end

    task automatic send_src_pulse;
        begin
            @(posedge clk_src);
            pulse_src = 1'b1;
            @(posedge clk_src);
            pulse_src = 1'b0;
            src_pulses++;
            repeat (5) @(posedge clk_src);
        end
    endtask

    task automatic expect_dst_pulse(input string label);
        int timeout;
        begin
            timeout = 0;
            while (!pulse_dst && timeout < 20) begin
                @(posedge clk_dst);
                #1;
                timeout++;
            end
            if (!pulse_dst) begin
                errors++;
                $error("%s did not produce a destination pulse", label);
            end else begin
                dst_pulses++;
                @(posedge clk_dst);
                #1;
                if (pulse_dst) begin
                    errors++;
                    $error("%s destination pulse lasted more than one cycle", label);
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        src_pulses = 0;
        dst_pulses = 0;
        rst_src_n = 1'b0;
        rst_dst_n = 1'b0;
        async_level = 1'b0;
        pulse_src = 1'b0;

        repeat (4) @(posedge clk_src);
        rst_src_n = 1'b1;
        repeat (3) @(posedge clk_dst);
        rst_dst_n = 1'b1;

        async_level = 1'b1;
        repeat (4) @(posedge clk_dst);
        if (sync_level !== 1'b1) begin
            errors++;
            $error("2FF synchronizer did not propagate asserted level");
        end

        async_level = 1'b0;
        repeat (4) @(posedge clk_dst);
        if (sync_level !== 1'b0) begin
            errors++;
            $error("2FF synchronizer did not propagate deasserted level");
        end

        send_src_pulse();
        expect_dst_pulse("pulse0");
        send_src_pulse();
        expect_dst_pulse("pulse1");
        send_src_pulse();
        expect_dst_pulse("pulse2");

        rst_dst_n = 1'b0;
        repeat (2) @(posedge clk_dst);
        if (sync_level !== 1'b0 || pulse_dst !== 1'b0) begin
            errors++;
            $error("Destination reset did not clear CDC outputs");
        end
        rst_dst_n = 1'b1;
        repeat (2) @(posedge clk_dst);

        if (errors == 0) begin
            $display("CDC_RESULT|status=PASS|detail=cdc_reset_clock_ratio_clean|src_pulses=%0d|dst_pulses=%0d", src_pulses, dst_pulses);
            $finish;
        end else begin
            $display("CDC_RESULT|status=FAIL|detail=cdc_reset_errors|errors=%0d", errors);
            $fatal(1, "CDC/RDC collateral test failed");
        end
    end

endmodule : tb_cdc_reset
