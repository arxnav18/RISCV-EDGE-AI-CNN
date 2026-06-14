`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Integrated Clock Gating Cell (ICG)
//
// Provides layer-level clock gating to reduce dynamic power consumption
// when CNN layers are idle. The gated clock is only active when the
// corresponding layer's `enable` signal is asserted.
//
// This module implements a latch-based ICG that is:
//   - Glitch-free (negative-latch + AND gate)
//   - Standard cell library compatible (synthesis tools recognize this pattern)
//   - Safe for ASIC and FPGA implementations
// -----------------------------------------------------------------------------

module clock_gate (
    input  wire clk_in,     // Free-running system clock
    input  wire enable,     // Layer enable signal (from controller)
    input  wire test_mode,  // Bypass gating during scan test
    output wire clk_out     // Gated clock to the layer
);

    reg en_latched;

    // Negative-edge transparent latch (captures enable on falling edge)
    // This prevents glitches on the gated clock
    always @(*) begin
        if (!clk_in)
            en_latched = enable | test_mode;
    end

    // AND gate: gated clock
    assign clk_out = clk_in & en_latched;

endmodule
