`default_nettype none


module mem(
    clk,
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
    output reg [31:0] inst;
    input wire [3:0] wmem;
    input wire [4:0] rmem;
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
        case (rmem) 
            // unsgigned 1 byte
            5'b00001: load_data = {24'h0, mem[mem_addr][7:0]};
            5'b00010: load_data = {24'h0, mem[mem_addr][15:8]};
            5'b00100: load_data = {24'h0, mem[mem_addr][23:16]};
            5'b01000: load_data = {24'h0, mem[mem_addr][31:24]};
            // signed 1 byte
            5'b10001: load_data = {{24{mem[mem_addr][7]}}, mem[mem_addr][7:0]};
            5'b10010: load_data = {{24{mem[mem_addr][15]}}, mem[mem_addr][15:8]};
            5'b10100: load_data = {{24{mem[mem_addr][23]}}, mem[mem_addr][23:16]};
            5'b11000: load_data = {{24{mem[mem_addr][31]}}, mem[mem_addr][31:24]};
            // unsigned 2 bytes
            5'b00011: load_data = {16'b0, mem[mem_addr][15:0]};  
            5'b01100: load_data = {16'h0, mem[mem_addr][31:16]}; 
            // signed 2 bytes
            5'b10011: load_data = {{16{mem[mem_addr][15]}}, mem[mem_addr][15:0]};  
            5'b11100: load_data = {{16{mem[mem_addr][31]}}, mem[mem_addr][31:16]}; 
            // 4 bytes
            5'b01111: load_data = mem[mem_addr];
            default: load_data = 0;    
        endcase
    end
    
    // store
    always_ff@(posedge clk)begin
        if(wmem)  mem[mem_addr] <= store_data;
    end
    
endmodule