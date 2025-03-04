`default_nettype none
`include "define.sv"

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

    wire [31:0] inst;
   
    // fetch 
    imem imem0(
        .clk(clk),
        .pc(pc),
        .inst(inst)     
    );
 
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
        jaloffset_de = {{11{sign}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}; 

        // forwarding 
        a_de = (rs1_de == 0) ? 0 : (is_load_ex & (rd_ex == rs1_de)) ? load_data : (is_write_back_ex & (rd_ex == rs1_de)) ? alu_out_ex : regfile[rs1_de]; 
        b_de = (rs2_de == 0) ? 0 : (is_load_ex & (rd_ex == rs2_de)) ? load_data : (is_write_back_ex & (rd_ex == rs2_de)) ? alu_out_ex : regfile[rs2_de];  

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
          ex <= 0;
        end else if(is_stoll)begin
          a_ex         <= a_ex        ;
          b_ex         <= b_ex        ;
          jaloffset_ex <= jaloffset_ex;
          broffset_ex  <= broffset_ex ;
          shamt_ex     <= shamt_ex    ;
          simm_ex      <= simm_ex     ;
          uimm_ex      <= uimm_ex     ;
          stimm_ex     <= stimm_ex    ;
          rd_ex        <= rd_ex       ;
          rs1_ex       <= rs1_ex      ;
          rs2_ex       <= rs2_ex      ;
          pc_ex        <= pc_ex;
          pc_plus_ex   <= pc_plus_ex;        
          ex           <= ex;
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
          pc_ex        <= pc;
          pc_plus_ex   <= pc_plus;        
          ex           <= de;
        end
    end

    // EXECUTE STATGE
    // output
    reg [63:0] mul;     
    reg is_load_ex;
    reg is_store;
    reg is_write_back_ex;             
    reg [31:0] alu_out_ex;         
    reg [3:0] wmem;
    reg [4:0] rmem;
    reg [31:0] mem_addr;
    reg [31:0] store_data;
    
    always_comb begin                                      
        alu_out_ex = 0;                                             
        mem_addr  = 0;                                     
        is_write_back_ex = 0;                                    
        wmem = 0;                                          
        rmem = 0;
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load_ex = 0;
        is_store = 0;
        is_jump = 0;
        is_stoll = 0;

        store_data = b_ex;                                    
        
        case (1'b1)
            ex.i_add: begin                                   // add
              alu_out_ex = a_ex + b_ex;
              is_write_back_ex = 1; 
            end                           

            ex.i_sub: begin                                   // sub
              alu_out_ex = a_ex - b_ex;
              is_write_back_ex = 1;                  
            end                         

            ex.i_and: begin                                   // and
              alu_out_ex = a_ex & b_ex;
              is_write_back_ex = 1;                  
            end                          

            ex.i_or: begin                                    // or
              alu_out_ex = a_ex | b_ex;
              is_write_back_ex = 1; 
            end

            ex.i_xor: begin                                   // xor
              alu_out_ex = a_ex ^ b_ex;
              is_write_back_ex = 1;   
            end
            
            ex.i_sll: begin                                   // sll
              alu_out_ex = a_ex << b_ex[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_srl: begin                                   // srl
              alu_out_ex = a_ex >> b_ex[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_sra: begin                                   // sra
              alu_out_ex = $signed(a_ex) >>> b_ex[4:0];
              is_write_back_ex = 1; 
            end

            ex.i_slli: begin                                  // slli
              alu_out_ex = a_ex << shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_srli: begin                                  // srli
              alu_out_ex = a_ex >> shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_srai: begin                                  // srai
              alu_out_ex = $signed(a_ex) >>> shamt_ex;
              is_write_back_ex = 1; 
            end

            ex.i_slt: begin                                   // slt
              if ($signed(a_ex) < $signed(b_ex)) alu_out_ex = 1; 
            end

            ex.i_sltu: begin                                  // sltu
              if ({1'b0,a_ex} < {1'b0,b_ex}) alu_out_ex = 1; 
            end

            ex.i_addi: begin                                  // addi
              alu_out_ex = a_ex + simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_andi: begin                                  // andi
              alu_out_ex = a_ex & simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_ori: begin                                   // ori
              alu_out_ex = a_ex | simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_xori: begin                                  // xori
              alu_out_ex = a_ex ^ simm_ex;
              is_write_back_ex = 1; 
            end

            ex.i_slti: begin                                  // slti
              if ($signed(a_ex) < $signed(simm_ex)) alu_out_ex = 1; 
            end

            ex.i_sltiu: begin                                 // sltiu
              if ({1'b0,a_ex} < {1'b0,simm_ex}) 
                alu_out_ex = 1; 
                end

            ex.i_lw: begin                                    // load 4bytes
              alu_out_ex = a_ex + simm_ex;                        
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              rmem = 5'b01111;                             
              is_write_back_ex = 1;
              is_load_ex = 1;                       
            end               

            ex.i_lbu: begin                                   // load 1byte unsigned
              alu_out_ex = a_ex + simm_ex;                        
              mem_addr  = {2'b0, alu_out_ex[31:2]};              
              rmem = 5'b00001 << alu_out_ex[1:0];
              is_write_back_ex = 1;
              is_load_ex = 1;                     
            end

            ex.i_lb: begin                                     // load 1byte
              alu_out_ex = a_ex + simm_ex;                         
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              rmem = (5'b00001 << alu_out_ex[1:0]) | 5'b10000;
              is_write_back_ex = 1; 
              is_load_ex = 1;                   
            end

            ex.i_lhu: begin                                    // load 2bytes unsigned
              alu_out_ex = a_ex + simm_ex;                         
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              rmem = 5'b00011 << {alu_out_ex[1],1'b0}; 
              is_write_back_ex = 1; 
              is_load_ex = 1;                   
            end

            ex.i_lh: begin                                     // load 2bytes 
              alu_out_ex = a_ex + simm_ex;                         
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              rmem = (5'b00011 << {alu_out_ex[1],1'b0}) | 5'b10000; 
              is_write_back_ex = 1; 
              is_load_ex = 1;                 
            end

            ex.i_sb: begin                                    // 1 byte store
              alu_out_ex = a_ex + stimm_ex;
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              wmem    = 4'b0001 << alu_out_ex[1:0];         // Which Byte position is it stored to?
              is_store = 1;
              
              if(alu_out_ex == `UART_TX_ADDR) begin
                   uart_en = 1'b1;
                   uart_tx_data = store_data[7:0];
              end
            end

            ex.i_sh: begin                                    // 2 bytes store
              alu_out_ex = a_ex + stimm_ex;
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              wmem = 4'b0011 << {alu_out_ex[1], 1'b0};        // Which Byte position is it sorted to?
              is_store = 1;
            end

            ex.i_sw: begin                                    // 4 bytes store
              alu_out_ex = a_ex + stimm_ex;
              mem_addr  = {2'b0, alu_out_ex[31:2]};
              wmem = 4'b1111;                                 // Which Byte position is it sorted to?
              is_store = 1;
            end

            ex.i_beq: begin                                   // beq
              if (a_ex == b_ex) begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bne: begin                                   // bne
              if (a_ex != b_ex)begin
               alu_out_ex = 1;
               is_jump = 1;
               jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_blt: begin                                   // blt
              if ($signed(a_ex) < $signed(b_ex))begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bge: begin                                   // bge
              if ($signed(a_ex) >= $signed(b_ex))begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex; 
              end
            end

            ex.i_bltu: begin                                  // bltu
              if ({1'b0,a_ex} < {1'b0,b_ex})begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex;
              end
               
            end

            ex.i_bgeu: begin                                  // bgeu
              if ({1'b0,a_ex} >= {1'b0,b_ex})begin
                alu_out_ex = 1;
                is_jump = 1;
                jump_addr = pc_ex + broffset_ex;
               end
               
            end

            ex.i_auipc: begin                                 // auipc
              alu_out_ex = pc_ex + uimm_ex;
              is_write_back_ex = 1; 
            end
              
            ex.i_lui: begin                                   // lui
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
              jump_addr = (a_ex + simm_ex) & 32'hfffffffe; 
              is_jump = 1;
            end
            
            ex.i_mul: begin
                mul = $signed(a_ex) * $signed(b_ex);
                alu_out_ex = mul[31:0]; 
                is_write_back_ex = 1;
            end
            
            ex.i_mulh: begin
                mul = $signed($signed(a_ex) * $signed(b_ex));
                alu_out_ex = mul[63:32]; 
                is_write_back_ex = 1;
                
            end
            
            ex.i_mulhsu: begin
                mul = $signed($signed(a_ex) * $signed({1'b0, b_ex}));
                alu_out_ex = mul[63:32];
                is_write_back_ex = 1;
            end
            
            ex.i_mulhu: begin
                mul = a_ex * b_ex;
                alu_out_ex = mul[63:32];
                is_write_back_ex = 1;
            end
            
            ex.i_div: begin
                alu_out_ex = $signed($signed(a_ex) / $signed(b_ex));
                is_write_back_ex = 1;
            end
            
            ex.i_divu: begin
                alu_out_ex = a_ex / b_ex;
                is_write_back_ex = 1;
            end
            
            ex.i_rem: begin
                alu_out_ex = $signed($signed(a_ex) % $signed(b_ex));
                is_write_back_ex = 1;
            end
            
            ex.i_remu: begin
                alu_out_ex = a_ex % b_ex;
                is_write_back_ex = 1;
            end
            default:;
 
        endcase
    end
    
    // MEM STAGE
    wire [31:0] load_data;

    dmem dmem0(
        .clk(clk),
        .wmem(wmem),
        .rmem(rmem),
        .mem_addr(mem_addr),
        .store_data(store_data),
        .load_data(load_data)
    );

    // WRITE BACK STAGE
    wire [31:0] write_back_data = is_load_ex ? load_data : alu_out_ex;

    always_ff @ (posedge clk) begin
        if (is_write_back_ex && (rd_ex != 0)) begin                 // rd_de = 0 is zero register, so cannot write back.
            regfile[rd_ex] <= write_back_data;                 
        end
    end

endmodule
