`timescale 1ns / 1ps

module image_buffer #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12 // 4096 addresses
)(
    input wire clk,
    
    // Port A (Write)
    input wire ena_a,
    input wire we_a,
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] din_a,
    
    // Port B (Read)
    input wire ena_b,
    input wire [ADDR_WIDTH-1:0] addr_b,
    output reg [DATA_WIDTH-1:0] dout_b
);

    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (ena_a) begin
            if (we_a) begin
                ram[addr_a] <= din_a;
            end
        end
    end

    always @(posedge clk) begin
        if (ena_b) begin
            dout_b <= ram[addr_b];
        end
    end

endmodule
