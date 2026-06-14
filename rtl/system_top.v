`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// UNIVERSAL SYSTEM WRAPPER — ASIC / FPGA Production Top
//
// This module provides a dual-interface standard for modern SoC integration:
//   1. AXI4 Master (M_AXI): For high-bandwidth DDR data transfers.
//   2. AXI4-Lite Slave (S_AXI): For register configuration and CPU control.
//
// Compatible with:
//   - Xilinx AXI Interconnect / SmartConnect
//   - Intel Qsys / Platform Designer
//   - OpenLane / Sky130 ASIC flows
//   - ARM/RISC-V/MIPS based SoCs
// -----------------------------------------------------------------------------

module system_top (
    input  wire clk,
    input  wire reset,
    output wire done
);

    // ---- Internal AXI4-Lite Slave (Control) ----
    wire [31:0] S_AXI_AWADDR;
    wire        S_AXI_AWVALID;
    wire        S_AXI_AWREADY;
    wire [31:0] S_AXI_WDATA;
    wire        S_AXI_WVALID;
    wire        S_AXI_WREADY;
    wire [1:0]  S_AXI_BRESP;
    wire        S_AXI_BVALID;
    wire        S_AXI_BREADY;
    wire [31:0] S_AXI_ARADDR;
    wire        S_AXI_ARVALID;
    wire        S_AXI_ARREADY;
    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_RVALID;
    wire        S_AXI_RREADY;

    // ---- Internal AXI4 Master (Data) ----
    wire [31:0] M_AXI_AWADDR;
    wire [7:0]  M_AXI_AWLEN;
    wire [2:0]  M_AXI_AWSIZE;
    wire [1:0]  M_AXI_AWBURST;
    wire        M_AXI_AWVALID;
    wire        M_AXI_AWREADY;
    wire [31:0] M_AXI_WDATA;
    wire [3:0]  M_AXI_WSTRB;
    wire        M_AXI_WLAST;
    wire        M_AXI_WVALID;
    wire        M_AXI_WREADY;
    wire [1:0]  M_AXI_BRESP;
    wire        M_AXI_BVALID;
    wire        M_AXI_BREADY;
    wire [31:0] M_AXI_ARADDR;
    wire [7:0]  M_AXI_ARLEN;
    wire [2:0]  M_AXI_ARSIZE;
    wire [1:0]  M_AXI_ARBURST;
    wire        M_AXI_ARVALID;
    wire        M_AXI_ARREADY;
    wire [31:0] M_AXI_RDATA;
    wire [1:0]  M_AXI_RRESP;
    wire        M_AXI_RLAST;
    wire        M_AXI_RVALID;
    wire        M_AXI_RREADY;

    // Invert the active-low external reset (e.g., from Nexys A7 button)
    // to create an active-high internal reset for the RISC-V core.
    wire sys_reset = ~reset;

    riscv_core_top u_riscv_core (
        .clk         (clk),
        .reset       (sys_reset),
        
        // Control Bus (AXI-Lite Slave)
        .S_AXI_AWADDR (S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID),.S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),  .S_AXI_WVALID (S_AXI_WVALID), .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),  .S_AXI_BVALID (S_AXI_BVALID), .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID),.S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),  .S_AXI_RRESP  (S_AXI_RRESP),  .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY),
        
        // Data Bus (AXI4 Master)
        .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN  (M_AXI_AWLEN),  .M_AXI_AWSIZE (M_AXI_AWSIZE), 
        .M_AXI_AWBURST(M_AXI_AWBURST),.M_AXI_AWVALID(M_AXI_AWVALID),.M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),  .M_AXI_WSTRB  (M_AXI_WSTRB),  .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),  .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN  (M_AXI_ARLEN),  .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),.M_AXI_ARVALID(M_AXI_ARVALID),.M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),  .M_AXI_RRESP  (M_AXI_RRESP),  .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY),
        
        .system_done (done)
    );

endmodule
