module timer_32k (
  input  logic        clk_32k,
  input  logic        rst_n,
  // APB slave (0x100 space)
  input  logic [11:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,
  // interrupt
  output logic        irq
);
  // Registers
  logic [31:0] reload_reg, value_reg;
  logic        en_reg;
  logic        unused_addr_bits;
  localparam logic [31:0] DEFAULT_RELOAD = 32'd1024;

  assign pready  = 1'b1;
  assign pslverr = 1'b0;

  // Consume lower address bits so lint knows they are intentionally unused
  assign unused_addr_bits = |paddr[1:0];

  // APB read mux
  always_comb begin
    unique case (paddr[11:2])
      10'h040: prdata = reload_reg;  // 0x100
      10'h041: prdata = value_reg;   // 0x104
      10'h042: prdata = {31'b0, en_reg}; // 0x108
      default: prdata = '0;
    endcase
  end

  logic [31:0] reload_next, value_next;
  logic        en_next;
  logic        irq_next;

  always_comb begin
    reload_next = reload_reg;
    value_next  = value_reg;
    en_next     = en_reg;
    irq_next    = 1'b0;

    if (en_reg) begin
      if (value_reg == 32'd0) begin
        value_next = reload_reg;
        irq_next   = 1'b1;
      end else begin
        value_next = value_reg - 32'd1;
      end
    end

    if (psel && penable && pwrite) begin
      unique case (paddr[11:2])
        10'h040: begin
          reload_next = pwdata;
          if (en_reg && value_reg == 32'd0) begin
            value_next = pwdata;
          end
        end
        10'h041: begin
          value_next = pwdata;
          irq_next   = 1'b0;
        end
        10'h042: begin
          en_next = pwdata[0];
          if (!pwdata[0]) begin
            irq_next = 1'b0;
          end
        end
        default: ;
      endcase
    end

    if (!en_next) begin
      irq_next = 1'b0;
    end
  end

  // Register update
  always_ff @(posedge clk_32k or negedge rst_n) begin
    if (!rst_n) begin
      reload_reg <= DEFAULT_RELOAD;
      value_reg  <= DEFAULT_RELOAD;
      en_reg     <= 1'b0;
      irq        <= 1'b0;
    end else begin
      reload_reg <= reload_next;
      value_reg  <= value_next;
      en_reg     <= en_next;
      irq        <= irq_next;
    end
  end
endmodule
