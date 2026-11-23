# Mini-eFPGA provisional timing constraints for Tiny Tapeout (SKY130)
# Adapted from https://www.tinytapeout.com/faq/#how-can-i-map-an-additional-external-clock-to-one-of-the-gpios
# IMPORTANT: The configuration chain feeds logic in the fabric clock domain.
# Asynchronous clock groups are only a provisional timing exception:
# verify that configuration remains stable during operation, and perform CDC review.

# Values shared by both clocks (currently assumes identical nominal clock periods)
set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}
set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]

# All input ports except clock ports
set data_inputs [all_inputs]
foreach clk_port [list [get_ports clk] [get_ports {uio_in[3]}]] {
    set idx [lsearch $data_inputs $clk_port]
    if { $idx >= 0 } {
        set data_inputs [lreplace $data_inputs $idx $idx]
    }
}

# Main fabric clock
create_clock [get_ports clk] -name fabric_clk -period $::env(CLOCK_PERIOD)
set_input_delay $input_delay_value -clock [get_clocks fabric_clk] $data_inputs
set_output_delay $output_delay_value -clock [get_clocks fabric_clk] [all_outputs]

# Serial configuration clock on uio_in[3]
create_clock [get_ports {uio_in[3]}] -name cfg_clk -period $::env(CLOCK_PERIOD)
set_input_delay $input_delay_value -clock [get_clocks cfg_clk] -add_delay $data_inputs
set_output_delay $output_delay_value -clock [get_clocks cfg_clk] -add_delay [all_outputs]

# These independent clock domains have config-to-fabric control/data crossings.
# Keep this exception ONLY after confirming programming freezes the fabric and
# configuration remains stable while its flip-flops run. STA does not verify CDC.
set_clock_groups -asynchronous -group [get_clocks fabric_clk] -group [get_clocks cfg_clk]

set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) [all_clocks]
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) [all_clocks]

# Use the Tiny Tapeout default driving cell and capacitive load conventions
set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $data_inputs
if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}
set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    [list [get_ports clk] [get_ports {uio_in[3]}]]
set_load $cap_load [all_outputs]
set_timing_derate -early [expr 1 - $::env(TIME_DERATING_CONSTRAINT) / 100.0]
set_timing_derate -late [expr 1 + $::env(TIME_DERATING_CONSTRAINT) / 100.0]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
