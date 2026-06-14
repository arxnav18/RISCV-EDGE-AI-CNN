//============================================================================
// Module: Pipeline Register EX/MEM
// Description: Latches ALU result (or accelerator result), write data,
//              destination register, and control signals from the Execute
//              stage to the Memory Access stage.
//============================================================================

module pipeline_register_ex_mem (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,       // Hold values during stall
    // Control signals in
    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire [1:0]  mem_to_reg_in,
    // Data in
    input  wire [31:0] alu_result_in,
    input  wire [31:0] rs2_data_in,     // Store data for memory writes
    input  wire [4:0]  rd_addr_in,
    // Control signals out
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg  [1:0]  mem_to_reg_out,
    // Data out
    output reg  [31:0] alu_result_out,
    output reg  [31:0] rs2_data_out,
    output reg  [4:0]  rd_addr_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_out    <= 1'b0;
            mem_read_out     <= 1'b0;
            mem_write_out    <= 1'b0;
            mem_to_reg_out   <= 2'b00;
            alu_result_out   <= 32'd0;
            rs2_data_out     <= 32'd0;
            rd_addr_out      <= 5'd0;
        end else if (!stall) begin
            reg_write_out    <= reg_write_in;
            mem_read_out     <= mem_read_in;
            mem_write_out    <= mem_write_in;
            mem_to_reg_out   <= mem_to_reg_in;
            alu_result_out   <= alu_result_in;
            rs2_data_out     <= rs2_data_in;
            rd_addr_out      <= rd_addr_in;
        end
    end

endmodule
