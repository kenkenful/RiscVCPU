`default_nettype none

module imem(
   clk,
   is_jump,
   is_stoll,
    pc,
    inst
);
    
    input wire clk;
    input wire is_jump;
    input wire is_stoll;
    input wire [31:0] pc;
    output reg [31:0] inst;

    localparam data_width = 32;
    localparam addr_width = 12;
    
    // Block RAM
    (* ram_style = "block" *)reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/code.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end

    always_ff@(posedge clk)begin
        if(is_stoll)
            inst <= inst;
        if(is_jump)
            inst <= 0;
        else
            inst <= mem[pc[31:2]];

    end
 
endmodule