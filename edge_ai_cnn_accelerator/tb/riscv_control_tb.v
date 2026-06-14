`timescale 1ns / 1ps

module riscv_control_tb;

    reg clk, rst_n;
    wire [31:0] mem_addr, mem_wdata;
    wire mem_wen, mem_ren;
    wire [31:0] mem_rdata;
    reg mem_ready;

    // Instance of RISC-V controller
    riscv_core_controller uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wen(mem_wen),
        .mem_ren(mem_ren),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    always #5 clk = ~clk;

    // Simulate simple memory response
    always @(posedge clk) begin
        if (mem_wen || mem_ren) begin
            // Ready in next cycle
            mem_ready <= 1'b1;
        end else begin
            mem_ready <= 1'b0;
        end
    end

    // Assign mock read data if asking for status
    assign mem_rdata = (mem_addr == 32'h00) ? 32'h02 : 32'h00; // Mock DONE bit = 1

    initial begin
        $dumpfile("riscv_control_tb.vcd");
        $dumpvars(0, riscv_control_tb);
        
        clk = 0;
        rst_n = 0;
        mem_ready = 0;
        
        #20 rst_n = 1;

        // Monitor writes
        $monitor("Time: %0t | ADDR: %h | WDATA: %h | WEN: %b | REN: %b",
                 $time, mem_addr, mem_wdata, mem_wen, mem_ren);
        
        // Allow enough time for the state machine to reach FINISH
        #200;
        $finish;
    end
endmodule
