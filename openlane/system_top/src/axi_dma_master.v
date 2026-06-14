`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// AXI4 DMA Master — External DDR Interface
//
// Implements an AXI4 burst master that can read/write large blocks of data
// from/to external DDR memory. This connects to the main SoC interconnect
// and provides high-bandwidth data paths for:
//   - Loading large images from DDR into CNN local SRAM
//   - Writing classification results back to DDR
//
// AXI4 Burst Features:
//   - Configurable burst length (1-256 beats)
//   - INCR burst type
//   - 32-bit data bus
// -----------------------------------------------------------------------------

module axi_dma_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MAX_BURST_LEN = 16     // Max burst beats (AXI4 allows up to 256)
)(
    input  wire                    ACLK,
    input  wire                    ARESETn,

    // ---- DMA Configuration (from register interface) ----
    input  wire                    dma_start,
    input  wire                    dma_dir,        // 0=read (DDR→SRAM), 1=write (SRAM→DDR)
    input  wire [ADDR_WIDTH-1:0]   dma_ext_addr,   // External DDR address
    input  wire [15:0]             dma_length,     // Transfer length in words
    output reg                     dma_done,
    output reg                     dma_busy,

    // ---- AXI4 Write Address Channel ----
    output reg  [ADDR_WIDTH-1:0]   AWADDR,
    output reg  [7:0]              AWLEN,
    output reg  [2:0]              AWSIZE,
    output reg  [1:0]              AWBURST,
    output reg                     AWVALID,
    input  wire                    AWREADY,

    // ---- AXI4 Write Data Channel ----
    output reg  [DATA_WIDTH-1:0]   WDATA,
    output reg  [3:0]              WSTRB,
    output reg                     WLAST,
    output reg                     WVALID,
    input  wire                    WREADY,

    // ---- AXI4 Write Response Channel ----
    input  wire [1:0]              BRESP,
    input  wire                    BVALID,
    output reg                     BREADY,

    // ---- AXI4 Read Address Channel ----
    output reg  [ADDR_WIDTH-1:0]   ARADDR,
    output reg  [7:0]              ARLEN,
    output reg  [2:0]              ARSIZE,
    output reg  [1:0]              ARBURST,
    output reg                     ARVALID,
    input  wire                    ARREADY,

    // ---- AXI4 Read Data Channel ----
    input  wire [DATA_WIDTH-1:0]   RDATA,
    input  wire [1:0]              RRESP,
    input  wire                    RLAST,
    input  wire                    RVALID,
    output reg                     RREADY,

    // ---- Local SRAM Interface ----
    output reg  [15:0]             sram_addr,
    output reg  [DATA_WIDTH-1:0]   sram_wdata,
    output reg                     sram_wen,
    input  wire [DATA_WIDTH-1:0]   sram_rdata
);

    // FSM States
    localparam IDLE        = 3'd0;
    localparam RD_ADDR     = 3'd1;
    localparam RD_DATA     = 3'd2;
    localparam WR_ADDR     = 3'd3;
    localparam WR_DATA     = 3'd4;
    localparam WR_RESP     = 3'd5;
    localparam DONE_STATE  = 3'd6;

    reg [2:0]  state;
    reg [15:0] remaining;
    reg [7:0]  beat_cnt;
    reg [ADDR_WIDTH-1:0] ext_ptr;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            state     <= IDLE;
            remaining <= 0;
            beat_cnt  <= 0;
            ext_ptr   <= 0;
            sram_addr <= 0;
            sram_wdata<= 0;
            sram_wen  <= 0;
            dma_done  <= 0;
            dma_busy  <= 0;
            AWADDR    <= 0; AWLEN <= 0; AWSIZE <= 3'b010; AWBURST <= 2'b01;
            AWVALID   <= 0;
            WDATA     <= 0; WSTRB <= 4'hF; WLAST <= 0; WVALID <= 0;
            BREADY    <= 0;
            ARADDR    <= 0; ARLEN <= 0; ARSIZE <= 3'b010; ARBURST <= 2'b01;
            ARVALID   <= 0;
            RREADY    <= 0;
        end else begin
            dma_done <= 1'b0;
            sram_wen <= 1'b0;

            case (state)
                IDLE: begin
                    dma_busy <= 1'b0;
                    if (dma_start) begin
                        dma_busy  <= 1'b1;
                        remaining <= dma_length;
                        ext_ptr   <= dma_ext_addr;
                        sram_addr <= 0;
                        if (dma_dir == 1'b0)
                            state <= RD_ADDR;  // DDR → SRAM
                        else
                            state <= WR_ADDR;  // SRAM → DDR
                    end
                end

                // ---- Read from DDR, Write to SRAM ----
                RD_ADDR: begin
                    ARADDR   <= ext_ptr;
                    ARLEN    <= (remaining > MAX_BURST_LEN) ? MAX_BURST_LEN - 1 : remaining - 1;
                    ARVALID  <= 1'b1;
                    beat_cnt <= 0;
                    if (ARREADY) begin
                        ARVALID <= 1'b0;
                        RREADY  <= 1'b1;
                        state   <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (RVALID) begin
                        sram_wdata <= RDATA;
                        sram_wen   <= 1'b1;
                        sram_addr  <= sram_addr + 1;
                        ext_ptr    <= ext_ptr + 4;
                        remaining  <= remaining - 1;
                        beat_cnt   <= beat_cnt + 1;

                        if (RLAST || remaining == 1) begin
                            RREADY <= 1'b0;
                            if (remaining <= 1)
                                state <= DONE_STATE;
                            else
                                state <= RD_ADDR;
                        end
                    end
                end

                // ---- Write to DDR from SRAM ----
                WR_ADDR: begin
                    AWADDR   <= ext_ptr;
                    AWLEN    <= (remaining > MAX_BURST_LEN) ? MAX_BURST_LEN - 1 : remaining - 1;
                    AWVALID  <= 1'b1;
                    beat_cnt <= 0;
                    if (AWREADY) begin
                        AWVALID <= 1'b0;
                        state   <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    WDATA  <= sram_rdata;
                    WSTRB  <= 4'hF;
                    WVALID <= 1'b1;
                    WLAST  <= (remaining == 1) || (beat_cnt == AWLEN);

                    if (WREADY) begin
                        sram_addr <= sram_addr + 1;
                        ext_ptr   <= ext_ptr + 4;
                        remaining <= remaining - 1;
                        beat_cnt  <= beat_cnt + 1;

                        if (WLAST) begin
                            WVALID <= 1'b0;
                            BREADY <= 1'b1;
                            state  <= WR_RESP;
                        end
                    end
                end

                WR_RESP: begin
                    if (BVALID) begin
                        BREADY <= 1'b0;
                        if (remaining == 0)
                            state <= DONE_STATE;
                        else
                            state <= WR_ADDR;
                    end
                end

                DONE_STATE: begin
                    dma_done <= 1'b1;
                    dma_busy <= 1'b0;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Suppress unused warning
    wire _unused = &{1'b0, BRESP, RRESP, 1'b0};

endmodule
