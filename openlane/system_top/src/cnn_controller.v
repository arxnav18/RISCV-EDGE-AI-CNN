`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Multi-Layer CNN Controller FSM
//
// Sequences the full LeNet-5 inference pipeline:
//   DMA_LOAD → CONV_LAYER1 → CONV_LAYER2 → FC_LAYER → DONE
//
// Each stage waits for its respective `done` signal before advancing.
// The RISC-V core triggers the entire pipeline with a single START pulse.
// -----------------------------------------------------------------------------

module cnn_controller (
    input wire clk,
    input wire rst_n,

    // From Register Interface
    input wire start,

    // DMA control
    output reg dma_start,
    input  wire dma_done,

    // Layer 1 control
    output reg l1_start,
    input  wire l1_done,

    // Layer 2 control
    output reg l2_start,
    input  wire l2_done,

    // FC layer control
    output reg fc_start,
    input  wire fc_done,

    // Legacy single-layer outputs (directly usable by conv3d_accelerator)
    output reg load_window,
    output reg enable_mac,
    output reg write_output,
    output reg next_pixel,

    // Overall done
    output reg done,

    // Legacy inputs (kept for backward compatibility)
    input wire mac_done,
    input wire image_done
);

    // FSM States
    localparam IDLE           = 4'd0;
    localparam DMA_LOAD       = 4'd1;
    localparam CONV1_RUN      = 4'd2;
    localparam CONV1_WAIT     = 4'd3;
    localparam CONV2_RUN      = 4'd4;
    localparam CONV2_WAIT     = 4'd5;
    localparam FC_RUN         = 4'd6;
    localparam FC_WAIT        = 4'd7;
    localparam DONE_STATE     = 4'd8;
    // Legacy single-layer states (for backward compatibility)
    localparam LEGACY_LOAD    = 4'd9;
    localparam LEGACY_MULT    = 4'd10;
    localparam LEGACY_ACC     = 4'd11;
    localparam LEGACY_WRITE   = 4'd12;
    localparam LEGACY_NEXT    = 4'd13;

    reg [3:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state   = state;
        dma_start    = 0;
        l1_start     = 0;
        l2_start     = 0;
        fc_start     = 0;
        load_window  = 0;
        enable_mac   = 0;
        write_output = 0;
        next_pixel   = 0;
        done         = 0;

        case (state)
            IDLE: begin
                if (start) next_state = DMA_LOAD;
            end

            // ---- Multi-Layer Pipeline ----
            DMA_LOAD: begin
                dma_start = 1;
                next_state = CONV1_RUN;
            end

            CONV1_RUN: begin
                l1_start = 1;
                next_state = CONV1_WAIT;
            end
            CONV1_WAIT: begin
                if (l1_done) next_state = CONV2_RUN;
            end

            CONV2_RUN: begin
                l2_start = 1;
                next_state = CONV2_WAIT;
            end
            CONV2_WAIT: begin
                if (l2_done) next_state = FC_RUN;
            end

            FC_RUN: begin
                fc_start = 1;
                next_state = FC_WAIT;
            end
            FC_WAIT: begin
                if (fc_done) next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1;
                next_state = IDLE;
            end

            // ---- Legacy Single-Layer States (backward compat) ----
            LEGACY_LOAD: begin
                load_window = 1;
                next_state = LEGACY_MULT;
            end
            LEGACY_MULT: begin
                enable_mac = 1;
                next_state = LEGACY_ACC;
            end
            LEGACY_ACC: begin
                enable_mac = 1;
                if (mac_done) next_state = LEGACY_WRITE;
                else next_state = LEGACY_MULT;
            end
            LEGACY_WRITE: begin
                write_output = 1;
                next_state = LEGACY_NEXT;
            end
            LEGACY_NEXT: begin
                next_pixel = 1;
                if (image_done) next_state = DONE_STATE;
                else next_state = LEGACY_LOAD;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
