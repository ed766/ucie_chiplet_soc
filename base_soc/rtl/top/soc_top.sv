module soc_top (
  input  logic        clk,
  input  logic        clk_32k,
  input  logic        rst_n,
  // Top-level APB slave exported
  input  logic [31:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  // AON: power controller and timer, plus APB bridge
  logic        pd1_sw_en, pd2_sw_en;
  logic        iso_pd1_n, iso_pd2_n;
  logic        save_pd2, restore_pd2;

  // APB interconnect signals
  logic        s0_psel,s0_penable,s0_pwrite; logic [11:0] s0_paddr; logic [31:0] s0_pwdata; logic [31:0] s0_prdata; logic s0_pready,s0_pslverr;
  logic        s1_psel,s1_penable,s1_pwrite; logic [11:0] s1_paddr; logic [31:0] s1_pwdata; logic [31:0] s1_prdata; logic s1_pready,s1_pslverr;
  logic        s2_psel,s2_penable,s2_pwrite; logic [11:0] s2_paddr; logic [31:0] s2_pwdata; logic [31:0] s2_prdata; logic s2_pready,s2_pslverr;
  logic        wake_irq_unused;
  logic [31:0] pd1_paddr_unused, pd1_pwdata_unused;
  logic        pd1_psel_unused, pd1_penable_unused, pd1_pwrite_unused;
  logic        pd1_halted_unused;
  logic        pd1_instr_ready_unused;
  logic        pd1_commit_valid_unused;
  logic [31:0] pd1_commit_instr_unused, pd1_commit_pc_unused, pd1_commit_next_pc_unused;
  logic        pd1_wb_valid_unused;
  logic [4:0]  pd1_wb_rd_unused;
  logic [31:0] pd1_wb_data_unused;
  logic        pd1_mem_valid_unused, pd1_mem_write_unused;
  logic [31:0] pd1_mem_addr_unused, pd1_mem_wdata_unused, pd1_mem_rdata_unused;
  logic        pd1_branch_taken_unused, pd1_illegal_unused;
  logic        retire_iso_unused;
  logic        unused_top_comb;
  // Raw (pre-isolation) signals from PD2
  logic [31:0] s2_prdata_raw; logic s2_pready_raw, s2_pslverr_raw;

  apb_bridge u_bus (
    .m_paddr(paddr), .m_psel(psel), .m_penable(penable), .m_pwrite(pwrite), .m_pwdata(pwdata),
    .m_prdata(prdata), .m_pready(pready), .m_pslverr(pslverr),
    .s0_psel(s0_psel), .s0_penable(s0_penable), .s0_pwrite(s0_pwrite), .s0_paddr(s0_paddr), .s0_pwdata(s0_pwdata), .s0_prdata(s0_prdata), .s0_pready(s0_pready), .s0_pslverr(s0_pslverr),
    .s1_psel(s1_psel), .s1_penable(s1_penable), .s1_pwrite(s1_pwrite), .s1_paddr(s1_paddr), .s1_pwdata(s1_pwdata), .s1_prdata(s1_prdata), .s1_pready(s1_pready), .s1_pslverr(s1_pslverr),
    .s2_psel(s2_psel), .s2_penable(s2_penable), .s2_pwrite(s2_pwrite), .s2_paddr(s2_paddr), .s2_pwdata(s2_pwdata), .s2_prdata(s2_prdata), .s2_pready(s2_pready), .s2_pslverr(s2_pslverr)
  );

  aon_power_ctrl u_pwr (
    .clk_32k   (clk_32k),
    .rst_n     (rst_n),
    .wake_req  (tim_irq),
    .paddr     (s0_paddr),
    .psel      (s0_psel),
    .penable   (s0_penable),
    .pwrite    (s0_pwrite),
    .pwdata    (s0_pwdata),
    .prdata    (s0_prdata),
    .pready    (s0_pready),
    .pslverr   (s0_pslverr),
    .pd1_sw_en (pd1_sw_en),
    .pd2_sw_en (pd2_sw_en),
    .iso_pd1_n (iso_pd1_n),
    .iso_pd2_n (iso_pd2_n),
    .save_pd2  (save_pd2),
    .restore_pd2(restore_pd2),
    .wake_irq  (wake_irq_unused)
  );

  logic tim_irq;
  timer_32k u_tim (
    .clk_32k (clk_32k), .rst_n(rst_n),
    .paddr   (s1_paddr), .psel(s1_psel), .penable(s1_penable), .pwrite(s1_pwrite), .pwdata(s1_pwdata),
    .prdata  (s1_prdata), .pready(s1_pready), .pslverr(s1_pslverr),
    .irq     (tim_irq)
  );

  // PD1: RV32 core (power switched and isolated)
  logic        pd1_retire;

  // Synchronized resets per domain
  logic pd1_rst_n, pd2_rst_n;
  rst_sync u_rst_pd1(.clk(clk), .arst_n(rst_n), .pwr_en(pd1_sw_en), .srst_n(pd1_rst_n));
  rst_sync u_rst_pd2(.clk(clk), .arst_n(rst_n), .pwr_en(pd2_sw_en), .srst_n(pd2_rst_n));

  rv32_core u_core (
    .clk    (clk),
    .rst_n  (pd1_rst_n),
    .instr_valid(1'b0),
    .instr_ready(pd1_instr_ready_unused),
    .instr  (32'h0000_0013),
    .paddr  (pd1_paddr_unused),
    .psel   (pd1_psel_unused),
    .penable(pd1_penable_unused),
    .pwrite (pd1_pwrite_unused),
    .pwdata (pd1_pwdata_unused),
    .prdata (32'h0),
    .pready (1'b1),
    .pslverr(1'b0),
    .commit_valid(pd1_commit_valid_unused),
    .commit_instr(pd1_commit_instr_unused),
    .commit_pc(pd1_commit_pc_unused),
    .commit_next_pc(pd1_commit_next_pc_unused),
    .wb_valid(pd1_wb_valid_unused),
    .wb_rd(pd1_wb_rd_unused),
    .wb_data(pd1_wb_data_unused),
    .mem_valid(pd1_mem_valid_unused),
    .mem_write(pd1_mem_write_unused),
    .mem_addr(pd1_mem_addr_unused),
    .mem_wdata(pd1_mem_wdata_unused),
    .mem_rdata(pd1_mem_rdata_unused),
    .branch_taken(pd1_branch_taken_unused),
    .illegal_instr(pd1_illegal_unused),
    .retire (pd1_retire),
    .halted (pd1_halted_unused)
  );

  // PD2: AES regs (power switched and isolated)
  aes_regs u_aes_regs (
    .clk     (clk), .rst_n(rst_n),
    .rst_pd_n(pd2_rst_n),
    .paddr   (s2_paddr), .psel(s2_psel), .penable(s2_penable), .pwrite(s2_pwrite), .pwdata(s2_pwdata),
    .prdata  (s2_prdata_raw), .pready(s2_pready_raw), .pslverr(s2_pslverr_raw),
    .pwr_en  (pd2_sw_en), .save(save_pd2), .restore(restore_pd2)
  );

  // Isolation for PD2 APB outputs into AON fabric
  logic [31:0] s2_prdata_iso; logic s2_pready_iso, s2_pslverr_iso;
  iso_cell #(.WIDTH(32)) u_iso_pd2_prdata (.iso_n(iso_pd2_n), .in(s2_prdata_raw),  .out(s2_prdata_iso));
  iso_cell #(.WIDTH(1 )) u_iso_pd2_pready (.iso_n(iso_pd2_n), .in(s2_pready_raw),  .out(s2_pready_iso));
  iso_cell #(.WIDTH(1 )) u_iso_pd2_pslerr (.iso_n(iso_pd2_n), .in(s2_pslverr_raw), .out(s2_pslverr_iso));

  // Rewire isolated signals back to AON bus mux
  assign s2_prdata  = s2_prdata_iso;
  assign s2_pready  = s2_pready_iso;
  assign s2_pslverr = s2_pslverr_iso;

  // Isolation examples (RV32 -> AON tracing)
  iso_cell #(.WIDTH(1)) u_iso_pd1_ret (.iso_n(iso_pd1_n), .in(pd1_retire), .out(retire_iso_unused));
  // Not used further but demonstrates isolation of cross-domain nets

  assign unused_top_comb = |{wake_irq_unused, retire_iso_unused,
                             pd1_psel_unused, pd1_penable_unused, pd1_pwrite_unused,
                             pd1_paddr_unused, pd1_pwdata_unused, pd1_halted_unused,
                             pd1_instr_ready_unused, pd1_commit_valid_unused,
                             pd1_commit_instr_unused, pd1_commit_pc_unused, pd1_commit_next_pc_unused,
                             pd1_wb_valid_unused, pd1_wb_rd_unused, pd1_wb_data_unused,
                             pd1_mem_valid_unused, pd1_mem_write_unused,
                             pd1_mem_addr_unused, pd1_mem_wdata_unused, pd1_mem_rdata_unused,
                             pd1_branch_taken_unused, pd1_illegal_unused};

  always_comb begin
    if (unused_top_comb) begin end
  end

endmodule
