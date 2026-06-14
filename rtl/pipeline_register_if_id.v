//============================================================================
// Module: Pipeline Register IF/ID
// Description: Latches the Program Counter and fetched instruction
//              from the Instruction Fetch stage to the Instruction Decode stage.
//              Supports flush for hazard handling.
//============================================================================

module pipeline_register_if_id (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,       // Hold current values when stalled
    input  wire        flush,       // Insert NOP (bubble)
    // IF stage inputs
    input  wire [31:0] pc_in,
    input  wire [31:0] instruction_in,
    // ID stage outputs
    output reg  [31:0] pc_out,
    output reg  [31:0] instruction_out
);

    always @(posedge clk or posedge reset) begin
        if (reset ) begin
            pc_out          <= 32'd0;
            instruction_out <= 32'h0000_0013; // NOP (ADDI x0, x0, 0)
        end else if (flush) begin
            pc_out          <= 32'd0;
            instruction_out <= 32'h0000_0013; // NOP (ADDI x0, x0, 0)
        end else if (!stall) begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
        end
        // If stalled, hold current values
    end

endmodule
