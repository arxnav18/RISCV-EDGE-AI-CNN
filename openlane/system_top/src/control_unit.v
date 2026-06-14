//============================================================================
// Module: Control Unit
// Description: Decodes the opcode field of the instruction and generates
//              control signals for the pipeline. Also includes ALU control
//              logic using funct3 and funct7 fields.
//
// Supported opcodes:
//   R-type  (0110011) : ADD, SUB, AND, OR
//   I-type  (0010011) : ADDI
//   Custom  (0001011) : Convolution accelerator trigger
//============================================================================

module control_unit (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    // Control signals
    output reg         reg_write,
    output reg         alu_src,       // 0 = rs2, 1 = immediate
    output reg  [3:0]  alu_ctrl,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  mem_to_reg     // 00 = ALU, 01 = memory, 10 = accelerator (removed)
);

    // Opcode definitions
    localparam OP_R_TYPE  = 7'b0110011;
    localparam OP_I_TYPE  = 7'b0010011;
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;

    // ALU control encoding
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;

    always @(*) begin
        // Default: all signals deasserted (NOP-safe)
        reg_write   = 1'b0;
        alu_src     = 1'b0;
        alu_ctrl    = ALU_ADD;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 2'b00;

        case (opcode)
            // ---------------------------------------------------------
            // R-type: ADD, SUB, AND, OR
            // ---------------------------------------------------------
            OP_R_TYPE: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;   // Operand B from rs2
                mem_to_reg = 2'b00;  // Write ALU result

                case (funct3)
                    3'b000: begin
                        // ADD or SUB based on funct7[5]
                        if (funct7[5])
                            alu_ctrl = ALU_SUB;
                        else
                            alu_ctrl = ALU_ADD;
                    end
                    3'b111: alu_ctrl = ALU_AND;
                    3'b110: alu_ctrl = ALU_OR;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // ---------------------------------------------------------
            // I-type: ADDI
            // ---------------------------------------------------------
            OP_I_TYPE: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // Operand B from immediate
                alu_ctrl   = ALU_ADD;
                mem_to_reg = 2'b00;  // Write ALU result
            end
            // ---------------------------------------------------------
            // Load and Store
            // ---------------------------------------------------------
            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_ctrl   = ALU_ADD;
                mem_read   = 1'b1;
                mem_to_reg = 2'b01;  // Write memory read data
            end
            
            OP_STORE: begin
                alu_src    = 1'b1;
                alu_ctrl   = ALU_ADD;
                mem_write  = 1'b1;
            end

            // ---------------------------------------------------------
            default: begin
                // NOP – all signals remain deasserted
            end
        endcase
    end

endmodule
