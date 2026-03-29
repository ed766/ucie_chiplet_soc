module power_switch #(
  parameter int WIDTH = 1
)(
  input  logic             en,
  input  logic [WIDTH-1:0] in,
  output logic [WIDTH-1:0] out
);
  always_comb begin
    if (en) out = in; else out = 'x;
  end
endmodule

