
module top(
         clk,
         reset,
         uart_en
    );
    
    input wire clk;                  // clock 
    input wire reset;                // reset
    output wire uart_en;
    
    riscv riscv_0(
        .clk(clk),
        .reset(reset),
        .uart_en(uart_en)
    );
    
endmodule
