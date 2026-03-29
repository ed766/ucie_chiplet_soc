module iso_cell #(
  parameter int WIDTH = 1
)(
  input  logic             iso_n,
  input  logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);
  always_comb begin
    out = iso_n ? in : '0;
  end
endmodule

