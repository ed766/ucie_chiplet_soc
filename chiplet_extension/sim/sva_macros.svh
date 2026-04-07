`ifndef CHIPLET_SVA_MACROS_SVH
`define CHIPLET_SVA_MACROS_SVH

`define ASSERT_PROP(name, prop) \
    assert property (prop) else begin \
        $error("%s failed", name); \
    end

`define TB_TIMEOUT(clk, cycles) \
    fork \
        begin : __tb_timeout_thread \
            int __tb_timeout_count; \
            __tb_timeout_count = 0; \
            while (__tb_timeout_count < (cycles)) begin \
                @(posedge clk); \
                __tb_timeout_count = __tb_timeout_count + 1; \
            end \
            $fatal(1, "Timeout after %0d cycles", __tb_timeout_count); \
        end \
    join_none

`endif // CHIPLET_SVA_MACROS_SVH
