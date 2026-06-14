`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Batch Normalization Layer
//
// Implements: y = (x - mean) * scale + offset
//
// Uses pre-computed parameters (frozen BN). The CPU loads mean, scale, and
// offset values via MMIO before inference. This module processes one value
// per clock in streaming mode.
//
// For INT8 inference, scale is represented as a fixed-point multiplier and
// the division is replaced by a right-shift.
// -----------------------------------------------------------------------------

module batch_norm #(
    parameter DATA_WIDTH = 32,
    parameter PARAM_WIDTH = 16    // Pre-computed parameter precision
)(
    input  wire                              clk,
    input  wire                              rst_n,

    // Streaming data
    input  wire signed [DATA_WIDTH-1:0]      data_in,
    input  wire                              valid_in,

    // Pre-loaded parameters (from MMIO registers, per-channel)
    input  wire signed [PARAM_WIDTH-1:0]     bn_mean,
    input  wire signed [PARAM_WIDTH-1:0]     bn_scale,   // Fixed-point scale (Q8.8)
    input  wire signed [PARAM_WIDTH-1:0]     bn_offset,

    // Output
    output reg  signed [DATA_WIDTH-1:0]      data_out,
    output reg                               valid_out
);

    // Pipeline stage 1: subtract mean
    reg signed [DATA_WIDTH-1:0] centered;
    reg                         s1_valid;

    // Pipeline stage 2: multiply by scale + add offset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            centered  <= 0;
            s1_valid  <= 0;
            data_out  <= 0;
            valid_out <= 0;
        end else begin
            // Stage 1: Center
            s1_valid <= valid_in;
            if (valid_in) begin
                centered <= data_in - {{(DATA_WIDTH-PARAM_WIDTH){bn_mean[PARAM_WIDTH-1]}}, bn_mean};
            end

            // Stage 2: Scale + Offset (fixed-point multiply with >>8 for Q8.8)
            valid_out <= s1_valid;
            if (s1_valid) begin
                data_out <= ((centered * {{(DATA_WIDTH-PARAM_WIDTH){bn_scale[PARAM_WIDTH-1]}}, bn_scale}) >>> 8)
                           + {{(DATA_WIDTH-PARAM_WIDTH){bn_offset[PARAM_WIDTH-1]}}, bn_offset};
            end
        end
    end

endmodule
