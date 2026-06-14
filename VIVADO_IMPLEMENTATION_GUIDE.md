# Vivado Implementation Guide: RISC-V + CNN Accelerator

This guide provides step-by-step instructions to migrate the `RISCV-with-custom-hardware-acceleration` project from its ASIC (OpenLane/Sky130) target to a Xilinx FPGA target using Vivado (2020.2 or later).

---

## TASK 1 — Vivado Simulation Setup

### 1. Importing RTL Sources
To bring the project into Vivado:
1. Open Vivado and select **Create Project**.
2. Name the project `riscv_cnn_fpga` and select **RTL Project** (uncheck "Do not specify sources at this time").
3. Click **Add Directories** and select the `/rtl` folder. Check "Scan and add RTL include files into project".
4. Click **Add Directories** again and select `/edge_ai_cnn_accelerator/rtl` and `/tb` (or the top-level testbench directory).
5. Choose your target FPGA (e.g., ZCU104 or Nexys A7).

### 2. Configure Simulation Sources
1. In the Vivado **Sources** pane, navigate to the **Simulation Sources** folder.
2. Locate `system_integration_tb.v`.
3. Right-click on it and select **Set as Top**.

### 3. Mapping Memory Primitives
The ASIC flow often uses `DFFRAM` macros. For Vivado, these must be mapped to Block RAM (BRAM).
⚠️ **Action Required**: Any explicit instantiation of Sky130 DFFRAM must be replaced. Use Vivado's native inference (as seen in `feature_map_ram.v`) or instantiate `XPM_MEMORY`:
```verilog
// Replace ASIC DFFRAM instance with XPM Macro
xpm_memory_spram #(
   .MEMORY_SIZE(65536),
   .READ_LATENCY_A(1)
) bram_inst (
   .clka(clk),
   .ena(en),
   .wea(we),
   .addra(addr),
   .dina(d_in),
   .douta(d_out)
);
```

### 4. Tool-Specific Issues (Syntax & Parsing)
Vivado's `xvlog` parser can be strict regarding SystemVerilog vs. Verilog-2001.
⚠️ **Action Required**: 
- If any files use `.sv` constructs (like `logic` or `always_ff`) but are saved as `.v`, right-click the file in Vivado -> **Set File Type** -> **SystemVerilog**.
- Ensure loop variables (`integer i;`) are declared outside `always` blocks for strict Verilog-2001 compatibility, which the codebase currently handles well.

### 5. Running Behavioral Simulation
1. Click **Run Simulation** -> **Run Behavioral Simulation**.
2. Allow the simulation to run for at least `10ms` (adjust run time in the toolbar).
3. Check the TCL Console output. You should observe:
   `PASS: System integration test complete. CNN asserted done.`

### 6. Generate `.wcfg` (Waveform Configuration)
To save your debug signals:
1. In the simulation waveform window, add the following signals:
   - `clk`, `reset` (System Top)
   - `mmio_addr`, `mmio_wdata` (AXI4-Lite / MMIO Bus)
   - `cnn_start`, `cnn_done` (CNN Controller)
   - `conv1_active`, `conv2_active`, `fc_active` (FSM States)
   - `dma_burst_valid` (DMA Controller)
2. Click **File -> Save Waveform Configuration As...** and save it as `debug_view.wcfg`.
3. When prompted, add this file to your simulation sources.

---

## TASK 2 — FPGA Implementation (Synthesis + P&R)

### 1. Identify Target and Top-Level
- **Top Module**: `system_top.v`
- **Target Board**: **Digilent Nexys A7 (XC7A100T-1CSG324C)** is highly recommended due to its large amount of BRAM (4.8Mb) and DSP slices (240), which are critical for the MAC array and Line Buffers.

### 2. Primitive Replacements
To ensure synthesis success on Xilinx:
- Remove any `sky130_fd_sc_hd__*` clock buffer instances. Replace them with standard `BUFG` or allow Vivado to auto-infer them from the primary clock port.

### 3. Basic XDC Constraints File
Create a file named `constraints.xdc` and add it to the **Constraints** folder in Vivado:

```tcl
# Clock constraint (100MHz)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports { clk }];

# Reset Pin (Active Low)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { reset_n }];

# CNN Done LED
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { cnn_done }];
```

### 4. Running Synthesis & Expected Reports
1. Click **Run Synthesis**.
2. **Review Utilization Report**: The Nexys A7 should easily fit this. Expect ~15% LUT utilization, heavily localized BRAM usage for the feature maps/line buffers, and dedicated DSP48 usage for `mac_array.v`.
3. **Review Timing Report**: Check the **Worst Negative Slack (WNS)**. A positive WNS confirms 100MHz is achievable. 
4. **Warnings**: Look out for "Multi-driven net" warnings on the AXI bus if read/write channels overlap improperly.

---

## TASK 3 — Improvement Suggestions for FPGA

Based on the repository analysis, here are the targeted improvements for Xilinx FPGAs:

### 1. DSP48 Utilization in `mac_array.v`
FPGAs pack high-speed multipliers and adders in DSP48 slices. To guarantee Vivado infers these correctly without flattening to LUTs, use the `(* use_dsp = "yes" *)` attribute.

**RTL Diff (`rtl/mac_array.v`)**:
```diff
-    reg signed [15:0] mult_res [0:8];
+    (* use_dsp = "yes" *) reg signed [15:0] mult_res [0:8];
```

### 2. BRAM Packing Efficiency
`feature_map_ram.v` currently has an `ADDR_WIDTH` of 6 and `DATA_WIDTH` of 8 (64 bytes). This is too small for a 36Kb Xilinx Block RAM and will likely be synthesized into Distributed RAM (LUTRAM). For the main image buffers:
- **Suggestion**: Ensure the memory depth `(1 << ADDR_WIDTH) * DATA_WIDTH` approaches 18Kb or 36Kb boundaries. If smaller memory is intended, force LUTRAM mapping to save BRAM for line buffers.
```verilog
(* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
```

### 3. Clock Frequency (Fmax) Improvements
To push beyond 100MHz on Artix-7/Kintex-7:
- **Add Pipeline Registers to BRAM**: Xilinx BRAMs perform fastest with a 2-cycle read latency. `feature_map_ram.v` currently uses 1-cycle latency. Adding an output register will significantly improve the memory critical path.

### 4. AXI Interface
Integrating custom AXI4 Master/Slave logic is prone to edge-case bugs.
- **Suggestion**: Replace `axi4_lite_slave.v` with the **Vivado AXI IPI (IP Integrator) AXI4-Lite Register block**. You can generate this using the Vivado "Create and Package New IP" wizard. This guarantees protocol compliance and improves timing closure.

### 5. Operand Isolation vs. Vivado CE Pins
The ASIC design implements operand isolation by freezing inputs when invalid to save dynamic power. On an FPGA, manual data-path multiplexing for isolation adds LUT delays. Instead, rely natively on the Flip-Flop Clock Enable (CE) pin.

**RTL Diff (Conceptual isolation removal for FPGA speed)**:
```diff
-            if (en) begin
-                px_reg[0] <= pixels_in[0*8 +: 8];
-                valid_stg1 <= 1'b1;
-            end else begin
-                valid_stg1 <= 1'b0;
-            end
+            // Vivado automatically infers the CE pin from the 'if(en)' statement.
+            // Removing manual isolation logic reduces LUT depth.
+            if (en) px_reg[0] <= pixels_in[0*8 +: 8];
+            valid_stg1 <= en;
```

### 6. ILA (Integrated Logic Analyzer) Insertion
To debug in real silicon, insert an ILA core to probe the CNN state machine.
- **Where to insert**: Inside `edge_ai_cnn_peripheral.v`, probe the `cnn_controller` state bus, `mac_array` valid flags, and the AXI DMA `awvalid`/`wvalid` signals.
- **How**: 
```verilog
// Insert directly into RTL for Vivado synthesis
(* mark_debug = "true" *) wire [2:0] current_fsm_state;
(* mark_debug = "true" *) wire cnn_done_flag;
```

---

### Priority Improvement Checklist
- [x] **High**: Map standard cell clock buffers/DFFRAM to standard Vivado equivalents.
- [x] **High**: Append `(* use_dsp = "yes" *)` to multiplier outputs in `mac_array.v`.
- [ ] **Medium**: Increase BRAM read latency to 2 cycles for >100MHz timing closure.
- [ ] **Medium**: Apply `(* mark_debug = "true" *)` to critical CNN FSM states for ILA probing.
- [ ] **Low**: Swap the custom `axi4_lite_slave.v` with Vivado IP Catalog standard AXI IP.
