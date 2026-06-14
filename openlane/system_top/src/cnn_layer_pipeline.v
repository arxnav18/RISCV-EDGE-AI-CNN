`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// CNN Layer Pipeline Wrapper
//
// Single reusable convolution layer stage:
//   conv3d_accelerator → ReLU → max_pool_2x2
//
// This module chains three processing elements into a clean streaming
// pipeline that can be instantiated multiple times for multi-layer networks.
// -----------------------------------------------------------------------------

module cnn_layer_pipeline (
    input  wire        clk,
    input  wire        rst_n,

    // Layer configuration
    input  wire        start,
    input  wire [15:0] img_width,
    input  wire [15:0] img_height,
    input  wire [7:0]  num_channels,

    // Data input (streaming pixels)
    input  wire        pixel_valid_in,
    input  wire [7:0]  pixel_in,

    // Weight input
    input  wire        weights_valid,
    input  wire [71:0] weight_in,

    // Data output (post-ReLU, post-Pool)
    output wire signed [31:0] pixel_out,
    output wire        out_valid,

    // Intermediate tap: post-conv pre-pool (for inspection/debug)
    output wire [31:0] conv_raw_out,
    output wire        conv_raw_valid,

    // Output dimensions (after pooling)
    output wire [15:0] pool_out_width,

    // Status
    output wire        conv_done
);

    // -------------------------------------------------------------------------
    // Stage 1: 3D Convolution
    // -------------------------------------------------------------------------
    wire [31:0] conv_out;
    wire        conv_valid;
    wire        conv_done_int;

    conv3d_accelerator u_conv (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_conv     (start),
        .img_width      (img_width),
        .img_height     (img_height),
        .num_channels   (num_channels),
        .pixel_valid_in (pixel_valid_in),
        .pixel_in       (pixel_in),
        .weights_valid  (weights_valid),
        .weight_in      (weight_in),
        .pixel_out      (conv_out),
        .out_valid      (conv_valid),
        .done           (conv_done_int)
    );

    assign conv_raw_out   = conv_out;
    assign conv_raw_valid = conv_valid;
    assign conv_done      = conv_done_int;

    // -------------------------------------------------------------------------
    // Stage 2: ReLU Activation
    // -------------------------------------------------------------------------
    wire [31:0] relu_out;
    wire        relu_valid;

    relu #(.DATA_WIDTH(32)) u_relu (
        .data_in  (conv_out),
        .valid_in (conv_valid),
        .data_out (relu_out),
        .valid_out(relu_valid)
    );

    // -------------------------------------------------------------------------
    // Stage 3: 2x2 Max Pooling
    // -------------------------------------------------------------------------
    // Output width after conv (valid padding): img_width - 2
    wire [15:0] conv_out_width = img_width - 16'd2;

    max_pool_2x2 #(
        .DATA_WIDTH(32),
        .MAX_IMAGE_WIDTH(1024)
    ) u_pool (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .img_width (conv_out_width),
        .pixel_in  (relu_out),
        .valid_in  (relu_valid),
        .pixel_out (pixel_out),
        .valid_out (out_valid),
        .out_width (pool_out_width),
        .out_height_unused()
    );

endmodule
