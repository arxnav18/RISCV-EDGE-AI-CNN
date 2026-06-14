`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Simple Burst DMA Controller
//
// Transfers a block of data between two memory regions without CPU intervention.
// The RISC-V core configures source address, destination address, and transfer
// length via MMIO registers, then pulses `start`. The DMA sequentially reads
// from `src` and writes to `dst` one word per clock until complete.
//
// This dramatically accelerates image loading from external memory into the
// CNN's local feature map SRAM.
// -----------------------------------------------------------------------------

module dma_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Configuration (from MMIO register interface)
    input  wire                    start,
    input  wire [ADDR_WIDTH-1:0]   src_addr,
    input  wire [ADDR_WIDTH-1:0]   dst_addr,
    input  wire [15:0]             transfer_len,  // Number of words to transfer

    // Memory Read Port (source)
    output reg  [ADDR_WIDTH-1:0]   mem_rd_addr,
    output reg                     mem_rd_en,
    input  wire [DATA_WIDTH-1:0]   mem_rd_data,

    // Memory Write Port (destination)
    output reg  [ADDR_WIDTH-1:0]   mem_wr_addr,
    output reg                     mem_wr_en,
    output reg  [DATA_WIDTH-1:0]   mem_wr_data,

    // Status
    output reg                     busy,
    output reg                     done
);

    // FSM States
    localparam IDLE  = 2'd0;
    localparam READ  = 2'd1;
    localparam WRITE = 2'd2;
    localparam FINISHED = 2'd3;

    reg [1:0]  state;
    reg [15:0] count;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [DATA_WIDTH-1:0] data_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            count       <= 0;
            rd_ptr      <= 0;
            wr_ptr      <= 0;
            data_buf    <= 0;
            mem_rd_addr <= 0;
            mem_rd_en   <= 0;
            mem_wr_addr <= 0;
            mem_wr_en   <= 0;
            mem_wr_data <= 0;
            busy        <= 0;
            done        <= 0;
        end else begin
            mem_rd_en <= 1'b0;
            mem_wr_en <= 1'b0;
            done      <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        state  <= READ;
                        rd_ptr <= src_addr;
                        wr_ptr <= dst_addr;
                        count  <= transfer_len;
                        busy   <= 1'b1;
                    end
                end

                READ: begin
                    if (count == 0) begin
                        state <= FINISHED;
                    end else begin
                        mem_rd_addr <= rd_ptr;
                        mem_rd_en   <= 1'b1;
                        state       <= WRITE;
                    end
                end

                WRITE: begin
                    // Data is available from memory after READ cycle
                    mem_wr_addr <= wr_ptr;
                    mem_wr_data <= mem_rd_data;
                    mem_wr_en   <= 1'b1;

                    rd_ptr <= rd_ptr + 1;
                    wr_ptr <= wr_ptr + 1;
                    count  <= count - 1;
                    state  <= READ;
                end

                FINISHED: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
