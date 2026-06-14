`timescale 1ns / 1ps

module cnn_comprehensive_tb();

    reg clk;
    reg rst_n;
    
    // -------------------------------------------------------------------------
    // 1. Module Instantiations
    // -------------------------------------------------------------------------

    // ReLU
    reg signed [31:0] relu_in;
    reg relu_valid_in;
    wire [31:0] relu_out;
    wire relu_valid_out;
    relu u_relu (.data_in(relu_in), .valid_in(relu_valid_in), .data_out(relu_out), .valid_out(relu_valid_out));

    // Sigmoid LUT
    reg sig_valid_in;
    reg [7:0] sig_in;
    wire [7:0] sig_out;
    wire sig_valid_out;
    activation_lut u_sig (
        .clk(clk), .rst_n(rst_n), .mode(1'b0),
        .data_in(sig_in), .valid_in(sig_valid_in),
        .data_out(sig_out), .valid_out(sig_valid_out)
    );

    // Batch Norm
    reg signed [31:0] bn_in;
    reg bn_valid_in;
    wire signed [31:0] bn_out;
    wire bn_valid_out;
    batch_norm u_bn (
        .clk(clk), .rst_n(rst_n),
        .data_in(bn_in), .valid_in(bn_valid_in),
        .bn_mean(16'sd10), .bn_scale(16'h0100), .bn_offset(16'sd5), // mean=10, scale=1.0, offset=5
        .data_out(bn_out), .valid_out(bn_valid_out)
    );

    // Skip Add
    reg signed [31:0] main_in, skip_in;
    reg main_valid, skip_valid;
    wire signed [31:0] skip_add_out;
    wire skip_add_valid;
    skip_add u_skip (
        .clk(clk), .rst_n(rst_n),
        .main_in(main_in), .main_valid(main_valid),
        .skip_in(skip_in), .skip_valid(skip_valid),
        .data_out(skip_add_out), .valid_out(skip_add_valid)
    );

    // Clock Gate
    reg cg_en;
    wire gated_clk;
    clock_gate u_cg (.clk_in(clk), .enable(cg_en), .test_mode(1'b0), .clk_out(gated_clk));

    // FC Layer
    reg fc_start;
    reg signed [7:0] fc_feature_in;
    reg fc_feature_valid;
    reg signed [7:0] fc_weight_in;
    reg signed [31:0] fc_bias_in;
    wire [15:0] fc_weight_addr;
    wire signed [31:0] fc_score_out;
    wire fc_score_valid;
    wire fc_done;
    fc_layer #(.MAX_INPUTS(10), .MAX_OUTPUTS(2)) u_fc (
        .clk(clk), .rst_n(rst_n), .start(fc_start),
        .num_inputs(16'd2), .num_outputs(8'd1),
        .feature_in(fc_feature_in), .feature_valid(fc_feature_valid),
        .weight_addr(fc_weight_addr), .weight_in(fc_weight_in),
        .bias_in(fc_bias_in),
        .score_out(fc_score_out), .score_valid(fc_score_valid), .done(fc_done)
    );

    // DMA Controller
    reg dma_start;
    reg [31:0] dma_src, dma_dst;
    reg [15:0] dma_len;
    wire [31:0] m_rd_addr, m_wr_addr, m_wr_data;
    wire m_rd_en, m_wr_en;
    reg [31:0] m_rd_data;
    wire dma_busy, dma_done;
    dma_controller u_dma (
        .clk(clk), .rst_n(rst_n), .start(dma_start),
        .src_addr(dma_src), .dst_addr(dma_dst), .transfer_len(dma_len),
        .mem_rd_addr(m_rd_addr), .mem_rd_en(m_rd_en), .mem_rd_data(m_rd_data),
        .mem_wr_addr(m_wr_addr), .mem_wr_en(m_wr_en), .mem_wr_data(m_wr_data),
        .busy(dma_busy), .done(dma_done)
    );

    // -------------------------------------------------------------------------
    // 2. Monitoring
    // -------------------------------------------------------------------------
    
    integer bn_pass = 0;
    always @(posedge clk) if (bn_valid_out && bn_out == 32'sd15) bn_pass = 1;

    integer skip_pass = 0;
    always @(posedge clk) if (skip_add_valid && skip_add_out == 32'sd150) skip_pass = 1;

    integer sig_pass_0 = 0;
    always @(posedge clk) if (sig_valid_out && sig_out == 8'd128) sig_pass_0 = 1;

    integer cg_active = 0;
    always @(gated_clk) if (cg_en) cg_active = 1;

    // -------------------------------------------------------------------------
    // 3. Test Logic
    // -------------------------------------------------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $display("--- Starting Comprehensive CNN Unit Tests ---");
        rst_n = 0;
        relu_in = 0; relu_valid_in = 0;
        sig_in = 0; sig_valid_in = 0;
        bn_in = 0; bn_valid_in = 0;
        main_in = 0; main_valid = 0;
        skip_in = 0; skip_valid = 0;
        cg_en = 0;
        fc_start = 0; fc_feature_in = 0; fc_feature_valid = 0; fc_weight_in = 0; fc_bias_in = 0;
        dma_start = 0; dma_src = 0; dma_dst = 0; dma_len = 0; m_rd_data = 0;
        
        #20 rst_n = 1;

        // --- ReLU Test ---
        $display("\nTesting ReLU...");
        relu_in = 32'sd100; relu_valid_in = 1; #10;
        if (relu_out == 32'sd100) $display("  PASS: Positive (100 -> %0d)", relu_out);
        else $display("  FAIL: Positive");
        relu_in = -32'sd50; #10;
        if (relu_out == 32'sd0) $display("  PASS: Negative (-50 -> %0d)", relu_out);
        else $display("  FAIL: Negative");
        relu_valid_in = 0;

        // --- Sigmoid LUT Test ---
        $display("\nTesting Sigmoid LUT...");
        @(posedge clk);
        sig_in = 8'sd0; sig_valid_in = 1;
        repeat(5) @(posedge clk);
        sig_valid_in = 0;
        if (sig_pass_0) $display("  PASS: Sigmoid at 0 = 128");
        else $display("  FAIL: Sigmoid at 0");

        // --- Batch Norm Test ---
        $display("\nTesting Batch Norm...");
        @(posedge clk);
        bn_in = 32'sd20; bn_valid_in = 1;
        @(posedge clk);
        bn_valid_in = 0;
        repeat(5) @(posedge clk);
        if (bn_pass) $display("  PASS: Batch Norm (20 -> 15)");
        else $display("  FAIL: Batch Norm");

        // --- Skip Add Test ---
        $display("\nTesting Skip Add...");
        @(posedge clk);
        main_in = 32'sd100; main_valid = 1;
        skip_in = 32'sd50; skip_valid = 1;
        @(posedge clk);
        main_valid = 0; skip_valid = 0;
        repeat(5) @(posedge clk);
        if (skip_pass) $display("  PASS: Skip Add (100+50 -> 150)");
        else $display("  FAIL: Skip Add");

        // --- Clock Gate Test ---
        $display("\nTesting Clock Gate...");
        cg_en = 0;
        #20;
        if (gated_clk === 1'b0) $display("  PASS: Disabled stable Low");
        cg_en = 1;
        #20;
        if (cg_active) $display("  PASS: Active when enabled");
        else $display("  FAIL: Gated clock stuck");

        // --- FC Layer Test ---
        $display("\nTesting FC Layer (2 inputs, 1 output)...");
        @(posedge clk);
        fc_start = 1; fc_bias_in = 32'sd10;
        @(posedge clk);
        fc_start = 0;
        // Input 1: feature=5, weight=2
        fc_feature_in = 8'sd5; fc_weight_in = 8'sd2; fc_feature_valid = 1;
        @(posedge clk);
        // Input 2: feature=3, weight=4
        fc_feature_in = 8'sd3; fc_weight_in = 8'sd4;
        @(posedge clk);
        fc_feature_valid = 0;
        // Total expected: (5*2 + 3*4) + 10 = 10 + 12 + 10 = 32
        wait(fc_score_valid);
        if (fc_score_out == 32'sd32) $display("  PASS: FC Store = 32");
        else $display("  FAIL: FC Score = %0d", fc_score_out);
        wait(fc_done);

        // --- DMA Test ---
        $display("\nTesting DMA (3 words)...");
        @(posedge clk);
        dma_src = 32'h100; dma_dst = 32'h200; dma_len = 16'd3; dma_start = 1;
        @(posedge clk);
        dma_start = 0;
        
        // Word 1
        wait(m_rd_en); m_rd_data = 32'hAAAA_BBBB;
        @(posedge clk);
        wait(m_wr_en && m_wr_addr == 32'h200 && m_wr_data == 32'hAAAA_BBBB);
        
        // Word 2
        wait(m_rd_en); m_rd_data = 32'hCCCC_DDDD;
        @(posedge clk);
        wait(m_wr_en && m_wr_addr == 32'h201 && m_wr_data == 32'hCCCC_DDDD);

        // Word 3
        wait(m_rd_en); m_rd_data = 32'hEEEE_FFFF;
        @(posedge clk);
        wait(m_wr_en && m_wr_addr == 32'h202 && m_wr_data == 32'hEEEE_FFFF);

        wait(dma_done);
        $display("  PASS: DMA Transfer complete");

        $display("\n--- Comprehensive Unit Tests Finished ---");
        $finish;
    end

endmodule
