`timescale 1ns / 1ps

module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter MAX_IMAGE_WIDTH = 128
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    
    input wire [7:0] image_width, // Dynamically configured width
    input wire [DATA_WIDTH-1:0] pixel_in,
    
    // Column outputs for 3x3 window: current row, row-1, row-2
    output reg [DATA_WIDTH-1:0] out_row0, // Newest
    output reg [DATA_WIDTH-1:0] out_row1, // Middle
    output reg [DATA_WIDTH-1:0] out_row2, // Oldest
    output reg valid_out
);

    // BRAM inference for line buffers
    // Note: We use a read-before-write or separate read/write logic to help Yosys infer BRAM
    reg [DATA_WIDTH-1:0] fifo_row1 [0:MAX_IMAGE_WIDTH-1];
    reg [DATA_WIDTH-1:0] fifo_row2 [0:MAX_IMAGE_WIDTH-1];
    
    reg [6:0] wr_ptr;
    
    reg [DATA_WIDTH-1:0] fifo1_out_q;
    reg [DATA_WIDTH-1:0] fifo2_out_q;

    // Synchronous memory read for better BRAM mapping
    always @(posedge clk) begin
        if (en) begin
            fifo1_out_q <= fifo_row1[wr_ptr];
            fifo2_out_q <= fifo_row2[wr_ptr];
            
            fifo_row1[wr_ptr] <= pixel_in;
            fifo_row2[wr_ptr] <= fifo_row1[wr_ptr];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            out_row0 <= 0;
            out_row1 <= 0;
            out_row2 <= 0;
            valid_out <= 0;
        end else if (en) begin
            // Set outputs from the fetched RAM data
            out_row0 <= pixel_in;
            out_row1 <= fifo1_out_q;
            out_row2 <= fifo2_out_q;
            valid_out <= 1'b1;
            
            // Manage pointers
            if ({1'b0, wr_ptr} == image_width - 8'd1) begin
                wr_ptr <= 0;
            end else begin
                wr_ptr <= wr_ptr + 1;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
