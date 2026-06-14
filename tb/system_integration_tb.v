`timescale 1ns / 1ps

module system_integration_tb();

    reg clk;
    reg rst_n;
    reg bus_we;
    reg bus_ren;
    reg [31:0] bus_addr;
    reg [31:0] bus_din;
    wire [31:0] bus_dout;
    wire cnn_done;

    // Instantiate UUT
    edge_ai_cnn_peripheral uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_we(bus_we),
        .bus_ren(bus_ren),
        .bus_addr(bus_addr),
        .bus_din(bus_din),
        .bus_dout(bus_dout),
        .cnn_done(cnn_done)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Bus Tasks
    task write_reg(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            bus_we <= 1;
            bus_addr <= addr;
            bus_din <= data;
            @(posedge clk);
            bus_we <= 0;
        end
    endtask

    task read_reg(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            bus_ren <= 1;
            bus_addr <= addr;
            @(posedge clk);
            #1; // Wait for combinational response
            data = bus_dout;
            bus_ren <= 0;
        end
    endtask

    integer i;
    reg [31:0] rdata;

    initial begin : test_logic
        $display("--- Starting System Integration Test ---");
        rst_n = 0;
        bus_we = 0;
        bus_ren = 0;
        bus_addr = 0;
        bus_din = 0;
        
        #50 rst_n = 1;

        // 1. Load weights (dummy)
        $display("Loading Weights...");
        for (i = 0; i < 4; i = i + 1) begin
            write_reg(32'h0000_0200 + (i*4), 32'h01020304);
        end

        // 2. Load Image Data into FM RAM
        $display("Loading Image Data...");
        for (i = 0; i < 10; i = i + 1) begin
            write_reg(32'h0001_0000 + (i*4), 32'h0A0B0C0D);
        end

        // 3. Configure Peripheral Registers
        $display("Configuring CNN Registers...");
        write_reg(32'h10, 32'd8);    // INPUT_WIDTH = 8
        write_reg(32'h14, 32'd8);    // INPUT_HEIGHT = 8
        write_reg(32'h18, 32'd1);    // CHANNELS = 1
        write_reg(32'h20, 32'd1);    // NUM_FILTERS = 1
        write_reg(32'h34, 32'd1);    // L2_CHANNELS = 1
        write_reg(32'h38, 32'd1);    // L2_NUM_FILTERS = 1
        write_reg(32'h3C, 32'd16);   // FC_NUM_INPUTS = 16 (4x4 pool output)
        write_reg(32'h40, 32'd1);    // FC_NUM_OUTPUTS = 1

        // 4. Start CNN
        $display("Starting CNN Inference Pipeline...");
        write_reg(32'h00, 32'd1);    // START_CNN bit

        // 5. Wait for Done
        $display("Waiting for CNN_DONE...");
        // Synchronous wait instead of fork/disable for better compatibility
        i = 0;
        while (!cnn_done && i < 2000) begin
            @(posedge clk);
            i = i + 1;
        end

        if (cnn_done) begin
            $display("--- CNN_DONE Success at %0t ---", $time);
            // 6. Read back result
            read_reg(32'h80, rdata);
            $display("FC Output Score [0]: %0d (raw: 0x%h)", rdata, rdata);
        end else begin
            $display("--- TIMEOUT: CNN did not finish ---");
        end

        $finish;
    end

endmodule
