## Constraints for Artix-7 xc7a100tcsg324-1 (Digilent Nexys A7)
## Top Module: system_top

# Clock constraint (100MHz)
# Nexys A7 board oscillator is connected to pin E3
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports { clk }];

# Reset Pin 
# Mapping to CPU Reset button (C12) which is active low on Nexys A7
# set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { reset }];

# Done LED
# Mapping the 'done' output to LED 0 (H17)
# set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { done }];

# Note: The AXI4 and AXI4-Lite interfaces in system_top.v are typically connected 
# internally within a Vivado Block Design (e.g., to a DDR controller or Interconnect).
# Therefore, package pins are not assigned for the AXI interface ports here. 
# If running an out-of-context (OOC) synthesis, these do not need pin assignments.
