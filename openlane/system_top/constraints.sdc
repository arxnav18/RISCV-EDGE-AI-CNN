# -----------------------------------------------------------------------------
# Synopsys Design Constraints (SDC) for system_top
# Target Toolchain: OpenROAD / Yosys
# Target Frequency: 100 MHz
# -----------------------------------------------------------------------------

# 1. Clock Definition (10.0 ns period = 100 MHz)
create_clock -name "clk" -period 10.0 [get_ports {clk}]

# 2. Clock Uncertainty (Jitter & Skew margin)
# Adds a 0.25ns buffer for realistic clock tree synthesis (CTS) variance
set_clock_uncertainty 0.25 [get_clocks {clk}]

# 3. Input Delays (Setup time margins for incoming signals)
# Assume 2.0ns (20% of period) is consumed by the external bus routing outside the chip
set_input_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {reset}]

# AXI4-Lite Slave Inputs (from external CPU)
set_input_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {S_AXI_AWADDR S_AXI_AWVALID S_AXI_WDATA S_AXI_WVALID S_AXI_BREADY S_AXI_ARADDR S_AXI_ARVALID S_AXI_RREADY}]

# AXI4 Master Inputs (from external DDR)
set_input_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {M_AXI_AWREADY M_AXI_WREADY M_AXI_BRESP M_AXI_BVALID M_AXI_ARREADY M_AXI_RDATA M_AXI_RRESP M_AXI_RLAST M_AXI_RVALID}]


# 4. Output Delays (Hold time margins required by external receivers)
# The external bus needs the data stable 2.0ns before the next clock edge
set_output_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {done}]

# AXI4-Lite Slave Outputs (to external CPU)
set_output_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {S_AXI_AWREADY S_AXI_WREADY S_AXI_BRESP S_AXI_BVALID S_AXI_ARREADY S_AXI_RDATA S_AXI_RRESP S_AXI_RVALID}]

# AXI4 Master Outputs (to external DDR)
set_output_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {M_AXI_AWADDR M_AXI_AWLEN M_AXI_AWSIZE M_AXI_AWBURST M_AXI_AWVALID}]
set_output_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {M_AXI_WDATA M_AXI_WSTRB M_AXI_WLAST M_AXI_WVALID M_AXI_BREADY}]
set_output_delay -max 2.0 -clock [get_clocks {clk}] [get_ports {M_AXI_ARADDR M_AXI_ARLEN M_AXI_ARSIZE M_AXI_ARBURST M_AXI_ARVALID M_AXI_RREADY}]


# 5. Output Load / Input Drive
# These tell OpenROAD how to buffer the outer perimeter of the chip
set_load 10.0 [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]

# 6. Max Transition / Fanout
set_max_transition 1.5 [current_design]
set_max_fanout 12 [current_design]
