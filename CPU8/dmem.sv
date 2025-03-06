`default_nettype none

module dmem(
    clk,
    wmem,
    rmem,
    mem_addr,
    store_data,
    load_data,
    
    );
    
    input wire clk;
    input wire [3:0] wmem;
    input wire [4:0] rmem;
    input wire [31:0] mem_addr;
    input wire [31:0] store_data;
    output reg [31:0] load_data;
    
    localparam data_width = 32;
    localparam addr_width = 15;
         
    // Block RAM
    (* ram_style = "block" *)reg [data_width-1:0] mem [2**addr_width-1:0];  //  data melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/data.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
      // load
    always_ff@(posedge clk) begin
      if(rmem) load_data = mem[mem_addr];
    end
    
    // store
    always_ff@(posedge clk)begin
      if(wmem) mem[mem_addr] <= store_data;
    end
    
    
endmodule
