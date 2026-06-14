`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// FC Bias RAM (MMIO Writable)
//
// Small SRAM storing one bias value per output neuron.
// Port A: CPU writes biases via MMIO.
// Port B: FC layer reads bias for each neuron during accumulation.
// -----------------------------------------------------------------------------

module fc_bias_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4    // 16 entries (supports up to 16 output classes)
)(
    input  wire                    clk,
    input  wire                    wea,
    input  wire [ADDR_WIDTH-1:0]   addra,
    input  wire [DATA_WIDTH-1:0]   dina,
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
