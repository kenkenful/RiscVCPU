`define UART_TX_ADDR 32'h20020

module alu(
    a,
    b,
    pc,
    pc_plus,
    
    i_auipc ,
    i_lui   ,
    i_jal   ,
    i_jalr  ,
    i_beq   ,
    i_bne   ,
    i_blt   ,
    i_bge   ,
    i_bltu  ,
    i_bgeu  ,
    i_lb    ,
    i_lh    ,
    i_lw    ,
    i_lbu   ,
    i_lhu   ,
    i_sb    ,
    i_sh    ,
    i_sw    ,
    i_addi  ,
    i_slti  ,
    i_sltiu ,
    i_xori  ,
    i_ori   ,
    i_andi  ,
    i_slli  ,
    i_srli  ,
    i_srai  ,
    i_add   ,
    i_sub   ,
    i_sll   ,
    i_slt   ,
    i_sltu  ,
    i_xor   ,
    i_srl   ,
    i_sra   ,
    i_or    ,
    i_and   ,

    i_fence  ,
    i_fencei ,
    i_ecall  ,
    i_ebreak ,

    i_csrrw  ,
    i_csrrs  ,
    i_csrrc  ,
    i_csrrwi ,
    i_csrrsi ,
    i_csrrci ,

    i_mul    ,
    i_mulh   ,
    i_mulhsu ,
    i_mulhu  ,
    i_div    ,
    i_divu   ,
    i_rem    ,
    i_remu   ,
    
    shamt,
    broffset,
    simm,
    stimm,   
    uimm,   
    jaloffset,
    
    wmem,
    rmem,
    mem_addr,
    store_data,
    is_load,
    is_store,
    write_back,
    alu_out,
    
    jump_addr,
    jump_type,
    
    uart_en,
    uart_tx_data
    
    );

    input wire   [31:0] a;
    input wire   [31:0] b;
    input wire   [31:0] pc;
    input wire   [31:0] pc_plus;
    
    input wire i_auipc ;
    input wire i_lui   ;
    input wire i_jal   ;
    input wire i_jalr  ;
    input wire i_beq   ;
    input wire i_bne   ;
    input wire i_blt   ;
    input wire i_bge   ;
    input wire i_bltu  ;
    input wire i_bgeu  ;
    input wire i_lb    ;
    input wire i_lh    ;
    input wire i_lw    ;
    input wire i_lbu   ;
    input wire i_lhu   ;
    input wire i_sb    ;
    input wire i_sh    ;
    input wire i_sw    ;
    input wire i_addi  ;
    input wire i_slti  ;
    input wire i_sltiu ;
    input wire i_xori  ;
    input wire i_ori   ;
    input wire i_andi  ;
    input wire i_slli  ;
    input wire i_srli  ;
    input wire i_srai  ;
    input wire i_add   ;
    input wire i_sub   ;
    input wire i_sll   ;
    input wire i_slt   ;
    input wire i_sltu  ;
    input wire i_xor   ;
    input wire i_srl   ;
    input wire i_sra   ;
    input wire i_or    ;
    input wire i_and   ;

    input wire i_fence  ;
    input wire i_fencei ;
    input wire i_ecall  ;
    input wire i_ebreak ;
   
    // rv32 zicsr
    input wire i_csrrw  ;
    input wire i_csrrs  ;
    input wire i_csrrc  ;
    input wire i_csrrwi ;
    input wire i_csrrsi ;
    input wire i_csrrci ;

    // rv32m
    input wire i_mul    ;
    input wire i_mulh   ;
    input wire i_mulhsu ;
    input wire i_mulhu  ;
    input wire i_div    ;
    input wire i_divu   ;
    input wire i_rem    ;
    input wire i_remu   ;
    
    
    input reg [4:0] shamt;
    input reg [31:0] broffset;
    input reg [31:0] simm; 
    input reg [31:0] stimm;   
    input reg [31:0] uimm;   
    input reg [31:0] jaloffset;
    
    output reg [3:0] wmem;
    output reg [4:0] rmem;
    output reg [31:0] mem_addr;
    output reg [31:0] store_data;
    
    reg [63:0] mul;   
    output reg is_load;
    output reg is_store;
    
    output reg write_back;             // 
    output reg [31:0] alu_out;         // alu output
    
    output reg [31:0] jump_addr;
    output reg [1:0]  jump_type;     //   00: non jump     01: non conditional jump      10 : conditional jump
   
    
    output reg uart_en;
    output reg [7:0] uart_tx_data;
    

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
                alu_out = $signed($signed(a) / $signed(b));
                write_back = 1;
            end
            
            i_divu:begin
                alu_out = a / b;
                write_back = 1;
            end
            
            i_rem:begin
                alu_out = $signed($signed(a) % $signed(b));
                write_back = 1;
            end
            
            i_remu:begin
                alu_out = a % b;
                write_back = 1;
            end
            default:;
 
        endcase
    end


endmodule