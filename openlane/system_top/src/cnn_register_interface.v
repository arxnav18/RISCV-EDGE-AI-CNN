`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// CNN Register Interface (Memory-Mapped) — FULLY ENHANCED
//
// Extended register map supporting all 12 improvements:
//   - Layer config, DMA, FC, BN, stride, zero-padding, activation, power gating
//   - Output result readback
//
// Register Map:
//   0x00 : CONTROL          [0] START, [1] DONE, [2] DMA_BUSY
//   0x04 : IMAGE_ADDR
//   0x08 : WEIGHT_ADDR
//   0x0C : FEATURE_ADDR
//   0x10 : INPUT_WIDTH      (16-bit)
//   0x14 : INPUT_HEIGHT     (16-bit)
//   0x18 : CHANNELS         (8-bit)
//   0x1C : KERNEL_SIZE      (8-bit)
//   0x20 : NUM_FILTERS      (8-bit)
//   0x24 : DMA_SRC_ADDR
//   0x28 : DMA_DST_ADDR
//   0x2C : DMA_LENGTH
//   0x30 : DMA_START        [0] pulse
//   0x34 : L2_CHANNELS
//   0x38 : L2_NUM_FILTERS
//   0x3C : FC_NUM_INPUTS
//   0x40 : FC_NUM_OUTPUTS
//   --- New Registers ---
//   0x44 : STRIDE_CFG       [3:0] conv stride, [7:4] pool stride
//   0x48 : PAD_CFG          [7:0] zero-pad size
//   0x4C : BN_MEAN          (16-bit, signed)
//   0x50 : BN_SCALE         (16-bit, Q8.8 fixed-point)
//   0x54 : BN_OFFSET        (16-bit, signed)
//   0x58 : ACTIVATION_MODE  [1:0] 0=ReLU, 1=Sigmoid, 2=pass-through
//   0x5C : POWER_GATE_CFG   [0] L1, [1] L2, [2] FC, [3] DMA enable
//   0x60 : SKIP_ENABLE      [0] L1 skip, [1] L2 skip
//   0x64 : AXI_DMA_DIR      [0] 0=DDR→SRAM, 1=SRAM→DDR
//   0x80–0xBC : RESULT[0-15] FC output scores (read-only)
// -----------------------------------------------------------------------------

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
    output reg [15:0] input_width,
    output reg [15:0] input_height,
    output reg [7:0]  channels,
    output reg [7:0]  kernel_size,
    output reg [7:0]  num_filters,
    output reg        start_cnn,

    // DMA configuration
    output reg [31:0] dma_src_addr,
    output reg [31:0] dma_dst_addr,
    output reg [15:0] dma_length,
    output reg        dma_start,

    // Layer 2 configuration
    output reg [7:0]  l2_channels,
    output reg [7:0]  l2_num_filters,

    // FC configuration
    output reg [15:0] fc_num_inputs,
    output reg [7:0]  fc_num_outputs,

    // New: Stride, padding, BN, activation, power gating, skip
    output reg [3:0]  conv_stride,
    output reg [3:0]  pool_stride,
    output reg [7:0]  pad_size,
    output reg signed [15:0] bn_mean,
    output reg signed [15:0] bn_scale,
    output reg signed [15:0] bn_offset,
    output reg [1:0]  activation_mode,   // 0=ReLU, 1=Sigmoid, 2=pass
    output reg [3:0]  power_gate_cfg,    // per-layer clock enable
    output reg [1:0]  skip_enable,       // per-layer skip connection
    output reg        axi_dma_dir,       // 0=read, 1=write

    // Status from CNN
    input wire        cnn_done,
    input wire        dma_busy_in,

    // Result readback
    input wire [31:0] result_data,
    output reg [3:0]  result_rd_addr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            image_addr      <= 0;
            weight_addr     <= 0;
            feature_addr    <= 0;
            input_width     <= 0;
            input_height    <= 0;
            channels        <= 0;
            kernel_size     <= 3;
            num_filters     <= 0;
            start_cnn       <= 0;
            dma_src_addr    <= 0;
            dma_dst_addr    <= 0;
            dma_length      <= 0;
            dma_start       <= 0;
            l2_channels     <= 0;
            l2_num_filters  <= 0;
            fc_num_inputs   <= 0;
            fc_num_outputs  <= 0;
            conv_stride     <= 4'd1;
            pool_stride     <= 4'd1;
            pad_size        <= 0;
            bn_mean         <= 0;
            bn_scale        <= 16'h0100; // 1.0 in Q8.8
            bn_offset       <= 0;
            activation_mode <= 2'd0;     // ReLU default
            power_gate_cfg  <= 4'hF;     // All enabled
            skip_enable     <= 2'd0;     // No skip
            axi_dma_dir     <= 0;
            result_rd_addr  <= 0;
            rdata           <= 0;
            ready           <= 0;
        end else begin
            ready     <= 1'b0;
            start_cnn <= 1'b0;
            dma_start <= 1'b0;

            if (wen) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: start_cnn       <= wdata[0];
                    8'h04: image_addr      <= wdata;
                    8'h08: weight_addr     <= wdata;
                    8'h0C: feature_addr    <= wdata;
                    8'h10: input_width     <= wdata[15:0];
                    8'h14: input_height    <= wdata[15:0];
                    8'h18: channels        <= wdata[7:0];
                    8'h1C: kernel_size     <= wdata[7:0];
                    8'h20: num_filters     <= wdata[7:0];
                    8'h24: dma_src_addr    <= wdata;
                    8'h28: dma_dst_addr    <= wdata;
                    8'h2C: dma_length      <= wdata[15:0];
                    8'h30: dma_start       <= wdata[0];
                    8'h34: l2_channels     <= wdata[7:0];
                    8'h38: l2_num_filters  <= wdata[7:0];
                    8'h3C: fc_num_inputs   <= wdata[15:0];
                    8'h40: fc_num_outputs  <= wdata[7:0];
                    8'h44: begin conv_stride <= wdata[3:0]; pool_stride <= wdata[7:4]; end
                    8'h48: pad_size        <= wdata[7:0];
                    8'h4C: bn_mean         <= wdata[15:0];
                    8'h50: bn_scale        <= wdata[15:0];
                    8'h54: bn_offset       <= wdata[15:0];
                    8'h58: activation_mode <= wdata[1:0];
                    8'h5C: power_gate_cfg  <= wdata[3:0];
                    8'h60: skip_enable     <= wdata[1:0];
                    8'h64: axi_dma_dir     <= wdata[0];
                    default: ;
                endcase
            end else if (ren) begin
                ready <= 1'b1;
                case (addr[7:0])
                    8'h00: rdata <= {29'd0, dma_busy_in, cnn_done, 1'b0};
                    8'h04: rdata <= image_addr;
                    8'h08: rdata <= weight_addr;
                    8'h0C: rdata <= feature_addr;
                    8'h10: rdata <= {16'd0, input_width};
                    8'h14: rdata <= {16'd0, input_height};
                    8'h18: rdata <= {24'd0, channels};
                    8'h1C: rdata <= {24'd0, kernel_size};
                    8'h20: rdata <= {24'd0, num_filters};
                    8'h24: rdata <= dma_src_addr;
                    8'h28: rdata <= dma_dst_addr;
                    8'h2C: rdata <= {16'd0, dma_length};
                    8'h34: rdata <= {24'd0, l2_channels};
                    8'h38: rdata <= {24'd0, l2_num_filters};
                    8'h3C: rdata <= {16'd0, fc_num_inputs};
                    8'h40: rdata <= {24'd0, fc_num_outputs};
                    8'h44: rdata <= {24'd0, pool_stride, conv_stride};
                    8'h48: rdata <= {24'd0, pad_size};
                    8'h4C: rdata <= {{16{bn_mean[15]}}, bn_mean};
                    8'h50: rdata <= {{16{bn_scale[15]}}, bn_scale};
                    8'h54: rdata <= {{16{bn_offset[15]}}, bn_offset};
                    8'h58: rdata <= {30'd0, activation_mode};
                    8'h5C: rdata <= {28'd0, power_gate_cfg};
                    8'h60: rdata <= {30'd0, skip_enable};
                    8'h64: rdata <= {31'd0, axi_dma_dir};
                    // Result registers at 0x80-0xBC (16 entries × 4 bytes)
                    8'h80, 8'h84, 8'h88, 8'h8C,
                    8'h90, 8'h94, 8'h98, 8'h9C,
                    8'hA0, 8'hA4, 8'hA8, 8'hAC,
                    8'hB0, 8'hB4, 8'hB8, 8'hBC: begin
                        result_rd_addr <= addr[5:2];
                        rdata <= result_data;
                    end
                    default: rdata <= 32'hDEADBEEF;
                endcase
            end
        end
    end

    wire _unused = &{1'b0, addr[31:8], 1'b0};

endmodule
