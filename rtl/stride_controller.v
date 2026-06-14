`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Stride Controller
//
// Decimation logic for convolution and pooling layers. Accepts a stream of
// valid pixels and only passes through every Nth pixel in both X and Y,
// effectively implementing strided convolution.
//
// Example: stride=2 on a 32×32 input → passes every 2nd pixel in each row
// and every 2nd row, producing a ~16×16 output.
// -----------------------------------------------------------------------------

module stride_controller #(
    parameter DATA_WIDTH = 32
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           start,

    // Configuration
    input  wire [3:0]                     stride,     // 1, 2, or 4
    input  wire [15:0]                    img_width,

    // Streaming input
    input  wire signed [DATA_WIDTH-1:0]   data_in,
    input  wire                           valid_in,

    // Decimated output
    output reg  signed [DATA_WIDTH-1:0]   data_out,
    output reg                            valid_out
);

    reg [15:0] col_cnt;
    reg [15:0] row_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || start) begin
            col_cnt   <= 0;
            row_cnt   <= 0;
            data_out  <= 0;
            valid_out <= 0;
        end else if (valid_in) begin
            // Pass pixel only if both col and row are multiples of stride
            if ((col_cnt[3:0] < stride ? col_cnt == 0 : col_cnt[3:0] == 0) &&
                (row_cnt[3:0] < stride ? row_cnt == 0 : row_cnt[3:0] == 0)) begin
                data_out  <= data_in;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end

            // Advance col/row counters
            if (col_cnt == img_width - 1) begin
                col_cnt <= 0;
                row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
