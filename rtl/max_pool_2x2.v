`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 2x2 Max Pooling Unit (Streaming)
//
// Processes a stream of pixels row by row and outputs the maximum value
// from each non-overlapping 2x2 block. Halves spatial dimensions.
//
// Internal mechanism:
//   - Uses a line buffer to hold the previous row.
//   - On even rows, stores the column-pair max into the line buffer.
//   - On odd rows, compares current column-pair max with the buffered
//     value from the previous row and emits the final 2x2 max.
// -----------------------------------------------------------------------------

module max_pool_2x2 #(
    parameter DATA_WIDTH = 32,
    parameter MAX_IMAGE_WIDTH = 1024  // Max supported input width (in pixels)
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       start,      // Pulse to reset counters
    input  wire [15:0]                img_width,  // Input feature map width

    // Streaming input
    input  wire signed [DATA_WIDTH-1:0] pixel_in,
    input  wire                       valid_in,

    // Streaming output
    output reg  signed [DATA_WIDTH-1:0] pixel_out,
    output reg                        valid_out,
    output wire [15:0]                out_width,  // Output width = img_width / 2
    output wire [15:0]                out_height_unused  // Placeholder
);

    assign out_width = img_width >> 1;
    assign out_height_unused = 16'd0; // Driven externally if needed

    // Column and row counters
    reg [15:0] col_cnt;
    reg [15:0] row_cnt;

    // Temporary register to hold the first pixel of a horizontal pair
    reg signed [DATA_WIDTH-1:0] col_pair_max;
    reg col_pair_valid;

    // Line buffer: stores the row-pair max from the even row
    reg signed [DATA_WIDTH-1:0] row_buf [0:MAX_IMAGE_WIDTH/2-1];
    reg [15:0] buf_wr_addr;

    // Horizontal pair max
    wire signed [DATA_WIDTH-1:0] h_max = (col_pair_max > pixel_in) ? col_pair_max : pixel_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt        <= 0;
            row_cnt        <= 0;
            col_pair_max   <= 0;
            col_pair_valid <= 0;
            buf_wr_addr    <= 0;
            pixel_out      <= 0;
            valid_out      <= 0;
        end else if (start) begin
            col_cnt        <= 0;
            row_cnt        <= 0;
            col_pair_max   <= 0;
            col_pair_valid <= 0;
            buf_wr_addr    <= 0;
            pixel_out      <= 0;
            valid_out      <= 0;
        end else if (valid_in) begin
            valid_out <= 1'b0;  // Default

            if (col_cnt[0] == 1'b0) begin
                // Even column: store pixel, wait for pair
                col_pair_max   <= pixel_in;
                col_pair_valid <= 1'b1;
            end else begin
                // Odd column: compute horizontal max
                col_pair_valid <= 1'b0;
                buf_wr_addr    <= col_cnt >> 1;

                if (row_cnt[0] == 1'b0) begin
                    // Even row: store h_max into line buffer
                    row_buf[col_cnt >> 1] <= h_max;
                end else begin
                    // Odd row: compare h_max with buffered value → emit
                    pixel_out <= (row_buf[col_cnt >> 1] > h_max) ? row_buf[col_cnt >> 1] : h_max;
                    valid_out <= 1'b1;
                end
            end

            // Advance counters
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
