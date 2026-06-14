# Repository Explained: RISC-V RV32I Processor & Custom Edge AI CNN Accelerator

This document provides a comprehensive overview of the `RISCV-with-custom-hardware-acceleration` repository, detailing its architecture, modules, design choices, and how to operate the project.

---

## 1. Project Overview

**What is this project?**
This project is a complete hardware/software co-design of an AI-enabled microprocessor. It pairs a custom-designed **RISC-V RV32I 5-stage pipelined processor** with a memory-mapped **CNN hardware accelerator peripheral**. 

**What problem does it solve?**
Running complex mathematical models, like Convolutional Neural Networks (CNNs), sequentially on a general-purpose CPU is inefficient and slow. This project solves this by offloading the intensive tensor mathematics and matrix multiplications of a **LeNet-5 CNN** directly into a dedicated hardware datapath. 

**Primary Goals:**
- Achieve massive parallel throughput for CNN inference using a custom MAC array and streaming line buffers.
- Provide a robust Memory-Mapped I/O (MMIO) and DMA integration to couple the CPU and the accelerator.
- Optimize for Power, Performance, and Area (PPA) with an eye towards an ASIC implementation (OpenLane/Sky130).

---

## 2. Repository Structure

Here is a breakdown of the primary directories and their purpose:

- **`rtl/`**: Contains the core Verilog source files for the integrated system, including the RISC-V CPU, the CNN accelerator, and bus interfaces.
- **`edge_ai_cnn_accelerator/`**: A self-contained test environment specifically for the CNN components. It includes standalone RTL copies, unit testbenches (`tb/`), automated simulation scripts (`scripts/`), and Python ground-truth models (`python_reference/`).
- **`docs/`**: Project documentation, architectural breakdowns, methodology, verification plans, and FPGA implementation guidelines.
- **`diagrams/`**: High-resolution block diagrams mapping out the system architecture and controller FSMs.
- **`openlane/`**: Contains the OpenLane collateral and configuration files (`system_top/`) needed for the ASIC physical design flow.
- **`python/`**: Python utility scripts used for generating memory test files and conducting stress tests.
- **`sim/` & `tb/`**: Legacy simulation scripts and top-level integration testbenches.
- **`synth/`**: Contains synthesis output netlists (e.g., `synth_system_top.v.gz`).

---

## 3. Architecture & Design

The system relies on two deeply integrated yet functionally distinct subsystems:

1. **RISC-V Core Controller**: A classic 5-stage pipeline (`IF → ID → EX → MEM → WB`) processor. It implements the base `RV32I` ISA and handles data hazards (forwarding, stalls, flushes). It acts as the system maestro.
2. **LeNet-5 CNN Accelerator**: Connected to the CPU via a memory-mapped bus (accessible for addresses ≥ `0x1000`). It features an **AXI4-Lite Slave** for configuration and an **AXI4 Master** for high-speed DMA data fetching.

**Interaction:**
The CPU configures the CNN accelerator by writing to its MMIO registers (e.g., image addresses, layer sizes, kernel configurations) and sends a START pulse. The accelerator's FSM then orchestrates a complete inference pipeline autonomously:
`DMA_LOAD` (fetch image to SRAM) → `CONV1` (Layer 1: Conv3D, ReLU, MaxPool) → `CONV2` (Layer 2) → `FC` (Fully Connected Dense Layer) → `DONE`. Once done, it asserts an interrupt/flag, and the CPU reads back the classification scores.

---

## 4. Core Modules / Source Files

Key source files found in `rtl/`:

- **`system_top.v`**: The absolute top-level ASIC/FPGA wrapper. It instantiates the RISC-V core and the CNN accelerator, exposing external AXI interfaces and standard `clk`/`reset`.
- **`riscv_core_top.v`**: The 5-stage pipelined RV32I CPU with hazard detection, data forwarding, and the logic required for MMIO bus decoding.
- **`edge_ai_cnn_peripheral.v`**: The full wrapper for the CNN coprocessor. Contains the memory maps, Layer 1 & 2 datapath pipelines, fully connected layer, and integrated clock gating logic.
- **`cnn_controller.v`**: The state machine (FSM) that orchestrates the data movement and triggers the specific pipeline phases for LeNet-5 inference.
- **`conv3d_accelerator.v`**: The heart of the 3D convolution layer. It chains line buffers, a 3x3 sliding window generator, the parallel MAC array, and channel accumulators.
- **`mac_array.v`**: Contains 9 parallel multipliers and an adder tree to compute the 3x3 dot product in hardware. It incorporates operand isolation.
- **`axi_dma_master.v` & `dma_controller.v`**: High-bandwidth burst DMA engines that move data from external memory directly into localized SRAM independently of the CPU.

---

## 5. Design Decisions & Trade-offs

- **Memory-Mapped I/O (MMIO) vs. Custom ISA Instructions:** The team chose an MMIO bus over adding custom instructions to the RISC-V ISA. *Trade-off:* While custom instructions might be cycle-tighter, MMIO allows the RISC-V core to remain strictly standard `RV32I`, enabling standard compiler toolchains (like standard GCC) without needing assembler modifications.
- **INT8 Quantization:** All pixel features and weights are quantized to 8-bit unsigned integers (INT8), with accumulation stored in 32-bit signed integers. *Trade-off:* This significantly reduces SRAM footprint and dynamic power consumption compared to FP32, with negligible accuracy loss for standard image classification.
- **PPA Optimizations (Power, Performance, Area):**
  - **Operand Isolation:** Multipliers in the `mac_array.v` freeze their inputs when inactive. This prevents flip-flop toggling and significantly saves dynamic power.
  - **Clock Gating:** Entire CNN layers are powered off via `clock_gate.v` when they are not in the active pipeline phase.
  - **Deep Pipelining:** Enables a high target frequency (100 MHz in a Sky130 process) by keeping critical path logic short.

---

## 6. Build & Toolchain

The project heavily relies on an open-source hardware toolchain:
- **Simulation**: Uses **Icarus Verilog (`iverilog`)** for RTL compilation and simulation, paired with **GTKWave** for visualizing `.vcd` and `.fst` waveform dumps.
- **Automation Scripts**: A custom bash test runner (`edge_ai_cnn_accelerator/scripts/run_simulation.sh`) automatically compiles code, handles include directories, executes simulations, and compresses waveforms.
- **ASIC Implementation**: Configured for the **OpenLane** RTL-to-GDSII flow utilizing the SkyWater 130nm PDK. The `openlane/system_top` folder contains configuration files specifying target density, clock speed (100MHz), SDC timing constraints, and memory macros (DFFRAM).

---

## 7. How to Run / Reproduce

To reproduce the hardware behavior and run a full system integration test from scratch:

1. **Verify Full RTL Compilation**:
   ```bash
   iverilog -o system_check.vvp rtl/*.v
   ```

2. **Run System Integration Simulation**:
   Navigate into the self-contained accelerator folder and execute the testbench runner:
   ```bash
   cd edge_ai_cnn_accelerator
   ./scripts/run_simulation.sh system_integration_tb
   ```
   *Expected Output:* `PASS: System integration test complete. CNN asserted done.`

3. **View Waveforms**:
   ```bash
   gtkwave sim_out/waveforms/system.fst
   ```

4. **Verify Math with Python**:
   Run the golden reference model to see the exact arrays expected by the hardware:
   ```bash
   python3 python_reference/cnn_reference_model.py
   ```

---

## 8. Dependencies

To build, simulate, and test the repository, the following dependencies are required:
- **Icarus Verilog (`iverilog`)**: RTL compiler and simulator.
- **GTKWave**: Waveform visualizer.
- **Python 3**: For test stimulus generation and the software ground-truth model.
  - Requires: `numpy` package (`pip3 install numpy`)
- *(Optional)* **OpenLane & Sky130 PDK**: Required only if you intend to run synthesis and place-and-route for ASIC tapeout.
