`timescale 1ns / 1ps

module feature_map_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6    // 64 elements for 8x8 input
)(
    input clk,
    
    // Port A: Write
    input wea,
    input [ADDR_WIDTH-1:0] addra,
    input [DATA_WIDTH-1:0] dina,
    
    // Port B: Read
    input enb,
    input [ADDR_WIDTH-1:0] addrb,
    output reg [DATA_WIDTH-1:0] doutb
);

    // RAM array
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

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
