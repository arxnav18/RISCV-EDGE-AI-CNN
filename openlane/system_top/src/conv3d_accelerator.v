`timescale 1ns / 1ps

module conv3d_accelerator (
    input wire clk,
    input wire rst_n,
    
    // Control interface from CNN Controller
    input wire start_conv,
    input wire [15:0] img_width,
    input wire [15:0] img_height,
    input wire [7:0] num_channels,
    
    // Data input
    input wire pixel_valid_in,
    input wire [7:0] pixel_in,
    
    // Weight input
    input wire weights_valid,
    input wire [71:0] weight_in,
    
    // Data output
    output wire [31:0] pixel_out,
    output wire out_valid,
    
    // Status
    output reg done
);

    wire [7:0] line_out_0, line_out_1, line_out_2;
    wire line_valid;
    
    line_buffer u_line_buf (
        .clk(clk),
        .rst_n(rst_n),
        .en(pixel_valid_in),
        .image_width(img_width),
        .pixel_in(pixel_in),
        .out_row0(line_out_0),
        .out_row1(line_out_1),
        .out_row2(line_out_2),
        .valid_out(line_valid)
    );
    
    wire [71:0] window_pixels;
    wire window_valid;
    
    sliding_window u_sliding_win (
        .clk(clk),
        .rst_n(rst_n),
        .en(line_valid),
        .col_row0(line_out_0),
        .col_row1(line_out_1),
        .col_row2(line_out_2),
        .window_out(window_pixels),
        .valid_out(window_valid)
    );
    
    wire [19:0] mac_result;
    wire mac_valid;
    
    mac_array u_mac_array (
        .clk(clk),
        .rst_n(rst_n),
        .en(window_valid && weights_valid),
        .pixels_in(window_pixels),
        .weights_in(weight_in),
        .mac_out(mac_result),
        .valid_out(mac_valid)
    );
    
    // Simplified accumulator logic: clear on new spatial pixel
    // For full 3D, we accumulate over channels. For this demo we just accumulate.
    reg clear_acc;
    reg [7:0] ch_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_count <= 0;
            clear_acc <= 1;
        end else if (mac_valid) begin
            if (ch_count == num_channels - 1) begin
                ch_count <= 0;
                clear_acc <= 1;
            end else begin
                ch_count <= ch_count + 1;
                clear_acc <= 0;
            end
        end
    end
    
    channel_accumulator u_chan_acc (
        .clk(clk),
        .rst_n(rst_n),
        .en(mac_valid),
        .clear(clear_acc),
        .mac_value(mac_result),
        .accum_out(pixel_out),
        .valid_out(out_valid)
    );
    
    // Logic for 'done' signal omitted for brevity; 
    // it would typically count generated output pixels and assert done when reaching width*height.
    reg [31:0] out_pixel_count;
    wire [31:0] total_pixels = img_width * img_height;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_pixel_count <= 0;
            done <= 0;
        end else begin
            if (start_conv) begin
                out_pixel_count <= 0;
                done <= 0;
            end else if (out_valid) begin // Count finished output pixel
                out_pixel_count <= out_pixel_count + 1;
                // Since this increments at the same cycle it asserts done,
                // done shouldn't lock forever, or it doesn't matter since the upper
                // logic waits for it. We'll leave it as is.
                if (out_pixel_count == total_pixels - 1) begin
                    done <= 1;
                end
            end
        end
    end

endmodule
