`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/08/2025 09:32:41 AM
// Design Name: 
// Module Name: riscv
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

`define UART_TX_ADDR 32'h20020

module riscv(
      clk,
      reset,
      uart_en,
      uart_tx_data
    );

    input wire clk;             // clock 
    input wire reset;           // reset
    output reg uart_en;
    output reg [7:0] uart_tx_data;
    

    wire [31:0] inst;           // instructin
    reg [31:0] pc;              // program counter

    reg [31:0] store_data;      // store data
    reg [31:0] mem_addr;        // load/store address
    
    reg write_back;             // 
    reg [3:0] wmem;             // write memory byte enables
    reg [3:0] rmem;
    reg [31:0] alu_out;         // alu output
    reg [31:0] mem_out;         // mem output

    // Distributed RAM
    //reg [31:0] mem [0:4095];  // instruction and data melmory
    
    // Block RAM
    //(* ram_style = "block" *)reg [31:0] mem [0:16383];  // instruction and data melmory
    reg [7:0] mem [0:32767];  // instruction and data melmory
    
    initial begin
        integer num = 0;
        integer i = 0;
        reg[7:0] dat;
        integer fd = $fopen("/home/ttt/Desktop/soft/test.bin", "rb");
        while($feof(fd)===0) begin
            num = $fread(dat, fd);
            if(num == 1)begin
                mem[i] = dat;
                $display( "memory read data: %x, %d", mem[i], num);
                i = i+1;
            end
        end
        $fclose(fd);      
    end
    
    assign inst = {mem[pc+3], mem[pc+2], mem[pc+1], mem[pc+0]};
       
    wire [31:0] load_data = {mem[mem_addr + 3], mem[mem_addr+2], mem[mem_addr+1], mem[mem_addr+0]};
    
    always_comb begin
        mem_out = 32'b0;
        case (rmem) 
            4'b0001:begin
                mem_out = {24'h0, load_data[ 7: 0]};
            end 
            4'b1001:begin
                mem_out = {{24{load_data[ 7]}}, load_data[ 7: 0]};  
            end
            4'b0010:begin
                mem_out = {16'h0, load_data[15: 0]}; 
            end
            4'b1010:begin
                mem_out = {{16{load_data[15]}}, load_data[15: 0]};  
            end
            4'b0100:begin
                mem_out = load_data;
            end
            default:;
        endcase
    end
    
    always_ff@(posedge clk)begin
        case(wmem)
          4'b0001:begin
            mem[mem_addr + 0] <= store_data[7:0];
          end
          4'b0010:begin
            mem[mem_addr + 0] <= store_data[7:0];
          end
          4'b0100:begin
            mem[mem_addr + 0] <= store_data[7:0];
          end
          4'b1000:begin
            mem[mem_addr + 0] <= store_data[7:0];
          end
          4'b0011:begin
            mem[mem_addr + 0] <= store_data[7:0];
            mem[mem_addr + 1] <= store_data[15:8];
          end
          4'b1100:begin
            mem[mem_addr + 0] <= store_data[7:0];
            mem[mem_addr + 1] <= store_data[15:8];
          
          end
          4'b1111:begin
            mem[mem_addr + 0] <= store_data[7:0];
            mem[mem_addr + 1] <= store_data[15:8];
            mem[mem_addr + 2] <= store_data[23:16];
            mem[mem_addr + 3] <= store_data[31:24];
          end
          default:;
        endcase
      
    end

    reg [31:0] next_pc;                            // next pc
    wire [31:0] pc_plus_4 = pc + 4;                  // pc + 4

    // instruction format
    wire [6:0] opcode = inst[6:0];   //
    wire [2:0] func3  = inst[14:12]; //
    wire [6:0] func7  = inst[31:25]; //
    wire [4:0] rd     = inst[11:7];  //
    wire [4:0] rs     = inst[19:15]; // = rs1
    wire [4:0] rt     = inst[24:20]; // = rs2
    wire [4:0] shamt  = inst[24:20]; // == rs2;
    wire sign   = inst[31];
    wire [11:0] imm    = inst[31:20];

    // branch offset            31:13          12      11       10:5         4:1     0
    wire   [31:0] broffset  = {{19{sign}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};   // beq, bne,  blt,  bge,   bltu, bgeu
    
    wire   [31:0] simm      = {{20{sign}},inst[31:20]};                                    // lw,  addi, slti, sltiu, xori, ori,  andi, jalr
    
    wire   [31:0] stimm     = {{20{sign}},inst[31:25],inst[11:7]};                         // store word    memory address
    
    wire   [31:0] uimm      = {inst[31:12],12'h0};                                         // lui, auipc
    
    wire   [31:0] jaloffset = {{11{sign}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0}; // jal
    // jal target               31:21          20       19:12       11       10:1      0

    // instruction decode
    wire i_auipc = (opcode == 7'b0010111);
    wire i_lui   = (opcode == 7'b0110111);
    wire i_jal   = (opcode == 7'b1101111);
    wire i_jalr  = (opcode == 7'b1100111) & (func3 == 3'b000);
    wire i_beq   = (opcode == 7'b1100011) & (func3 == 3'b000);
    wire i_bne   = (opcode == 7'b1100011) & (func3 == 3'b001);
    wire i_blt   = (opcode == 7'b1100011) & (func3 == 3'b100);
    wire i_bge   = (opcode == 7'b1100011) & (func3 == 3'b101);
    wire i_bltu  = (opcode == 7'b1100011) & (func3 == 3'b110);
    wire i_bgeu  = (opcode == 7'b1100011) & (func3 == 3'b111);
    wire i_lb    = (opcode == 7'b0000011) & (func3 == 3'b000);
    wire i_lh    = (opcode == 7'b0000011) & (func3 == 3'b001);
    wire i_lw    = (opcode == 7'b0000011) & (func3 == 3'b010);
    wire i_lbu   = (opcode == 7'b0000011) & (func3 == 3'b100);
    wire i_lhu   = (opcode == 7'b0000011) & (func3 == 3'b101);
    wire i_sb    = (opcode == 7'b0100011) & (func3 == 3'b000);
    wire i_sh    = (opcode == 7'b0100011) & (func3 == 3'b001);
    wire i_sw    = (opcode == 7'b0100011) & (func3 == 3'b010);
    wire i_addi  = (opcode == 7'b0010011) & (func3 == 3'b000);
    wire i_slti  = (opcode == 7'b0010011) & (func3 == 3'b010);
    wire i_sltiu = (opcode == 7'b0010011) & (func3 == 3'b011);
    wire i_xori  = (opcode == 7'b0010011) & (func3 == 3'b100);
    wire i_ori   = (opcode == 7'b0010011) & (func3 == 3'b110);
    wire i_andi  = (opcode == 7'b0010011) & (func3 == 3'b111);
    wire i_slli  = (opcode == 7'b0010011) & (func3 == 3'b001) & (func7 == 7'b0000000);
    wire i_srli  = (opcode == 7'b0010011) & (func3 == 3'b101) & (func7 == 7'b0000000);
    wire i_srai  = (opcode == 7'b0010011) & (func3 == 3'b101) & (func7 == 7'b0100000);
    wire i_add   = (opcode == 7'b0110011) & (func3 == 3'b000) & (func7 == 7'b0000000);
    wire i_sub   = (opcode == 7'b0110011) & (func3 == 3'b000) & (func7 == 7'b0100000);
    wire i_sll   = (opcode == 7'b0110011) & (func3 == 3'b001) & (func7 == 7'b0000000);
    wire i_slt   = (opcode == 7'b0110011) & (func3 == 3'b010) & (func7 == 7'b0000000);
    wire i_sltu  = (opcode == 7'b0110011) & (func3 == 3'b011) & (func7 == 7'b0000000);
    wire i_xor   = (opcode == 7'b0110011) & (func3 == 3'b100) & (func7 == 7'b0000000);
    wire i_srl   = (opcode == 7'b0110011) & (func3 == 3'b101) & (func7 == 7'b0000000);
    wire i_sra   = (opcode == 7'b0110011) & (func3 == 3'b101) & (func7 == 7'b0100000);
    wire i_or    = (opcode == 7'b0110011) & (func3 == 3'b110) & (func7 == 7'b0000000);
    wire i_and   = (opcode == 7'b0110011) & (func3 == 3'b111) & (func7 == 7'b0000000);


    // pc
    always_ff @ (posedge clk) begin
        if (reset) pc <= 0;
        else       pc <= next_pc;
    end

    wire        load = i_lw | i_lb | i_lbu | i_lh | i_lhu;     
    wire [31:0] write_back_data = load ? mem_out : alu_out;

    reg    [31:0] regfile [1:31];                          //  regfile[0] is zero register.
   
    wire   [31:0] a = (rs==0) ? 0 : regfile[rs];           //  index 0 is zero register, so return 0. 
    wire   [31:0] b = (rt==0) ? 0 : regfile[rt];           //  index 0 is zero register, so return 0.
    
    
    always_ff @ (posedge clk) begin
        if (write_back && (rd != 0)) begin                 // rd = 0 is zero register, so cannot write back.
            regfile[rd] <= write_back_data;                 
        end
    end

    // control signals, will be combinational circuit
    always_comb begin                                      
        alu_out = 0;                                       // alu output
        mem_addr  = 0;                                     // memory address
        write_back = 0;                                    // write regfile
        wmem = 4'b0000;                                    // write memory (sw)
        rmem = 4'b000;
        store_data = b;                                    // store data
        next_pc = pc_plus_4;
        uart_en = 1'b0;
        uart_tx_data = 8'b0;
     
        case (1'b1)
            i_add: begin                                   // add
              alu_out = a + b;
              write_back  = 1; 
            end                           

            i_sub: begin                                   // sub
              alu_out = a - b;
              write_back = 1;                  
            end                         

            i_and: begin                                   // and
              alu_out = a & b;
              write_back = 1;                  
            end                          

            i_or: begin                                    // or
              alu_out = a | b;
              write_back = 1; 
            end

            i_xor: begin                                   // xor
              alu_out = a ^ b;
              write_back = 1;   
            end
            
            i_sll: begin                                   // sll
              alu_out = a << b[4:0];
              write_back = 1; 
            end

            i_srl: begin                                   // srl
              alu_out = a >> b[4:0];
              write_back = 1; 
            end

            i_sra: begin                                   // sra
              alu_out = $signed(a) >>> b[4:0];
              write_back = 1; 
            end

            i_slli: begin                                  // slli
              alu_out = a << shamt;
              write_back = 1; 
            end

            i_srli: begin                                  // srli
              alu_out = a >> shamt;
              write_back = 1; 
            end

            i_srai: begin                                  // srai
              alu_out = $signed(a) >>> shamt;
              write_back = 1; 
            end

            i_slt: begin                                   // slt
              if ($signed(a) < $signed(b)) 
                  alu_out = 1; 
            end

            i_sltu: begin                                  // sltu
              if ({1'b0,a} < {1'b0,b}) 
                alu_out = 1; 
            end

            i_addi: begin                                  // addi
              alu_out = a + simm;
              write_back = 1; 
            end

            i_andi: begin                                  // andi
              alu_out = a & simm;
              write_back = 1; 
            end

            i_ori: begin                                   // ori
              alu_out = a | simm;
              write_back = 1; 
            end

            i_xori: begin                                  // xori
              alu_out = a ^ simm;
              write_back = 1; 
            end

            i_slti: begin                                  // slti
              if ($signed(a) < $signed(simm)) 
                alu_out = 1; 
                end

            i_sltiu: begin                                 // sltiu
              if ({1'b0,a} < {1'b0,simm}) 
                alu_out = 1; 
                end

            i_lw: begin                                    // load 4bytes
              alu_out = a + simm;                        
              mem_addr  = {alu_out[31:2], 2'b00};          // alu_out[1:0] != 0, exception
              write_back = 1;
              rmem = 4'b0100;                             // signed 2bytes                        
            end               

            i_lbu: begin                                   // load 1byte unsigned
              alu_out = a + simm;                        
              mem_addr  = alu_out;
              write_back = 1;
              rmem = 4'b0001;                              // unsigned 1byte                       
            end

            i_lb: begin                                     // load 1byte
              alu_out = a + simm;                         
              mem_addr  = alu_out;                         
              write_back = 1; 
              rmem = 4'b1001;                              // signed 1byte                       
            end

            i_lhu: begin                                    // load 2bytes unsigned
              alu_out = a + simm;                         
              mem_addr  = {alu_out[31:1], 1'b0};             // alu_out[0] != 0, exception
              write_back = 1; 
              rmem = 4'b0010;                              // unsigned 2bytes                       
            end

            i_lh: begin                                     // load 2bytes 
              alu_out = a + simm;                         
              mem_addr  = {alu_out[31:1],1'b0};             // alu_out[0] != 0, exception
              write_back = 1; 
              rmem = 4'b1010;                              // signed 2bytes                       
            end

            i_sb: begin                                    // 1 byte store
              alu_out = a + stimm;
              mem_addr  = alu_out;
              wmem    = 4'b0001 << alu_out[1:0];         // Which Byte position is it sorted to?
              if(mem_addr == `UART_TX_ADDR) begin
                   uart_en = 1'b1;
                   uart_tx_data = store_data[7:0];
              end
              
            end

            i_sh: begin                                    // 2 bytes store
              alu_out = a + stimm;
              mem_addr  = {alu_out[31:1], 1'b0};           // alu_out[0] != 0, exception
              wmem = 4'b0011 << {alu_out[1], 1'b0};   // Which Byte position is it sorted to?
            end

            i_sw: begin                                    // 4 bytes store
              alu_out = a + stimm;
              mem_addr  = {alu_out[31:2], 2'b00};           // alu_out[1:0] != 0, exception
              wmem = 4'b1111;                         // Which Byte position is it sorted to?
            end

            i_beq: begin                                   // beq
              if (a == b) 
                next_pc = pc + broffset; 
            end

            i_bne: begin                                   // bne
              if (a != b) 
                next_pc = pc + broffset; 
            end

            i_blt: begin                                   // blt
              if ($signed(a) < $signed(b)) 
                next_pc = pc + broffset; 
            end

            i_bge: begin                                   // bge
              if ($signed(a) >= $signed(b)) 
                next_pc = pc + broffset; 
            end

            i_bltu: begin                                  // bltu
              if ({1'b0,a} < {1'b0,b}) 
                next_pc = pc + broffset; 
            end

            i_bgeu: begin                                  // bgeu
              if ({1'b0,a} >= {1'b0,b}) 
                next_pc = pc + broffset; 
            end

            i_auipc: begin                                 // auipc
              alu_out = pc + uimm;
              write_back = 1; 
            end
              
            i_lui: begin                                   // lui
              alu_out = uimm;
              write_back = 1; 
            end

            i_jal: begin                                   
              alu_out = pc_plus_4;                       // set pc+4 to link register
              write_back = 1;
              next_pc = pc + jaloffset; 
            end

            i_jalr: begin                                  
              alu_out = pc_plus_4;                       // set pc+4 to link register
              write_back = 1;
              next_pc = (a + simm) & 32'hfffffffe; 
            end

            default:;
 
        endcase
    end
endmodule
