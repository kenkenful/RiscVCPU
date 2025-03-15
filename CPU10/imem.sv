`default_nettype none
`include "define.sv"

module imem(
   clk,
    pc,
    inst
    );
    
    input wire clk;
    input wire [31:0] pc;
    output reg [31:0] inst;
     
    reg [data_width-1:0] mem [2**inst_addr_width-1:0];  // instruction melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/code.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
    assign inst = mem[pc[31:2]];
    
endmodule