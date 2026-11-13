module rv32_muldiv_formal(input logic clk);
  (* anyseq *) logic rst_n;
  (* anyseq *) logic req_valid;
  (* anyseq *) logic [2:0] req_op;
  (* anyseq *) logic [31:0] req_lhs,req_rhs;
  (* anyseq *) logic rsp_ready;
  logic req_ready,rsp_valid;logic[31:0]rsp_result;
  logic initialized=0;
  logic pending;logic[2:0]accepted_op;logic[5:0]age;
  logic [2:0] completed;
  logic cancelled=0;
  rv32_muldiv dut(.*);
  always_ff @(posedge clk)begin
    initialized<=1;
    if(!initialized)assume(!rst_n);
`ifdef FORMAL_COVER
    // Reachability only: deterministic traffic avoids solving irrelevant arithmetic data.
    assume(req_lhs==0);assume(req_rhs==1);assume(req_valid);assume(rsp_ready);
`endif
    if(!rst_n)begin
      if(initialized&&pending)cancelled<=1;
      pending<=0;completed<=0;accepted_op<=0;age<=0;
    end
    else begin
      if(pending&&!rsp_valid)age<=age+1'b1;
      if(req_valid&&req_ready)begin
        assert(!pending);pending<=1;accepted_op<=req_op;age<=0;
      end
      if(rsp_valid&&rsp_ready)begin assert(pending);pending<=0;completed<=completed+1'b1;end
      assert(!(rsp_valid&&!pending));
      if(pending&&!rsp_valid)assert(age<=36);
      if(initialized&&$past(rst_n)&&$past(rsp_valid&&!rsp_ready))begin assert(rsp_valid);assert($stable(rsp_result));end
      if(initialized&&!$past(rst_n))assert(!rsp_valid);
      for(integer op=0;op<8;op++)cover(rsp_valid&&accepted_op==op);
      cover(completed>=2);
      cover(cancelled&&rsp_valid);
    end
  end
endmodule
