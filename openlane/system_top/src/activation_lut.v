`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Activation LUT — Sigmoid Approximation (Fully Synthesizable)
//
// Piecewise-linear sigmoid approximation implemented as pure combinational
// logic. No initial blocks — ASIC/FPGA synthesis safe.
//
// Sigmoid(x) ≈ piecewise_linear(x + 128) for x ∈ [-128, 127]
// Output range: [0, 255] (8-bit unsigned)
// -----------------------------------------------------------------------------

module activation_lut #(
    parameter IN_WIDTH  = 8,
    parameter OUT_WIDTH = 8
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Mode: 0 = sigmoid, 1 = pass-through
    input  wire                          mode,

    // Streaming input
    input  wire signed [IN_WIDTH-1:0]    data_in,
    input  wire                          valid_in,

    // Output
    output reg  [OUT_WIDTH-1:0]          data_out,
    output reg                           valid_out
);

    // Synthesizable piecewise-linear sigmoid approximation
    wire [7:0] unsigned_in;
    assign unsigned_in = data_in + 8'd128;  // Shift [-128,127] → [0,255]
    
    reg [OUT_WIDTH-1:0] sigmoid_val;

    always @(*) begin
        if      (unsigned_in < 8'd64)  sigmoid_val = 8'd0;
        else if (unsigned_in < 8'd96)  sigmoid_val = (unsigned_in - 8'd64) << 1;
        else if (unsigned_in < 8'd128) sigmoid_val = 8'd64 + (unsigned_in - 8'd96);
        else if (unsigned_in < 8'd160) sigmoid_val = 8'd128 + (unsigned_in - 8'd128);
        else if (unsigned_in < 8'd192) sigmoid_val = 8'd192 + ((unsigned_in - 8'd160) >> 1);
        else                           sigmoid_val = 8'd255;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            data_out  <= (mode == 1'b0) ? sigmoid_val : data_in[OUT_WIDTH-1:0];
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
