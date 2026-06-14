//============================================================================
// Testbench: RISC-V 5-Stage Pipeline — Complex Stress Test
// Description: Tests back-to-back data dependencies, forwarding chains,
//              negative immediates, and convolution accelerator with
//              complex input/kernel values.
//============================================================================

`timescale 1ns / 1ps

module riscv_testbench;

    //==========================================================================
    // Clock and Reset
    //==========================================================================
    reg clk;
    reg reset;

    initial clk = 0;
    always #5 clk = ~clk;

    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    riscv_core_top u_dut (
        .clk   (clk),
        .reset (reset)
    );

    //==========================================================================
    // VCD Waveform Dump
    //==========================================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, riscv_testbench);
    end

    //==========================================================================
    // Simulation Control
    //==========================================================================
    integer pass_count;
    integer fail_count;

    initial begin
        pass_count = 0;
        fail_count = 0;

        $display("==========================================================");
        $display(" RISC-V RV32I 5-Stage Pipeline — COMPLEX STRESS TEST");
        $display("==========================================================");
        $display("");

        // Assert reset
        reset = 1;
        #20;
        reset = 0;
        $display("TIME=%0t | Reset released, starting execution...", $time);
        $display("");

        // Run for enough cycles (program + memory mapped delay loops + drain)
        #3000;

        $display("");
        $display("==========================================================");
        $display(" Register File Final State");
        $display("==========================================================");
        $display(" x1  = 0x%08h  (%0d)", u_dut.u_regfile.registers[1],  u_dut.u_regfile.registers[1]);
        $display(" x2  = 0x%08h  (%0d)", u_dut.u_regfile.registers[2],  u_dut.u_regfile.registers[2]);
        $display(" x3  = 0x%08h  (%0d)", u_dut.u_regfile.registers[3],  u_dut.u_regfile.registers[3]);
        $display(" x4  = 0x%08h  (%0d)", u_dut.u_regfile.registers[4],  u_dut.u_regfile.registers[4]);
        $display(" x5  = 0x%08h  (%0d)", u_dut.u_regfile.registers[5],  u_dut.u_regfile.registers[5]);
        $display(" x6  = 0x%08h  (%0d)", u_dut.u_regfile.registers[6],  u_dut.u_regfile.registers[6]);
        $display(" x7  = 0x%08h  (%0d)", u_dut.u_regfile.registers[7],  u_dut.u_regfile.registers[7]);
        $display(" x8  = 0x%08h  (%0d)", u_dut.u_regfile.registers[8],  u_dut.u_regfile.registers[8]);
        $display(" x9  = 0x%08h  (%0d)", u_dut.u_regfile.registers[9],  u_dut.u_regfile.registers[9]);
        $display(" x10 = 0x%08h  (%0d)", u_dut.u_regfile.registers[10], u_dut.u_regfile.registers[10]);
        $display(" x13 = 0x%08h  (CNN immediate poll flag)", u_dut.u_regfile.registers[13]);
        $display(" x14 = 0x%08h  (CNN delayed poll flag)  ", u_dut.u_regfile.registers[14]);

        $display("");
        $display("==========================================================");
        $display(" Verification (Complex Stress Test)");
        $display("==========================================================");

        // x1 = ADDI x1, x0, 100 => 100
        if (u_dut.u_regfile.registers[1] == 32'd100) begin
            $display(" [PASS] x1 = 100  (ADDI x1, x0, 100)");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x1 = %0d (expected 100)", u_dut.u_regfile.registers[1]);
            fail_count = fail_count + 1;
        end

        // x2 = ADDI x2, x0, 55 => 55
        if (u_dut.u_regfile.registers[2] == 32'd55) begin
            $display(" [PASS] x2 = 55   (ADDI x2, x0, 55)");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x2 = %0d (expected 55)", u_dut.u_regfile.registers[2]);
            fail_count = fail_count + 1;
        end

        // x3 = ADD x3, x1, x2 => 100 + 55 = 155 (back-to-back forwarding)
        if (u_dut.u_regfile.registers[3] == 32'd155) begin
            $display(" [PASS] x3 = 155  (ADD x3, x1, x2) [FWD: x1 from EX/MEM, x2 mid-pipe]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x3 = %0d (expected 155)", u_dut.u_regfile.registers[3]);
            fail_count = fail_count + 1;
        end

        // x4 = SUB x4, x3, x1 => 155 - 100 = 55 (chain: x3 just computed)
        if (u_dut.u_regfile.registers[4] == 32'd55) begin
            $display(" [PASS] x4 = 55   (SUB x4, x3, x1) [FWD: x3 from EX/MEM]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x4 = %0d (expected 55)", u_dut.u_regfile.registers[4]);
            fail_count = fail_count + 1;
        end

        // x5 = ADD x5, x3, x4 => 155 + 55 = 210 (double forwarding: x3 MEM/WB, x4 EX/MEM)
        if (u_dut.u_regfile.registers[5] == 32'd210) begin
            $display(" [PASS] x5 = 210  (ADD x5, x3, x4) [FWD: x3 MEM/WB, x4 EX/MEM]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x5 = %0d (expected 210)", u_dut.u_regfile.registers[5]);
            fail_count = fail_count + 1;
        end

        // x6 = AND x6, x1, x2 => 0x64 & 0x37 = 0x24 = 36
        if (u_dut.u_regfile.registers[6] == 32'd36) begin
            $display(" [PASS] x6 = 36   (AND x6, x1, x2) [0x64 & 0x37 = 0x24]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x6 = 0x%08h (expected 36 / 0x24)", u_dut.u_regfile.registers[6]);
            fail_count = fail_count + 1;
        end

        // x7 = OR x7, x1, x2 => 0x64 | 0x37 = 0x77 = 119
        if (u_dut.u_regfile.registers[7] == 32'd119) begin
            $display(" [PASS] x7 = 119  (OR  x7, x1, x2) [0x64 | 0x37 = 0x77]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x7 = 0x%08h (expected 119 / 0x77)", u_dut.u_regfile.registers[7]);
            fail_count = fail_count + 1;
        end

        // x8 = ADDI x8, x5, -10 => 210 - 10 = 200 (negative immediate)
        if (u_dut.u_regfile.registers[8] == 32'd200) begin
            $display(" [PASS] x8 = 200  (ADDI x8, x5, -10) [negative imm, FWD from MEM/WB]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x8 = %0d (expected 200)", u_dut.u_regfile.registers[8]);
            fail_count = fail_count + 1;
        end

        // x9 = SUB x9, x8, x7 => 200 - 119 = 81
        if (u_dut.u_regfile.registers[9] == 32'd81) begin
            $display(" [PASS] x9 = 81   (SUB x9, x8, x7) [FWD: x8 from EX/MEM]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x9 = %0d (expected 81)", u_dut.u_regfile.registers[9]);
            fail_count = fail_count + 1;
        end

        // x10 = ADD x10, x9, x6 => 81 + 36 = 117
        if (u_dut.u_regfile.registers[10] == 32'd117) begin
            $display(" [PASS] x10 = 117 (ADD x10, x9, x6) [FWD: x9 from EX/MEM]");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x10 = %0d (expected 117)", u_dut.u_regfile.registers[10]);
            fail_count = fail_count + 1;
        end

        // x13 was polled immediately after SW START
        if (u_dut.u_regfile.registers[13] == 32'd0) begin
            $display(" [PASS] x13 = 0   (CNN Poll immediately returns 0 indicating busy)");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x13 = %0d (expected CNN initially busy flag 0)", u_dut.u_regfile.registers[13]);
            fail_count = fail_count + 1;
        end
        
        // x14 was polled after ~50 NOP cycles
        if (u_dut.u_regfile.registers[14] == 32'd1) begin
            $display(" [PASS] x14 = 1   (CNN Poll after delay returns 1 indicating DONE)");
            pass_count = pass_count + 1;
        end else begin
            $display(" [FAIL] x14 = %0d (expected CNN completed flag 1)", u_dut.u_regfile.registers[14]);
            fail_count = fail_count + 1;
        end

        $display("");
        $display("==========================================================");
        $display(" Results: %0d PASSED, %0d FAILED out of 12 tests", pass_count, fail_count);
        $display("==========================================================");

        if (fail_count == 0)
            $display(" >>> ALL TESTS PASSED <<<");
        else
            $display(" >>> SOME TESTS FAILED <<<");

        $display("");
        $finish;
    end

    //==========================================================================
    // Pipeline trace
    //==========================================================================
    always @(posedge clk) begin
        if (!reset) begin
            $display("TIME=%0t | PC=0x%08h | IF_Instr=0x%08h",
                     $time, u_dut.pc_current, u_dut.instruction_fetched);
        end
    end

endmodule
