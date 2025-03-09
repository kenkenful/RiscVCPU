`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2025 09:54:04 AM
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


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
