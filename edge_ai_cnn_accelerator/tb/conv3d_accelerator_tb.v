`timescale 1ns / 1ps

module conv3d_accelerator_tb;

    reg clk;
    reg rst_n;
    reg start_conv;
    reg [7:0] img_width, img_height, num_channels;
    
    reg pixel_valid_in;
    reg [7:0] pixel_in;
    reg weights_valid;
    reg [71:0] weight_in;
    
    wire [31:0] pixel_out;
    wire out_valid;
    wire done;

    conv3d_accelerator uut (
        .clk(clk),
        .rst_n(rst_n),
        .start_conv(start_conv),
        .img_width(img_width),
        .img_height(img_height),
        .num_channels(num_channels),
        .pixel_valid_in(pixel_valid_in),
        .pixel_in(pixel_in),
        .weights_valid(weights_valid),
        .weight_in(weight_in),
        .pixel_out(pixel_out),
        .out_valid(out_valid),
        .done(done)
    );

    always #5 clk = ~clk;

    parameter DEBUG_LEVEL = 1;
    integer i;

    initial begin
        // Configurable Waveform Dumping
        if (DEBUG_LEVEL > 0) begin
            $dumpfile("sim_out/waveforms/conv3d_accelerator.fst");
            if (DEBUG_LEVEL == 1)      $dumpvars(1, conv3d_accelerator_tb); // Top-level only
            else if (DEBUG_LEVEL == 2) $dumpvars(0, conv3d_accelerator_tb.uut); // Accelerator/uut only
            else                       $dumpvars(0, conv3d_accelerator_tb); // Full debug dump
        end
        
        clk = 0;
        rst_n = 0;
        start_conv = 0;
        img_width = 8;
        img_height = 8;
        num_channels = 3;
        pixel_valid_in = 0;
        pixel_in = 0;
        weights_valid = 0;
        weight_in = 0;
        
        #20 rst_n = 1;
        
        #10 start_conv = 1;
        #10 start_conv = 0;
        
        // Feed image data (width*height * channels = 8*8*3 = 192 pixels)
        weights_valid = 1;
        weight_in = 72'h010101010101010101; // Kernel of 1s
        
        // Feed extra pixels to flush pipeline
        for (i=0; i<200; i=i+1) begin
            #10;
            pixel_valid_in = 1;
            pixel_in = 8'h01; // Pixel values of 1
        end
        
        #10;
        pixel_valid_in = 0;
        
        // Wait for pipeline to flush and accumulate
        #100;
        
        if (done) $display("PASS: Conv3D completed");
        
        #50 $finish;
    end

endmodule
