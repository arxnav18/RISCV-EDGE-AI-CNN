`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Multi-Filter Parallel MAC Bank
//
// Instantiates NUM_PARALLEL independent MAC arrays, each computing a different
// output filter simultaneously. This provides NUM_PARALLEL× throughput for
// the convolution operation.
//
// Each parallel lane has its own weight input and produces its own MAC output.
// All lanes share the same pixel window input (since they all operate on the
// same spatial position, just different filters).
// -----------------------------------------------------------------------------

module multi_filter_mac #(
    parameter NUM_PARALLEL = 4,     // Number of parallel filter computations
    parameter PIXEL_WIDTH  = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter MAC_OUT_WIDTH = 20
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              en,

    // Shared pixel window (9 × 8-bit = 72-bit from sliding window)
    input  wire [PIXEL_WIDTH*9-1:0]          pixels_in,

    // Per-filter weight inputs (each filter has 9 weights)
    input  wire [WEIGHT_WIDTH*9*NUM_PARALLEL-1:0] weights_in,

    // Per-filter MAC outputs
    output wire [MAC_OUT_WIDTH*NUM_PARALLEL-1:0]  mac_out,
    output wire [NUM_PARALLEL-1:0]                valid_out
);

    genvar i;
    generate
        for (i = 0; i < NUM_PARALLEL; i = i + 1) begin : gen_mac
            mac_array u_mac (
                .clk        (clk),
                .rst_n      (rst_n),
                .en         (en),
                .pixels_in  (pixels_in),
                .weights_in (weights_in[WEIGHT_WIDTH*9*(i+1)-1 : WEIGHT_WIDTH*9*i]),
                .mac_out    (mac_out[MAC_OUT_WIDTH*(i+1)-1 : MAC_OUT_WIDTH*i]),
                .valid_out  (valid_out[i])
            );
        end
    endgenerate

endmodule
