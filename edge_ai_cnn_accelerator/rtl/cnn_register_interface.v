`timescale 1ns / 1ps

module cnn_register_interface (
    input wire clk,
    input wire rst_n,
    
    // Simple Memory-Mapped Interface from RISC-V
    input wire [31:0] addr,
    input wire [31:0] wdata,
    input wire wen,
    input wire ren,
    output reg [31:0] rdata,
    output reg ready,
    
    // CNN configuration registers
    output reg [31:0] image_addr,
    output reg [31:0] weight_addr,
    output reg [31:0] feature_addr,
    output reg [7:0]  input_width,
    output reg [7:0]  input_height,
    output reg [7:0]  channels,
    output reg [7:0]  kernel_size,
    output reg [7:0]  num_filters,
    output reg        start_cnn,
    
    // Status from CNN
    input wire        cnn_done
);

    // Register Map
    // 0x00 : STATUS/CONTROL [0] START, [1] DONE
    // 0x04 : IMAGE_ADDR
    // 0x08 : WEIGHT_ADDR
    // 0x0C : FEATURE_ADDR
    // 0x10 : INPUT_WIDTH
    // 0x14 : INPUT_HEIGHT
    // 0x18 : CHANNELS
    // 0x1C : KERNEL_SIZE
    // 0x20 : NUM_FILTERS

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            image_addr <= 0;
            weight_addr <= 0;
            feature_addr <= 0;
            input_width <= 0;
            input_height <= 0;
            channels <= 0;
            kernel_size <= 0;
            num_filters <= 0;
            start_cnn <= 0;
            rdata <= 0;
            ready <= 0;
        end else begin
            ready <= 1'b0;
            start_cnn <= 1'b0; // Pulse start
            
            if (wen) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: start_cnn <= wdata[0];
                    8'h04: image_addr <= wdata;
                    8'h08: weight_addr <= wdata;
                    8'h0C: feature_addr <= wdata;
                    8'h10: input_width <= wdata[7:0];
                    8'h14: input_height <= wdata[7:0];
                    8'h18: channels <= wdata[7:0];
                    8'h1C: kernel_size <= wdata[7:0];
                    8'h20: num_filters <= wdata[7:0];
                    default: ; // Unmapped address — no action
                endcase
            end else if (ren) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: rdata <= {30'd0, cnn_done, 1'b0};
                    8'h04: rdata <= image_addr;
                    8'h08: rdata <= weight_addr;
                    8'h0C: rdata <= feature_addr;
                    8'h10: rdata <= {24'd0, input_width};
                    8'h14: rdata <= {24'd0, input_height};
                    8'h18: rdata <= {24'd0, channels};
                    8'h1C: rdata <= {24'd0, kernel_size};
                    8'h20: rdata <= {24'd0, num_filters};
                    default: rdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end

    // Suppress unused-signal warning for upper address bits
    wire _unused = &{1'b0, addr[31:8], 1'b0};

endmodule
