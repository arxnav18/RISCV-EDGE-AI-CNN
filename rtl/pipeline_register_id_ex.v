//============================================================================
// Module: Pipeline Register ID/EX
// Description: Latches decoded control signals, register read data,
//              immediate value, destination register, and function fields
//              from the Decode stage to the Execute stage.
//============================================================================

module pipeline_register_id_ex (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,       // Hold values during stall
    input  wire        flush,       // Insert bubble on hazard
    // Control signals in
    input  wire        reg_write_in,
    input  wire        alu_src_in,
    input  wire [3:0]  alu_ctrl_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire [1:0]  mem_to_reg_in,
    // Data in
    input  wire [31:0] pc_in,
    input  wire [31:0] rs1_data_in,
    input  wire [31:0] rs2_data_in,
    input  wire [31:0] immediate_in,
    input  wire [4:0]  rd_addr_in,
    input  wire [4:0]  rs1_addr_in,
    input  wire [4:0]  rs2_addr_in,
    // Control signals out
    output reg         reg_write_out,
    output reg         alu_src_out,
    output reg  [3:0]  alu_ctrl_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg  [1:0]  mem_to_reg_out,
    // Data out
    output reg  [31:0] pc_out,
    output reg  [31:0] rs1_data_out,
    output reg  [31:0] rs2_data_out,
    output reg  [31:0] immediate_out,
    output reg  [4:0]  rd_addr_out,
    output reg  [4:0]  rs1_addr_out,
    output reg  [4:0]  rs2_addr_out
);

    always @(posedge clk or posedge reset) begin
        if (reset)  begin
            // Insert NOP bubble
            reg_write_out   <= 1'b0;
            alu_src_out     <= 1'b0;
            alu_ctrl_out    <= 4'b0000;
            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            mem_to_reg_out  <= 2'b00;
            pc_out          <= 32'd0;
            rs1_data_out    <= 32'd0;
            rs2_data_out    <= 32'd0;
            immediate_out   <= 32'd0;
            rd_addr_out     <= 5'd0;
            rs1_addr_out    <= 5'd0;
            rs2_addr_out    <= 5'd0;
        end else if (reset)  begin
            // Insert NOP bubble
            reg_write_out   <= 1'b0;
            alu_src_out     <= 1'b0;
            alu_ctrl_out    <= 4'b0000;
            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            mem_to_reg_out  <= 2'b00;
            pc_out          <= 32'd0;
            rs1_data_out    <= 32'd0;
            rs2_data_out    <= 32'd0;
            immediate_out   <= 32'd0;
            rd_addr_out     <= 5'd0;
            rs1_addr_out    <= 5'd0;
            rs2_addr_out    <= 5'd0;
        end else if (!stall) begin
            reg_write_out   <= reg_write_in;
            alu_src_out     <= alu_src_in;
            alu_ctrl_out    <= alu_ctrl_in;
            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;
            mem_to_reg_out  <= mem_to_reg_in;
            pc_out          <= pc_in;
            rs1_data_out    <= rs1_data_in;
            rs2_data_out    <= rs2_data_in;
            immediate_out   <= immediate_in;
            rd_addr_out     <= rd_addr_in;
            rs1_addr_out    <= rs1_addr_in;
            rs2_addr_out    <= rs2_addr_in;
        end
    end

endmodule
