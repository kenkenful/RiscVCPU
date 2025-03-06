`default_nettype none

module mem(
    clk,
    is_jump,
    is_stoll,
    pc,
    inst,
    wmem,
    rmem,
    mem_addr,
    store_data,
    load_data,
    );
    
    input wire clk;
    input wire [31:0] pc;
    input wire is_jump;
    input wire is_stoll;
    output reg [31:0] inst;
    input wire [3:0] wmem;
    input wire [4:0] rmem;
    input wire [31:0] mem_addr;
    input wire [31:0] store_data;
    output reg [31:0] load_data;
    
    // Distributed RAM 
    localparam data_width = 32;
    localparam addr_width = 12; 
    
    // Block RAM
    (* ram_style = "block" *)reg [data_width-1:0] mem[2**addr_width-1:0];  // instruction and data melmory
    
    initial begin 
      integer i = 0;
      $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/test.hex", mem);
      
      for(i=0; i<100; i=i+1)begin
        $display( "%x: %x",i*4, mem[i]);
      end 
    end
    
    always_ff@(posedge clk)begin
      if(is_jump)
          inst <= 0;
      else if(is_stoll)
          inst <= inst;
      else
          inst <= mem[pc[31:2]];
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
