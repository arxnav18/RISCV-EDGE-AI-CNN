# Product Requirements Document (PRD)
## Project: Edge AI CNN Accelerator with RISC-V RV32I Core

**Document Status:** DRAFT  
**Target Node:** SkyWater 130nm (ASIC) / Xilinx 7-Series (FPGA Prototype)  
**Version:** 1.0.0  

---

## 1. Executive Summary

### 1.1 Product Vision
To deliver a highly efficient, power-optimized System-on-Chip (SoC) that integrates a general-purpose RISC-V microcontroller with a dedicated, high-throughput Convolutional Neural Network (CNN) hardware accelerator. This product bridges the gap between software flexibility and hardware performance, targeting low-power Edge AI applications.

### 1.2 Target Audience & Use Cases
- **IoT Device Manufacturers**: Smart doorbells (face/motion detection), environmental sensors.
- **Industrial Automation**: Quality control, defect detection on assembly lines.
- **Medical Wearables**: 1D/2D signal classification (e.g., ECG anomaly detection).
- **Autonomous Systems**: Drone obstacle detection, robotics navigation.

---

## 2. Architecture & Technical Scope

The SoC consists of two deeply integrated subsystems:
1. **RISC-V Host Processor**: A 5-stage pipelined RV32I core responsible for system control, peripheral configuration, and post-processing of AI inference results.
2. **LeNet-5 CNN Coprocessor**: A memory-mapped hardware accelerator designed to autonomously execute quantized (INT8) neural network inferences using a 3x3 MAC array, streaming line buffers, and an integrated Burst DMA controller.

---

## 3. Requirements

### 3.1 Functional Requirements (FRs)

| ID | Feature | Description | Priority |
|---|---|---|---|
| **FR-01** | **RV32I Base ISA** | The CPU must correctly execute the full unprivileged RISC-V RV32I instruction set (excluding CSRs/exceptions for v1.0). | P0 |
| **FR-02** | **CNN Inference Engine** | The accelerator must natively support a LeNet-5 style pipeline: `Conv2D -> ReLU -> MaxPool2x2 -> FC`. | P0 |
| **FR-03** | **Memory-Mapped I/O** | The CPU must be able to configure the CNN coprocessor via an AXI4-Lite slave interface mapped to a 256-byte MMIO window. | P0 |
| **FR-04** | **Direct Memory Access** | A dedicated AXI4 Master DMA must handle burst transfers of image data from external memory to localized SRAM without CPU intervention. | P0 |
| **FR-05** | **Hardware Quantization** | The CNN datapath must operate on INT8 inputs/weights, accumulate in INT32, and requantize to INT8 between layers. | P1 |
| **FR-06** | **Variable Resolution** | The line buffer and sliding window generators must support variable feature map dimensions up to 2048 x 2048 pixels. | P1 |

### 3.2 Non-Functional Requirements (NFRs)

| ID | Metric | Target Specification |
|---|---|---|
| **NFR-01** | **Clock Frequency** | Minimum 100 MHz under typical conditions (OpenLane/Sky130). |
| **NFR-02** | **Area Footprint** | Target die area ≤ 3.5mm x 3.5mm with ~40% core utilization. |
| **NFR-03** | **Dynamic Power** | Must implement Clock Gating and Operand Isolation to minimize switching activity during idle states. |
| **NFR-04** | **Latency** | Single layer convolution throughput must approach 1 pixel/cycle per output channel after pipeline fill. |
| **NFR-05** | **Portability** | RTL must be fully synthesizable on both ASIC standard cell libraries and commercial FPGAs (Xilinx Vivado). |

---

## 4. System Interfaces

### 4.1 Bus Architecture
- **Control Plane**: AXI4-Lite Slave. The RISC-V core acts as the master, configuring 17 memory-mapped registers (Base Addr, Dimensions, DMA configs).
- **Data Plane**: AXI4 Master. The CNN DMA acts as the master, issuing burst read/write requests to the external memory controller.

### 4.2 SRAM & Memory Macros
- Requires 64 KB of localized SRAM for image, weight, and intermediate feature map buffering.
- Must support automated swapping between standard Xilinx BRAMs (FPGA) and DFFRAM macros (ASIC) during synthesis.

---

## 5. Implementation & Verification Strategy

### 5.1 Verification Plan
- **Unit Testing**: Isolated testbenches for MAC Array, DMA Controller, and FSM.
- **Python Golden Model**: A bit-accurate Numpy implementation of the quantized LeNet-5 network to generate stimulus and expected output vectors.
- **System Integration**: Top-level simulation executing a full firmware binary on the RISC-V core that triggers a CNN inference and verifies the final class scores.

### 5.2 FPGA Prototyping
- Target: Digilent Nexys A7 (XC7A100T) or Xilinx ZCU104.
- ILA (Integrated Logic Analyzer) cores will be inserted on the MMIO and FSM buses for real-time silicon validation.

### 5.3 ASIC Backend Flow
- Toolchain: OpenLane RTL-to-GDSII flow.
- PDK: SkyWater 130nm.
- Sign-off: Static Timing Analysis (STA), LVS, and DRC clean at 100MHz.

---

## 6. Milestones & Timeline

| Phase | Milestone | Deliverables | Status |
|---|---|---|---|
| **Phase 1** | RTL Architecture & Design | RV32I Core, CNN Datapath, FSM RTL | Complete |
| **Phase 2** | Subsystem Verification | Component testbenches, Python Reference Model | Complete |
| **Phase 3** | System Integration | `system_top.v` integration, Firmware execution | Complete |
| **Phase 4** | FPGA Prototyping | Vivado project, ILA validation, 100MHz closure | Pending |
| **Phase 5** | ASIC Physical Design | OpenLane configuration, DRC/LVS clean GDSII | Pending |

---

## 7. Risks & Mitigations

1. **Timing Closure on AXI Bus (ASIC & FPGA)**
   - *Risk*: Deep logic cones in the AXI read/write decoding may fail 100MHz setup times.
   - *Mitigation*: Insert dedicated pipeline registers at the AXI boundaries and utilize 2-cycle read latencies on localized SRAMs.

2. **DSP/Multiplier Mapping (FPGA)**
   - *Risk*: The 9 parallel multipliers may synthesize into LUTs, starving the FPGA of routing resources and failing timing.
   - *Mitigation*: Explicitly tag multipliers with `(* use_dsp = "yes" *)` and adhere to Xilinx DSP48E2 pipeline recommendations.

3. **Memory Yield / Footprint (ASIC)**
   - *Risk*: 64KB of DFFRAM may exceed the 3.5x3.5mm target area density constraints.
   - *Mitigation*: Evaluate OpenRAM integration or reduce intermediate feature map resolution limitations if density violations occur.
