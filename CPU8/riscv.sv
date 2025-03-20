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

    // DECODE STAGE
    de_ex_pipeline_reg de;

    reg [31:0] a_de;
    reg [31:0] b_de;
    reg [31:0] jaloffset_de;
    reg [31:0] broffset_de;
    reg [4:0]  shamt_de; 
    reg [31:0] simm_de;
    reg [31:0] uimm_de; 
    reg [31:0] stimm_de; 
    reg [4:0]  rd_de;
    reg [4:0]  rs1_de;
    reg [4:0]  rs2_de;

    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7; 
    reg sign;        
    reg [11:0] imm;  

    reg  [31:0] regfile [1:31];                          //  regfile[0] is zero register.

    always_comb begin
        opcode    = inst[6:0];  
        funct3    = inst[14:12];
        funct7    = inst[31:25];
        sign      = inst[31];
        imm       = inst[31:20];
        
        rs1_de       = inst[19:15];
        rs2_de       = inst[24:20];
        rd_de        = inst[11:7];
        broffset_de  = {{19{sign}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
        simm_de      = {{20{sign}}, inst[31:20]};                                   
        stimm_de     = {{20{sign}}, inst[31:25], inst[11:7]};                        
        uimm_de      = {inst[31:12],12'h0};                                          
        shamt_de     = inst[24:20]; 
        jaloffset_de = {{11{sign}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; // jal

        // forwarding 
        a_de = (rs1_de == 0) ? 0 : (is_write_back_wb & (rd_wb == rs1_de)) ? write_back_data : regfile[rs1_de]; 
        b_de = (rs2_de == 0) ? 0 : (is_write_back_wb & (rd_wb == rs2_de)) ? write_back_data : regfile[rs2_de];  

        de.i_auipc  = (opcode == 7'b0010111);
        de.i_lui    = (opcode == 7'b0110111);
        de.i_jal    = (opcode == 7'b1101111);
        de.i_jalr   = (opcode == 7'b1100111) & (funct3 == 3'b000);
        de.i_beq    = (opcode == 7'b1100011) & (funct3 == 3'b000);
        de.i_bne    = (opcode == 7'b1100011) & (funct3 == 3'b001);
        de.i_blt    = (opcode == 7'b1100011) & (funct3 == 3'b100);
        de.i_bge    = (opcode == 7'b1100011) & (funct3 == 3'b101);
        de.i_bltu   = (opcode == 7'b1100011) & (funct3 == 3'b110);
        de.i_bgeu   = (opcode == 7'b1100011) & (funct3 == 3'b111);
        de.i_lb     = (opcode == 7'b0000011) & (funct3 == 3'b000);
        de.i_lh     = (opcode == 7'b0000011) & (funct3 == 3'b001);
        de.i_lw     = (opcode == 7'b0000011) & (funct3 == 3'b010);
        de.i_lbu    = (opcode == 7'b0000011) & (funct3 == 3'b100);
        de.i_lhu    = (opcode == 7'b0000011) & (funct3 == 3'b101);
        de.i_sb     = (opcode == 7'b0100011) & (funct3 == 3'b000);
        de.i_sh     = (opcode == 7'b0100011) & (funct3 == 3'b001);
        de.i_sw     = (opcode == 7'b0100011) & (funct3 == 3'b010);
        de.i_addi   = (opcode == 7'b0010011) & (funct3 == 3'b000);
        de.i_slti   = (opcode == 7'b0010011) & (funct3 == 3'b010);
        de.i_sltiu  = (opcode == 7'b0010011) & (funct3 == 3'b011);
        de.i_xori   = (opcode == 7'b0010011) & (funct3 == 3'b100);
        de.i_ori    = (opcode == 7'b0010011) & (funct3 == 3'b110);
        de.i_andi   = (opcode == 7'b0010011) & (funct3 == 3'b111);
        de.i_slli   = (opcode == 7'b0010011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        de.i_srli   = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        de.i_srai   = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        de.i_add    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000000);
        de.i_sub    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0100000);
        de.i_sll    = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        de.i_slt    = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000000);
        de.i_sltu   = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000000);
        de.i_xor    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000000);
        de.i_srl    = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        de.i_sra    = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        de.i_or     = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000000);
        de.i_and    = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000000);
        de.i_fence  = (opcode == 7'b0001111) & (rd_de == 5'b00000) & (funct3 == 3'b000) & (rs1_de == 5'b00000) & (inst[31:28] == 4'b0000);
        de.i_fencei = (opcode == 7'b0001111) & (rd_de == 5'b00000) & (funct3 == 3'b001) & (rs1_de == 5'b00000) & (imm == 12'b000000000000);
        de.i_ecall  = (opcode == 7'b1110011) & (rd_de == 5'b00000) & (funct3 == 3'b000) & (rs1_de == 5'b00000) & (imm == 12'b000000000000);
        de.i_ebreak = (opcode == 7'b1110011) & (rd_de == 5'b00000) & (funct3 == 3'b000) & (rs1_de == 5'b00000) & (imm == 12'b000000000001);
        de.i_csrrw  = (opcode == 7'b1110011) & (funct3 == 3'b001);
        de.i_csrrs  = (opcode == 7'b1110011) & (funct3 == 3'b010);
        de.i_csrrc  = (opcode == 7'b1110011) & (funct3 == 3'b011);
        de.i_csrrwi = (opcode == 7'b1110011) & (funct3 == 3'b101);
        de.i_csrrsi = (opcode == 7'b1110011) & (funct3 == 3'b110);
        de.i_csrrci = (opcode == 7'b1110011) & (funct3 == 3'b111);
        de.i_mul    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000001);
        de.i_mulh   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000001);
        de.i_mulhsu = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000001);
        de.i_mulhu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000001);
        de.i_div    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000001);
        de.i_divu   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000001);
        de.i_rem    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000001);
        de.i_remu   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000001);
    end

    // DECODE/EXECUTE pipline reg
    de_ex_pipeline_reg ex;
    reg [31:0] a_ex;
    reg [31:0] b_ex;
    reg [31:0] jaloffset_ex;
    reg [31:0] broffset_ex;
    reg [4:0]  shamt_ex; 
    reg [31:0] simm_ex;
    reg [31:0] uimm_ex; 
    reg [31:0] stimm_ex; 
    reg [4:0]  rd_ex;
    reg [4:0]  rs1_ex;
    reg [4:0]  rs2_ex;    
    reg [31:0] pc_ex;   
    reg [31:0] pc_plus_ex;

    always_ff@(posedge clk)begin
        if(is_jump)begin
          a_ex         <= 0;
          b_ex         <= 0;
          jaloffset_ex <= 0;
          broffset_ex  <= 0;
          shamt_ex     <= 0;
          simm_ex      <= 0;
          uimm_ex      <= 0;
          stimm_ex     <= 0;
          rd_ex        <= 0;
          rs1_ex       <= 0;
          rs2_ex       <= 0;
          pc_ex        <= 0;
          pc_plus_ex   <= 0;
          ex           <= 0;
        end else if(is_stoll)begin
          a_ex         <= a_ex         ;
          b_ex         <= b_ex         ;
          jaloffset_ex <= jaloffset_ex ;
          broffset_ex  <= broffset_ex  ;
          shamt_ex     <= shamt_ex     ;
          simm_ex      <= simm_ex      ;
          uimm_ex      <= uimm_ex      ;
          stimm_ex     <= stimm_ex     ;
          rd_ex        <= rd_ex        ;
          rs1_ex       <= rs1_ex       ;
          rs2_ex       <= rs2_ex       ;
          pc_ex        <= pc_ex        ;
          pc_plus_ex   <= pc_plus_ex   ;      
          ex           <= ex           ;
        end else begin
          a_ex         <= a_de        ;
          b_ex         <= b_de        ;
          jaloffset_ex <= jaloffset_de;
          broffset_ex  <= broffset_de ;
          shamt_ex     <= shamt_de    ;
          simm_ex      <= simm_de     ;
          uimm_ex      <= uimm_de     ;
          stimm_ex     <= stimm_de    ;
          rd_ex        <= rd_de       ;
          rs1_ex       <= rs1_de      ;
          rs2_ex       <= rs2_de      ;
          pc_ex        <= pc_de;
          pc_plus_ex   <= pc_plus_de;        
          ex           <= de;
        end
    end

    // EXECUTE STATGE
    reg [31:0] a;
    reg [31:0] b;

    // output
    reg [63:0] mul;     
    reg is_load_ex;
    reg is_store_ex;
    reg is_write_back_ex;             
    reg [31:0] alu_out_ex;         
    reg [3:0] wmem;
    reg [4:0] rmem_ex;
    reg [31:0] mem_addr_ex;
    reg [31:0] store_data_ex;
    
    always_comb begin                                      
        alu_out_ex = 0;                                             
        mem_addr_ex  = 0;                                     
        is_write_back_ex = 0;                                    
        wmem = 0;                                          
        rmem_ex = 0;
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load_ex = 0;
        is_store_ex = 0;
        is_jump = 0;
        store_data_ex = 0;

        // forwarding 
        a = (!is_load_mem & is_write_back_mem & (rd_mem == rs1_ex)) ? alu_out_mem : (is_write_back_wb & (rd_wb == rs1_ex)) ? write_back_data : a_ex;
        b = (!is_load_mem & is_write_back_mem & (rd_mem == rs2_ex)) ? alu_out_mem : (is_write_back_wb & (rd_wb == rs2_ex)) ? write_back_data : b_ex;
        
        // stoll
        is_stoll = (is_load_mem & ((rd_mem == rs1_ex) | (rd_mem == rs2_ex)));
          
        case (1'b1)
            ex.i_add: begin                                   
              alu_out_ex = a + b;
              is_write_back_ex = 1; 
            end                           

            ex.i_sub: begin                                   
              alu_out_ex = a - b;
              is_write_back_ex = 1;                  
            end                         

            ex.i_and: begin                                   
              alu_out_ex = a & b;
              is_write_back_ex = 1;                  
            end                          

            ex.i_or: begin                                    
              alu_out_ex = a | b;
              is_write_back_ex = 1; 
            end

            ex.i_xor: begin                                   
              alu_out_ex = a ^ b;
              is_write_back_ex = 1;   
            end
            
            ex.i_sll: begin                                   
              alu_out_ex = a << b[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_srl: begin                                   
              alu_out_ex = a >> b[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_sra: begin                                   
              alu_out_ex = $signed(a) >>> b[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_slli: begin                                  
              alu_out_ex = a << shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_srli: begin                                  
              alu_out_ex = a >> shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_srai: begin                                  
              alu_out_ex = $signed(a) >>> shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_slt: begin                                   
              if ($signed(a) < $signed(b)) alu_out_ex = 1; 
            end

            ex.i_sltu: begin                                  
              if ({1'b0,a} < {1'b0,b}) alu_out_ex = 1; 
            end

            ex.i_addi: begin                                  
              alu_out_ex = a + simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_andi: begin                                  
              alu_out_ex = a & simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_ori: begin                                  
              alu_out_ex = a | simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_xori: begin                                  
              alu_out_ex = a ^ simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_slti: begin                                  
              if ($signed(a) < $signed(simm_ex)) alu_out_ex = 1; 
            end

            ex.i_sltiu: begin                                 
              if ({1'b0,a} < {1'b0,simm_ex}) 
                alu_out_ex = 1; 
                end

            ex.i_lw: begin                                    // load 4bytes
              alu_out_ex = a + simm_ex;                        
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              rmem_ex = 5'b01111;                             
              is_write_back_ex = 1;
              is_load_ex = 1;                       
            end               

            ex.i_lbu: begin                                   // load 1byte unsigned
              alu_out_ex = a + simm_ex;                        
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};              
              rmem_ex = 5'b00001 << alu_out_ex[1:0];
              is_write_back_ex = 1;
              is_load_ex = 1;                     
            end

            ex.i_lb: begin                                     // load 1byte
              alu_out_ex = a + simm_ex;                         
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              rmem_ex = (5'b00001 << alu_out_ex[1:0]) | 5'b10000;
              is_write_back_ex = 1; 
              is_load_ex = 1;                   
            end

            ex.i_lhu: begin                                    // load 2bytes unsigned
              alu_out_ex = a + simm_ex;                         
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              rmem_ex = 5'b00011 << {alu_out_ex[1],1'b0}; 
              is_write_back_ex = 1; 
              is_load_ex = 1;                   
            end

            ex.i_lh: begin                                     // load 2bytes 
              alu_out_ex = a + simm_ex;                         
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              rmem_ex = (5'b00011 << {alu_out_ex[1],1'b0}) | 5'b10000; 
              is_write_back_ex = 1; 
              is_load_ex = 1;                 
            end

            ex.i_sb: begin                                    // 1 byte store
              alu_out_ex = a + stimm_ex;
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              wmem    = 4'b0001 << alu_out_ex[1:0];         // Which Byte position is it stored to?
              is_store_ex = 1;

              case(wmem)
                4'b0001: store_data_ex = {24'b0, b[7:0]};
                4'b0010: store_data_ex = {16'b0, b[7:0], 8'b0};
                4'b0100: store_data_ex = {8'b0, b[7:0], 16'b0};
                4'b1000: store_data_ex = {b[7:0], 24'b0};
                default: store_data_ex = 0;
              endcase
              
              if(alu_out_ex == `UART_TX_ADDR) begin
                   uart_en = 1;
                   uart_tx_data = store_data_ex[7:0];
              end
            end

            ex.i_sh: begin                                    // 2 bytes store
              alu_out_ex = a + stimm_ex;
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              wmem = 4'b0011 << {alu_out_ex[1], 1'b0};        // Which Byte position is it sorted to?
              is_store_ex = 1;
              case(wmem)
                4'b0011: store_data_ex = {16'b0, b[15:0]};
                4'b1100: store_data_ex = {b[15:0],16'b0};   
                default: store_data_ex = 0;
              endcase
            end

            ex.i_sw: begin                                    // 4 bytes store
              alu_out_ex = a + stimm_ex;
              mem_addr_ex  = {2'b0, alu_out_ex[31:2]};
              wmem = 4'b1111;                              // Which Byte position is it sorted to?
              is_store_ex = 1;
              store_data_ex = b; 
            end

            ex.i_beq: begin                                   
              if (a == b) begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bne: begin                                   
              if (a != b)begin
               alu_out_ex = 1;
               is_jump = 1;
               jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_blt: begin                                   
              if ($signed(a) < $signed(b))begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bge: begin                                   
              if ($signed(a) >= $signed(b))begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bltu: begin                                  
              if ({1'b0,a} < {1'b0,b})begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex;
              end
               
            end

            ex.i_bgeu: begin                                  
              if ({1'b0,a} >= {1'b0,b})begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex;
               end
               
            end

            ex.i_auipc: begin                                 
              alu_out_ex = pc_ex + uimm_ex;
              is_write_back_ex = 1; 
            end
              
            ex.i_lui: begin                                   
              alu_out_ex = uimm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_jal: begin                                   
              alu_out_ex = pc_plus_ex;                       // set pc+4 to link register
              is_write_back_ex = 1;
              jump_addr = pc_ex + jaloffset_ex; 
              is_jump = 1;
            end

            ex.i_jalr: begin                                  
              alu_out_ex = pc_plus_ex;                       // set pc+4 to link register
              is_write_back_ex = 1;
              jump_addr = (a + simm_ex) & 32'hfffffffe; 
              is_jump = 1;
            end
            
            ex.i_mul: begin
                mul = $signed(a) * $signed(b);
                alu_out_ex = mul[31:0]; 
                is_write_back_ex = 1;
            end
            
            ex.i_mulh: begin
                mul = $signed($signed(a) * $signed(b));
                alu_out_ex = mul[63:32]; 
                is_write_back_ex = 1;
                
            end
            
            ex.i_mulhsu: begin
                mul = $signed($signed(a) * $signed({1'b0, b}));
                alu_out_ex = mul[63:32];
                is_write_back_ex = 1;
            end
            
            ex.i_mulhu: begin
                mul = a * b;
                alu_out_ex = mul[63:32];
                is_write_back_ex = 1;
            end
            
            ex.i_div: begin
                alu_out_ex = $signed($signed(a) / $signed(b));
                is_write_back_ex = 1;
            end
            
            ex.i_divu: begin
                alu_out_ex = a / b;
                is_write_back_ex = 1;
            end
            
            ex.i_rem: begin
                alu_out_ex = $signed($signed(a) % $signed(b));
                is_write_back_ex = 1;
            end
            
            ex.i_remu: begin
                alu_out_ex = a % b;
                is_write_back_ex = 1;
            end
            default:;
 
        endcase
    end
    
    // MEM STAGE
    reg is_load_mem;
    reg is_store_mem;
    reg [4:0] rd_mem;
    reg is_write_back_mem;             
    reg [31:0] alu_out_mem;     

    reg [4:0] rmem_mem;
    reg [31:0] mem_addr_mem;
    reg [31:0] store_data_mem;
    reg [31:0] load_data_mem;

    // execute/mem pipline
    always@(posedge clk)begin
      if(is_stoll)begin
        is_store_mem      <= 0;
        is_load_mem       <= 0;
        rd_mem            <= 0;
        is_write_back_mem <= 0;
        alu_out_mem       <= 0;
        rmem_mem          <= 0;
        mem_addr_mem      <= 0;
        store_data_mem    <= 0;
        
      end else begin
        is_store_mem      <= is_store_ex;
        is_load_mem       <= is_load_ex;
        rd_mem            <= rd_ex;
        is_write_back_mem <= is_write_back_ex;
        alu_out_mem       <= alu_out_ex;
        rmem_mem          <= rmem_ex;
        mem_addr_mem      <= mem_addr_ex;
        store_data_mem    <= store_data_ex;

      end
    end
      
    dmem dmem0(
        .clk(clk),
        .is_store(is_store_mem),
        .is_load(is_load_mem),
        .mem_addr(mem_addr_mem),
        .store_data(store_data_mem),
        .load_data(load_data_mem)
    );

    reg is_write_back_wb;
    reg [4:0] rd_wb;
    reg [31:0] alu_out_wb;
    reg is_load_wb;
    reg [31:0] load_data_wb;
    reg [4:0] rmem_wb;

    // mem/write back pipline
    always_ff@(posedge clk)begin
      is_write_back_wb <= is_write_back_mem;
      is_load_wb       <= is_load_mem; 
      alu_out_wb       <= alu_out_mem;
      rd_wb            <= rd_mem;
      rmem_wb          <= rmem_mem;
    end

    always_comb begin
      case (rmem_wb) 
        // unsgigned 1 byte
        5'b00001: load_data_wb = {24'h0, load_data_mem[7:0]};
        5'b00010: load_data_wb = {24'h0, load_data_mem[15:8]};
        5'b00100: load_data_wb = {24'h0, load_data_mem[23:16]};
        5'b01000: load_data_wb = {24'h0, load_data_mem[31:24]};
        // signed 1 byte
        5'b10001: load_data_wb = {{24{load_data_mem[7]}}, load_data_mem[7:0]};
        5'b10010: load_data_wb = {{24{load_data_mem[15]}}, load_data_mem[15:8]};
        5'b10100: load_data_wb = {{24{load_data_mem[23]}}, load_data_mem[23:16]};
        5'b11000: load_data_wb = {{24{load_data_mem[31]}}, load_data_mem[31:24]};
        // unsigned 2 bytes
        5'b00011: load_data_wb = {16'h0, load_data_mem[15:0]};  
        5'b01100: load_data_wb = {16'h0, load_data_mem[31:16]}; 
        // signed 2 bytes
        5'b10011: load_data_wb = {{16{load_data_mem[15]}}, load_data_mem[15:0]};  
        5'b11100: load_data_wb = {{16{load_data_mem[31]}}, load_data_mem[31:16]}; 
        // 4 bytes
        5'b01111: load_data_wb = load_data_mem;
        default:  load_data_wb = 0;    
      endcase
    end

    // WRITE BACK STAGE
    wire [31:0] write_back_data = is_load_wb ? load_data_wb : alu_out_wb;

    always_ff @ (posedge clk) begin
        if (is_write_back_wb && (rd_wb != 0)) begin                 // rd_de = 0 is zero register, so cannot write back.
            regfile[rd_wb] <= write_back_data;                 
        end
    end

endmodule
