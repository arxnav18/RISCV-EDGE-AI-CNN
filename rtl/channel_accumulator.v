`timescale 1ns / 1ps

module channel_accumulator #(
    parameter IN_WIDTH = 20,
    parameter OUT_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire clear,        // Clear accumulator for new spatial pixel
    
    input wire signed [IN_WIDTH-1:0] mac_value,
    
    output reg signed [OUT_WIDTH-1:0] accum_out,
    output reg valid_out
);

    reg signed [OUT_WIDTH-1:0] sum_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg <= 0;
            accum_out <= 0;
            valid_out <= 0;
        end else if (en) begin
            if (clear) begin
                sum_reg <= {{(OUT_WIDTH-IN_WIDTH){mac_value[IN_WIDTH-1]}}, mac_value};
                accum_out <= sum_reg; // Output the finalized value from previous sequence
                valid_out <= 1'b1;
            end else begin
                sum_reg <= sum_reg + {{(OUT_WIDTH-IN_WIDTH){mac_value[IN_WIDTH-1]}}, mac_value};
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
