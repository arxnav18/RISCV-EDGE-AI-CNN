`timescale 1ns / 1ps

module system_integration_tb;

    // 1. Clock generator
    reg clk;
    always #5 clk = ~clk;

    // 2. Reset logic
    reg rst_n;

    // Signals
    wire system_done;

    // DUT
    edge_ai_cnn_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .system_done(system_done)
    );

    // 6. Waveform dump control
    parameter DEBUG_LEVEL = 3;

    initial begin
        // Formatted Waveform output
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/system.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, system_integration_tb); // Top-level only
            else if (DEBUG_LEVEL == 2) $dumpvars(0, system_integration_tb.uut); // Accelerator/uut only
            else                       $dumpvars(0, system_integration_tb); // Full debug dump
        end
    end

    initial begin
        clk = 0;
        rst_n = 0;
        
        $display("Starting System Level Test");
        
        #20 rst_n = 1;
        
        // 3. Input image loader (Mock logic, would interface with RAM/RISC-V)
        
        // 4. CNN accelerator trigger (Mock, triggered internally by RISC-V)
        
        // 5. Output validation
        wait(system_done == 1'b1);
        $display("PASS: System integration test complete. CNN asserted done.");
        
        #50 $finish;
    end
    
    // Safety Simulation Timeout
    initial begin
        #10000;
        $display("FAIL: Simulation timeout reached.");
        $finish;
    end

endmodule
