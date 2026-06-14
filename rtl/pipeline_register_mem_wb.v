//============================================================================
// Module: Pipeline Register MEM/WB
// Description: Latches memory read data, ALU result, accelerator result,
//              and destination register from the Memory Access stage to
//              the Write Back stage.
//============================================================================

module pipeline_register_mem_wb (
    input  wire        clk,
    input  wire        reset,
    // Control signals in
    input  wire        reg_write_in,
    input  wire [1:0]  mem_to_reg_in,
    // Data in
    input  wire [31:0] mem_data_in,     // Data read from memory
    input  wire [31:0] alu_result_in,   // ALU result pass-through
    input  wire [4:0]  rd_addr_in,
    // Control signals out
    output reg         reg_write_out,
    output reg  [1:0]  mem_to_reg_out,
    // Data out
    output reg  [31:0] mem_data_out,
    output reg  [31:0] alu_result_out,
    output reg  [4:0]  rd_addr_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_out    <= 1'b0;
            mem_to_reg_out   <= 2'b00;
            mem_data_out     <= 32'd0;
            alu_result_out   <= 32'd0;
            rd_addr_out      <= 5'd0;
        end else begin
            reg_write_out    <= reg_write_in;
            mem_to_reg_out   <= mem_to_reg_in;
            mem_data_out     <= mem_data_in;
            alu_result_out   <= alu_result_in;
            rd_addr_out      <= rd_addr_in;
        end
    end

endmodule
