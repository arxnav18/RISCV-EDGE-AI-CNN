`timescale 1ns / 1ps

module sliding_window #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    
    // In from line buffers
    input wire [DATA_WIDTH-1:0] col_row0, // Bottom row
    input wire [DATA_WIDTH-1:0] col_row1, // Middle row
    input wire [DATA_WIDTH-1:0] col_row2, // Top row
    
    // Output 9 pixels of the 3x3 window
    // [0-2]: Top row (left to right)
    // [3-5]: Mid row
    // [6-8]: Bot row
    output reg [DATA_WIDTH*9-1:0] window_out,
    output reg valid_out
);

    // Shift registers for the window
    reg [DATA_WIDTH-1:0] r0_c0, r0_c1, r0_c2; // Top row
    reg [DATA_WIDTH-1:0] r1_c0, r1_c1, r1_c2; // Middle row
    reg [DATA_WIDTH-1:0] r2_c0, r2_c1, r2_c2; // Bottom row

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0_c0 <= 0; r0_c1 <= 0; r0_c2 <= 0;
            r1_c0 <= 0; r1_c1 <= 0; r1_c2 <= 0;
            r2_c0 <= 0; r2_c1 <= 0; r2_c2 <= 0;
            window_out <= 0;
            valid_out <= 0;
        end else if (en) begin
            // Shift values right
            r0_c0 <= r0_c1; r0_c1 <= r0_c2; r0_c2 <= col_row2;
            r1_c0 <= r1_c1; r1_c1 <= r1_c2; r1_c2 <= col_row1;
            r2_c0 <= r2_c1; r2_c1 <= r2_c2; r2_c2 <= col_row0;
            
            // Map to flat output vector
            // Format: {bot_R, bot_M, bot_L, mid_R, mid_M, mid_L, top_R, top_M, top_L}
            // For MAC alignment:
            // window_out[8*8 +: 8] = top_left
            // window_out[0*8 +: 8] = bottom_right
            
            window_out <= {
                col_row0, r2_c2, r2_c0, // Bottom row: right, mid, left
                col_row1, r1_c2, r1_c0, // Middle row: right, mid, left
                col_row2, r0_c2, r0_c0  // Top row: right, mid, left
            };
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
