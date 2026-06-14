//============================================================================
// Module: Program Counter (PC)
// Description: 32-bit program counter with synchronous reset.
//              Increments by 4 each clock cycle to fetch the next instruction.
//============================================================================

module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,       // Pipeline stall signal
    output reg  [31:0] pc_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'h0000_0000;
        end else if (!stall) begin
            pc_out <= pc_out + 32'd4;
        end
        // If stall is asserted, PC holds its current value
    end

endmodule
