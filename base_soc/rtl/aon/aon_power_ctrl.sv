module aon_power_ctrl (
  input  logic        clk_32k,
  input  logic        rst_n,
  input  logic        wake_req, // e.g., timer IRQ for wake from SLEEP

  // APB slave (0x000 space)
  input  logic [11:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,

  // Power controls
  output logic        pd1_sw_en,
  output logic        pd2_sw_en,
  output logic        iso_pd1_n,
  output logic        iso_pd2_n,
  output logic        save_pd2,
  output logic        restore_pd2,
  output logic        wake_irq
);

  // Registers
  typedef enum logic [1:0] {RUN=2'd0, SLEEP=2'd1, CRYPTO_ONLY=2'd2, DEEP_SLEEP=2'd3} pst_e;
  pst_e pst, pst_next;

  logic [31:0] reg_ctrl;   // [1]=force_deepsleep, [0]=force_sleep
  logic [31:0] reg_status; // [3:0] pst_state, [8]=wake_irq

  // APB
  assign pready  = 1'b1;
  assign pslverr = 1'b0;
  always_comb begin
    unique case (paddr[11:2])
      10'h000: prdata = reg_ctrl;
      10'h001: prdata = reg_status;
      default: prdata = 32'h0;
    endcase
  end

  // FSM sequencing helpers
  logic [2:0] seq_cnt;
  logic        unused_addr_bits;

  assign unused_addr_bits = |paddr[1:0];

  // Outputs default
  always_ff @(posedge clk_32k or negedge rst_n) begin
    if (!rst_n) begin
      reg_ctrl    <= '0;
      reg_status  <= '0;
    end else begin
      // APB write
      if (psel && penable && pwrite) begin
        unique case (paddr[11:2])
          10'h000: reg_ctrl <= pwdata;
          default: ;
        endcase
      end
      // Auto-clear sleep request on wake
      if (pst==SLEEP && wake_req) begin
        reg_ctrl[0] <= 1'b0;
      end
      // status update
      reg_status[3:0] <= {2'b00,pst};
      reg_status[8]   <= wake_irq;
    end
  end

  // Decode target state from control
  always_comb begin
    pst_next = pst;
    if (reg_ctrl[1]) pst_next = DEEP_SLEEP;
    else if (reg_ctrl[0]) pst_next = SLEEP;
    else pst_next = RUN;
    // Timer wake: only from SLEEP to RUN
    if (pst==SLEEP && wake_req) pst_next = RUN;
  end

  // Simple sequencing enforcing iso/save/power/restore order when state changes
  typedef enum logic [1:0] {IDLE, PRE_OFF, POWER_TOGGLE, POST_ON} seq_e;
  seq_e seq_state;

  always_ff @(posedge clk_32k or negedge rst_n) begin
    if (!rst_n) begin
      pst          <= RUN;
      pd1_sw_en    <= 1'b1;
      pd2_sw_en    <= 1'b1;
      iso_pd1_n    <= 1'b1;
      iso_pd2_n    <= 1'b1;
      save_pd2     <= 1'b0;
      restore_pd2  <= 1'b0;
      wake_irq     <= 1'b0;
      seq_state    <= IDLE;
      seq_cnt      <= '0;
    end else begin
      save_pd2    <= 1'b0;
      restore_pd2 <= 1'b0;
      wake_irq    <= 1'b0;

      case (seq_state)
        IDLE: begin
          if (pst_next != pst) begin
            // assert isolation before power-off as needed for next state
            iso_pd1_n <= (pst_next==RUN) ? 1'b1 : 1'b0; // PD1 isolated unless RUN
            iso_pd2_n <= (pst_next==RUN || pst_next==CRYPTO_ONLY || pst_next==SLEEP) ? 1'b1 : 1'b0; // PD2 only isolated in DEEP_SLEEP
            // For SLEEP/DEEP_SLEEP, prepare save on PD2
            if (pst_next==SLEEP || pst_next==DEEP_SLEEP) begin
              save_pd2  <= 1'b1;
            end
            seq_state <= PRE_OFF;
            seq_cnt   <= 3'd0;
          end else begin
            // No change
          end
        end
        PRE_OFF: begin
          // after one cycle, toggle power switches according to next state
          seq_cnt   <= seq_cnt + 3'd1;
          if (seq_cnt==3'd1) begin
            // PD1 off in all but RUN
            pd1_sw_en <= (pst_next==RUN);
            // PD2 off only in DEEP_SLEEP
            pd2_sw_en <= (pst_next==RUN || pst_next==CRYPTO_ONLY);
            pst       <= pst_next;
            seq_state <= POWER_TOGGLE;
            seq_cnt   <= 3'd0;
          end
        end
        POWER_TOGGLE: begin
          // after power-on request, handle restore and de-isolate
          seq_cnt <= seq_cnt + 3'd1;
          if (seq_cnt==3'd1) begin
            if (pd2_sw_en) begin
              // coming from SLEEP to RUN: restore PD2
              if (pst==RUN) begin
                restore_pd2 <= 1'b1;
                wake_irq    <= 1'b1;
              end
            end
            seq_state <= POST_ON;
          end
        end
        POST_ON: begin
          // deassert isolation after power is stable
          iso_pd1_n <= (pst==RUN) ? 1'b1 : 1'b0;
          iso_pd2_n <= (pst==RUN || pst==CRYPTO_ONLY) ? 1'b1 : 1'b0;
          seq_state <= IDLE;
        end
      endcase
    end
  end

endmodule
