`timescale 1ns / 1ps

module cnn_controller (
    input wire clk,
    input wire rst_n,
    
    // From Register Interface
    input wire start,
    
    // Outputs to datapath
    output reg load_window,
    output reg enable_mac,
    output reg write_output,
    output reg next_pixel,
    
    // Output to interface
    output reg done,
    
    // External counters/conditions
    input wire mac_done,
    input wire image_done
);

    // FSM States
    localparam IDLE           = 3'd0;
    localparam LOAD_WINDOW    = 3'd1;
    localparam MULTIPLY       = 3'd2;
    localparam ACCUMULATE     = 3'd3;
    localparam WRITE_OUTPUT   = 3'd4;
    localparam NEXT_PIXEL     = 3'd5;
    localparam DONE_STATE     = 3'd6;
    
    reg [2:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        load_window = 0;
        enable_mac = 0;
        write_output = 0;
        next_pixel = 0;
        done = 0;
        
        case(state)
            IDLE: begin
                if (start) next_state = LOAD_WINDOW;
            end
            LOAD_WINDOW: begin
                load_window = 1;
                next_state = MULTIPLY;
            end
            MULTIPLY: begin
                enable_mac = 1;
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                enable_mac = 1;
                if (mac_done) next_state = WRITE_OUTPUT;
                else next_state = MULTIPLY; // Assuming multi-cycle wait
            end
            WRITE_OUTPUT: begin
                write_output = 1;
                next_state = NEXT_PIXEL;
            end
            NEXT_PIXEL: begin
                next_pixel = 1;
                if (image_done) next_state = DONE_STATE;
                else next_state = LOAD_WINDOW;
            end
            DONE_STATE: begin
                done = 1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
