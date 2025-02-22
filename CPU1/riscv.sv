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
    

    wire [31:0] inst;
    reg [3:0] wmem;
    reg [4:0] rmem;
    reg [31:0] mem_addr;
    reg [31:0] store_data;
    wire [31:0] load_data;

    reg [31:0] pc;              // program counter
    reg [31:0] jump_addr;
    reg [1:0]  jump_type;     //   00: non jump     01: non conditional jump      10 : conditional jump
          
    wire [31:0] pc_plus = pc + 4;
    wire [31:0] next_pc = (jump_type == 2'b00) ? pc_plus : jump_addr;
    
    // pc
    always_ff @ (posedge clk) begin
        if (reset) pc <= 0;
        else       pc <= next_pc;
    end
    
    mem mem0(
        .clk(clk),
        .pc(pc),
        .inst(inst),
        .wmem(wmem),
        .rmem(rmem),
        .mem_addr(mem_addr),
        .store_data(store_data),
        .load_data(load_data)
    );
    
    // fetch
    //wire [31:0] inst = mem[pc[31:2]];

    // decode
    wire [6:0] opcode = inst[6:0];  
    wire [2:0] funct3  = inst[14:12]; 
    wire [6:0] funct7  = inst[31:25]; 
    wire [4:0] rd     = inst[11:7];  
    wire [4:0] rs1     = inst[19:15]; 
    wire [4:0] rs2     = inst[24:20]; 
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

    wire i_auipc = (opcode == 7'b0010111);
    wire i_lui   = (opcode == 7'b0110111);
    wire i_jal   = (opcode == 7'b1101111);
    wire i_jalr  = (opcode == 7'b1100111) & (funct3 == 3'b000);
    wire i_beq   = (opcode == 7'b1100011) & (funct3 == 3'b000);
    wire i_bne   = (opcode == 7'b1100011) & (funct3 == 3'b001);
    wire i_blt   = (opcode == 7'b1100011) & (funct3 == 3'b100);
    wire i_bge   = (opcode == 7'b1100011) & (funct3 == 3'b101);
    wire i_bltu  = (opcode == 7'b1100011) & (funct3 == 3'b110);
    wire i_bgeu  = (opcode == 7'b1100011) & (funct3 == 3'b111);
    wire i_lb    = (opcode == 7'b0000011) & (funct3 == 3'b000);
    wire i_lh    = (opcode == 7'b0000011) & (funct3 == 3'b001);
    wire i_lw    = (opcode == 7'b0000011) & (funct3 == 3'b010);
    wire i_lbu   = (opcode == 7'b0000011) & (funct3 == 3'b100);
    wire i_lhu   = (opcode == 7'b0000011) & (funct3 == 3'b101);
    wire i_sb    = (opcode == 7'b0100011) & (funct3 == 3'b000);
    wire i_sh    = (opcode == 7'b0100011) & (funct3 == 3'b001);
    wire i_sw    = (opcode == 7'b0100011) & (funct3 == 3'b010);
    wire i_addi  = (opcode == 7'b0010011) & (funct3 == 3'b000);
    wire i_slti  = (opcode == 7'b0010011) & (funct3 == 3'b010);
    wire i_sltiu = (opcode == 7'b0010011) & (funct3 == 3'b011);
    wire i_xori  = (opcode == 7'b0010011) & (funct3 == 3'b100);
    wire i_ori   = (opcode == 7'b0010011) & (funct3 == 3'b110);
    wire i_andi  = (opcode == 7'b0010011) & (funct3 == 3'b111);
    wire i_slli  = (opcode == 7'b0010011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
    wire i_srli  = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
    wire i_srai  = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
    wire i_add   = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000000);
    wire i_sub   = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0100000);
    wire i_sll   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
    wire i_slt   = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000000);
    wire i_sltu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000000);
    wire i_xor   = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000000);
    wire i_srl   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
    wire i_sra   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
    wire i_or    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000000);
    wire i_and   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000000);
    
    wire i_fence  = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (inst[31:28] == 4'b0000);
    wire i_fencei = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b001) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
    wire i_ecall  = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
    wire i_ebreak = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000001);
   
    // rv32 zicsr
    wire i_csrrw  = (opcode == 7'b1110011) && (funct3 == 3'b001);
    wire i_csrrs  = (opcode == 7'b1110011) && (funct3 == 3'b010);
    wire i_csrrc  = (opcode == 7'b1110011) && (funct3 == 3'b011);
    wire i_csrrwi = (opcode == 7'b1110011) && (funct3 == 3'b101);
    wire i_csrrsi = (opcode == 7'b1110011) && (funct3 == 3'b110);
    wire i_csrrci = (opcode == 7'b1110011) && (funct3 == 3'b111);

    // rv32m
    wire i_mul    = (opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0000001);
    wire i_mulh   = (opcode == 7'b0110011) && (funct3 == 3'b001) && (funct7 == 7'b0000001);
    wire i_mulhsu = (opcode == 7'b0110011) && (funct3 == 3'b010) && (funct7 == 7'b0000001);
    wire i_mulhu  = (opcode == 7'b0110011) && (funct3 == 3'b011) && (funct7 == 7'b0000001);
    wire i_div    = (opcode == 7'b0110011) && (funct3 == 3'b100) && (funct7 == 7'b0000001);
    wire i_divu   = (opcode == 7'b0110011) && (funct3 == 3'b101) && (funct7 == 7'b0000001);
    wire i_rem    = (opcode == 7'b0110011) && (funct3 == 3'b110) && (funct7 == 7'b0000001);
    wire i_remu   = (opcode == 7'b0110011) && (funct3 == 3'b111) && (funct7 == 7'b0000001);

    reg    [31:0] regfile [1:31];                          //  regfile[0] is zero register.
   
    wire   [31:0] a = (rs1==0) ? 0 : regfile[rs1];           //  index 0 is zero register, so return 0. 
    wire   [31:0] b = (rs2==0) ? 0 : regfile[rs2];           //  index 0 is zero register, so return 0.
    
    // execute
    //reg [31:0] store_data;      // store data
    //reg [31:0] mem_addr;        // load/store address
    //reg [3:0] wmem;             // write memory byte enables
    //reg [4:0] rmem;
    
    reg [63:0] mul;   
    reg is_load;
    reg is_store;
    
    reg write_back;             // 
    reg [31:0] alu_out;         // alu output
    
    always_comb begin                                      
        alu_out = 0;                                       // alu output
        mem_addr  = 0;                                     // memory address
        write_back = 0;                                    // write regfile
        wmem = 0;                                    // write memory (sw)
        rmem = 0;
        store_data = b;                                    // store data
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load = 0;
        is_store = 0;
        jump_type = 0;
        
        case (1'b1)
            i_add: begin                                   // add
              alu_out = a + b;
              write_back = 1; 
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
              if ($signed(a) < $signed(b)) alu_out = 1; 
            end

            i_sltu: begin                                  // sltu
              if ({1'b0,a} < {1'b0,b}) alu_out = 1; 
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
              if ($signed(a) < $signed(simm)) alu_out = 1; 
            end

            i_sltiu: begin                                 // sltiu
              if ({1'b0,a} < {1'b0,simm}) 
                alu_out = 1; 
                end

            i_lw: begin                                    // load 4bytes
              alu_out = a + simm;                        
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = 5'b01111;                             
              write_back = 1;
              is_load = 1'b1;                       
            end               

            i_lbu: begin                                   // load 1byte unsigned
              alu_out = a + simm;                        
              mem_addr  = {2'b0, alu_out[31:2]};              
              rmem = 5'b00001 << alu_out[1:0];
              write_back = 1;
              is_load = 1'b1;                     
            end

            i_lb: begin                                     // load 1byte
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00001 << alu_out[1:0]) | 5'b10000;
              write_back = 1; 
              is_load = 1'b1;                   
            end

            i_lhu: begin                                    // load 2bytes unsigned
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = 5'b00011 << {alu_out[1],1'b0}; 
              write_back = 1; 
              is_load = 1'b1;                   
            end

            i_lh: begin                                     // load 2bytes 
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00011 << {alu_out[1],1'b0}) | 5'b10000; 
              write_back = 1; 
              is_load = 1'b1;                 
            end

            i_sb: begin                                    // 1 byte store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem    = 4'b0001 << alu_out[1:0];         // Which Byte position is it stored to?
              is_store = 1'b1;
              
              if(alu_out == `UART_TX_ADDR) begin
                   uart_en = 1'b1;
                   uart_tx_data = store_data[7:0];
              end
            end

            i_sh: begin                                    // 2 bytes store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b0011 << {alu_out[1], 1'b0};        // Which Byte position is it sorted to?
              is_store = 1'b1;
            end

            i_sw: begin                                    // 4 bytes store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b1111;                              // Which Byte position is it sorted to?
              is_store = 1'b1;
            end

            i_beq: begin                                   // beq
              if (a == b) begin
                alu_out = 1;
                jump_type = 2'b10;
                jump_addr = pc + broffset; 
              end
            end

            i_bne: begin                                   // bne
              if (a != b)begin
               alu_out = 1;
               jump_type = 2'b10;
               jump_addr = pc + broffset; 
              end
            end

            i_blt: begin                                   // blt
              if ($signed(a) < $signed(b))begin
                alu_out = 1;
                jump_type = 2'b10;
                jump_addr = pc + broffset; 
              end
            end

            i_bge: begin                                   // bge
              if ($signed(a) >= $signed(b))begin
                alu_out = 1;
                jump_type = 2'b10;
                jump_addr = pc + broffset; 
              end
            end

            i_bltu: begin                                  // bltu
              if ({1'b0,a} < {1'b0,b})begin
                alu_out = 1;
                jump_type = 2'b10;
                jump_addr = pc + broffset;
              end
               
            end

            i_bgeu: begin                                  // bgeu
              if ({1'b0,a} >= {1'b0,b})begin
                 alu_out = 1;
                jump_type = 2'b10;
                jump_addr = pc + broffset;
               end
               
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
              alu_out = pc_plus;                       // set pc+4 to link register
              write_back = 1;
              jump_addr = pc + jaloffset; 
              jump_type = 2'b01;
            end

            i_jalr: begin                                  
              alu_out = pc_plus;                       // set pc+4 to link register
              write_back = 1;
              jump_addr = (a + simm) & 32'hfffffffe; 
              jump_type = 2'b01;
            end
            
            i_mul: begin
                mul = $signed(a) * $signed(b);
                alu_out = mul[31:0]; 
                write_back = 1;
            end
            
            i_mulh:begin
                mul = $signed($signed(a) * $signed(b));
                alu_out = mul[63:32]; 
                write_back = 1;
                
            end
            
            i_mulhsu:begin
                mul = $signed($signed(a) * $signed({1'b0, b}));
                alu_out = mul[63:32];
                write_back = 1;
            end
            
            i_mulhu:begin
                mul = a * b;
                alu_out = mul[63:32];
                write_back = 1;
            end
            
            i_div:begin
                alu_out = $signed($signed(rs1) / $signed(rs2));
                write_back = 1;
            end
            
            i_divu:begin
                alu_out = rs1 / rs2;
                write_back = 1;
            end
            
            i_rem:begin
                alu_out = $signed($signed(rs1) % $signed(rs2));
                write_back = 1;
            end
            
            i_remu:begin
                alu_out = rs1 % rs2;
                write_back = 1;
            end
            default:;
 
        endcase
    end

    wire [31:0] write_back_data = is_load ? load_data : alu_out;

    // write back
    always_ff @ (posedge clk) begin
        if (write_back && (rd != 0)) begin                 // rd = 0 is zero register, so cannot write back.
            regfile[rd] <= write_back_data;                 
        end
    end

endmodule