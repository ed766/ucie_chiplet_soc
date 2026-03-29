`ifndef SVA_MACROS_SVH
`define SVA_MACROS_SVH
`ifdef VERILATOR
  `define ASSERT_PROP(p,msg) assert(p) else $error(msg)
`else
  `define ASSERT_PROP(p,msg) assert property (p) else $error(msg)
`endif
`endif

