`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// PPA-Optimized MAC Array
//
// Improvements:
// 1. Performance: Split the 9-input adder tree into 2 pipeline stages.
// 2. Power: Implemented Operand Isolation (registers only toggle when valid).
// 3. Timing: Added register retiming buffers after multiplication.
// -----------------------------------------------------------------------------

module mac_array (
    input wire clk,
    input wire rst_n,
    input wire en,
    
    // 9 pixels from 3x3 window, 8-bit each
    input wire [71:0] pixels_in, // {p8, p7, ..., p0}
    // 9 weights from 3x3 kernel, 8-bit each
    input wire [71:0] weights_in, // {w8, w7, ..., w0}
    
    // Output of the 3x3 MAC (9 multiplications + accumulation)
    output reg [19:0] mac_out,
    output reg valid_out
);

    // Stage 1 Registers (Input Capture)
    reg signed [7:0] px_reg [0:8];
    reg signed [7:0] wt_reg [0:8];
    reg valid_stg1;

    // Stage 2 Registers (Multiplication)
    reg signed [15:0] mult_res [0:8];
    reg valid_stg2;

    // Stage 3 Registers (Adder Tree Part 1)
    reg signed [17:0] sum_part0, sum_part1, sum_part2;
    reg valid_stg3;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<9; i=i+1) begin
                px_reg[i] <= 0;
                wt_reg[i] <= 0;
                mult_res[i] <= 0;
            end
            sum_part0 <= 0; sum_part1 <= 0; sum_part2 <= 0;
            mac_out   <= 0;
            valid_stg1 <= 0; valid_stg2 <= 0; valid_stg3 <= 0; valid_out <= 0;
        end else begin
            // ---- Stage 1: Input Isolation ----
            if (en) begin
                px_reg[0] <= pixels_in[0*8 +: 8]; px_reg[1] <= pixels_in[1*8 +: 8]; px_reg[2] <= pixels_in[2*8 +: 8];
                px_reg[3] <= pixels_in[3*8 +: 8]; px_reg[4] <= pixels_in[4*8 +: 8]; px_reg[5] <= pixels_in[5*8 +: 8];
                px_reg[6] <= pixels_in[6*8 +: 8]; px_reg[7] <= pixels_in[7*8 +: 8]; px_reg[8] <= pixels_in[8*8 +: 8];
                
                wt_reg[0] <= weights_in[0*8 +: 8]; wt_reg[1] <= weights_in[1*8 +: 8]; wt_reg[2] <= weights_in[2*8 +: 8];
                wt_reg[3] <= weights_in[3*8 +: 8]; wt_reg[4] <= weights_in[4*8 +: 8]; wt_reg[5] <= weights_in[5*8 +: 8];
                wt_reg[6] <= weights_in[6*8 +: 8]; wt_reg[7] <= weights_in[7*8 +: 8]; wt_reg[8] <= weights_in[8*8 +: 8];
                valid_stg1 <= 1'b1;
            end else begin
                valid_stg1 <= 1'b0;
            end

            // ---- Stage 2: Multiply & Isolation ----
            if (valid_stg1) begin
                mult_res[0] <= px_reg[0] * wt_reg[0]; mult_res[1] <= px_reg[1] * wt_reg[1]; mult_res[2] <= px_reg[2] * wt_reg[2];
                mult_res[3] <= px_reg[3] * wt_reg[3]; mult_res[4] <= px_reg[4] * wt_reg[4]; mult_res[5] <= px_reg[5] * wt_reg[5];
                mult_res[6] <= px_reg[6] * wt_reg[6]; mult_res[7] <= px_reg[7] * wt_reg[7]; mult_res[8] <= px_reg[8] * wt_reg[8];
                valid_stg2  <= 1'b1;
            end else begin
                valid_stg2  <= 1'b0;
            end

            // ---- Stage 3: Adder Tree (Reduced Logic Depth) ----
            if (valid_stg2) begin
                // Parallel partial sums
                sum_part0 <= mult_res[0] + mult_res[1] + mult_res[2];
                sum_part1 <= mult_res[3] + mult_res[4] + mult_res[5];
                sum_part2 <= mult_res[6] + mult_res[7] + mult_res[8];
                valid_stg3 <= 1'b1;
            end else begin
                valid_stg3 <= 1'b0;
            end

            // ---- Stage 4: Final Sum ----
            if (valid_stg3) begin
                mac_out   <= sum_part0 + sum_part1 + sum_part2;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
