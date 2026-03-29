`ifndef CHIPLET_SVA_MACROS_SVH
`define CHIPLET_SVA_MACROS_SVH

`define ASSERT_PROP(name, prop) \
    assert property (prop) else begin \
        $error("%s failed", name); \
        $finish; \
    end

`define TB_TIMEOUT(clk, cycles) \
    fork \
        begin \
            repeat (cycles) @(posedge clk); \
            $fatal(1, "Timeout after %0d cycles", cycles); \
        end \
    join_none

`endif // CHIPLET_SVA_MACROS_SVH
