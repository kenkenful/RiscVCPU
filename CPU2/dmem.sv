
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
    
       // Distributed RAM
    localparam data_width = 32;
    localparam addr_width = 12;
     
    reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
    
    // Block RAM
    //(* ram_style = "block" *)reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
    
    initial begin 
        integer i = 0;
        $readmemh("/home/ttt/Desktop/soft/data.hex", mem);
        
        for(i=0; i<100; i=i+1)begin
                   $display( "%x: %x",i*4, mem[i]);
        end 
    end
    
    // load
    always_comb begin
        load_data = 32'b0;        
        case (rmem) 
            // unsgigned 1 byte
            5'b00001:begin
                load_data = {24'h0, mem[mem_addr][7:0]};
            end
            5'b00010:begin
                load_data = {24'h0, mem[mem_addr][15:8]};
            end
            5'b00100:begin
                load_data = {24'h0, mem[mem_addr][23:16]};
            end
            5'b01000:begin
              load_data = {24'h0, mem[mem_addr][31:24]};
            end 
            // signed 1 byte
            5'b10001:begin
                load_data = {{24{mem[mem_addr][7]}}, mem[mem_addr][7:0]};
            end
            5'b10010:begin
                load_data = {{24{mem[mem_addr][15]}}, mem[mem_addr][15:8]};
            end
            5'b10100:begin
                load_data = {{24{mem[mem_addr][23]}}, mem[mem_addr][23:16]};
            end
            5'b11000:begin
                load_data = {{24{mem[mem_addr][31]}}, mem[mem_addr][31:24]};
            end 
            // unsigned 2 bytes
            5'b00011:begin
                load_data = {16'b0, mem[mem_addr][15:0]};  
            end
            5'b01100:begin
                load_data = {16'h0, mem[mem_addr][31:16]}; 
            end
            // signed 2 bytes
            5'b10011:begin
                load_data = {{16{mem[mem_addr][15]}}, mem[mem_addr][15:0]};  
            end
            5'b11100:begin
                load_data = {{16{mem[mem_addr][31]}}, mem[mem_addr][31:16]}; 
            end
            // 4 bytes
            5'b01111:begin
                load_data = mem[mem_addr];
            end
            default:;
        endcase
    end
    
    // store
    always_ff@(posedge clk)begin
        case(wmem)
          4'b0001:begin
            mem[mem_addr] <= {24'b0, store_data[7:0]};
          end
          4'b0010:begin
            mem[mem_addr] <= {16'b0, store_data[7:0], 8'b0};
          end
          4'b0100:begin
            mem[mem_addr] <= {8'b0, store_data[7:0], 16'b0};
          end
          4'b1000:begin
            mem[mem_addr] <= {store_data[7:0], 24'b0};
          end
          4'b0011:begin
            mem[mem_addr] <= {16'b0, store_data[15:0]};
          end
          4'b1100:begin
            mem[mem_addr] <= {store_data[15:0],16'b0};    
          end
          4'b1111:begin
            mem[mem_addr] <= store_data[31:0];
          end
          default:;
        endcase
    end
    
endmodule
