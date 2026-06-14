`timescale 1ns / 1ps

module cnn_controller_tb;

    reg clk, rst_n;
    reg start, mac_done, image_done;
    
    wire load_window, enable_mac, write_output, next_pixel, done;

    cnn_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .load_window(load_window),
        .enable_mac(enable_mac),
        .write_output(write_output),
        .next_pixel(next_pixel),
        .done(done),
        .mac_done(mac_done),
        .image_done(image_done)
    );

    parameter DEBUG_LEVEL = 1;

    always #5 clk = ~clk;

    // Latch the done pulse (it is only high for 1 clock cycle)
    reg done_seen;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_seen <= 0;
        else if (done) done_seen <= 1;
    end

    initial begin
        // Configurable Waveform Dumping
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/cnn_controller.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, cnn_controller_tb);
            else if (DEBUG_LEVEL == 2) $dumpvars(0, cnn_controller_tb.uut);
            else                       $dumpvars(0, cnn_controller_tb);
        end
        
        clk = 0;
        rst_n = 0;
        start = 0;
        mac_done = 0;
        image_done = 0;
        
        // Release reset
        #20 rst_n = 1;
        
        // Pulse start
        @(posedge clk); #1 start = 1;
        @(posedge clk); #1 start = 0;
        
        // FSM path: IDLE -> LOAD_WINDOW -> MULTIPLY -> ACCUMULATE
        // Wait for ACCUMULATE, then assert mac_done
        @(posedge clk); // LOAD_WINDOW
        @(posedge clk); // MULTIPLY
        #1 mac_done = 1;
        @(posedge clk); // ACCUMULATE sees mac_done -> WRITE_OUTPUT
        #1 mac_done = 0;
        
        // FSM path: WRITE_OUTPUT -> NEXT_PIXEL
        // Assert image_done before NEXT_PIXEL samples it
        @(posedge clk); // WRITE_OUTPUT
        #1 image_done = 1;
        @(posedge clk); // NEXT_PIXEL sees image_done -> DONE_STATE
        #1 image_done = 0;
        
        // Wait for DONE_STATE
        @(posedge clk); // DONE_STATE (done=1 for this cycle)
        @(posedge clk); // Back to IDLE
        
        #5;
        if (done_seen) $display("PASS: CNN Controller finished sequence.");
        else $display("FAIL: CNN Controller did not finish.");
        
        #10 $finish;
    end
endmodule
