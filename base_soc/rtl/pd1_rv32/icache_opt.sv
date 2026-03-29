// Optional simple direct-mapped I-cache placeholder
module icache_opt #(
  parameter int LINE_SIZE_BYTES = 16
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] addr,
  input  logic        req,
  output logic [127:0] line,
  output logic        hit
);
  // Placeholder: always miss on first access then hit same address
  logic [31:0] last_addr;
  logic        valid;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      last_addr <= '0; valid <= 1'b0; hit <= 1'b0; line <= '0;
    end else begin
      if (req) begin
        hit  <= valid && (addr==last_addr);
        line <= {4{addr}}; // trivial fill pattern
        last_addr <= addr;
        valid <= 1'b1;
      end else begin
        hit <= 1'b0;
      end
    end
  end
endmodule

