// Power sequencing assertions bound into aon_power_ctrl.

module aon_power_ctrl_sva (
  input logic clk_32k,
  input logic rst_n,
  input logic pd1_sw_en,
  input logic pd2_sw_en,
  input logic iso_pd1_n,
  input logic iso_pd2_n,
  input logic save_pd2,
  input logic restore_pd2
);
  default clocking cb @(posedge clk_32k); endclocking
  default disable iff (!rst_n);

  // Isolation must be active before PD1 power is cut.
  property pd1_iso_before_powerdown;
    $fell(pd1_sw_en) |-> $past(iso_pd1_n == 1'b0, 1);
  endproperty
  assert property (pd1_iso_before_powerdown)
    else $error("PD1 power cut without isolation asserted");

  // Isolation must be active before PD2 power is cut.
  property pd2_iso_before_powerdown;
    $fell(pd2_sw_en) |-> $past(iso_pd2_n == 1'b0, 1);
  endproperty
  assert property (pd2_iso_before_powerdown)
    else $error("PD2 power cut without isolation asserted");

  // Save pulse must precede PD2 shutdown during sleep/deep sleep entry.
  property pd2_save_before_off;
    $fell(pd2_sw_en) |-> (save_pd2 || $past(save_pd2, 1));
  endproperty
  assert property (pd2_save_before_off)
    else $error("PD2 power cut without save sequence");

  // Restore pulse must follow PD2 power-up within two cycles.
  property pd2_restore_after_on;
    $rose(pd2_sw_en) |-> (restore_pd2 || $past(restore_pd2, 1) || $past(restore_pd2, 2));
  endproperty
  assert property (pd2_restore_after_on)
    else $error("PD2 power-up without restore sequence");

  // When a domain is off, isolation must remain asserted.
  assert property ((pd1_sw_en == 1'b0) |-> (iso_pd1_n == 1'b0))
    else $error("PD1 isolated signal released while power is off");
  assert property ((pd2_sw_en == 1'b0) |-> (iso_pd2_n == 1'b0))
    else $error("PD2 isolated signal released while power is off");

endmodule

bind aon_power_ctrl aon_power_ctrl_sva (
  .clk_32k(clk_32k),
  .rst_n(rst_n),
  .pd1_sw_en(pd1_sw_en),
  .pd2_sw_en(pd2_sw_en),
  .iso_pd1_n(iso_pd1_n),
  .iso_pd2_n(iso_pd2_n),
  .save_pd2(save_pd2),
  .restore_pd2(restore_pd2)
);
