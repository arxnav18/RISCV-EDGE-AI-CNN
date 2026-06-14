`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Skip Connection (Residual Add)
//
// Implements element-wise addition between two streaming data paths for
// residual/skip connections (ResNet-style). Adds the current layer output
// with a buffered copy of the layer input.
//
// Both inputs must be synchronized and produce data at the same rate.
// The skip path can be delayed through a small FIFO to match pipeline latency.
// -----------------------------------------------------------------------------

module skip_add #(
    parameter DATA_WIDTH = 32
)(
    input  wire                           clk,
    input  wire                           rst_n,

    // Main path (layer output)
    input  wire signed [DATA_WIDTH-1:0]   main_in,
    input  wire                           main_valid,

    // Skip path (buffered layer input)
    input  wire signed [DATA_WIDTH-1:0]   skip_in,
    input  wire                           skip_valid,

    // Residual sum output
    output reg  signed [DATA_WIDTH-1:0]   data_out,
    output reg                            valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= 0;
            valid_out <= 0;
        end else if (main_valid && skip_valid) begin
            data_out  <= main_in + skip_in;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
