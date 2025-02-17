`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2025 09:50:21 AM
// Design Name: 
// Module Name: top
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