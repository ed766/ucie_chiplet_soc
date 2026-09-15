`timescale 1ns/1ps
module tb_rv32m_random;
  localparam int MAX_VECTORS=256;
  logic clk=0,rst_n=0,req_valid=0,req_ready,rsp_valid,rsp_ready=0;
  logic[2:0]req_op;logic[31:0]req_lhs,req_rhs,rsp_result;
  logic[98:0]vectors[0:MAX_VECTORS-1];
  string vector_file;integer vector_count,failures=0,max_latency=0;
  always #5 clk=~clk;
  rv32_muldiv dut(.*);
  initial begin
    if(!$value$plusargs("VECTORS=%s",vector_file))$fatal(1,"missing VECTORS");
    if(!$value$plusargs("VECTOR_COUNT=%d",vector_count))vector_count=32;
    $readmemh(vector_file,vectors);
    repeat(3)@(posedge clk);rst_n=1;
    for(integer i=0;i<vector_count;i++)begin
      integer latency;
      while(!req_ready)@(posedge clk);
      @(negedge clk);{req_op,req_lhs,req_rhs}=vectors[i][98:32];req_valid=1;
      @(posedge clk);@(negedge clk);req_valid=0;latency=0;
      while(!rsp_valid&&latency<=36)begin @(posedge clk);latency++;end
      if(!rsp_valid||rsp_result!==vectors[i][31:0])begin
        failures++;$display("RV32M_RANDOM_FAIL|index=%0d|op=%0d|lhs=%08x|rhs=%08x|got=%08x|expected=%08x",
          i,req_op,req_lhs,req_rhs,rsp_result,vectors[i][31:0]);
      end
      if(latency>max_latency)max_latency=latency;
      @(negedge clk);rsp_ready=1;@(posedge clk);@(negedge clk);rsp_ready=0;
    end
    $display("RV32M_RANDOM_SUMMARY|status=%s|vectors=%0d|failures=%0d|max_latency=%0d",
      failures?"FAIL":"PASS",vector_count,failures,max_latency);
    if(failures)$fatal(1,"random arithmetic mismatch");$finish;
  end
endmodule
