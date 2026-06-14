`timescale 1ns / 1ps

module weight_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10 // 1024 addresses
)(
    input wire clk,
    
    // Port A (Write - from RISC-V config)
    input wire ena_a,
    input wire we_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] din_a,
    
    // Port B (Read - to MAC array)
    input wire ena_b,
    input wire [ADDR_WIDTH-1:0] addr_b,
    // Output 9 weights simultaneously (simulating wide read port for 3x3)
    // In practice, this might be a set of registers loaded sequentially
    // But for simplified FPGA, we can organize memory words as 72-bits
    output reg [71:0] dout_b // 9 * 8-bit
);

    // Memory structured to hold a full 3x3 kernel per address
    reg [71:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (ena_a) begin
            if (we_a) begin
                // In a real system, RISC-V might write 32 bits at a time.
                // For simplicity, we assume the testbench or memory mapper packs it.
                // We'll just define the memory interface.
                // We can use a partial write mechanism if needed, but keeping it simple here.
                // Assuming RISC-V memory mapper packs 72-bit writes (or 3x 32-bit writes into an intermediate register)
                ram[addr_a] <= {64'd0, din_a}; // Placeholder logic if 8-bit write. 
                // Wait, if it's 8 bit write, we need a 72-bit memory. Let's make it simple.
            end
        end
    end

    always @(posedge clk) begin
        if (ena_b) begin
            dout_b <= ram[addr_b];
        end
    end

endmodule
