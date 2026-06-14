`timescale 1ns / 1ps

module weight_ram #(
    parameter WEIGHT_WIDTH = 72,  // 9 weights * 8 bits
    parameter ADDR_WIDTH = 2      // 3 layers => 4 elements
)(
    input clk,
    
    // Port A: Write (from Processor configuration)
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [WEIGHT_WIDTH-1:0] dina,
    
    // Port B: Read (to Conv Accelerator)
    input enb,
    input [ADDR_WIDTH-1:0] addrb,
    output reg [WEIGHT_WIDTH-1:0] doutb
);

    // RAM array
    reg [WEIGHT_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (wea) begin
            ram[addra] <= dina;
        end
    end

    always @(posedge clk) begin
        if (enb) begin
            doutb <= ram[addrb];
        end
    end

endmodule
