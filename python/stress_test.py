#!/usr/bin/env python3
"""
Automated Multi-Dataset Stress Tester
======================================
Generates multiple random test datasets, writes instruction memory and
accelerator data files, recompiles and simulates each, and reports
pass/fail across all test runs.

Usage:
    python3 python/stress_test.py [num_tests]
    Default: 10 random test runs
"""

import numpy as np
import subprocess
import os
import sys
import re

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL_DIR = os.path.join(PROJECT_DIR, "rtl")
SIM_DIR = os.path.join(PROJECT_DIR, "sim")
TB_DIR = os.path.join(PROJECT_DIR, "tb")


def encode_addi(rd, rs1, imm):
    imm12 = imm & 0xFFF
    return (imm12 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0010011


def encode_add(rd, rs1, rs2):
    return (0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0110011


def encode_sub(rd, rs1, rs2):
    return (0b0100000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | 0b0110011


def encode_and(rd, rs1, rs2):
    return (0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b111 << 12) | (rd << 7) | 0b0110011


def encode_or(rd, rs1, rs2):
    return (0b0000000 << 25) | (rs2 << 20) | (rs1 << 15) | (0b110 << 12) | (rd << 7) | 0b0110011


def encode_custom(rd):
    return (rd << 7) | 0b0001011


def encode_nop():
    return 0x00000013


def sign_extend_12(val):
    val = val & 0xFFF
    if val & 0x800:
        return val | 0xFFFFF000
    return val


def to_signed_32(val):
    val = val & 0xFFFFFFFF
    if val >= 0x80000000:
        return val - 0x100000000
    return val


def generate_test_case(rng, test_id):
    """Generate one random test case."""
    a = int(rng.integers(-500, 500))
    b = int(rng.integers(-500, 500))
    c = int(rng.integers(-100, 100))

    # Python reference computation (32-bit unsigned)
    x1 = a & 0xFFFFFFFF
    x2 = b & 0xFFFFFFFF
    x3 = (x1 + x2) & 0xFFFFFFFF
    x4 = (x3 - x1) & 0xFFFFFFFF  # should equal x2
    x5 = (x3 + x4) & 0xFFFFFFFF
    x6 = x1 & x2
    x7 = (x1 | x2) & 0xFFFFFFFF
    se_c = sign_extend_12(c & 0xFFF)
    x8 = (x5 + se_c) & 0xFFFFFFFF
    x9 = (x8 - x7) & 0xFFFFFFFF
    x10 = (x9 + x6) & 0xFFFFFFFF

    expected = {1: x1, 2: x2, 3: x3, 4: x4, 5: x5,
                6: x6, 7: x7, 8: x8, 9: x9, 10: x10}

    instructions = [
        encode_addi(1, 0, a & 0xFFF),
        encode_addi(2, 0, b & 0xFFF),
        encode_add(3, 1, 2),
        encode_sub(4, 3, 1),
        encode_add(5, 3, 4),
        encode_and(6, 1, 2),
        encode_or(7, 1, 2),
        encode_addi(8, 5, c & 0xFFF),
        encode_sub(9, 8, 7),
        encode_add(10, 9, 6),
        encode_custom(11),
    ]
    for _ in range(20):
        instructions.append(encode_nop())

    # Random accelerator data (3x3, 8-bit unsigned 0-9)
    kernel = rng.integers(0, 10, 9).astype(int)
    input_win = rng.integers(0, 10, 9).astype(int)
    conv_result = int(np.sum(kernel * input_win))
    expected[11] = conv_result & 0xFFFFFFFF

    return {
        "id": test_id, "a": a, "b": b, "c": c,
        "instructions": instructions,
        "kernel": kernel, "input_win": input_win,
        "conv_result": conv_result, "expected": expected,
    }


def write_files(tc):
    """Write instruction memory and accelerator data files."""
    # Instructions
    with open(os.path.join(SIM_DIR, "instructions.mem"), "w") as f:
        for instr in tc["instructions"]:
            f.write(f"{instr:08X}\n")

    # Kernel
    with open(os.path.join(SIM_DIR, "accel_kernel.mem"), "w") as f:
        for v in tc["kernel"]:
            f.write(f"{int(v):02X}\n")

    # Input window
    with open(os.path.join(SIM_DIR, "accel_input.mem"), "w") as f:
        for v in tc["input_win"]:
            f.write(f"{int(v):02X}\n")


def compile_once():
    """Compile the Verilog (only needed once since RTL doesn't change)."""
    rtl_files = sorted([os.path.join(RTL_DIR, f) for f in os.listdir(RTL_DIR) if f.endswith(".v")])
    tb_file = os.path.join(TB_DIR, "riscv_testbench.v")

    cmd = ["iverilog", "-o", os.path.join(SIM_DIR, "cpu.out")] + rtl_files + [tb_file]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=PROJECT_DIR)
    if result.returncode != 0:
        print(f"COMPILATION FAILED:\n{result.stderr}")
        return False
    return True


def run_simulation():
    """Run the simulation. Returns stdout."""
    result = subprocess.run(
        [os.path.join(SIM_DIR, "cpu.out")],
        capture_output=True, text=True, cwd=SIM_DIR
    )
    return result.stdout


def parse_final_registers(output):
    """Parse the final register state from simulation output."""
    regs = {}
    # Match lines like: x1  = 0x00000064  (100)
    for match in re.finditer(r"x(\d+)\s+=\s+0x([0-9a-fA-F]+)\s+\(", output):
        reg_num = int(match.group(1))
        reg_val = int(match.group(2), 16)
        regs[reg_num] = reg_val
    return regs


def main():
    num_tests = int(sys.argv[1]) if len(sys.argv) > 1 else 10

    print("=" * 70)
    print(f"   RISC-V Pipeline Automated Stress Test — {num_tests} Random Datasets")
    print("=" * 70)
    print()

    # Compile once (RTL doesn't change between tests, only .mem files)
    print("[*] Compiling Verilog (one-time)...")
    if not compile_once():
        print("    FATAL: Compilation failed. Aborting.")
        return 1
    print("    Compilation successful ✅")
    print()

    rng = np.random.default_rng(seed=2026)

    total_checks = 0
    total_pass = 0
    total_fail = 0
    failed_tests = []

    for t in range(num_tests):
        tc = generate_test_case(rng, t + 1)
        kernel_str = tc["kernel"].tolist()
        input_str = tc["input_win"].tolist()

        print(f"Test {tc['id']:2d} | a={tc['a']:+5d} b={tc['b']:+5d} c={tc['c']:+4d} | "
              f"conv={tc['conv_result']:4d} | ", end="")

        # Write .mem files
        write_files(tc)

        # Run simulation
        output = run_simulation()

        # Parse results
        regs = parse_final_registers(output)
        test_passed = True
        failures = []

        for reg_num in sorted(tc["expected"].keys()):
            expected = tc["expected"][reg_num]
            actual = regs.get(reg_num)
            total_checks += 1

            if actual == expected:
                total_pass += 1
            else:
                total_fail += 1
                test_passed = False
                act_str = f"0x{actual:08X}" if actual is not None else "MISSING"
                failures.append(f"x{reg_num}: got {act_str}, exp 0x{expected:08X}")

        if test_passed:
            print(f"ALL 11 PASS ✅")
        else:
            print(f"FAIL ❌  {'; '.join(failures)}")
            failed_tests.append((tc["id"], failures))

    print()
    print("=" * 70)
    print(f"   RESULTS: {total_pass}/{total_checks} checks passed across {num_tests} tests")
    print("=" * 70)

    if total_fail == 0:
        print(f"   🎯 ALL {num_tests} TESTS PASSED — ZERO FAILURES")
    else:
        print(f"   ❌ {len(failed_tests)} test(s) had failures:")
        for tid, fails in failed_tests:
            for f in fails:
                print(f"      Test {tid}: {f}")

    print()
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
