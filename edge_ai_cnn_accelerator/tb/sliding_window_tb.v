`timescale 1ns / 1ps

module sliding_window_tb;

    reg clk;
    reg rst_n;
    reg en;
    reg [7:0] col_row0; // Bottom row
    reg [7:0] col_row1; // Middle row
    reg [7:0] col_row2; // Top row
    
    wire [71:0] window_out;
    wire valid_out;

    sliding_window uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .col_row0(col_row0),
        .col_row1(col_row1),
        .col_row2(col_row2),
        .window_out(window_out),
        .valid_out(valid_out)
    );

    parameter DEBUG_LEVEL = 1;

    always #5 clk = ~clk;

    initial begin
        // Configurable Waveform Dumping
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/sliding_window.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, sliding_window_tb); // Top-level only
            else if (DEBUG_LEVEL == 2) $dumpvars(0, sliding_window_tb.uut); // Accelerator/uut only
            else                       $dumpvars(0, sliding_window_tb); // Full debug dump
        end
        
        clk = 0;
        rst_n = 0;
        en = 0;
        col_row0 = 0;
        col_row1 = 0;
        col_row2 = 0;
        
        #20 rst_n = 1;
        
        // Cycle 1
        #10;
        en = 1;
        col_row2 = 8'h11; // Top
        col_row1 = 8'h21; // Mid
        col_row0 = 8'h31; // Bot
        
        // Cycle 2
        #10;
        col_row2 = 8'h12;
        col_row1 = 8'h22;
        col_row0 = 8'h32;
        
        // Cycle 3 (Window should be full after this cycle)
        #10;
        col_row2 = 8'h13;
        col_row1 = 8'h23;
        col_row0 = 8'h33;
        
        // Delay to allow outputs to register
        #5; 
        
        // Expected output layout mapping check
        if (valid_out) begin
            $display("Window Valid!");
            $display("Top Row: %x %x %x", window_out[23:16], window_out[15:8], window_out[7:0]);
            $display("Mid Row: %x %x %x", window_out[47:40], window_out[39:32], window_out[31:24]);
            $display("Bot Row: %x %x %x", window_out[71:64], window_out[63:56], window_out[55:48]);
            $display("SW Test PASS");
        end else begin
            $display("FAIL: Valid signal not asserted");
        end

        #5 en = 0;
        
        #30 $finish;
    end

endmodule
