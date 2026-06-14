`timescale 1ns / 1ps

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

    integer i;
    
    // Hardware registers for MAC array
    // These are small arrays and intentional for synthesis as registers
    reg signed [7:0] px_reg_0, px_reg_1, px_reg_2, px_reg_3, px_reg_4, px_reg_5, px_reg_6, px_reg_7, px_reg_8;
    reg signed [7:0] wt_reg_0, wt_reg_1, wt_reg_2, wt_reg_3, wt_reg_4, wt_reg_5, wt_reg_6, wt_reg_7, wt_reg_8;
    reg signed [15:0] mult_res_0, mult_res_1, mult_res_2, mult_res_3, mult_res_4, mult_res_5, mult_res_6, mult_res_7, mult_res_8;
    reg valid_stg1, valid_stg2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px_reg_0 <= 0; px_reg_1 <= 0; px_reg_2 <= 0; px_reg_3 <= 0; px_reg_4 <= 0; px_reg_5 <= 0; px_reg_6 <= 0; px_reg_7 <= 0; px_reg_8 <= 0;
            wt_reg_0 <= 0; wt_reg_1 <= 0; wt_reg_2 <= 0; wt_reg_3 <= 0; wt_reg_4 <= 0; wt_reg_5 <= 0; wt_reg_6 <= 0; wt_reg_7 <= 0; wt_reg_8 <= 0;
            mult_res_0 <= 0; mult_res_1 <= 0; mult_res_2 <= 0; mult_res_3 <= 0; mult_res_4 <= 0; mult_res_5 <= 0; mult_res_6 <= 0; mult_res_7 <= 0; mult_res_8 <= 0;
            mac_out <= 0;
            valid_stg1 <= 0;
            valid_stg2 <= 0;
            valid_out <= 0;
        end else begin
            // Stage 1: Register Inputs
            if (en) begin
                px_reg_0 <= pixels_in[0*8 +: 8]; px_reg_1 <= pixels_in[1*8 +: 8]; px_reg_2 <= pixels_in[2*8 +: 8];
                px_reg_3 <= pixels_in[3*8 +: 8]; px_reg_4 <= pixels_in[4*8 +: 8]; px_reg_5 <= pixels_in[5*8 +: 8];
                px_reg_6 <= pixels_in[6*8 +: 8]; px_reg_7 <= pixels_in[7*8 +: 8]; px_reg_8 <= pixels_in[8*8 +: 8];
                
                wt_reg_0 <= weights_in[0*8 +: 8]; wt_reg_1 <= weights_in[1*8 +: 8]; wt_reg_2 <= weights_in[2*8 +: 8];
                wt_reg_3 <= weights_in[3*8 +: 8]; wt_reg_4 <= weights_in[4*8 +: 8]; wt_reg_5 <= weights_in[5*8 +: 8];
                wt_reg_6 <= weights_in[6*8 +: 8]; wt_reg_7 <= weights_in[7*8 +: 8]; wt_reg_8 <= weights_in[8*8 +: 8];
                
                valid_stg1 <= 1'b1;
            end else begin
                valid_stg1 <= 1'b0;
            end
            
            // Stage 2: Multiply
            if (valid_stg1) begin
                mult_res_0 <= px_reg_0 * wt_reg_0; mult_res_1 <= px_reg_1 * wt_reg_1; mult_res_2 <= px_reg_2 * wt_reg_2;
                mult_res_3 <= px_reg_3 * wt_reg_3; mult_res_4 <= px_reg_4 * wt_reg_4; mult_res_5 <= px_reg_5 * wt_reg_5;
                mult_res_6 <= px_reg_6 * wt_reg_6; mult_res_7 <= px_reg_7 * wt_reg_7; mult_res_8 <= px_reg_8 * wt_reg_8;
                valid_stg2 <= 1'b1;
            end else begin
                valid_stg2 <= 1'b0;
            end
            
            // Stage 3: Accumulate 9 products
            if (valid_stg2) begin
                mac_out <= {{4{mult_res_0[15]}}, mult_res_0} + {{4{mult_res_1[15]}}, mult_res_1} + {{4{mult_res_2[15]}}, mult_res_2} +
                           {{4{mult_res_3[15]}}, mult_res_3} + {{4{mult_res_4[15]}}, mult_res_4} + {{4{mult_res_5[15]}}, mult_res_5} +
                           {{4{mult_res_6[15]}}, mult_res_6} + {{4{mult_res_7[15]}}, mult_res_7} + {{4{mult_res_8[15]}}, mult_res_8};
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule
