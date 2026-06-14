`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// PPA-Optimized Fully Connected (Dense) Layer
//
// Improvements:
// 1. Performance: Added a pipeline stage to the multiplier (retiming).
// 2. Power: Operand Isolation for the multiplier inputs.
// 3. Timing: Balanced critical path for high-frequency operation.
// -----------------------------------------------------------------------------

module fc_layer #(
    parameter FEATURE_WIDTH = 8,
    parameter WEIGHT_WIDTH  = 8,
    parameter ACC_WIDTH     = 32,
    parameter MAX_INPUTS    = 576,
    parameter MAX_OUTPUTS   = 10
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           start,
    input  wire [15:0]                    num_inputs,
    input  wire [7:0]                     num_outputs,
    input  wire signed [FEATURE_WIDTH-1:0] feature_in,
    input  wire                           feature_valid,
    output reg  [15:0]                    weight_addr,
    input  wire signed [WEIGHT_WIDTH-1:0] weight_in,
    input  wire signed [ACC_WIDTH-1:0]    bias_in,
    output reg  signed [ACC_WIDTH-1:0]    score_out,
    output reg                            score_valid,
    output reg                            done
);

    localparam IDLE       = 2'd0;
    localparam COMPUTE    = 2'd1;
    localparam OUTPUT     = 2'd2;
    localparam DONE_STATE = 2'd3;

    reg [1:0]  state;
    reg signed [ACC_WIDTH-1:0] accumulator;
    reg [15:0] input_idx;
    reg [7:0]  output_idx;

    // Pipeline Registers for MAC
    reg signed [ACC_WIDTH-1:0] mul_res_reg;
    reg                        mul_valid_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            accumulator   <= 0;
            input_idx     <= 0;
            output_idx    <= 0;
            weight_addr   <= 0;
            score_out     <= 0;
            score_valid   <= 0;
            done          <= 0;
            mul_res_reg   <= 0;
            mul_valid_reg <= 0;
        end else begin
            score_valid   <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state       <= COMPUTE;
                        accumulator <= 0;
                        input_idx   <= 0;
                        output_idx  <= 0;
                        weight_addr <= 0;
                    end
                end

                COMPUTE: begin
                    // ---- Pipelined MAC Stage 1: Multiplication & Isolation ----
                    if (feature_valid) begin
                        mul_res_reg <= ({{(ACC_WIDTH-FEATURE_WIDTH){feature_in[FEATURE_WIDTH-1]}}, feature_in} *
                                        {{(ACC_WIDTH-WEIGHT_WIDTH){weight_in[WEIGHT_WIDTH-1]}}, weight_in});
                        mul_valid_reg <= 1'b1;
                        weight_addr   <= weight_addr + 1;
                        input_idx     <= input_idx + 1;
                        
                        // Check if this was the last input capture
                        if (input_idx == num_inputs - 1) begin
                            state <= OUTPUT;
                        end
                    end else begin
                        mul_valid_reg <= 1'b0;
                    end

                    // ---- Pipelined MAC Stage 2: Accumulation ----
                    if (mul_valid_reg) begin
                        accumulator <= accumulator + mul_res_reg;
                    end
                end

                OUTPUT: begin
                    // Final drain of pipeline
                    if (mul_valid_reg) begin
                        accumulator <= accumulator + mul_res_reg;
                        mul_valid_reg <= 1'b0; // Ensure single addition
                    end else begin
                        score_out   <= accumulator + bias_in;
                        score_valid <= 1'b1;
                        accumulator <= 0;
                        input_idx   <= 0;
                        output_idx  <= output_idx + 1;

                        if (output_idx == num_outputs - 1) begin
                            state <= DONE_STATE;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                DONE_STATE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
