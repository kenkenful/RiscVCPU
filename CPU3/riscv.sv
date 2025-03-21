`default_nettype none

`define UART_TX_ADDR 32'h20020

module riscv(
      clk,
      reset,
      uart_en,
      uart_tx_data
    );

    input wire clk;              
    input wire reset;           
    output reg uart_en;
    output reg [7:0] uart_tx_data;
    
    wire [31:0] inst;
    reg [3:0] wmem;
    reg [4:0] rmem;
    reg [31:0] mem_addr;
    reg [31:0] store_data;
    reg [31:0] load_data;

    reg [31:0] pc;   
    reg [31:0] jump_addr;
    reg is_jump;     
          
    wire [31:0] pc_plus = pc + 4;
    wire [31:0] next_pc = (is_jump == 0) ? pc_plus : jump_addr;
    
    // pc
    always_ff @ (posedge clk) begin
        if (reset) pc <= 0;
        else       pc <= next_pc;
    end
   
    // fetch 
    imem imem0(
        .clk(clk),
        .pc(pc),
        .inst(inst)
    );

    // decode
    wire [6:0] opcode = inst[6:0];  
    wire [2:0] funct3 = inst[14:12]; 
    wire [6:0] funct7 = inst[31:25]; 
    wire [4:0] rd     = inst[11:7];  
    wire [4:0] rs1    = inst[19:15]; 
    wire [4:0] rs2    = inst[24:20]; 
    wire [4:0] shamt  = inst[24:20]; 
    wire sign         = inst[31];
    wire [11:0] imm   = inst[31:20];

    wire   [31:0] broffset  = {{19{sign}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};   
    wire   [31:0] simm      = {{20{sign}}, inst[31:20]};                                    
    wire   [31:0] stimm     = {{20{sign}}, inst[31:25], inst[11:7]};                         
    wire   [31:0] uimm      = {inst[31:12], 12'h0};                                         
    wire   [31:0] jaloffset = {{11{sign}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; 

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
    wire i_csrrw  = (opcode == 7'b1110011) & (funct3 == 3'b001);
    wire i_csrrs  = (opcode == 7'b1110011) & (funct3 == 3'b010);
    wire i_csrrc  = (opcode == 7'b1110011) & (funct3 == 3'b011);
    wire i_csrrwi = (opcode == 7'b1110011) & (funct3 == 3'b101);
    wire i_csrrsi = (opcode == 7'b1110011) & (funct3 == 3'b110);
    wire i_csrrci = (opcode == 7'b1110011) & (funct3 == 3'b111);

    // rv32m
    wire i_mul    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000001);
    wire i_mulh   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000001);
    wire i_mulhsu = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000001);
    wire i_mulhu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000001);
    wire i_div    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000001);
    wire i_divu   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000001);
    wire i_rem    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000001);
    wire i_remu   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000001);

    reg    [31:0] regfile [1:31];                          //  regfile[0] is zero register.
   
    wire   [31:0] a = (rs1==0) ? 0 : regfile[rs1];           //  index 0 is zero register, so return 0. 
    wire   [31:0] b = (rs2==0) ? 0 : regfile[rs2];           //  index 0 is zero register, so return 0.
    
    // execute
    reg [63:0] mul;   
    reg is_load;
    reg is_store;
    
    reg is_write_back;           
    reg [31:0] alu_out;         
    
    always_comb begin                                      
        alu_out = 0;                                
        mem_addr  = 0;                              
        is_write_back = 0;                          
        wmem = 0;                                   
        rmem = 0;
        store_data = b;                             
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load = 0;
        is_store = 0;
        is_jump = 0;
        
        case (1'b1)
            i_add: begin                                   // add
              alu_out = a + b;
              is_write_back = 1; 
            end                           

            i_sub: begin                                   // sub
              alu_out = a - b;
              is_write_back = 1;                  
            end                         

            i_and: begin                                   // and
              alu_out = a & b;
              is_write_back = 1;                  
            end                          

            i_or: begin                                    // or
              alu_out = a | b;
              is_write_back = 1; 
            end

            i_xor: begin                                   // xor
              alu_out = a ^ b;
              is_write_back = 1;   
            end
            
            i_sll: begin                                   // sll
              alu_out = a << b[4:0];
              is_write_back = 1; 
            end

            i_srl: begin                                   // srl
              alu_out = a >> b[4:0];
              is_write_back = 1; 
            end

            i_sra: begin                                   // sra
              alu_out = $signed(a) >>> b[4:0];
              is_write_back = 1; 
            end

            i_slli: begin                                  // slli
              alu_out = a << shamt;
              is_write_back = 1; 
            end

            i_srli: begin                                  // srli
              alu_out = a >> shamt;
              is_write_back = 1; 
            end

            i_srai: begin                                  // srai
              alu_out = $signed(a) >>> shamt;
              is_write_back = 1; 
            end

            i_slt: begin                                   // slt
              if ($signed(a) < $signed(b)) alu_out = 1; 
            end

            i_sltu: begin                                  // sltu
              if ({1'b0,a} < {1'b0,b}) alu_out = 1; 
            end

            i_addi: begin                                  // addi
              alu_out = a + simm;
              is_write_back = 1; 
            end

            i_andi: begin                                  // andi
              alu_out = a & simm;
              is_write_back = 1; 
            end

            i_ori: begin                                   // ori
              alu_out = a | simm;
              is_write_back = 1; 
            end

            i_xori: begin                                  // xori
              alu_out = a ^ simm;
              is_write_back = 1; 
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
              is_write_back = 1;
              is_load = 1;                       
            end               

            i_lbu: begin                                   // load 1byte unsigned
              alu_out = a + simm;                        
              mem_addr  = {2'b0, alu_out[31:2]};              
              rmem = 5'b00001 << alu_out[1:0];
              is_write_back = 1;
              is_load = 1;                     
            end

            i_lb: begin                                     // load 1byte
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00001 << alu_out[1:0]) | 5'b10000;
              is_write_back = 1; 
              is_load = 1;                   
            end

            i_lhu: begin                                    // load 2bytes unsigned
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = 5'b00011 << {alu_out[1],1'b0}; 
              is_write_back = 1; 
              is_load = 1;                   
            end

            i_lh: begin                                     // load 2bytes 
              alu_out = a + simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00011 << {alu_out[1],1'b0}) | 5'b10000; 
              is_write_back = 1; 
              is_load = 1;                 
            end

            i_sb: begin                                    // 1 byte store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem    = 4'b0001 << alu_out[1:0];         // Which Byte position is it stored to?
              is_store = 1;

              case(wmem)
                4'b0001: store_data = {24'b0, b[7:0]};
                4'b0010: store_data = {16'b0, b[7:0], 8'b0};
                4'b0100: store_data = {8'b0, b[7:0], 16'b0};
                4'b1000: store_data = {b[7:0], 24'b0};
                default: store_data = 0;
              endcase
              
              if(alu_out == `UART_TX_ADDR) begin
                   uart_en = 1;
                   uart_tx_data = store_data[7:0];
              end
            end

            i_sh: begin                                    // 2 bytes store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b0011 << {alu_out[1], 1'b0};        // Which Byte position is it sorted to?
              is_store = 1;

              case(wmem)
                4'b0011: store_data = {16'b0, b[15:0]};
                4'b1100: store_data = {b[15:0],16'b0};   
                default: store_data = 0;
              endcase
            end

            i_sw: begin                                    // 4 bytes store
              alu_out = a + stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b1111;                              // Which Byte position is it sorted to?
              is_store = 1;
            end

            i_beq: begin                                   // beq
              if (a == b) begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc + broffset; 
              end
            end

            i_bne: begin                                   // bne
              if (a != b)begin
               alu_out = 1;
               is_jump = 1;
               jump_addr = pc + broffset; 
              end
            end

            i_blt: begin                                   // blt
              if ($signed(a) < $signed(b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc + broffset; 
              end
            end

            i_bge: begin                                   // bge
              if ($signed(a) >= $signed(b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc + broffset; 
              end
            end

            i_bltu: begin                                  // bltu
              if ({1'b0,a} < {1'b0,b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc + broffset;
              end
               
            end

            i_bgeu: begin                                  // bgeu
              if ({1'b0,a} >= {1'b0,b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc + broffset;
               end
               
            end

            i_auipc: begin                                 // auipc
              alu_out = pc + uimm;
              is_write_back = 1; 
            end
              
            i_lui: begin                                   // lui
              alu_out = uimm;
              is_write_back = 1; 
            end

            i_jal: begin                                   
              alu_out = pc_plus;                       // set pc+4 to link register
              is_write_back = 1;
              jump_addr = pc + jaloffset; 
              is_jump = 1;
            end

            i_jalr: begin                                  
              alu_out = pc_plus;                       // set pc+4 to link register
              is_write_back = 1;
              jump_addr = (a + simm) & 32'hfffffffe; 
              is_jump = 1;
            end
            
            i_mul: begin
                mul = $signed(a) * $signed(b);
                alu_out = mul[31:0]; 
                is_write_back = 1;
            end
            
            i_mulh:begin
                mul = $signed($signed(a) * $signed(b));
                alu_out = mul[63:32]; 
                is_write_back = 1;
                
            end
            
            i_mulhsu:begin
                mul = $signed($signed(a) * $signed({1'b0, b}));
                alu_out = mul[63:32];
                is_write_back = 1;
            end
            
            i_mulhu:begin
                mul = a * b;
                alu_out = mul[63:32];
                is_write_back = 1;
            end
            
            i_div:begin
                alu_out = $signed($signed(a) / $signed(b));
                is_write_back = 1;
            end
            
            i_divu:begin
                alu_out = a / b;
                is_write_back = 1;
            end
            
            i_rem:begin
                alu_out = $signed($signed(a) % $signed(b));
                is_write_back = 1;
            end
            
            i_remu:begin
                alu_out = a % b;
                is_write_back = 1;
            end
            default:;
 
        endcase
    end
    
    wire [31:0] mem_out;

    // store/load
    dmem dmem0(
        .clk(clk),
        .is_store(is_store),
        .is_load(is_load),
        .mem_addr(mem_addr),
        .store_data(store_data),
        .load_data(mem_out)
    );

    always_comb begin
      case (rmem) 
        // unsgigned 1 byte
        5'b00001: load_data = {24'h0, mem_out[7:0]};
        5'b00010: load_data = {24'h0, mem_out[15:8]};
        5'b00100: load_data = {24'h0, mem_out[23:16]};
        5'b01000: load_data = {24'h0, mem_out[31:24]};
        // signed 1 byte
        5'b10001: load_data = {{24{mem_out[7]}},  mem_out[7:0]};
        5'b10010: load_data = {{24{mem_out[15]}}, mem_out[15:8]};
        5'b10100: load_data = {{24{mem_out[23]}}, mem_out[23:16]};
        5'b11000: load_data = {{24{mem_out[31]}}, mem_out[31:24]};
        // unsigned 2 bytes
        5'b00011: load_data = {16'h0, mem_out[15:0]};  
        5'b01100: load_data = {16'h0, mem_out[31:16]}; 
        // signed 2 bytes
        5'b10011: load_data = {{16{mem_out[15]}}, mem_out[15:0]};  
        5'b11100: load_data = {{16{mem_out[31]}}, mem_out[31:16]}; 
        // 4 bytes
        5'b01111: load_data = mem_out;
        default: load_data = 0;    
      endcase
    end

    // write back
    wire [31:0] write_back_data = is_load ? load_data : alu_out;

    always_ff @ (posedge clk) begin
        if (is_write_back && (rd != 0)) begin                 // rd = 0 is zero register, so cannot write back.
            regfile[rd] <= write_back_data;                 
        end
    end

endmodule
