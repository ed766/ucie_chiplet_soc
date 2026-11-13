// Assume-guarantee abstraction for core control only. Real-unit protocol BMC is separate.
module rv32_muldiv(
  input logic clk,rst_n,req_valid,
  output logic req_ready,
  input logic [2:0] req_op,
  input logic [31:0] req_lhs,req_rhs,
  output logic rsp_valid,
  input logic rsp_ready,
  output logic [31:0] rsp_result
);
  logic pending;
  logic [5:0] age;
  (* anyconst *) logic [5:0] latency;
  (* anyseq *) logic [31:0] result;
  assign req_ready=!pending&&!rsp_valid;
  always_ff @(posedge clk) begin
    assume(latency>=1 && latency<=36);
    if(!rst_n)begin pending<=0;age<=0;rsp_valid<=0;rsp_result<=0;end
    else begin
      if(req_valid&&req_ready)begin pending<=1;age<=0;end
      if(pending)begin
        age<=age+1;
        if(age+1==latency)begin pending<=0;rsp_valid<=1;rsp_result<=result;end
      end
      if(rsp_valid&&rsp_ready)rsp_valid<=0;
    end
  end
endmodule
