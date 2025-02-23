`timescale 1ns / 1ps

module tb;
    localparam  SYSSTEP         = 8;
    localparam  STEP            = 10;

    reg         SYSCLK;  //125MHz
    reg         SYSRST;  
    
    always begin
        SYSCLK = 0; #(SYSSTEP / 2);
        SYSCLK = 1; #(SYSSTEP / 2);
    end
    
    initial begin
        SYSRST = 0; #(SYSSTEP *10);
        SYSRST = 1; #(SYSSTEP);
        SYSRST = 0;
    end
    
    top top(
        .clk(SYSCLK),
        .reset(SYSRST)
    
    );

endmodule
