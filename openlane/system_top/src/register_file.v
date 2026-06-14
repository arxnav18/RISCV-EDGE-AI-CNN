//============================================================================
// Module: Register File
// Description: 32x32-bit RISC-V register file.
//              - 2 combinational read ports (rs1, rs2)
//              - 1 synchronous write port (rd)
//              - Register x0 is hardwired to zero
//============================================================================

module register_file (
    input  wire        clk,
    input  wire        reset,
    // Read ports
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    // Write port
    input  wire        wr_en,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];

    integer i;

    // Initialize all registers to zero
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (wr_en && (rd_addr != 5'd0)) begin
            // Write on positive clock edge; x0 is never written
            registers[rd_addr] <= rd_data;
        end
    end

    // Combinational reads with write-first (write-through) behavior
    // If the register being read is the same being written this cycle,
    // forward the write data directly (solves WB→ID same-cycle hazard)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 :
                      (wr_en && (rd_addr == rs1_addr)) ? rd_data :
                      registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 :
                      (wr_en && (rd_addr == rs2_addr)) ? rd_data :
                      registers[rs2_addr];

endmodule
