//============================================================================
// Module: Instruction Memory
// Description: ROM-based instruction memory. Loads instructions from a hex
//              file (instructions.mem) using $readmemh. Word-addressed.
//============================================================================

module instruction_memory (
    input  wire [31:0] addr,
    output wire [31:0] instruction
);

    // 256 words of instruction memory (1 KB)
    reg [31:0] mem [0:255];

    // Load instructions from hex file
    initial begin
        $readmemh("instructions.mem", mem);
    end

    // Word-aligned read: address is byte-addressed, divide by 4
    assign instruction = mem[addr[9:2]];

endmodule
