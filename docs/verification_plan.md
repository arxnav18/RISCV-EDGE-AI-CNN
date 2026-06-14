# Verification Plan

## Overview
The verification framework ensures mathematical edge-case correctness and cycle-accurate memory timings before executing physically on an FPGA. The datapath uses a dedicated hierarchy of standard Verilog testbenches compiled strictly using Open-Source **Icarus Verilog (`iverilog`)**.

A fully custom automated script (`scripts/run_simulation.sh`) drives the entire compilation and simulation workflow, generating highly compressed `.fst` waveforms for viewing, catching any failure outputs dynamically. Finally, a dedicated mathematical equivalent **Python script** acts as the Behavioral Ground-Truth Generator.

## Testbench Hierarchy

### 1. Isolated Component Verification
- **MAC Array (`mac_array_tb.v`)**: Directly stimulates the combinational multiply-accumulate mathematical tree. It feeds boundary inputs (zeros, maximum precision ints) into the 3x3 sliding window, ensuring the summation tree correctly overflows or bounds cleanly to the expected mathematical sum.
- **Line Buffer (`line_buffer.v` implicitly in wrapper tests)**: Shift-register raster-scan behavioral bounding verified accurately under the Top datapath loops.

### 2. Accelerator Logic Verification
- **CNN Controller FSM (`cnn_controller_tb.v`)**: Examines the logical transitions of states `IDLE -> MEM_LOAD -> COMPUTE -> DONE`. Simulates memory stall states and invalid parameter rejections.
- **3D Convolution Accelerator (`conv3d_accelerator_tb.v`)**: Validates the true sequential logic of parsing streaming input image blocks, catching them in the line buffers, aligning them into sliding windows, and executing the nested multi-channel accumulation loops. Testbenches inject a stream of known values (e.g., all 1s or incrementing pixels) and read out the memory stream to verify correct bounding.

### 3. Memory-Mapped Datapath Validation
- **Top System Integration (`system_integration_tb.v`)**: Represents the absolute End-to-End hardware dataflow mimicking a RISC-V processor. It writes the configuration data down an emulated MMIO mapped bus (setting `START` registers, polling `DONE` registers), loads physical arrays into the memory blocks, and waits for the hardware accelerator to process all pixels and assert the completion interrupt. This testbench also verifies standard **AXI4 Dual-Interface** compliance and that **PPA Isolations** correctly block idle switching.

## The Python Ground Truth Model (`cnn_reference_model.py`)

No hardware behaves reliably without a software analogue. `python_reference/cnn_reference_model.py` provides absolute mathematical verification:

1. Uses `numpy` to generate generic randomized multidimensional Image and Kernel objects.
2. Performs a nested `for` loop, floating-point convolution output array.
3. Automatically bounds, pads, and casts mathematical results.

**Usage:** Execute `python3 cnn_reference_model.py` to visibly trace the ground truth mathematical matrix prior to trusting the GTKWave outputs.

## Running the Automated Test Suite

Any individual testbench component can be targeted through the unified bash integration script.

```bash
# Example: Run just the Controller Module TB
./scripts/run_simulation.sh cnn_controller_tb

# Example: Run the entire integrated CNN Datapath
./scripts/run_simulation.sh system_integration_tb
```

If the mathematical testbench asserts perfectly, `PASS:` is printed and the compressed `.fst` waveform is instantly logged into `/sim_out/waveforms/`. To view the signals visually:
```bash
gtkwave sim_out/waveforms/system.fst
```
