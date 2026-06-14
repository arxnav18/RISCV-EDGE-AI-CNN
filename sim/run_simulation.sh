#!/bin/bash
#============================================================================
# RISC-V 5-Stage Pipeline Simulation Script
# Description: Compiles all RTL and testbench with Icarus Verilog,
#              runs the simulation, and generates a VCD waveform file.
#
# Usage: bash sim/run_simulation.sh
# Requirements: Icarus Verilog (iverilog, vvp), GTKWave (optional)
#============================================================================

set -e

# Project root directory (script assumes it's run from project root)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "============================================="
echo " RISC-V RV32I 5-Stage Pipeline Simulator"
echo "============================================="
echo ""

# Step 1: Compile
echo "[1/3] Compiling Verilog sources..."
iverilog -o sim/cpu.out \
    rtl/pc.v \
    rtl/instruction_memory.v \
    rtl/register_file.v \
    rtl/alu.v \
    rtl/control_unit.v \
    rtl/pipeline_register_if_id.v \
    rtl/pipeline_register_id_ex.v \
    rtl/pipeline_register_ex_mem.v \
    rtl/pipeline_register_mem_wb.v \
    rtl/mac_array.v \
    rtl/sliding_window.v \
    rtl/conv_accelerator.v \
    rtl/cnn_controller.v \
    rtl/feature_map_ram.v \
    rtl/weight_ram.v \
    rtl/cnn_register_interface.v \
    rtl/edge_ai_cnn_top.v \
    rtl/riscv_core_top.v \
    tb/riscv_testbench.v

echo "       Compilation successful!"
echo ""

# Step 2: Simulate
echo "[2/3] Running simulation..."
cd sim
vvp cpu.out
cd "$PROJECT_DIR"
echo ""

# Step 3: Waveform
echo "[3/3] Waveform generated: sim/waveform.vcd"
echo ""
echo "============================================="
echo " To view waveforms, run:"
echo "   gtkwave sim/waveform.vcd"
echo "============================================="
