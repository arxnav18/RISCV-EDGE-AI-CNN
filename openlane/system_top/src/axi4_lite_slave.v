`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// AXI4-Lite Slave Interface — Universal Control Wrapper
//
// Converts standard AXI4-Lite bus transactions into the internal simple bus
// used by the CNN Register Interface. This makes the IP core compatible
// with any standard SoC interconnect (Interconnect, SmartConnect, NoC).
// -----------------------------------------------------------------------------

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    S_AXI_ACLK,
    input  wire                    S_AXI_ARESETN,

    // ---- AXI4-Lite Slave Interface ----
    input  wire [ADDR_WIDTH-1:0]   S_AXI_AWADDR,
    input  wire [2:0]              S_AXI_AWPROT,
    input  wire                    S_AXI_AWVALID,
    output reg                     S_AXI_AWREADY,

    input  wire [DATA_WIDTH-1:0]   S_AXI_WDATA,
    input  wire [3:0]              S_AXI_WSTRB,
    input  wire                    S_AXI_WVALID,
    output reg                     S_AXI_WREADY,

    output reg  [1:0]              S_AXI_BRESP,
    output reg                     S_AXI_BVALID,
    input  wire                    S_AXI_BREADY,

    input  wire [ADDR_WIDTH-1:0]   S_AXI_ARADDR,
    input  wire [2:0]              S_AXI_ARPROT,
    input  wire                    S_AXI_ARVALID,
    output reg                     S_AXI_ARREADY,

    output reg  [DATA_WIDTH-1:0]   S_AXI_RDATA,
    output reg  [1:0]              S_AXI_RRESP,
    output reg                     S_AXI_RVALID,
    input  wire                    S_AXI_RREADY,

    // ---- Internal Simple Bus Interface ----
    output reg                     bus_we,
    output reg                     bus_ren,
    output reg  [ADDR_WIDTH-1:0]   bus_addr,
    output reg  [DATA_WIDTH-1:0]   bus_din,
    input  wire [DATA_WIDTH-1:0]   bus_dout,
    input  wire                    bus_ready
);

    // Write Channel Logic
    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg aw_en;

    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            aw_en         <= 1'b1;
            bus_we        <= 1'b0;
        end else begin
            // Address Ready
            if (!S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                S_AXI_AWREADY <= 1'b1;
                awaddr_reg    <= S_AXI_AWADDR;
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // Data Ready
            if (!S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                S_AXI_WREADY <= 1'b1;
                wdata_reg    <= S_AXI_WDATA;
            end else begin
                S_AXI_WREADY <= 1'b0;
            end

            // Trigger Internal Write
            if (S_AXI_AWREADY && S_AXI_WREADY) begin
                bus_we   <= 1'b1;
                bus_addr <= awaddr_reg;
                bus_din  <= wdata_reg;
                aw_en    <= 1'b0;
            end else begin
                bus_we   <= 1'b0;
            end

            // Respond
            if (bus_we) begin // Simplified: assume internal bus is 1-cycle for now or wait for ready
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b0;
                aw_en        <= 1'b1;
            end
        end
    end

    // Read Channel Logic
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00;
            bus_ren       <= 1'b0;
        end else begin
            if (!S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;
                bus_addr      <= S_AXI_ARADDR;
                bus_ren       <= 1'b1;
            end else begin
                S_AXI_ARREADY <= 1'b0;
                bus_ren       <= 1'b0;
            end

            if (S_AXI_ARREADY) begin
                // Latch internal response
                S_AXI_RDATA  <= bus_dout;
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= 2'b00;
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    // Unused warnings
    wire _unused = &{1'b0, S_AXI_AWPROT, S_AXI_ARPROT, S_AXI_WSTRB, bus_ready, 1'b0};

endmodule
