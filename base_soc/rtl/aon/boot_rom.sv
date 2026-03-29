module boot_rom #(
  parameter int DEPTH_WORDS = 256
)(
  input  logic        clk,
  input  logic        en,
  input  logic [31:0] addr,   // word address
  output logic [31:0] rdata
);
  logic [31:0] mem [0:DEPTH_WORDS-1];

  // Optional external initialization via $readmemh("boot.hex", mem);
  initial begin : init_mem
    integer i;
    for (i=0;i<DEPTH_WORDS;i++) mem[i] = 32'h00000013; // NOP (ADDI x0,x0,0)
  end

  always_ff @(posedge clk) begin
    if (en) rdata <= mem[addr[$clog2(DEPTH_WORDS)+1:2]];
  end
endmodule

