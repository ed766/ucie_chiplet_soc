// Simplified iterative AES-128 placeholder: performs 10 rounds of XOR with key
module aes128_iterative (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [127:0] key,
  input  logic [127:0] block_in,
  output logic        ready,
  output logic        done,
  output logic [127:0] block_out
);
  logic [3:0] round;
  logic       busy;
  logic [127:0] state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ready <= 1'b1; done <= 1'b0; busy <= 1'b0; round <= '0; state <= '0; block_out <= '0;
    end else begin
      done <= 1'b0;
      if (!busy) begin
        if (start) begin
          busy  <= 1'b1;
          ready <= 1'b0;
          round <= 4'd0;
          state <= block_in ^ key;
        end
      end else begin
        // 10 dummy rounds: rotate and xor key
        state <= {state[126:0], state[127]} ^ key;
        round <= round + 4'd1;
        if (round == 4'd9) begin
          busy      <= 1'b0;
          ready     <= 1'b1;
          done      <= 1'b1;
          block_out <= state;
        end
      end
    end
  end
endmodule

