`ifndef TB_PARAMS_SVH
`define TB_PARAMS_SVH

`ifndef TB_LANES
`define TB_LANES 16
`endif
`ifndef TB_DATA_WIDTH
`define TB_DATA_WIDTH 64
`endif
`ifndef TB_FLIT_WIDTH
`define TB_FLIT_WIDTH 256
`endif

`ifndef TB_ERROR_PROB_NUM
`define TB_ERROR_PROB_NUM 0
`endif
`ifndef TB_ERROR_PROB_DEN
`define TB_ERROR_PROB_DEN 1
`endif
`ifndef TB_JITTER_CYCLES
`define TB_JITTER_CYCLES 1
`endif
`ifndef TB_PIPELINE_STAGES
`define TB_PIPELINE_STAGES 2
`endif

`ifndef TB_REACH_MM
`define TB_REACH_MM 15
`endif
`ifndef TB_SKEW_STAGES
`define TB_SKEW_STAGES 2
`endif
`ifndef TB_CROSSTALK_SENSITIVITY
`define TB_CROSSTALK_SENSITIVITY 4
`endif

`ifndef TB_SEED_DEFAULT
`define TB_SEED_DEFAULT 32'h1ACE
`endif
`ifndef TB_MAX_LATENCY
`define TB_MAX_LATENCY 64
`endif

`endif
