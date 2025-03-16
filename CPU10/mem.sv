`default_nettype none

module mem(
    clk,
    pc,
    inst,
    is_store,
    is_load,
    mem_addr,
    store_data,
    load_data,
    
    );
        
    input wire clk;
    input wire [31:0] pc;
    output reg [31:0] inst;
    input wire is_store;
    input wire is_load;
    input wire [31:0] mem_addr;
    input wire [31:0] store_data;
    output reg [31:0] load_data;
    
    // Distributed RAM
    localparam data_width = 32;
    localparam addr_width = 12;
     
    reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
        
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/test.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
    assign inst = mem[pc[31:2]];
    
    // load
    always_comb begin
        if(is_load) load_data = mem[mem_addr];
    end
    
    // store
    always_ff@(posedge clk)begin
        if(is_store)  mem[mem_addr] <= store_data;
    end
    
endmodule