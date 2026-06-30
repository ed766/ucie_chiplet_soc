`timescale 1ns/1ps

module tb_credit_mgr_edges;
    logic clk;
    logic rst_n;
    logic [7:0] credit_debit;
    logic [7:0] credit_return;
    logic [7:0] credit_available;
    logic underflow;
    logic overflow;

    int errors;

    credit_mgr #(
        .CREDIT_WIDTH(8),
        .MAX_CREDITS(16)
    ) u_credit_mgr (
        .clk(clk),
        .rst_n(rst_n),
        .credit_init(8'd4),
        .credit_debit(credit_debit),
        .credit_return(credit_return),
        .credit_available(credit_available),
        .underflow(underflow),
        .overflow(overflow)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic expect_credit(
        input logic [7:0] expected_credit,
        input bit expected_underflow,
        input bit expected_overflow,
        input string label
    );
        begin
            @(posedge clk);
            #1;
            if ((credit_available !== expected_credit) ||
                (underflow !== expected_underflow) ||
                (overflow !== expected_overflow)) begin
                errors++;
                $error("%s mismatch credit=%0d/%0d underflow=%0b/%0b overflow=%0b/%0b",
                       label,
                       credit_available,
                       expected_credit,
                       underflow,
                       expected_underflow,
                       overflow,
                       expected_overflow);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        credit_debit = '0;
        credit_return = '0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        expect_credit(8'd4, 1'b0, 1'b0, "reset_credit");

        credit_debit = 8'd8;
        credit_return = 8'd0;
        expect_credit(8'd0, 1'b1, 1'b0, "underflow_saturates_to_zero");

        credit_debit = 8'd0;
        credit_return = 8'd40;
        expect_credit(8'd16, 1'b0, 1'b1, "overflow_saturates_to_max");

        credit_debit = 8'd3;
        credit_return = 8'd1;
        expect_credit(8'd14, 1'b0, 1'b0, "normal_update_after_saturation");

        if (errors == 0) begin
            $display("CREDIT_RESULT|status=PASS|detail=credit_saturation_edges_clean");
            $finish;
        end else begin
            $display("CREDIT_RESULT|status=FAIL|detail=credit_saturation_edges_errors|errors=%0d", errors);
            $fatal(1, "credit manager edge test failed");
        end
    end

endmodule : tb_credit_mgr_edges
