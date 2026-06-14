//============================================================================
// Module: RISC-V Core Top (riscv_core_top)
// Description: Top-level integration of the 5-stage pipelined RV32I processor
//              with convolution accelerator, AXI DMA Master, and AXI-Lite Slave.
//
// Features:
//   - AXI4 Master interface for high-speed DDR access
//   - AXI4-Lite Slave interface for configuration/control
//============================================================================

module riscv_core_top (
    input  wire        clk,
    input  wire        reset,

    // ---- AXI4-Lite Slave Interface (Control) ----
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,
    input  wire [31:0] S_AXI_WDATA,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input  wire        S_AXI_BREADY,
    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input  wire        S_AXI_RREADY,

    // ---- AXI4 Master Interface (Data) ----
    output wire [31:0] M_AXI_AWADDR,
    output wire [7:0]  M_AXI_AWLEN,
    output wire [2:0]  M_AXI_AWSIZE,
    output wire [1:0]  M_AXI_AWBURST,
    output wire        M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,
    output wire        M_AXI_WLAST,
    output wire        M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output wire        M_AXI_BREADY,
    output wire [31:0] M_AXI_ARADDR,
    output wire [7:0]  M_AXI_ARLEN,
    output wire [2:0]  M_AXI_ARSIZE,
    output wire [1:0]  M_AXI_ARBURST,
    output wire        M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RLAST,
    input  wire        M_AXI_RVALID,
    output wire        M_AXI_RREADY,

    output wire        system_done
);

    // [CPU Pipeline logic remains unchanged...]
    // The CPU can still access its own internal memories.
    // The CNN accelerator is now exposed via the top-level AXI ports.

    // CNN Integration
    edge_ai_cnn_peripheral u_cnn_accel (
        .clk      (clk),
        .rst_n    (~reset),
        
        // Connect to Top-Level AXI-Lite Slave
        .S_AXI_AWADDR (S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID),.S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),  .S_AXI_WVALID (S_AXI_WVALID), .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),  .S_AXI_BVALID (S_AXI_BVALID), .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR), .S_AXI_ARVALID(S_AXI_ARVALID),.S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),  .S_AXI_RRESP  (S_AXI_RRESP),  .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY),
        
        // Connect to Top-Level AXI Master
        .M_AXI_AWADDR (M_AXI_AWADDR), .M_AXI_AWLEN  (M_AXI_AWLEN),  .M_AXI_AWSIZE (M_AXI_AWSIZE), 
        .M_AXI_AWBURST(M_AXI_AWBURST),.M_AXI_AWVALID(M_AXI_AWVALID),.M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),  .M_AXI_WSTRB  (M_AXI_WSTRB),  .M_AXI_WLAST  (M_AXI_WLAST),
        .M_AXI_WVALID (M_AXI_WVALID), .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),  .M_AXI_BVALID (M_AXI_BVALID), .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR), .M_AXI_ARLEN  (M_AXI_ARLEN),  .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),.M_AXI_ARVALID(M_AXI_ARVALID),.M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),  .M_AXI_RRESP  (M_AXI_RRESP),  .M_AXI_RLAST  (M_AXI_RLAST),
        .M_AXI_RVALID (M_AXI_RVALID), .M_AXI_RREADY (M_AXI_RREADY),
        
        .cnn_done (system_done)
    );

      // =========================================================================
    // RISC-V 5-Stage Pipeline Integration
    // =========================================================================

    // --- Pipeline Control & Hazards ---
    wire stall = 1'b0; // To be implemented if stalls needed
    wire flush = 1'b0; // To be implemented for control hazards
    
    // --- IF Stage ---
    (* keep = "true" *) wire [31:0] pc_if;
    (* keep = "true" *) wire [31:0] instr_if;

    pc u_pc (
        .clk    (clk),
        .reset  (reset),
        .stall  (stall),
        .pc_out (pc_if)
    );

    instruction_memory u_imem (
        .addr        (pc_if),
        .instruction (instr_if)
    );

    // --- IF/ID Pipeline Register ---
    (* keep = "true" *) wire [31:0] pc_id;
    (* keep = "true" *) wire [31:0] instr_id;

    pipeline_register_if_id u_pipe_if_id (
        .clk             (clk),
        .reset           (reset),
        .stall           (stall),
        .flush           (flush),
        .pc_in           (pc_if),
        .instruction_in  (instr_if),
        .pc_out          (pc_id),
        .instruction_out (instr_id)
    );

    // --- ID Stage ---
    // Decode Instruction Fields
    (* keep = "true" *) wire [6:0]  opcode = instr_id[6:0];
    (* keep = "true" *) wire [4:0]  rd     = instr_id[11:7];
    (* keep = "true" *) wire [2:0]  funct3 = instr_id[14:12];
    (* keep = "true" *) wire [4:0]  rs1    = instr_id[19:15];
    (* keep = "true" *) wire [4:0]  rs2    = instr_id[24:20];
    (* keep = "true" *) wire [6:0]  funct7 = instr_id[31:25];

    // Immediate extraction (I-type default for simplicity in integration)
    (* keep = "true" *) wire [31:0] imm_id = {{20{instr_id[31]}}, instr_id[31:20]};

    // Control Unit Output Wires
    (* keep = "true" *) wire       ctrl_reg_write_id;
    (* keep = "true" *) wire       ctrl_alu_src_id;
    (* keep = "true" *) wire [3:0] ctrl_alu_ctrl_id;
    (* keep = "true" *) wire       ctrl_mem_read_id;
    (* keep = "true" *) wire       ctrl_mem_write_id;
    (* keep = "true" *) wire [1:0] ctrl_mem_to_reg_id;

    control_unit u_ctrl (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .reg_write  (ctrl_reg_write_id),
        .alu_src    (ctrl_alu_src_id),
        .alu_ctrl   (ctrl_alu_ctrl_id),
        .mem_read   (ctrl_mem_read_id),
        .mem_write  (ctrl_mem_write_id),
        .mem_to_reg (ctrl_mem_to_reg_id)
    );

    // Register File Output Wires
    (* keep = "true" *) wire [31:0] rs1_data_id;
    (* keep = "true" *) wire [31:0] rs2_data_id;
    
    // Writeback wires (from WB stage)
    (* keep = "true" *) wire        wb_reg_write;
    (* keep = "true" *) wire [4:0]  wb_rd_addr;
    (* keep = "true" *) wire [31:0] wb_rd_data;

    register_file u_regfile (
        .clk      (clk),
        .reset    (reset),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rs1_data (rs1_data_id),
        .rs2_data (rs2_data_id),
        .wr_en    (wb_reg_write),
        .rd_addr  (wb_rd_addr),
        .rd_data  (wb_rd_data)
    );

    // --- ID/EX Pipeline Register ---
    (* keep = "true" *) wire        ctrl_reg_write_ex;
    (* keep = "true" *) wire        ctrl_alu_src_ex;
    (* keep = "true" *) wire [3:0]  ctrl_alu_ctrl_ex;
    (* keep = "true" *) wire        ctrl_mem_read_ex;
    (* keep = "true" *) wire        ctrl_mem_write_ex;
    (* keep = "true" *) wire [1:0]  ctrl_mem_to_reg_ex;

    (* keep = "true" *) wire [31:0] pc_ex;
    (* keep = "true" *) wire [31:0] rs1_data_ex;
    (* keep = "true" *) wire [31:0] rs2_data_ex;
    (* keep = "true" *) wire [31:0] imm_ex;
    (* keep = "true" *) wire [4:0]  rd_addr_ex;
    (* keep = "true" *) wire [4:0]  rs1_addr_ex;
    (* keep = "true" *) wire [4:0]  rs2_addr_ex;

    pipeline_register_id_ex u_pipe_id_ex (
        .clk            (clk),
        .reset          (reset),
        .stall          (stall),
        .flush          (flush),
        
        .reg_write_in   (ctrl_reg_write_id),
        .alu_src_in     (ctrl_alu_src_id),
        .alu_ctrl_in    (ctrl_alu_ctrl_id),
        .mem_read_in    (ctrl_mem_read_id),
        .mem_write_in   (ctrl_mem_write_id),
        .mem_to_reg_in  (ctrl_mem_to_reg_id),
        
        .pc_in          (pc_id),
        .rs1_data_in    (rs1_data_id),
        .rs2_data_in    (rs2_data_id),
        .immediate_in   (imm_id),
        .rd_addr_in     (rd),
        .rs1_addr_in    (rs1),
        .rs2_addr_in    (rs2),

        .reg_write_out  (ctrl_reg_write_ex),
        .alu_src_out    (ctrl_alu_src_ex),
        .alu_ctrl_out   (ctrl_alu_ctrl_ex),
        .mem_read_out   (ctrl_mem_read_ex),
        .mem_write_out  (ctrl_mem_write_ex),
        .mem_to_reg_out (ctrl_mem_to_reg_ex),

        .pc_out         (pc_ex),
        .rs1_data_out   (rs1_data_ex),
        .rs2_data_out   (rs2_data_ex),
        .immediate_out  (imm_ex),
        .rd_addr_out    (rd_addr_ex),
        .rs1_addr_out   (rs1_addr_ex),
        .rs2_addr_out   (rs2_addr_ex)
    );

    // --- EX Stage ---
    (* keep = "true" *) wire [31:0] alu_operand_a = rs1_data_ex; // Assuming no forwarding for now
    (* keep = "true" *) wire [31:0] alu_operand_b = ctrl_alu_src_ex ? imm_ex : rs2_data_ex;
    (* keep = "true" *) wire [31:0] alu_result_ex;
    (* keep = "true" *) wire        alu_zero_ex;
    alu u_alu (
        .operand_a  (alu_operand_a),
        .operand_b  (alu_operand_b),
        .alu_ctrl   (ctrl_alu_ctrl_ex),
        .alu_result (alu_result_ex),
        .zero_flag  (alu_zero_ex)
    );

    // --- EX/MEM Pipeline Register ---
    (* keep = "true" *) wire        ctrl_reg_write_mem;
    (* keep = "true" *) wire        ctrl_mem_read_mem;
    (* keep = "true" *) wire        ctrl_mem_write_mem;
    (* keep = "true" *) wire [1:0]  ctrl_mem_to_reg_mem;

    (* keep = "true" *) wire [31:0] alu_result_mem;
    (* keep = "true" *) wire [31:0] rs2_data_mem;
    (* keep = "true" *) wire [4:0]  rd_addr_mem;

    pipeline_register_ex_mem u_pipe_ex_mem (
        .clk            (clk),
        .reset          (reset),
        .stall          (stall),

        .reg_write_in   (ctrl_reg_write_ex),
        .mem_read_in    (ctrl_mem_read_ex),
        .mem_write_in   (ctrl_mem_write_ex),
        .mem_to_reg_in  (ctrl_mem_to_reg_ex),

        .alu_result_in  (alu_result_ex),
        .rs2_data_in    (rs2_data_ex),
        .rd_addr_in     (rd_addr_ex),

        .reg_write_out  (ctrl_reg_write_mem),
        .mem_read_out   (ctrl_mem_read_mem),
        .mem_write_out  (ctrl_mem_write_mem),
        .mem_to_reg_out (ctrl_mem_to_reg_mem),

        .alu_result_out (alu_result_mem),
        .rs2_data_out   (rs2_data_mem),
        .rd_addr_out    (rd_addr_mem)
    );

    // --- MEM Stage ---
    // Memory interface not completely defined in files, mapping to dummy signals for now
    // In a real SoC, this would connect to a Data cache or AXI Master.
    (* keep = "true" *) wire [31:0] mem_read_data = 32'd0; 

    // --- MEM/WB Pipeline Register ---
    (* keep = "true" *) wire [1:0]  ctrl_mem_to_reg_wb;
    (* keep = "true" *) wire [31:0] mem_data_wb;
    (* keep = "true" *) wire [31:0] alu_result_wb;

    pipeline_register_mem_wb u_pipe_mem_wb (
        .clk            (clk),
        .reset          (reset),

        .reg_write_in   (ctrl_reg_write_mem),
        .mem_to_reg_in  (ctrl_mem_to_reg_mem),
        
        .mem_data_in    (mem_read_data),
        .alu_result_in  (alu_result_mem),
        .rd_addr_in     (rd_addr_mem),

        .reg_write_out  (wb_reg_write),
        .mem_to_reg_out (ctrl_mem_to_reg_wb),

        .mem_data_out   (mem_data_wb),
        .alu_result_out (alu_result_wb),
        .rd_addr_out    (wb_rd_addr)
    );

    // --- WB Stage ---
    assign wb_rd_data = (ctrl_mem_to_reg_wb == 2'b01) ? mem_data_wb : alu_result_wb;

endmodule
