# Chiplet top timing constraints for OpenLane/LibreLane.
set_units -time ns

create_clock -name clk -period $::env(CLOCK_PERIOD) [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

set_false_path -from [get_ports rst_n]
set_input_delay -clock clk 0 [get_ports rst_n]

set_output_delay -clock clk 0 [get_ports {plaintext_monitor ciphertext_monitor die_b_ciphertext_monitor crypto_error_flag}]
