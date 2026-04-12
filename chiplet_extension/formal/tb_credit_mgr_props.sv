`timescale 1ns/1ps

module tb_credit_mgr_props;

    logic clk;
    logic rst_n;
    logic [15:0] credit_init;
    logic [15:0] credit_debit;
    logic [15:0] credit_return;
    logic [15:0] credit_available;
    logic underflow;
    logic overflow;

    credit_mgr #(
        .CREDIT_WIDTH(16),
        .MAX_CREDITS(16)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .credit_init     (credit_init),
        .credit_debit    (credit_debit),
        .credit_return   (credit_return),
        .credit_available(credit_available),
        .underflow       (underflow),
        .overflow        (overflow)
    );

    always #5 clk = ~clk;

    property p_credit_bound;
        @(posedge clk) rst_n |-> (credit_available <= 16);
    endproperty

    assert property (p_credit_bound);

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        credit_init = 16'd8;
        credit_debit = 16'd0;
        credit_return = 16'd0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        assert (credit_available == 16'd8);

        credit_debit = 16'd3;
        @(posedge clk);
        credit_debit = 16'd0;
        assert (credit_available == 16'd5);

        credit_return = 16'd2;
        @(posedge clk);
        credit_return = 16'd0;
        assert (credit_available == 16'd7);

        credit_debit = 16'd15;
        @(posedge clk);
        credit_debit = 16'd0;
        assert (credit_available == 16'd0);
        assert (underflow == 1'b1);

        credit_return = 16'd32;
        @(posedge clk);
        credit_return = 16'd0;
        assert (credit_available == 16'd16);
        assert (overflow == 1'b1);

        $display("PROP_RESULT|name=credit_mgr_bounds|status=PASS|detail=credits_bound_and_saturating");
        $finish;
    end

endmodule : tb_credit_mgr_props
