`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// ReLU Activation Function
//
// Combinational module: clamps negative signed values to zero.
// Passes positive values unchanged. Designed for streaming inline use
// after `channel_accumulator` output.
// -----------------------------------------------------------------------------

module relu #(
    parameter DATA_WIDTH = 32
)(
    input  wire signed [DATA_WIDTH-1:0] data_in,
    input  wire                         valid_in,

    output wire [DATA_WIDTH-1:0]        data_out,
    output wire                         valid_out
);

    // If MSB (sign bit) is 1, the value is negative → clamp to 0
    assign data_out  = data_in[DATA_WIDTH-1] ? {DATA_WIDTH{1'b0}} : data_in;
    assign valid_out = valid_in;

endmodule
