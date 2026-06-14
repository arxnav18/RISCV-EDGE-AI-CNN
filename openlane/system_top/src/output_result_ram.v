`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Output Result RAM (MMIO Readable)
//
// Stores FC layer output scores so the RISC-V CPU can read classification
// results via MMIO after inference completes.
// Port A: FC layer writes scores during inference.
// Port B: CPU reads results via MMIO bus.
// -----------------------------------------------------------------------------

module output_result_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4    // 16 entries (up to 16 output classes)
)(
    input  wire                    clk,
    // Port A: Write (from FC layer)
    input  wire                    wea,
    input  wire [ADDR_WIDTH-1:0]   addra,
    input  wire [DATA_WIDTH-1:0]   dina,
    // Port B: Read (to MMIO bus)
    input  wire                    enb,
    input  wire [ADDR_WIDTH-1:0]   addrb,
    output reg  [DATA_WIDTH-1:0]   doutb
);

    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (wea) ram[addra] <= dina;
    end

    always @(posedge clk) begin
        if (enb) doutb <= ram[addrb];
    end

endmodule
