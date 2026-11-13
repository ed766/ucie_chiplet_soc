`timescale 1ns/1ps
module tb_rv32m_boundaries #(parameter bit ENABLE_M=1);
  logic clk=0, rst_n=0, instr_valid=0, instr_ready;
  logic [31:0] instr=32'h13;
  logic irq_ext=0, irq_timer=0, pready=1, pslverr=0;
  logic [31:0] prdata=32'd7;
  string mode, trace_path;
  integer op, phase, source, masked, alias_kind, waits, fd, cycles=0, apb_count=0;
  integer m_count=0, irq_count=0, reset_count=0;
  logic [31:0] m_pc, expected, saved_next, destination;
  logic [63:0] expected_cycle, expected_instret;
  always #5 clk=~clk;
  rv32_core #(.ENABLE_M(ENABLE_M),.ENABLE_TRAPS(1),.EBREAK_TEST_HALT(0)) dut (
    .clk,.rst_n,.instr,.instr_valid,.instr_ready,.irq_ext,.irq_timer,.pready,.pslverr,.prdata
  );
  function automatic logic [31:0] addi(input int rd,rs1,imm);
    return {imm[11:0],rs1[4:0],3'b000,rd[4:0],7'h13};
  endfunction
  function automatic logic [31:0] csr(input int rd,addr,rs1);
    return {addr[11:0],rs1[4:0],3'b001,rd[4:0],7'h73};
  endfunction
  function automatic logic [31:0] mop(input int rd,rs1,rs2);
    return {7'd1,rs2[4:0],rs1[4:0],op[2:0],rd[4:0],7'h33};
  endfunction
  function automatic logic [31:0] reference_result(input int operation,input logic [31:0] a,b);
    logic signed [63:0] sa,sb,product;
    logic [63:0] ua,ub,up;
    sa={{32{a[31]}},a};sb={{32{b[31]}},b};ua={32'b0,a};ub={32'b0,b};
    product=sa*sb;up=ua*ub;
    case(operation)
      0:return up[31:0];
      1:return product[63:32];
      2:begin product=sa*$signed(ub);return product[63:32];end
      3:return up[63:32];
      4:return 32'(sa/sb);
      5:return 32'(ua/ub);
      6:return 32'(sa%sb);
      7:return 32'(ua%ub);
      default:return 0;
    endcase
  endfunction
  task automatic issue(input logic [31:0] value);
    while(!instr_ready) @(negedge clk);
    instr=value;instr_valid=1;
    @(negedge clk);instr_valid=0;
  endtask
  task automatic retirement;
    integer count;
    count=0;
    while(!dut.rvfi_valid && count<100)begin @(negedge clk);count++;end
    if(!dut.rvfi_valid)$fatal(1,"boundary retirement timeout");
  endtask
  task automatic execute(input logic [31:0] value);
    issue(value);retirement();@(negedge clk);
  endtask
  task automatic reboot;
    rst_n=0;instr_valid=0;irq_ext=0;irq_timer=0;
    repeat(3)@(negedge clk);
    rst_n=1;reset_count++;
    repeat(2)@(negedge clk);
    if(dut.rvfi_valid||dut.muldiv_rsp_valid||dut.muldiv_active_q)
      $fatal(1,"old-epoch arithmetic state after reset");
  endtask
  task automatic operands;
    execute(addi(1,0,-7));execute(addi(2,0,3));
    expected=reference_result(op,32'hfffffff9,3);
  endtask
  task automatic set_irq;
    irq_ext=(source!=1);irq_timer=(source!=0);
    $display("BOUNDARY_EVENT|irq_arrival|cycle=%0d|phase=%0d|busy=%0d|result=%0d",cycles,phase,dut.muldiv_active_q,dut.muldiv_rsp_valid);
  endtask
  always @(posedge clk) begin
    cycles<=cycles+1;
    expected_cycle=rst_n ? dut.mcycle_q+1 : 0;
    expected_instret=rst_n ? dut.minstret_q+64'(dut.retire&&!dut.rvfi_intr&&!dut.rvfi_trap) : 0;
    if(rst_n && dut.psel && dut.penable && pready)apb_count<=apb_count+1;
    if(rst_n && dut.muldiv_active_q && dut.psel)$fatal(1,"younger APB during M");
  end
  always @(negedge clk) begin
    if(rst_n && (dut.mcycle_q!=expected_cycle || dut.minstret_q!=expected_instret))
      $fatal(1,"architectural counter accounting mismatch");
    if(rst_n && dut.rvfi_valid)begin
    if(dut.regs_q[0]!=0)$fatal(1,"x0 corrupted");
    if(dut.rvfi_insn[6:0]==7'h33 && dut.rvfi_insn[31:25]==1 && !dut.rvfi_trap && !dut.rvfi_intr)m_count++;
    if(dut.rvfi_intr)irq_count++;
    if(fd) $fdisplay(fd,"%0d,%0d,%0d,%08x,%08x,%08x,%0d,%0d,%0d,%0d,%08x,%08x,%0d,%08x,%08x,%x,%x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%08x,%0d,%0d",cycles,reset_count-1,dut.rvfi_order,dut.rvfi_insn,dut.rvfi_pc_rdata,dut.rvfi_pc_wdata,dut.rvfi_trap,dut.rvfi_intr,dut.rvfi_rs1_addr,dut.rvfi_rs2_addr,dut.rvfi_rs1_rdata,dut.rvfi_rs2_rdata,dut.rvfi_rd_addr,dut.rvfi_rd_wdata,dut.rvfi_mem_addr,dut.rvfi_mem_rmask,dut.rvfi_mem_wmask,dut.rvfi_mem_rdata,dut.rvfi_mem_wdata,dut.rvfi_mstatus,dut.rvfi_mie,dut.rvfi_mtvec,dut.rvfi_mscratch,dut.rvfi_mepc,dut.rvfi_mcause,dut.rvfi_mtval,dut.pc_q,irq_ext,irq_timer);
    end
  end
  initial begin
    if(!$value$plusargs("MODE=%s",mode))mode="alias";
    if(!$value$plusargs("OP=%d",op))op=0;
    if(!$value$plusargs("PHASE=%d",phase))phase=0;
    if(!$value$plusargs("SOURCE=%d",source))source=0;
    if(!$value$plusargs("MASKED=%d",masked))masked=0;
    if(!$value$plusargs("ALIAS=%d",alias_kind))alias_kind=0;
    if(!$value$plusargs("WAITS=%d",waits))waits=0;
    fd=0;
    if($value$plusargs("TRACE=%s",trace_path))begin
      fd=$fopen(trace_path,"w");if(!fd)$fatal(1,"cannot open trace");
      $fdisplay(fd,"cycle,epoch,order,insn,pc_rdata,pc_wdata,trap,intr,rs1_addr,rs2_addr,rs1_rdata,rs2_rdata,rd_addr,rd_wdata,mem_addr,mem_rmask,mem_wmask,mem_rdata,mem_wdata,mstatus,mie,mtvec,mscratch,mepc,mcause,mtval,current_pc,irq_level,irq_timer_level");
    end
    reboot();operands();
    if(mode=="disabled")begin
      issue(mop(3,1,2));retirement();
      if(!dut.rvfi_trap||dut.rvfi_mcause!=2||dut.rvfi_rd_addr!=0||dut.rvfi_mem_wmask||dut.psel)
        $fatal(1,"disabled M precise trap failure");
    end else if(mode=="alias")begin
      destination=(alias_kind==3)?0:(alias_kind==1)?1:(alias_kind==2)?2:3;
      issue(mop(int'(destination),1,2));retirement();
      if(dut.rvfi_trap||dut.rvfi_rd_wdata!=(destination==0?0:expected))$fatal(1,"alias result failure");
      @(negedge clk);operands();execute(mop(3,1,2));execute(mop(4,3,2));
      if(dut.regs_q[4]!=reference_result(op,expected,3))$fatal(1,"back-to-back dependency failure");
    end else if(mode=="reset")begin
      issue(mop(3,1,2));
      if(phase>0)begin
        wait(dut.muldiv_active_q);@(negedge clk);
        case(phase)
          1:repeat(1)@(negedge clk);
          2:repeat(16)@(negedge clk);
          3:wait(dut.u_muldiv.iteration_q==31);
          4:wait(dut.u_muldiv.state_q==2);
          5:wait(dut.muldiv_rsp_valid);
        endcase
      end
      // Reset is asserted away from the active sampling edge.
      #1;$display("BOUNDARY_EVENT|reset_target|cycle=%0d|epoch=%0d|phase=%0d|busy=%0d|result=%0d|iteration=%0d|state=%0d",cycles,reset_count-1,phase,dut.muldiv_active_q,dut.muldiv_rsp_valid,dut.u_muldiv.iteration_q,dut.u_muldiv.state_q);
      reboot();operands();execute(mop(3,1,2));
      if(dut.regs_q[3]!=expected)$fatal(1,"reboot M result failure");
    end else if(mode=="irq")begin
      execute(32'h000010b7);execute(addi(1,1,-1920));execute(csr(0,12'h304,1));
      if(!masked)begin execute(addi(1,0,8));execute(csr(0,12'h300,1));end
      operands();m_pc=dut.pc_q;
      if(phase==0)set_irq();
      issue(mop(3,1,2));
      if(phase==1)begin wait(dut.muldiv_active_q);repeat(16)@(negedge clk);set_irq();end
      if(phase==2)begin wait(dut.muldiv_rsp_valid);@(negedge clk);set_irq();end
      retirement();saved_next=dut.rvfi_pc_wdata;
      if(phase==0&&!masked)begin
        if(!dut.rvfi_intr||dut.rvfi_mepc!=m_pc)$fatal(1,"pre-dispatch IRQ ownership");
      end else begin
        if(!dut.rvfi_valid||dut.rvfi_intr||dut.rvfi_trap||dut.rvfi_rd_wdata!=expected)$fatal(1,"IRQ preempted M result");
        @(negedge clk);
        if(phase==3)set_irq();
        if(masked)begin
          execute(addi(1,0,8));execute(csr(0,12'h300,1));saved_next=dut.pc_q;
        end
        issue(addi(5,0,1));retirement();
        if(!dut.rvfi_intr||dut.rvfi_mepc!=saved_next)$fatal(1,"post-M IRQ mepc");
      end
      if(dut.rvfi_mcause!=(source==1?32'h80000007:32'h8000000b))$fatal(1,"IRQ priority/cause");
      @(negedge clk);irq_ext=0;irq_timer=0;
      execute(mop(6,2,2));execute(32'h30200073);
      if(dut.pc_q!=dut.mepc_q||!dut.mstatus_q[3])$fatal(1,"MRET restoration");
      if(phase==0&&!masked)execute(mop(3,1,2));
    end else if(mode=="fault")begin
      case(phase)
        0:destination=32'h100;
        1:destination=32'h104;
        2:destination=32'h1fc;
        3:destination=32'h200;
        4:destination=32'h101;
        5:destination=32'h1ff;
        6:destination=32'h100;
        7:destination=32'h104;
      endcase
      execute(addi(1,0,int'(destination)));execute(addi(2,0,1));execute(mop(4,1,2));
      if(dut.regs_q[4]!=destination)$fatal(1,"M-generated address incorrect");
      pslverr=(phase==7);
      issue({12'd0,5'd4,(phase==6?3'b011:3'b010),5'd3,7'h03});retirement();
      if(phase<3)begin
        if(dut.rvfi_trap||dut.rvfi_rd_wdata!=7||apb_count!=1)$fatal(1,"legal region boundary");
      end else begin
        if(!dut.rvfi_trap||dut.rvfi_rd_addr!=0||dut.regs_q[3]!=0)$fatal(1,"imprecise post-M load fault");
        if(dut.rvfi_mcause!=(phase==4||phase==5?4:phase==6?2:5))$fatal(1,"wrong post-M trap cause");
        if(apb_count!=(phase==7?1:0))$fatal(1,"fault caused unintended APB transfer");
      end
      @(negedge clk);
    end else if(mode=="apb")begin
      execute(addi(4,0,256));pready=0;
      issue({12'd0,5'd4,3'b010,5'd1,7'h03});
      wait(dut.penable);repeat(waits)begin @(negedge clk);if(dut.rvfi_valid)$fatal(1,"APB load early retirement");end
      pready=1;retirement();if(dut.rvfi_rd_wdata!=7)$fatal(1,"APB load data");
      @(negedge clk);execute(mop(3,1,2));expected=reference_result(op,7,3);
      pready=0;issue({7'd0,5'd3,5'd4,3'b010,5'd0,7'h23});
      wait(dut.penable);repeat(waits)begin @(negedge clk);if(dut.rvfi_valid)$fatal(1,"APB store early retirement");end
      if(dut.pwdata!=expected)$fatal(1,"M-to-APB store dependency");
      pready=1;retirement();if(apb_count!=2)$fatal(1,"APB exact accounting");
    end else $fatal(1,"unknown mode");
    @(negedge clk);
    $display("RV32M_BOUNDARY|status=PASS|mode=%s|op=%0d|phase=%0d|source=%0d|masked=%0d|m_retirements=%0d|interrupts=%0d|apb=%0d|resets=%0d",mode,op,phase,source,masked,m_count,irq_count,apb_count,reset_count);
    if(fd)$fclose(fd);$finish;
  end
  initial begin repeat(5000)@(posedge clk);$fatal(1,"boundary scenario timeout");end
endmodule
