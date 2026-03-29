module ret_ff #(
  parameter int WIDTH = 1
)(
  input  logic             clk,
  input  logic             rst_n,
  input  logic             pwr_en,
  input  logic             save,
  input  logic             restore,
  input  logic [WIDTH-1:0] d,
  input  logic             we,
  output logic [WIDTH-1:0] q
);
  logic [WIDTH-1:0] shadow;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q      <= '0;
      shadow <= '0;
    end else begin
      if (save) shadow <= q;
      if (restore) q <= shadow;
      else if (pwr_en && we) q <= d;
    end
  end
endmodule
