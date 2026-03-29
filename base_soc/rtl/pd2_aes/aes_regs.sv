module aes_regs (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        rst_pd_n,
  // APB slave (0x200 space)
  input  logic [11:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,
  // Power intent hooks
  input  logic        pwr_en,
  input  logic        save,
  input  logic        restore
);
  // Key registers (retained)
  logic [31:0] key [0:3];
  // Data in/out
  logic [31:0] din [0:3];
  logic [31:0] dout[0:3];
  // Control/status
  logic        start;
  logic        ready, done;
  logic        unused_addr_bits;

  // Retention FF wrappers for keys
  genvar i;
  generate for (i=0;i<4;i++) begin : g_key
    ret_ff #(.WIDTH(32)) u_ret (
      .clk   (clk),
      .rst_n (rst_n),
      .pwr_en(pwr_en),
      .save  (save),
      .restore(restore),
      .d     (pwdata),
      .we    (psel && penable && pwrite && paddr[11:2]==(10'h080+i)), // 0x200..0x20C
      .q     (key[i])
    );
  end endgenerate

  // Consume low address bits to keep lint quiet about byte lanes
  assign unused_addr_bits = |paddr[1:0];

  // APB simple regs
  assign pready  = 1'b1;
  assign pslverr = 1'b0;
  always_comb begin
    unique case (paddr[11:2])
      // Key, Din, Dout spaces
      10'h080,10'h081,10'h082,10'h083: prdata = key[paddr[3:2]];
      10'h084,10'h085,10'h086,10'h087: prdata = din[paddr[3:2]];
      10'h088,10'h089,10'h08A,10'h08B: prdata = dout[paddr[3:2]];
      10'h08C: prdata = {31'b0, start}; // CTRL
      10'h08D: prdata = {30'b0, done, ready}; // STATUS
      default: prdata = '0;
    endcase
  end

  // Write for DIN/CTRL
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      din[0] <= '0; din[1] <= '0; din[2] <= '0; din[3] <= '0;
      start  <= 1'b0;
    end else begin
      if (psel && penable && pwrite) begin
        unique case (paddr[11:2])
          10'h084,10'h085,10'h086,10'h087: din[paddr[3:2]] <= pwdata;
          10'h08C: start <= pwdata[0];
          default: ;
        endcase
      end else begin
        start <= 1'b0; // pulse
      end
    end
  end

  // AES core hookup
  logic [127:0] key_bus, din_bus, dout_bus;
  assign key_bus = {key[3],key[2],key[1],key[0]};
  assign din_bus = {din[3],din[2],din[1],din[0]};
  assign {dout[3],dout[2],dout[1],dout[0]} = dout_bus;

  aes128_iterative u_aes (
    .clk      (clk),
    .rst_n    (rst_pd_n),
    .start    (start & pwr_en),
    .key      (key_bus),
    .block_in (din_bus),
    .ready    (ready),
    .done     (done),
    .block_out(dout_bus)
  );
endmodule
