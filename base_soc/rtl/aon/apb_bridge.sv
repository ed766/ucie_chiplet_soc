// Simple APB-Lite decoder/bridge from one master to three slaves
// Address map (word addressed):
//  0x000-0x0FF : AON power controller
//  0x100-0x10F : Timer 32k
//  0x200-0x23F : AES registers
module apb_bridge (
  // APB master (from top-level or AON master)
  input  logic  [31:0] m_paddr,
  input  logic         m_psel,
  input  logic         m_penable,
  input  logic         m_pwrite,
  input  logic  [31:0] m_pwdata,
  output logic  [31:0] m_prdata,
  output logic         m_pready,
  output logic         m_pslverr,

  // Slave 0: power controller (0x000)
  output logic         s0_psel,
  output logic         s0_penable,
  output logic         s0_pwrite,
  output logic  [11:0] s0_paddr,
  output logic  [31:0] s0_pwdata,
  input  logic  [31:0] s0_prdata,
  input  logic         s0_pready,
  input  logic         s0_pslverr,

  // Slave 1: timer (0x100)
  output logic         s1_psel,
  output logic         s1_penable,
  output logic         s1_pwrite,
  output logic  [11:0] s1_paddr,
  output logic  [31:0] s1_pwdata,
  input  logic  [31:0] s1_prdata,
  input  logic         s1_pready,
  input  logic         s1_pslverr,

  // Slave 2: AES regs (0x200)
  output logic         s2_psel,
  output logic         s2_penable,
  output logic         s2_pwrite,
  output logic  [11:0] s2_paddr,
  output logic  [31:0] s2_pwdata,
  input  logic  [31:0] s2_prdata,
  input  logic         s2_pready,
  input  logic         s2_pslverr
);

  // decode
  logic [1:0] sel;
  logic       invalid_high_bits;
  always_comb begin
    invalid_high_bits = |m_paddr[31:12];
    sel = 2'd3; // invalid
    if (!invalid_high_bits) begin
      unique casez (m_paddr[11:8])
        4'h0: sel = 2'd0; // 0x000
        4'h1: sel = 2'd1; // 0x100
        4'h2,4'h3: sel = 2'd2; // 0x200-0x3FF
        default: sel = 2'd3;
      endcase
    end
  end


  // fanout
  assign s0_psel    = m_psel && (sel==2'd0);
  assign s1_psel    = m_psel && (sel==2'd1);
  assign s2_psel    = m_psel && (sel==2'd2);

  assign s0_penable = m_penable;
  assign s1_penable = m_penable;
  assign s2_penable = m_penable;

  assign s0_pwrite  = m_pwrite;
  assign s1_pwrite  = m_pwrite;
  assign s2_pwrite  = m_pwrite;

  assign s0_paddr   = m_paddr[11:0];
  assign s1_paddr   = m_paddr[11:0];
  assign s2_paddr   = m_paddr[11:0];

  assign s0_pwdata  = m_pwdata;
  assign s1_pwdata  = m_pwdata;
  assign s2_pwdata  = m_pwdata;

  // mux back
  always_comb begin
    m_prdata  = 32'h0;
    m_pready  = 1'b1;
    m_pslverr = 1'b0;
    unique case (sel)
      2'd0: begin m_prdata=s0_prdata; m_pready=s0_pready; m_pslverr=s0_pslverr; end
      2'd1: begin m_prdata=s1_prdata; m_pready=s1_pready; m_pslverr=s1_pslverr; end
      2'd2: begin m_prdata=s2_prdata; m_pready=s2_pready; m_pslverr=s2_pslverr; end
      default: begin m_prdata=32'hDEAD_BEEF; m_pready=1'b1; m_pslverr=m_psel; end
    endcase
  end

endmodule
