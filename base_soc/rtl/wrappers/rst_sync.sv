module rst_sync (
  input  logic clk,
  input  logic arst_n,   // async, active-low
  input  logic pwr_en,   // domain power enable
  output logic srst_n    // synced, active-low
);
  // Combine async sources: assert reset when either low
  logic arst_pd_n;
  assign arst_pd_n = arst_n & pwr_en;

  // Two-flop synchronizer for deassertion
  logic [1:0] sync_ff;
  always_ff @(posedge clk or negedge arst_pd_n) begin
    if (!arst_pd_n) begin
      sync_ff <= 2'b00;
    end else begin
      sync_ff <= {sync_ff[0], 1'b1};
    end
  end

  assign srst_n = sync_ff[1];
endmodule

