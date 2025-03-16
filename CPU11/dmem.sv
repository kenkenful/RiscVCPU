`default_nettype none
`include "define.sv"

module dmem(
    clk,
    is_store,
    is_load,
    mem_addr,
    store_data,
    load_data,
    );
    
    input wire clk;
    input wire is_store;
    input wire is_load;
    input wire [31:0] mem_addr;
    input wire [31:0] store_data;
    output reg [31:0] load_data;

    // Block RAM
    (* ram_style = "block" *)reg [data_width-1:0] mem [2**total_addr_width-1: 2**inst_addr_width];  // data melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/data.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
    // load
    always_ff@(negedge clk) begin
        if(is_load) load_data = mem[mem_addr];
    end
    
    // store
    always_ff@(posedge clk)begin
        if(is_store) mem[mem_addr] <= store_data;
        
    end

endmodule