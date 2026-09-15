module rv32_muldiv_formal(input logic clk);
  logic rst_n=0;
  (* anyseq *) logic req_valid;
  (* anyseq *) logic [2:0] req_op;
  (* anyseq *) logic [31:0] req_lhs,req_rhs;
  (* anyseq *) logic rsp_ready;
  logic req_ready,rsp_valid;logic[31:0]rsp_result;
  logic accepted,responded,consumed;logic[2:0]accepted_op;logic[5:0]age;
  rv32_muldiv dut(.*);
  always_ff @(posedge clk)begin
    rst_n<=1;
    if(!rst_n)begin accepted<=0;responded<=0;consumed<=0;accepted_op<=0;age<=0;end
    else begin
      if(accepted&&!responded&&!rsp_valid)age<=age+1'b1;
      if(req_valid&&req_ready)begin accepted<=1;accepted_op<=req_op;age<=0;end
      if(rsp_valid)responded<=1;
      if(rsp_valid&&rsp_ready)begin assert(!consumed);consumed<=1;end
      if(accepted)assume(!req_valid);
      assert(!(rsp_valid&&!accepted));
      if(accepted&&!responded)assert(age<=36);
      if($past(rsp_valid&&!rsp_ready))begin assert(rsp_valid);assert($stable(rsp_result));end
      for(integer op=0;op<8;op++)cover(responded&&accepted_op==op);
    end
  end
endmodule
