`default_nettype none
`include "define.sv"

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
    
    reg [31:0] pc;        
    reg [31:0] jump_addr;
    reg  is_jump;
    reg  is_stoll;
          
    wire [31:0] pc_plus = pc + 4;
    wire [31:0] next_pc = (is_jump) ? jump_addr : pc_plus ;
    
    // pc
    always_ff @ (posedge clk) begin
        if (reset) pc <= 0;
        else if(is_stoll) pc <= pc;
        else       pc <= next_pc;
    end
   
    // fetch 
    imem imem0(
        .clk(clk),
        .is_jump(is_jump),
        .is_stoll(is_stoll),
        .pc(pc),
        .inst(inst)   // FETCH/DECODE pipline      
    );

    //FETCH/DECODE pipeline reg
    always_ff@(posedge clk)begin
      if(is_jump)begin
        pc_de <= 0;
        pc_plus_de <= 0;
      end else if(is_stoll)begin
        pc_de <= pc_de;
        pc_plus_de <= pc_plus_de;
      end else begin
        pc_de <= pc;
        pc_plus_de <= pc_plus;
      end
    end

    reg [31:0] inst;
    reg [31:0] pc_de;
    reg [31:0] pc_plus_de;

    reg [31:0]  a;
    reg [31:0]  b;
    reg [31:0]  jaloffset;
    reg [31:0]  broffset;
    reg [4:0]   shamt; 
    reg [31:0]  simm;
    reg [31:0]  uimm; 
    reg [31:0]  stimm; 

    reg [4:0]  rd;

    reg i_auipc ;
    reg i_lui   ;
    reg i_jal   ;
    reg i_jalr  ;
    reg i_beq   ;
    reg i_bne   ;
    reg i_blt   ;
    reg i_bge   ;
    reg i_bltu  ;
    reg i_bgeu  ;
    reg i_lb    ;
    reg i_lh    ;
    reg i_lw    ;
    reg i_lbu   ;
    reg i_lhu   ;
    reg i_sb    ;
    reg i_sh    ;
    reg i_sw    ;
    reg i_addi  ;
    reg i_slti  ;
    reg i_sltiu ;
    reg i_xori  ;
    reg i_ori   ;
    reg i_andi  ;
    reg i_slli  ;
    reg i_srli  ;
    reg i_srai  ;
    reg i_add   ;
    reg i_sub   ;
    reg i_sll   ;
    reg i_slt   ;
    reg i_sltu  ;
    reg i_xor   ;
    reg i_srl   ;
    reg i_sra   ;
    reg i_or    ;
    reg i_and   ;
    reg i_fence ;
    reg i_fencei;
    reg i_ecall ;
    reg i_ebreak;  
    reg i_csrrw ;
    reg i_csrrs ;
    reg i_csrrc ;
    reg i_csrrwi;
    reg i_csrrsi;
    reg i_csrrci;
    reg i_mul   ;
    reg i_mulh  ;
    reg i_mulhsu;
    reg i_mulhu ;
    reg i_div   ;
    reg i_divu  ;
    reg i_rem   ;
    reg i_remu  ;
  
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7; 
    reg sign;        
    reg [11:0] imm;  
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [4:0] rd;

    reg  [31:0] regfile [1:31];                          //  regfile[0] is zero register.

    always_comb begin
        opcode    = inst[6:0];  
        funct3    = inst[14:12];
        funct7    = inst[31:25];
        sign      = inst[31];
        imm       = inst[31:20];
        
        rs1       = inst[19:15];
        rs2       = inst[24:20];
        rd        = inst[11:7];
        broffset  = {{19{sign}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
        simm      = {{20{sign}}, inst[31:20]};                                   
        stimm     = {{20{sign}}, inst[31:25], inst[11:7]};                        
        uimm      = {inst[31:12],12'h0};                                          
        shamt     = inst[24:20]; 
        jaloffset = {{11{sign}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; 

        // forwarding 
        a = (rs1 == 0) ? 0 : regfile[rs1]; 
        b = (rs2 == 0) ? 0 : regfile[rs2];  

        i_auipc  = (opcode == 7'b0010111);
        i_lui    = (opcode == 7'b0110111);
        i_jal    = (opcode == 7'b1101111);
        i_jalr   = (opcode == 7'b1100111) & (funct3 == 3'b000);
        i_beq    = (opcode == 7'b1100011) & (funct3 == 3'b000);
        i_bne    = (opcode == 7'b1100011) & (funct3 == 3'b001);
        i_blt    = (opcode == 7'b1100011) & (funct3 == 3'b100);
        i_bge    = (opcode == 7'b1100011) & (funct3 == 3'b101);
        i_bltu   = (opcode == 7'b1100011) & (funct3 == 3'b110);
        i_bgeu   = (opcode == 7'b1100011) & (funct3 == 3'b111);
        i_lb     = (opcode == 7'b0000011) & (funct3 == 3'b000);
        i_lh     = (opcode == 7'b0000011) & (funct3 == 3'b001);
        i_lw     = (opcode == 7'b0000011) & (funct3 == 3'b010);
        i_lbu    = (opcode == 7'b0000011) & (funct3 == 3'b100);
        i_lhu    = (opcode == 7'b0000011) & (funct3 == 3'b101);
        i_sb     = (opcode == 7'b0100011) & (funct3 == 3'b000);
        i_sh     = (opcode == 7'b0100011) & (funct3 == 3'b001);
        i_sw     = (opcode == 7'b0100011) & (funct3 == 3'b010);
        i_addi   = (opcode == 7'b0010011) & (funct3 == 3'b000);
        i_slti   = (opcode == 7'b0010011) & (funct3 == 3'b010);
        i_sltiu  = (opcode == 7'b0010011) & (funct3 == 3'b011);
        i_xori   = (opcode == 7'b0010011) & (funct3 == 3'b100);
        i_ori    = (opcode == 7'b0010011) & (funct3 == 3'b110);
        i_andi   = (opcode == 7'b0010011) & (funct3 == 3'b111);
        i_slli   = (opcode == 7'b0010011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        i_srli   = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        i_srai   = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        i_add    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000000);
        i_sub    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0100000);
        i_sll    = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        i_slt    = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000000);
        i_sltu   = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000000);
        i_xor    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000000);
        i_srl    = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        i_sra    = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        i_or     = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000000);
        i_and    = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000000);
        i_fence  = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (inst[31:28] == 4'b0000);
        i_fencei = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b001) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        i_ecall  = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        i_ebreak = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000001);
        i_csrrw  = (opcode == 7'b1110011) & (funct3 == 3'b001);
        i_csrrs  = (opcode == 7'b1110011) & (funct3 == 3'b010);
        i_csrrc  = (opcode == 7'b1110011) & (funct3 == 3'b011);
        i_csrrwi = (opcode == 7'b1110011) & (funct3 == 3'b101);
        i_csrrsi = (opcode == 7'b1110011) & (funct3 == 3'b110);
        i_csrrci = (opcode == 7'b1110011) & (funct3 == 3'b111);
        i_mul    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000001);
        i_mulh   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000001);
        i_mulhsu = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000001);
        i_mulhu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000001);
        i_div    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000001);
        i_divu   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000001);
        i_rem    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000001);
        i_remu   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000001);
    end

    // EXECUTE STATGE
    reg [31:0] pc_ex;
    reg [31:0] pc_plus_ex;

    // output
    reg [63:0] mul;     
    reg is_load;
    reg is_store;
    reg is_write_back;             
    reg [31:0] alu_out;         
    reg [3:0] wmem;
    reg [4:0] rmem;
    reg [31:0] mem_addr;
    reg [31:0] store_data;
    
    always_comb begin                                      
        alu_out = 0;                                             
        mem_addr  = 0;                                     
        is_write_back = 0;                                    
        wmem = 0;                                          
        rmem = 0;
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load = 0;
        is_store = 0;
        is_jump = 0;
        is_stoll = 0;
        store_data = b;     
        pc_ex = pc_de;
        pc_plus_ex = pc_plus_de;                               
        
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
                jump_addr = pc_ex + broffset; 
              end
            end

            i_bne: begin                                   // bne
              if (a != b)begin
               alu_out = 1;
               is_jump = 1;
               jump_addr = pc_ex + broffset; 
              end
            end

            i_blt: begin                                   // blt
              if ($signed(a) < $signed(b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset; 
              end
            end

            i_bge: begin                                   // bge
              if ($signed(a) >= $signed(b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset; 
              end
            end

            i_bltu: begin                                  // bltu
              if ({1'b0,a} < {1'b0,b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset;
              end
               
            end

            i_bgeu: begin                                  // bgeu
              if ({1'b0,a} >= {1'b0,b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset;
               end
            end

            i_auipc: begin                                 // auipc
              alu_out = pc_ex + uimm;
              is_write_back = 1; 
            end
              
            i_lui: begin                                   // lui
              alu_out = uimm;
              is_write_back = 1; 
            end

            i_jal: begin                                   
              alu_out = pc_plus_ex;                       // set pc+4 to link register
              is_write_back = 1;
              jump_addr = pc_ex + jaloffset; 
              is_jump = 1;
            end

            i_jalr: begin                                  
              alu_out = pc_plus_ex;                       // set pc+4 to link register
              is_write_back = 1;
              jump_addr = (a + simm) & 32'hfffffffe; 
              is_jump = 1;
            end
            
            i_mul: begin
                mul = $signed(a) * $signed(b);
                alu_out = mul[31:0]; 
                is_write_back = 1;
            end
            
            i_mulh: begin
                mul = $signed($signed(a) * $signed(b));
                alu_out = mul[63:32]; 
                is_write_back = 1;
                
            end
            
            i_mulhsu: begin
                mul = $signed($signed(a) * $signed({1'b0, b}));
                alu_out = mul[63:32];
                is_write_back = 1;
            end
            
            i_mulhu: begin
                mul = a * b;
                alu_out = mul[63:32];
                is_write_back = 1;
            end
            
            i_div: begin
                alu_out = $signed($signed(a) / $signed(b));
                is_write_back = 1;
            end
            
            i_divu: begin
                alu_out = a / b;
                is_write_back = 1;
            end
            
            i_rem: begin
                alu_out = $signed($signed(a) % $signed(b));
                is_write_back = 1;
            end
            
            i_remu: begin
                alu_out = a % b;
                is_write_back = 1;
            end
            default:;
 
        endcase
    end
    
    // MEM STAGE
    wire [31:0] mem_out;
    reg [31:0] load_data;

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

    // WRITE BACK STAGE
    wire [31:0] write_back_data = is_load ? load_data : alu_out;

    always_ff @ (posedge clk) begin
        if (is_write_back && (rd != 0)) begin                 // rd_de = 0 is zero register, so cannot write back.
            regfile[rd] <= write_back_data;                 
        end
    end

endmodule
