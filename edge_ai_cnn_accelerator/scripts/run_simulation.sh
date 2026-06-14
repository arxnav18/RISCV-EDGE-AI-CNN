#!/bin/bash

# run_simulation.sh
# Automates the compilation and simulation of the Edge AI CNN Accelerator
# Usage: ./scripts/run_simulation.sh [testbench_name]

# Default testbench if not provided
TB_NAME=${1:-system_integration_tb}
TB_FILE="tb/${TB_NAME}.v"

if [ ! -f "$TB_FILE" ]; then
    echo "ERROR: Testbench file $TB_FILE not found."
    exit 1
fi

echo "==========================================="
echo " Building and Running Simulation: $TB_NAME "
echo "==========================================="

# Ensure directories exist
mkdir -p sim_out/waveforms
mkdir -p sim_out/logs

# Compile RTL and Testbench
echo "[1/3] Compiling RTL and Testbench using Icarus Verilog..."
iverilog -o sim_out/sim_exec -I rtl \
    rtl/*.v \
    $TB_FILE \
    > sim_out/logs/${TB_NAME}_build.log 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed. See sim_out/logs/${TB_NAME}_build.log"
    cat sim_out/logs/${TB_NAME}_build.log
    exit 1
fi
echo "Compilation successful."

# Run simulation
echo "[2/3] Running Simulation..."
# -fst flag is correctly placed after the executable
vvp sim_out/sim_exec -fst > sim_out/logs/${TB_NAME}_run.log 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed. See sim_out/logs/${TB_NAME}_run.log"
    cat sim_out/logs/${TB_NAME}_run.log
    exit 1
fi
echo "Simulation successful. Logs saved to sim_out/logs/${TB_NAME}_run.log"

WAVEFORM_FILE="sim_out/waveforms/${TB_NAME%_tb}.fst"
if [ "$TB_NAME" = "system_integration_tb" ]; then
    WAVEFORM_FILE="sim_out/waveforms/system.fst"
fi

echo "[3/3] Done. Waveform should be at $WAVEFORM_FILE"
echo "You can view the waveform with GTKWave:"
echo "gtkwave $WAVEFORM_FILE"
echo "==========================================="
