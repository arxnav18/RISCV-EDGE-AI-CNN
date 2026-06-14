# Module Descriptions — Detailed Reference

## Full Inference Pipeline
```text
Input → [ZeroPad] → Conv1 → BN → ReLU/Sigmoid → Pool → Conv2 → BN → ReLU/Sigmoid → Pool → FC → Sigmoid → Class Scores
         ↑ skip ─────────────────────────────────┘      ↑ skip ────────────────────────┘
```

---

## Datapath Components

### `mac_array.v` — Parallel MAC Array
9 pipelined multipliers computing `pixel[i] * weight[i]` followed by an adder tree. 3-stage pipeline: register inputs → multiply → accumulate. Produces one 20-bit MAC result per valid cycle.

### `multi_filter_mac.v` — Multi-Filter Parallel Bank
Uses `generate` to instantiate N independent MAC arrays, each computing a different output filter simultaneously. All lanes share the same pixel window but have separate weight inputs, providing N× throughput.

### `line_buffer.v` — Row Caching
Dual BRAM-inferred FIFOs maintaining historical row vectors. Supports up to 2048px wide images with 11-bit write pointers and wrap-around logic.

### `sliding_window.v` — 3×3 Spatial Window
Receives 3 column vectors every clock, shifts previous variables right, and exposes a flattened 72-bit vector (9×8-bit pixels) to the MAC Array.

### `channel_accumulator.v` — Depth Accumulation
Maintains a running 32-bit tally of partial MAC results across the depth dimension (e.g., RGB channels). Asserts clear at tensor boundaries.

### `relu.v` — ReLU Activation
Combinational: `data_out = data_in[MSB] ? 0 : data_in`. Zero latency, zero area impact.

### `max_pool_2x2.v` — 2×2 Max Pooling
Streaming pooling with internal line buffer. Processes column pairs and row pairs, storing intermediate maximums. Halves both width and height.

### `batch_norm.v` — Batch Normalization
2-stage pipeline: Stage 1 centers the input (`x - mean`), Stage 2 scales and offsets (`centered * scale + offset`). Uses Q8.8 fixed-point for the scale factor. Pre-computed (frozen BN) parameters loaded via MMIO.

### `activation_lut.v` — Sigmoid/Softmax LUT
256-entry piecewise-linear sigmoid approximation. Input is shifted from signed [-128,127] to unsigned [0,255] for LUT indexing. Supports bypass mode for when ReLU is preferred.

### `skip_add.v` — Residual Skip Connection
Element-wise addition between main path (layer output) and skip path (buffered layer input). Both streams must be synchronized. Enables ResNet-style architectures.

### `zero_pad.v` — Zero-Padding
Inserts configurable rows/columns of zeros around the input stream. For pad_size=1 with 3×3 kernel, output size = input size (same convolution). Generates backpressure to upstream via `ready_out`.

### `stride_controller.v` — Stride Decimation
Accepts a pixel stream and passes every Nth pixel in both X and Y dimensions. Configurable stride (1, 2, or 4). Reduces output dimensions by the stride factor.

### `fc_layer.v` — Fully Connected Layer
Sequential MAC engine for classification. For each output neuron: `score[j] = Σ(feature[i] × weight[j][i]) + bias[j]`. Reads features, multiplies against weight memory, accumulates, and emits class scores.

---

## Memory Modules

### `feature_map_ram.v` — Image/Feature Map SRAM
Dual-port synchronous RAM. Port A for writes, Port B for reads. Used 3× in the system: Layer 1 input, inter-layer buffer, and FC input buffer. 64KB capacity (16-bit address).

### `fc_weight_ram.v` — FC Weight SRAM
Dual-port RAM with 14-bit addressing (16,384 entries). Port A is MMIO-writable by the CPU for loading trained weights. Port B is read by the FC layer during inference.

### `fc_bias_ram.v` — FC Bias SRAM
Small dual-port RAM (16 entries × 32-bit). One bias per output neuron. MMIO-writable via a dedicated address range.

### `output_result_ram.v` — Classification Score SRAM
Stores FC output scores (16 entries × 32-bit). Written by hardware during inference, readable by the CPU via MMIO registers 0x80–0xBC.

### `weight_ram.v` — Conv Kernel Weight SRAM
72-bit wide (9 × 8-bit weights per entry). Stores conv kernel weights for both Layer 1 and Layer 2.

---

## Control & Infrastructure

### `cnn_controller.v` — Multi-Layer FSM
Sequences the full pipeline: `IDLE → DMA_LOAD → CONV1_RUN → CONV1_WAIT → CONV2_RUN → CONV2_WAIT → FC_RUN → FC_WAIT → DONE`. Each stage asserts a start signal and waits for the corresponding done signal. Also retains legacy single-layer states for backward compatibility.

### `cnn_register_interface.v` — MMIO Register Map (30+ registers)
Extended register interface covering: image config (0x00–0x20), DMA config (0x24–0x30), Layer 2 config (0x34–0x38), FC config (0x3C–0x40), stride/pad (0x44–0x48), batch norm params (0x4C–0x54), activation mode (0x58), power gate config (0x5C), skip enables (0x60), AXI-DMA direction (0x64), and result readback (0x80–0xBC).

### `dma_controller.v` — Simple Burst DMA
FSM-based sequential DMA: READ → WRITE cycle for each word. One word per clock. Configurable source, destination, and transfer length.

### `axi_dma_master.v` — AXI4 Burst DMA Master
Full AXI4 burst master interface for DDR access. Supports both read (DDR→SRAM) and write (SRAM→DDR) with configurable burst length (up to 16 beats). Enables high-bandwidth data transfer for large images.

### `axi4_lite_slave.v` — AXI4-Lite Slave Wrapper
Standard AXI4-Lite slave translating AXI read/write transactions to simple `wen/ren/addr/wdata` signals. Enables plug-and-play integration with ARM Zynq, SoC interconnects, and AXI ecosystems.

### `clock_gate.v` — Integrated Clock Gating Cell
Latch-based ICG for per-layer clock gating. Negative-edge latch prevents glitches. Test mode bypass for DFT. Controls power for Layer 1, Layer 2, FC, and DMA independently.

---

## System Wrappers

### `cnn_layer_pipeline.v` — Reusable Layer Stage
Chains `conv3d_accelerator → relu → max_pool_2x2` into a clean streaming pipeline. Instantiated twice for Layer 1 and Layer 2.

### `edge_ai_cnn_peripheral.v` — CNN Peripheral (Top)
The master integration module containing the full LeNet-5 pipeline with all 12 improvements. Instantiates register interface, controller, DMA, clock gates, two layer pipelines, batch norm, skip connections, FC layer with real weight/bias RAMs, sigmoid activation, and output result RAM.

### `riscv_core_top.v` — 5-Stage RISC-V CPU
Complete RV32I processor with data forwarding, hazard detection, and MMIO CNN interface. The `system_done` output prevents synthesis optimization.

### `system_top.v` — Synthesis Top Module
ASIC/FPGA wrapper exposing only `clk`, `reset`, and `done`.
