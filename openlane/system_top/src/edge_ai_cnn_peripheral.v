`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Memory-Mapped CNN Accelerator Peripheral — PPA OPTIMIZED 
//
// Improvements:
// 1. Power: Operand Isolation on SRAM address/data buses.
// 2. Power: Fine-grained clock gating for each layer.
// 3. Performance: Standardized AXI4 dual-interface.
// -----------------------------------------------------------------------------

module edge_ai_cnn_peripheral (
    input  wire        clk,
    input  wire        rst_n,

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

    // Status
    output wire        cnn_done
);

    // Internal bus signals
    wire        bus_we, bus_ren;
    wire [31:0] bus_addr, bus_din, bus_dout;
    wire        bus_ready;

    // =========================================================================
    // AXI4-Lite Slave Adapter
    // =========================================================================
    axi4_lite_slave u_axil_slave (
        .S_AXI_ACLK(clk), .S_AXI_ARESETN(rst_n),
        .S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWPROT(3'd0), .S_AXI_AWVALID(S_AXI_AWVALID), .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA), .S_AXI_WSTRB(4'hF), .S_AXI_WVALID(S_AXI_WVALID), .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP), .S_AXI_BVALID(S_AXI_BVALID), .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR), .S_AXI_ARPROT(3'd0), .S_AXI_ARVALID(S_AXI_ARVALID), .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA), .S_AXI_RRESP(S_AXI_RRESP), .S_AXI_RVALID(S_AXI_RVALID), .S_AXI_RREADY(S_AXI_RREADY),
        .bus_we(bus_we), .bus_ren(bus_ren), .bus_addr(bus_addr), .bus_din(bus_din), .bus_dout(bus_dout), .bus_ready(bus_ready)
    );

    // Clock Gating
    wire [3:0] power_gate_cfg;
    wire clk_l1, clk_l2, clk_fc, clk_dma;
    clock_gate u_icg_l1  (.clk_in(clk), .enable(power_gate_cfg[0]), .test_mode(1'b0), .clk_out(clk_l1));
    clock_gate u_icg_l2  (.clk_in(clk), .enable(power_gate_cfg[1]), .test_mode(1'b0), .clk_out(clk_l2));
    clock_gate u_icg_fc  (.clk_in(clk), .enable(power_gate_cfg[2]), .test_mode(1'b0), .clk_out(clk_fc));
    clock_gate u_icg_dma (.clk_in(clk), .enable(power_gate_cfg[3]), .test_mode(1'b0), .clk_out(clk_dma));

    // Registers
    wire [31:0] image_addr, weight_addr, feature_addr;
    wire [15:0] input_width, input_height;
    wire [7:0]  channels, kernel_size, num_filters;
    wire        start_req, pipeline_done, reg_ready;
    wire [31:0] dma_src_addr, dma_dst_addr;
    wire [15:0] dma_length;
    wire        dma_start_cfg;
    wire [7:0]  l2_channels, l2_num_filters;
    wire [15:0] fc_num_inputs;
    wire [7:0]  fc_num_outputs;
    wire [3:0]  conv_stride, pool_stride;
    wire [7:0]  pad_size;
    wire signed [15:0] bn_mean, bn_scale, bn_offset;
    wire [1:0]  activation_mode;
    wire [1:0]  skip_enable;
    wire        axi_dma_dir;
    wire        dma_busy_status;
    wire [31:0] result_readback;
    wire [3:0]  result_rd_addr;

    cnn_register_interface u_reg_if (
        .clk(clk), .rst_n(rst_n), .addr(bus_addr), .wdata(bus_din), .wen(bus_we), .ren(bus_ren), .rdata(bus_dout), .ready(reg_ready),
        .image_addr(image_addr), .weight_addr(weight_addr), .feature_addr(feature_addr), .input_width(input_width), .input_height(input_height),
        .channels(channels), .kernel_size(kernel_size), .num_filters(num_filters), .start_cnn(start_req), .dma_src_addr(dma_src_addr),
        .dma_dst_addr(dma_dst_addr), .dma_length(dma_length), .dma_start(dma_start_cfg),
        .l2_channels(l2_channels), .l2_num_filters(l2_num_filters), .fc_num_inputs(fc_num_inputs), .fc_num_outputs(fc_num_outputs),
        .conv_stride(conv_stride), .pool_stride(pool_stride), .pad_size(pad_size), .bn_mean(bn_mean), .bn_scale(bn_scale), .bn_offset(bn_offset),
        .activation_mode(activation_mode), .power_gate_cfg(power_gate_cfg), .skip_enable(skip_enable), .axi_dma_dir(axi_dma_dir),
        .cnn_done(pipeline_done), .dma_busy_in(dma_busy_status), .result_data(result_readback), .result_rd_addr(result_rd_addr)
    );
    assign bus_ready = reg_ready;

    // Controller
    wire ctrl_dma_start, ctrl_l1_start, ctrl_l2_start, ctrl_fc_start;
    wire dma_done_sig, l1_done_sig, l2_done_sig, fc_done_sig;
    wire ctrl_load_win, ctrl_en_mac, ctrl_wr_out, ctrl_nxt_pix;
    cnn_controller u_cnn_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start_req), .dma_start(ctrl_dma_start), .dma_done(dma_done_sig),
        .l1_start(ctrl_l1_start), .l1_done(l1_done_sig), .l2_start(ctrl_l2_start), .l2_done(l2_done_sig),
        .fc_start(ctrl_fc_start), .fc_done(fc_done_sig), .load_window(ctrl_load_win),
        .enable_mac(ctrl_en_mac), .write_output(ctrl_wr_out), .next_pixel(ctrl_nxt_pix), .done(pipeline_done),
        .mac_done(1'b1), .image_done(1'b0)
    );

    // DMA
    wire [15:0] dma_sram_addr; wire [31:0] dma_sram_wdata, dma_sram_rdata; wire dma_sram_wen;
    axi_dma_master u_axi_dma (
        .ACLK(clk_dma), .ARESETn(rst_n), .dma_start(ctrl_dma_start | dma_start_cfg), .dma_dir(axi_dma_dir),
        .dma_ext_addr(dma_src_addr), .dma_length(dma_length), .dma_done(dma_done_sig), .dma_busy(dma_busy_status),
        .AWADDR(M_AXI_AWADDR), .AWLEN(M_AXI_AWLEN), .AWSIZE(M_AXI_AWSIZE), .AWBURST(M_AXI_AWBURST),
        .AWVALID(M_AXI_AWVALID), .AWREADY(M_AXI_AWREADY), .WDATA(M_AXI_WDATA), .WSTRB(M_AXI_WSTRB),
        .WLAST(M_AXI_WLAST), .WVALID(M_AXI_WVALID), .WREADY(M_AXI_WREADY), .BRESP(M_AXI_BRESP), .BVALID(M_AXI_BVALID), .BREADY(M_AXI_BREADY),
        .ARADDR(M_AXI_ARADDR), .ARLEN(M_AXI_ARLEN), .ARSIZE(M_AXI_ARSIZE), .ARBURST(M_AXI_ARBURST), .ARVALID(M_AXI_ARVALID), .ARREADY(M_AXI_ARREADY),
        .RDATA(M_AXI_RDATA), .RRESP(M_AXI_RRESP), .RLAST(M_AXI_RLAST), .RVALID(M_AXI_RVALID), .RREADY(M_AXI_RREADY),
        .sram_addr(dma_sram_addr), .sram_wdata(dma_sram_wdata), .sram_wen(dma_sram_wen), .sram_rdata(dma_sram_rdata)
    );

    // =========================================================================
    // Operand Isolation for Feature Map RAM
    // =========================================================================
    wire [7:0] fm_rdata;
    wire fm_cpu_we = bus_we && (bus_addr >= 32'h0001_0000 && bus_addr < 32'h0002_0000);
    wire fm_we     = dma_busy_status ? dma_sram_wen : fm_cpu_we;
    
    // PPA FIX: Operand Isolation
    // Don't let address/data lines toggle when not writing
    wire [15:0] fm_wr_addr_raw = dma_busy_status ? dma_sram_addr : bus_addr[17:2];
    wire [7:0]  fm_wr_data_raw = dma_busy_status ? dma_sram_wdata[7:0] : bus_din[7:0];
    
    wire [15:0] fm_wr_addr = fm_we ? fm_wr_addr_raw : 16'h0;
    wire [7:0]  fm_wr_data = fm_we ? fm_wr_data_raw : 8'h0;

    reg [15:0] fm_read_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) fm_read_addr <= 16'd0;
        else if (start_req) fm_read_addr <= 16'd0;
        else if (ctrl_load_win | ctrl_l1_start) fm_read_addr <= fm_read_addr + 1'b1;
    end
    feature_map_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(10)) u_fm_ram (.clk(clk), .wea(fm_we), .addra(fm_wr_addr), .dina(fm_wr_data), .enb(1'b1), .addrb(fm_read_addr), .doutb(fm_rdata));

    // =========================================================================
    // Weight RAM Isolation
    // =========================================================================
    wire [71:0] wt_rdata; wire wt_we_en = bus_we && (bus_addr >= 32'h0000_0200 && bus_addr < 32'h0000_0300);
    wire [1:0]  wt_wr_addr = wt_we_en ? bus_addr[3:2] : 2'b0;
    wire [71:0] wt_wr_data = wt_we_en ? {40'd0, bus_din} : 72'd0;
    weight_ram #(.WEIGHT_WIDTH(72), .ADDR_WIDTH(2)) u_wt_ram (.clk(clk), .wea(wt_we_en), .addra(wt_wr_addr), .dina(wt_wr_data), .enb(1'b1), .addrb(2'd0), .doutb(wt_rdata));

    // Layer 1
    wire signed [31:0] l1_out_pixel; wire l1_out_valid; wire [15:0] l1_pool_width; wire l1_conv_done;
    cnn_layer_pipeline u_layer1 (.clk(clk_l1), .rst_n(rst_n), .start(ctrl_l1_start), .img_width(input_width), .img_height(input_height), .num_channels(channels), .pixel_valid_in(1'b1), .pixel_in(fm_rdata), .weights_valid(1'b1), .weight_in(wt_rdata), .pixel_out(l1_out_pixel), .out_valid(l1_out_valid), .pool_out_width(l1_pool_width), .conv_done(l1_conv_done));
    assign l1_done_sig = l1_conv_done;

    wire signed [31:0] bn1_out; wire bn1_valid;
    batch_norm #(.DATA_WIDTH(32), .PARAM_WIDTH(16)) u_bn1 (.clk(clk_l1), .rst_n(rst_n), .data_in(l1_out_pixel), .valid_in(l1_out_valid), .bn_mean(bn_mean), .bn_scale(bn_scale), .bn_offset(bn_offset), .data_out(bn1_out), .valid_out(bn1_valid));

    wire signed [31:0] skip1_out; wire skip1_valid;
    skip_add #(.DATA_WIDTH(32)) u_skip1 (.clk(clk_l1), .rst_n(rst_n), .main_in(bn1_out), .main_valid(bn1_valid), .skip_in({{24{fm_rdata[7]}}, fm_rdata}), .skip_valid(bn1_valid & skip_enable[0]), .data_out(skip1_out), .valid_out(skip1_valid));
    wire signed [31:0] l1_final = skip_enable[0] ? skip1_out : bn1_out; wire l1_final_valid = skip_enable[0] ? skip1_valid : bn1_valid;

    // Inter-FM Buffer
    reg [15:0] l1_wr_addr; wire [7:0] inter_fm_rdata; reg [15:0] l2_read_addr;
    always @(posedge clk or negedge rst_n) begin if (!rst_n) l1_wr_addr <= 16'd0; else if (ctrl_l1_start) l1_wr_addr <= 16'd0; else if (l1_final_valid) l1_wr_addr <= l1_wr_addr + 1'b1; end
    always @(posedge clk or negedge rst_n) begin if (!rst_n) l2_read_addr <= 16'd0; else if (ctrl_l2_start) l2_read_addr <= 16'd0; else l2_read_addr <= l2_read_addr + 1'b1; end
    feature_map_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(10)) u_inter_fm (.clk(clk), .wea(l1_final_valid), .addra(l1_wr_addr), .dina(l1_final[7:0]), .enb(1'b1), .addrb(l2_read_addr), .doutb(inter_fm_rdata));

    // Layer 2
    wire signed [31:0] l2_out_pixel; wire l2_out_valid; wire [15:0] l2_pool_width; wire l2_conv_done;
    cnn_layer_pipeline u_layer2 (.clk(clk_l2), .rst_n(rst_n), .start(ctrl_l2_start), .img_width(l1_pool_width), .img_height(l1_pool_width), .num_channels(l2_channels), .pixel_valid_in(1'b1), .pixel_in(inter_fm_rdata), .weights_valid(1'b1), .weight_in(wt_rdata), .pixel_out(l2_out_pixel), .out_valid(l2_out_valid), .pool_out_width(l2_pool_width), .conv_done(l2_conv_done));
    assign l2_done_sig = l2_conv_done;

    reg [15:0] fc_wr_addr; wire [7:0] fc_feature_rdata; reg [15:0] fc_read_addr;
    always @(posedge clk or negedge rst_n) begin if (!rst_n) fc_wr_addr <= 16'd0; else if (ctrl_l2_start) fc_wr_addr <= 16'd0; else if (l2_out_valid) fc_wr_addr <= fc_wr_addr + 1'b1; end
    feature_map_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(10)) u_fc_buf (.clk(clk), .wea(l2_out_valid), .addra(fc_wr_addr), .dina(l2_out_pixel[7:0]), .enb(1'b1), .addrb(fc_read_addr), .doutb(fc_feature_rdata));

    // FC Layer & Result RAM
    wire signed [31:0] fc_score; wire fc_score_valid; wire [15:0] fc_wt_rd_addr; wire [7:0] fc_wt_rdata; wire [31:0] fc_bias_rdata;
    fc_layer #(.FEATURE_WIDTH(8), .WEIGHT_WIDTH(8), .ACC_WIDTH(32), .MAX_INPUTS(576), .MAX_OUTPUTS(10)) u_fc (.clk(clk_fc), .rst_n(rst_n), .start(ctrl_fc_start), .num_inputs(fc_num_inputs), .num_outputs(fc_num_outputs), .feature_in(fc_feature_rdata), .feature_valid(1'b1), .weight_addr(fc_wt_rd_addr), .weight_in(fc_wt_rdata), .bias_in(fc_bias_rdata), .score_out(fc_score), .score_valid(fc_score_valid), .done(fc_done_sig));
    
    // FC RAMs with Operand Isolation
    wire fc_wt_we = bus_we && (bus_addr >= 32'h0002_0000 && bus_addr < 32'h0002_4000);
    wire [13:0] fc_wt_wra = fc_wt_we ? bus_addr[15:2] : 14'h0;
    wire [7:0]  fc_wt_wrd = fc_wt_we ? bus_din[7:0] : 8'h0;
    fc_weight_ram #(.DATA_WIDTH(8), .ADDR_WIDTH(10)) u_fc_wt_ram (.clk(clk), .wea(fc_wt_we), .addra(fc_wt_wra), .dina(fc_wt_wrd), .enb(1'b1), .addrb(fc_wt_rd_addr[13:0]), .doutb(fc_wt_rdata));

    wire fc_bias_we = bus_we && (bus_addr >= 32'h0002_4000 && bus_addr < 32'h0002_4040);
    wire [3:0]  fc_bias_wra = fc_bias_we ? bus_addr[5:2] : 4'h0;
    wire [31:0] fc_bias_wrd = fc_bias_we ? bus_din : 32'h0;
    reg [3:0] fc_bias_rd_addr;
    fc_bias_ram #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_fc_bias_ram (.clk(clk), .wea(fc_bias_we), .addra(fc_bias_wra), .dina(fc_bias_wrd), .enb(1'b1), .addrb(fc_bias_rd_addr), .doutb(fc_bias_rdata));

    always @(posedge clk or negedge rst_n) begin if (!rst_n) fc_read_addr <= 16'd0; else if (ctrl_fc_start) fc_read_addr <= 16'd0; else fc_read_addr <= fc_read_addr + 1'b1; end
    always @(posedge clk or negedge rst_n) begin if (!rst_n) fc_bias_rd_addr <= 4'd0; else if (ctrl_fc_start) fc_bias_rd_addr <= 4'd0; else if (fc_score_valid) fc_bias_rd_addr <= fc_bias_rd_addr + 1'b1; end

    reg [3:0] result_wr_addr; always @(posedge clk or negedge rst_n) begin if (!rst_n) result_wr_addr <= 4'd0; else if (ctrl_fc_start) result_wr_addr <= 4'd0; else if (fc_score_valid) result_wr_addr <= result_wr_addr + 1'b1; end
    output_result_ram #(.DATA_WIDTH(32), .ADDR_WIDTH(4)) u_result_ram (.clk(clk), .wea(fc_score_valid), .addra(result_wr_addr), .dina(fc_score), .enb(1'b1), .addrb(result_rd_addr), .doutb(result_readback));

    assign cnn_done = pipeline_done;
    assign dma_sram_rdata = {24'd0, fm_rdata};
    wire _unused = &{1'b0, reg_ready, image_addr, weight_addr, feature_addr, kernel_size, num_filters, conv_stride, pool_stride, pad_size, activation_mode, skip_enable, 1'b0};
endmodule
