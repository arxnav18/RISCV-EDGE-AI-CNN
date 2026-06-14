`timescale 1ns / 1ps

module edge_ai_cnn_top_tb;

    // Inputs
    reg clk;
    reg rst_n;
    reg bus_we;
    reg [31:0] bus_addr;
    reg [31:0] bus_din;
    
    // Outputs
    wire [31:0] bus_dout;
    wire cnn_done;

    // Instantiate the Unit Under Test (UUT)
    edge_ai_cnn_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_we(bus_we),
        .bus_addr(bus_addr),
        .bus_din(bus_din),
        .bus_dout(bus_dout),
        .cnn_done(cnn_done)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Bus Write Task
    task write_reg(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            bus_we <= 1;
            bus_addr <= addr;
            bus_din <= data;
            @(posedge clk);
            bus_we <= 0;
            bus_addr <= 32'dx;
            bus_din <= 32'dx;
        end
    endtask
    
    // Bus Read Task
    task read_reg(input [31:0] addr);
        begin
            @(posedge clk);
            bus_we <= 0;
            bus_addr <= addr;
            @(posedge clk);
        end
    endtask

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        bus_we = 0;
        bus_addr = 0;
        bus_din = 0;

        // Reset system
        #20 rst_n = 1;
        #10;
        
        $display("[%0t] Configuration Phase Started...", $time);
        
        // Write Configurations
        write_reg(32'h00, 32'h1000); // Set input text address
        write_reg(32'h04, 32'h2000); // Set weight address
        write_reg(32'h08, 32'h3000); // Set output address
        write_reg(32'h0C, 32'd8);    // Set Feature Size (8x8)
        write_reg(32'h10, 32'd3);    // Set Kernel Size (3x3)
        
        $display("[%0t] Starting CNN Accelerator...", $time);
        
        // Start Processing
        write_reg(32'h14, 32'd1);    // Set START bit
        
        // Wait for completion
        wait(cnn_done == 1'b1);
        $display("[%0t] CNN Accelerator Done!", $time);
        
        #50;
        $finish;
    end

endmodule
