`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2025 06:22:09 PM
// Design Name: 
// Module Name: imem
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


module imem(
   clk,
    pc,
    inst
    );
    
    input wire clk;
    input wire [31:0] pc;
    output reg [31:0] inst;

    // Distributed RAM
    localparam data_width = 32;
    localparam addr_width = 12;
     
    reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
    
    // Block RAM
    //(* ram_style = "block" *)reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/soft/code.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
    assign inst = mem[pc[31:2]];
    
endmodule
