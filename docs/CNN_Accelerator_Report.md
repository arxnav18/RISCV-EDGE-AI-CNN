# Processor-Controlled LeNet-5 CNN Accelerator for Edge AI

## 1. Abstract
This project implements a hardware-efficient **LeNet-5 Convolutional Neural Network Accelerator** optimized for Edge AI applications. The architecture features a full multi-layer inference pipeline — Conv1 → ReLU → Pool → Conv2 → ReLU → Pool → FC — explicitly managed by a RISC-V processor over a Memory-Mapped I/O (MMIO) bus. The design utilizes pure synthesizable Verilog RTL modules with INT8 quantized inference, a DMA engine for high-throughput data transfer, and support for images up to 2048×2048 pixels.

## 2. Introduction
Edge AI refers to deploying artificial intelligence algorithms locally on "edge" hardware devices, rather than relying on cloud computing. For computer vision tasks, CNNs are the predominant algorithm. However, executing CNNs requires immense parallel computations. A dedicated hardware accelerator utilizing spatial computation (parallel MAC arrays, line buffers, and streaming pooling) significantly increases throughput and reduces latency, enabling complex Edge AI vision applications on resource-constrained devices.

## 3. Problem Statement
Standard software-based CPU CNN evaluation suffers from poor localized memory reuse and sequential arithmetic limits. Our multi-layer hardware accelerator with an integrated Control FSM, DMA engine, and streaming datapath solves these bottlenecks by handling memory propagation natively and processing multiple neural network layers autonomously.

## 4. Proposed Architecture
The architecture features a localized multi-stage hardware pipeline commanded by processor-writable registers. A central `cnn_controller` FSM sequences the full inference pipeline: **DMA_LOAD → CONV1 → CONV2 → FC → DONE**. Each layer stage is encapsulated in a reusable `cnn_layer_pipeline` module chaining `conv3d_accelerator → relu → max_pool_2x2`.

## 5. System Architecture

**Full Pipeline:**
```text
RISC-V Host → MMIO Bus → CNN Controller → DMA → Conv1+ReLU+Pool → Conv2+ReLU+Pool → FC → Class Scores
```

**Data Flow Detail:**
1. The RISC-V CPU configures image dimensions, channel counts, filter counts, and DMA parameters via MMIO registers.
2. The CPU triggers the pipeline with a single START pulse.
3. The **DMA Controller** burst-transfers image data from external memory into local 64KB SRAM.
4. **Layer 1 Pipeline**: Input pixels stream through line buffers → sliding window → MAC array → channel accumulator → ReLU → 2×2 max pooling.
5. INT8 quantization converts 32-bit accumulator outputs back to 8-bit for intermediate SRAM storage.
6. **Layer 2 Pipeline**: Reads intermediate feature maps and processes them through an identical Conv→ReLU→Pool chain.
7. **FC Layer**: Reads the flattened pool output, performs sequential MAC operations against weight memory, and produces final class scores.
8. The `DONE` flag is asserted, and the RISC-V core reads results via MMIO.

## 6. RTL Design
The architecture is designed hierarchically through distinct component Verilog modules:

- **`riscv_core_top`** & **`system_top`**: The integration wrappers bounding the processor MMIO interface together with the CNN hardware elements.
- **`cnn_controller`**: Multi-layer FSM sequencing DMA → Conv1 → Conv2 → FC → Done.
- **`cnn_layer_pipeline`**: Reusable wrapper chaining conv3d_accelerator → relu → max_pool_2x2.
- **`conv3d_accelerator`**: Top-level computation wrapper for a single convolution stage (line buffer + sliding window + MAC array + channel accumulator).
- **`relu`**: Combinational ReLU activation with zero latency.
- **`max_pool_2x2`**: Streaming 2×2 max pooling with internal line buffer.
- **`fc_layer`**: Sequential MAC fully connected layer for final classification.
- **`dma_controller`**: Burst DMA engine for CPU-free memory block transfers.
- **`mac_array`**: 9 parallel multipliers + adder tree for 3×3 kernel convolution.
- **`line_buffer`**: BRAM-inferred row caching supporting up to 2048px wide images.

## 7. Simulation & Verification
RTL verification was managed via completely automated scripts relying on **Icarus Verilog (`iverilog`)** and **GTKWave**:
1. **Syntax Check**: Full system compilation via `iverilog -o system_check.vvp rtl/*.v` — zero errors.
2. **FSM Operation**: Polling register verification confirms multi-layer sequencing from IDLE through all stages to DONE.
3. **Mathematical Correctness**: A Python verification subsystem (NumPy) generates identically shaped multidimensional arrays, proving the hardware datapath replicates the mathematics of the Python reference model.
4. **System Integration**: Top-level testbenches force stimuli down the MMIO data buses, mimicking real firmware executing across the wires.

## 8. Performance Specifications

| Metric | Value |
|--------|-------|
| Max Image Size | 2048 × 2048 pixels |
| Max Channels | 255 |
| Kernel Size | 3×3 (fixed) |
| Parallel MACs/cycle | 9 |
| Pixel/Weight Precision | 8-bit unsigned (INT8) |
| Accumulator Precision | 32-bit signed |
| Image SRAM | 64 KB |
| Pipeline | Conv→ReLU→Pool × 2 + FC |
| DMA | 1 word/cycle burst |

## 9. Applications
The modular multi-layer CNN accelerator can power:
- **Computer Vision**: Real-time object detection, facial recognition, digit classification (MNIST/CIFAR-10)
- **Signal Processing**: 1D/2D signal denoising, ECG anomaly detection
- **Autonomous Systems**: Edge inference for robotic navigation
- **Industrial IoT**: Defect detection, vibration classification, predictive maintenance
- **Agriculture**: Crop health analysis from aerial imagery

## 10. Conclusion
This project successfully designed and proved a multi-layer, processor-controlled CNN Accelerator implementing a full LeNet-5 inference pipeline. By decomposing the hardware into discrete functional modules — MAC arrays, ReLU activations, max pooling units, channel accumulators, line-buffer sliding windows, DMA engines, and fully connected classifiers — we demonstrated scalable hardware-software co-design for real-world Edge AI applications. The design is fully synthesizable and ready for ASIC tapeout or FPGA deployment.
