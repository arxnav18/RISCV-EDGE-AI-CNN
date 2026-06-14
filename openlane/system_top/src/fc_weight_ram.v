`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// FC Weight RAM (MMIO Writable)
//
// Dual-port SRAM storing FC layer weights. Port A is written via the RISC-V
// MMIO bus (the CPU pre-loads trained weights). Port B is read by the FC layer
// during inference.
// -----------------------------------------------------------------------------

module fc_weight_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 14   // 16384 entries (supports 576×10 = 5760 weights + headroom)
)(
    input  wire                    clk,
    // Port A: Write (from MMIO bus)
    input  wire                    wea,
    input  wire [ADDR_WIDTH-1:0]   addra,
    input  wire [DATA_WIDTH-1:0]   dina,
    // Port B: Read (to FC layer)
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
