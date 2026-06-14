# Design Methodology

## Hardware/Software Co-Design Flow

This project follows a structured design methodology that inherently compares high-level software models against rigorous hardware-level Register-Transfer Logic (RTL).

```
┌──────────────────┐
│  1. Python Math   │   NumPy convolution reference model
│     Modeling      │   → Defines correct spatial multi-dimensional math
└────────┬─────────┘
         ▼
┌──────────────────┐
│  2. RTL Design    │   Verilog modules: MAC Array, Line Buffers,
│                   │   FSM Control Unit, MMIO Interface
└────────┬─────────┘
         ▼
┌──────────────────┐
│  3. Integration   │   Top-level module wiring all datapath stages,
│                   │   binding to the CPU via AXI/MMIO memory
└────────┬─────────┘
         ▼
┌──────────────────┐
│  4. Automated     │   `run_simulation.sh` regression scripts
│     Testing       │   → Compiles to highly compressed `.fst`
└────────┬─────────┘
         ▼
┌──────────────────┐
│  5. Verification  │   Compare Icarus Verilog output via GTKWave vs.
│                   │   the Python print statements.
└──────────────────┘
```

## Phase Details

### Phase 1: Algorithm Modeling
- Implement multi-dimensional convolution arithmetic in pure Python via NumPy (`cnn_reference_model.py`).
- Generate dynamic matrix test dimensions to act as the Ground Truth.
- Prove algorithms scale correctly independent of bit-width precision before writing any silicon description.

### Phase 2: RTL Design
- Design individual hardware IP blocks (e.g. `mac_array.v`).
- Parameterize components using `generate` blocks and scalable `#()` macro parameters to test different precision levels smoothly.

### Phase 3: Hardware Integration
- Mount the deeply pipelined CNN logic over a flexible state machine controller (`cnn_controller.v`).
- Bind the controller logic specifically to the Memory-Mapped I/O read/write operations mimicking a processor's memory load/stores.

### Phase 4: Automated Simulation
- A central bash script (`scripts/run_simulation.sh`) completely manages compilation pipelines.
- Code is compiled sequentially using Icarus Verilog (`iverilog`).
- Execute generated targets sequentially with the discrete execution engine (`vvp`).
- Dump all timing/signal changes to highly compressed Fast Signal Transfer (`.fst`) blocks to preserve SSD storage natively spanning gigabytes of toggles.

### Phase 5: Verification & Self-Checking
- Automated testbench wrappers provide localized validation and `$display` explicit `PASS:` or `FAIL:` states.
- System Integration level benches test specific memory array addresses against Python Ground Truth calculations.

## Core Toolchain

| Tool           | Purpose                          | Integration Level |
|----------------|----------------------------------|-------------------|
| Icarus Verilog | Open-source Verilog Synthesizer  | Simulation        |
| VVP            | Simulation runtime engine       | Simulation        |
| GTKWave        | `.fst` visualizer / debugging   | Verification      |
| Python + NumPy | Multi-dimensional Math Baseline  | Algorithmic Truth |
| Bash           | Automated regression suites      | Continuous CI/CD  |
