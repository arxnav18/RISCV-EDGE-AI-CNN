//============================================================================
// Module: ALU (Arithmetic Logic Unit)
// Description: Supports ADD, SUB, AND, OR operations.
//              Outputs result and zero flag.
//============================================================================

module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] alu_result,
    output wire        zero_flag
);

    // ALU control encoding
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD: alu_result = operand_a + operand_b;
            ALU_SUB: alu_result = operand_a - operand_b;
            ALU_AND: alu_result = operand_a & operand_b;
            ALU_OR:  alu_result = operand_a | operand_b;
            default: alu_result = 32'd0;
        endcase
    end

    // Zero flag: asserted when result is zero
    assign zero_flag = (alu_result == 32'd0);

endmodule
