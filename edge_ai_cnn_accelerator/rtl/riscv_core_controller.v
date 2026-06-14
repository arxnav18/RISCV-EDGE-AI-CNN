`timescale 1ns / 1ps

module riscv_core_controller (
    input wire clk,
    input wire rst_n,
    
    // Simple Memory-mapped IO bus to configure CNN
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg mem_wen,
    output reg mem_ren,
    input wire [31:0] mem_rdata,
    input wire mem_ready
);

    // This module acts as a simplified RISC-V executing a predefined sequence
    // simulating firmware loading weights, configuring, and starting CNN.
    
    reg [3:0] state;
    
    localparam INIT_MEM  = 4'd0;
    localparam CONF_W    = 4'd1;
    localparam CONF_H    = 4'd2;
    localparam CONF_C    = 4'd3;
    localparam START     = 4'd4;
    localparam POLL      = 4'd5;
    localparam FINISH    = 4'd6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= INIT_MEM;
            mem_addr <= 0;
            mem_wdata <= 0;
            mem_wen <= 0;
            mem_ren <= 0;
        end else begin
            mem_wen <= 0;
            mem_ren <= 0;
            case (state)
                INIT_MEM: begin
                    // Firmware delay/init
                    state <= CONF_W;
                end
                CONF_W: begin
                    mem_addr <= 32'h10;
                    mem_wdata <= 32'h08; // width 8
                    mem_wen <= 1;
                    if (mem_ready) state <= CONF_H;
                end
                CONF_H: begin
                    mem_addr <= 32'h14;
                    mem_wdata <= 32'h08; // height 8
                    mem_wen <= 1;
                    if (mem_ready) state <= CONF_C;
                end
                CONF_C: begin
                    mem_addr <= 32'h18;
                    mem_wdata <= 32'h03; // channels 3
                    mem_wen <= 1;
                    if (mem_ready) state <= START;
                end
                START: begin
                    mem_addr <= 32'h00;
                    mem_wdata <= 32'h01; // START conv1
                    mem_wen <= 1;
                    if (mem_ready) state <= POLL;
                end
                POLL: begin
                    mem_addr <= 32'h00;
                    mem_ren <= 1;
                    if (mem_ready) begin
                        if (mem_rdata[1] == 1'b1) // DONE bit set
                            state <= FINISH;
                    end
                end
                FINISH: begin
                    // Execution done
                end
                default: begin
                    state <= INIT_MEM;
                end
            endcase
        end
    end

    // Suppress unused-signal warnings for mem_rdata bits not checked
    wire _unused = &{1'b0, mem_rdata[31:2], mem_rdata[0], 1'b0};

endmodule
