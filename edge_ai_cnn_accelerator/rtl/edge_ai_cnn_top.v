`timescale 1ns / 1ps

module edge_ai_cnn_top (
    input wire clk,
    input wire rst_n,
    
    // External interfaces if any (e.g. debugging, UART)
    output wire system_done
);

    // -------------------------------------------------------------------------
    // RISC-V Memory Bus Signals
    // -------------------------------------------------------------------------
    wire [31:0] rv_mem_addr;
    wire [31:0] rv_mem_wdata;
    wire rv_mem_wen;
    wire rv_mem_ren;
    wire [31:0] rv_mem_rdata;
    wire rv_mem_ready;

    // -------------------------------------------------------------------------
    // Instantiation: RISC-V Core Controller
    // -------------------------------------------------------------------------
    riscv_core_controller u_riscv (
        .clk       (clk),
        .rst_n     (rst_n),
        .mem_addr  (rv_mem_addr),
        .mem_wdata (rv_mem_wdata),
        .mem_wen   (rv_mem_wen),
        .mem_ren   (rv_mem_ren),
        .mem_rdata (rv_mem_rdata),
        .mem_ready (rv_mem_ready)
    );

    // -------------------------------------------------------------------------
    // Reg/Controller Signals
    // -------------------------------------------------------------------------
    wire [7:0]  img_w, img_h, channels, k_size, num_f;
    wire start_req;
    wire conv_done;

    wire [31:0] _unused_img_addr, _unused_wt_addr, _unused_fm_addr;

    cnn_register_interface u_reg_if (
        .clk          (clk),
        .rst_n        (rst_n),
        .addr         (rv_mem_addr),
        .wdata        (rv_mem_wdata),
        .wen          (rv_mem_wen),
        .ren          (rv_mem_ren),
        .rdata        (rv_mem_rdata),
        .ready        (rv_mem_ready),
        .image_addr   (_unused_img_addr),
        .weight_addr  (_unused_wt_addr),
        .feature_addr (_unused_fm_addr),
        .input_width  (img_w),
        .input_height (img_h),
        .channels     (channels),
        .kernel_size  (k_size),
        .num_filters  (num_f),
        .start_cnn    (start_req),
        .cnn_done     (conv_done)
    );

    // -------------------------------------------------------------------------
    // CNN Acceleration Subsystem Layer 1 (Conv3D)
    // -------------------------------------------------------------------------
    wire load_win, en_mac, wr_out, nxt_pix;
    
    cnn_controller u_cnn_ctrl (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start_req),
        .load_window (load_win),
        .enable_mac  (en_mac),
        .write_output(wr_out),
        .next_pixel  (nxt_pix),
        .done        (conv_done),
        .mac_done    (1'b1), // Mock condition for simplicity
        .image_done  (1'b0)  // Managed by datapath top
    );
    
    wire [31:0] fm_out_data;
    wire fm_out_valid;
    
    conv3d_accelerator u_conv1 (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_conv     (start_req),
        .img_width      (img_w),
        .img_height     (img_h),
        .num_channels   (channels),
        .pixel_valid_in (load_win),    // Driven by controller
        .pixel_in       (8'h01),       // Connect to image buffer read
        .weights_valid  (en_mac),      // Driven by controller
        .weight_in      (72'h0101010101010101),
        .pixel_out      (fm_out_data),
        .out_valid      (fm_out_valid),
        .done           (system_done)  // Connect to local done
    );

    // Unused output sinks (prevent synthesis warnings)
    // k_size, num_f, wr_out, nxt_pix are reserved for future multi-layer support
    // unused outputs
    wire _unused = &{1'b0, k_size, num_f, wr_out, nxt_pix, fm_out_data, fm_out_valid,
                     _unused_img_addr, _unused_wt_addr, _unused_fm_addr, 1'b0};

    // Memory stubs are abstracted out from the top for simplicity in basic test.
    // In a full implementation, you connect Memory to Conv here.

endmodule
