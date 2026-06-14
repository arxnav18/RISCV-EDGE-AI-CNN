# Module Description — Complete System

## Full Inference Pipeline
```text
Input → [ZeroPad] → Conv1 → BN → ReLU/Sigmoid → Pool → Conv2 → BN → ReLU/Sigmoid → Pool → FC → Activation → Output
         ↑ skip ─────────────────────────────────┘
```

---

## Datapath Components

| Module | Description |
|--------|-------------|
| `mac_array.v` | 9 pipelined multipliers + adder tree with **Operand Isolation** for 3×3 convolution |
| `multi_filter_mac.v` | N-way parallel MAC bank for N× filter throughput |
| `line_buffer.v` | Dual BRAM FIFOs, up to 2048px wide |
| `sliding_window.v` | 3×3 shift-register window generating 9 pixels/cycle |
| `channel_accumulator.v` | 32-bit running tally across depth channels |
| `relu.v` | Combinational ReLU (clamp negative → 0) |
| `max_pool_2x2.v` | Streaming 2×2 max pooling with line buffer |
| `batch_norm.v` | 2-stage pipelined BN: `y = (x-mean)*scale + offset` |
| `activation_lut.v` | 256-entry sigmoid LUT approximation |
| `skip_add.v` | Element-wise residual add (ResNet-style) |
| `zero_pad.v` | Configurable zero-padding for dimension preservation |
| `stride_controller.v` | Pixel decimation for strided convolution/pooling |
| `fc_layer.v` | Sequential MAC fully connected classification layer (Pipelined MAC) |

## Memory Modules

| Module | Description |
|--------|-------------|
| `feature_map_ram.v` | 64KB dual-port SRAM for image/feature maps (×3 instances) |
| `weight_ram.v` | 72-bit wide SRAM for 3×3 conv kernel weights |
| `fc_weight_ram.v` | 16K-entry SRAM for FC layer weights (MMIO writable) |
| `fc_bias_ram.v` | 16-entry SRAM for FC bias values (MMIO writable) |
| `output_result_ram.v` | 16-entry SRAM for FC scores (MMIO readable) |
| `image_buffer.v` | 4KB staging buffer |

## Control & Infrastructure

| Module | Description |
|--------|-------------|
| `conv3d_accelerator.v` | Single-layer conv wrapper (LB + SW + MAC + CA) |
| `cnn_layer_pipeline.v` | Reusable stage: Conv3D → ReLU → MaxPool |
| `cnn_controller.v` | Multi-layer FSM: DMA → L1 → L2 → FC → DONE |
| `cnn_register_interface.v` | 30+ MMIO registers for full system config |
| `dma_controller.v` | Simple burst DMA for local memory transfers |
| `axi_dma_master.v` | AXI4 burst master for external DDR access |
| `axi4_lite_slave.v` | AXI4-Lite slave wrapper for ARM/SoC integration |
| `clock_gate.v` | Latch-based ICG cell for per-layer power gating |

## System Wrappers

| Module | Description |
|--------|-------------|
| `edge_ai_cnn_peripheral.v` | Top-level CNN peripheral with full pipeline and configurable Clock Gating |
| `riscv_core_top.v` | 5-stage RV32I CPU with MMIO CNN interface |
| `system_top.v` | ASIC/FPGA synthesis top module |
