`timescale 1ns / 1ps

module mac_array_tb;

    reg clk;
    reg rst_n;
    reg en;
    reg [71:0] pixels_in;
    reg [71:0] weights_in;
    wire [19:0] mac_out;
    wire valid_out;

    mac_array uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .pixels_in(pixels_in),
        .weights_in(weights_in),
        .mac_out(mac_out),
        .valid_out(valid_out)
    );

    parameter DEBUG_LEVEL = 1;

    always #5 clk = ~clk;

    initial begin
        // Configurable Waveform Dumping
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/mac_array.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, mac_array_tb); // Top-level only
            else if (DEBUG_LEVEL == 2) $dumpvars(0, mac_array_tb.uut); // Accelerator/uut only
            else                       $dumpvars(0, mac_array_tb); // Full debug dump
        end
        
        clk = 0;
        rst_n = 0;
        en = 0;
        pixels_in = 0;
        weights_in = 0;
        
        #20 rst_n = 1;
        
        // Test Case 1: All 1s
        #10;
        en = 1;
        pixels_in = 72'h010101010101010101; // 9 times 1
        weights_in = 72'h010101010101010101; // 9 times 1
        
        #10;
        en = 0;
        
        #40;
        if (mac_out !== 20'd9) $display("FAIL: Expected 9, got %0d", mac_out);
        else $display("PASS: All 1s");

        // Test Case 2: Random Values
        #10;
        en = 1;
        pixels_in = {8'h02, 8'h03, 8'h01, 8'h00, 8'h04, 8'h02, 8'h01, 8'h01, 8'h05}; 
        weights_in = {8'h01, 8'h01, 8'h02, 8'h01, 8'h01, 8'h00, 8'h02, 8'h03, 8'h01};
        // Expect: 2*1+3*1+1*2+0*1+4*1+2*0+1*2+1*3+5*1
        //       = 2 + 3 + 2 + 0 + 4 + 0 + 2 + 3 + 5
        //       = 21
        
        #10;
        en = 0;
        
        #40;
        if (mac_out !== 20'd21) $display("FAIL: Expected 21, got %0d", mac_out);
        else $display("PASS: Complex Vector");

        #20 $finish;
    end

endmodule
