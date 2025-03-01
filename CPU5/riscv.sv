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
    
    wire [31:0] inst;
    reg [3:0] wmem;
    reg [4:0] rmem;
    reg [31:0] mem_addr;
    reg [31:0] store_data;
    wire [31:0] load_data;

    reg [31:0] pc;        
    reg [31:0] jump_addr;
    reg  is_jump;     
          
    wire [31:0] pc_plus = pc + 4;
    wire [31:0] next_pc = (is_jump == 1) ? jump_addr : pc_plus ;
    
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

    //FETCH/DECODE pipeline reg
    always_ff@(posedge clk)begin
      if(is_jump == 1)begin
        inst_de <= 0;
        pc_de <= 0;
        pc_plus_de <= 0;
      end else begin
        inst_de <= inst;
        pc_de <= pc;
        pc_plus_de <= pc_plus;
      end
    end

    reg [31:0] inst_de;
    reg [31:0] pc_de;
    reg [31:0] pc_plus_de;

    // DECODE STAGE
    de_ex_pipeline_reg de;

    reg [6:0] opcode;
    reg [2:0] funct3;
    reg [6:0] funct7; 
    reg [4:0] rd;     
    reg [4:0] rs1;    
    reg [4:0] rs2;    
    reg sign;        
    reg [11:0] imm;  

    reg  [31:0] regfile [1:31];                          //  regfile[0] is zero register.

    always_comb begin
        opcode    = inst_de[6:0];  
        funct3    = inst_de[14:12];
        funct7    = inst_de[31:25];
        rd        = inst_de[11:7]; 
        rs1       = inst_de[19:15];
        rs2       = inst_de[24:20];
        sign      = inst_de[31];
        imm       = inst_de[31:20];

        de.pc = pc_de;
        de.pc_plus = pc_plus_de;
        de.rd = inst_de[11:7];

        // forwarding 
        de.a = (rs1==0) ? 0 : (is_load == 1 && ex.rd == rs1)? load_data : (write_back == 1 && ex.rd == rs1)? alu_out : regfile[rs1];           //  index 0 is zero register, so return 0. 
        de.b = (rs2==0) ? 0 : (is_load == 1 && ex.rd == rs2)? load_data : (write_back == 1 && ex.rd == rs2)? alu_out : regfile[rs2];           //  index 0 is zero register, so return 0.

        de.broffset  = {{19{sign}}, inst_de[31], inst_de[7], inst_de[30:25], inst_de[11:8], 1'b0};
        de.simm      = {{20{sign}}, inst_de[31:20]};                                    // lw,  addi, slti, sltiu, xori, ori,  andi, jalr
        de.stimm     = {{20{sign}}, inst_de[31:25], inst_de[11:7]};                         // store word    memory address
        de.uimm      = {inst_de[31:12],12'h0};                                         // lui, auipc

        de.shamt     = inst_de[24:20]; // == rs2;
            
        de.jaloffset = {{11{sign}}, inst_de[31], inst_de[19:12], inst_de[20], inst_de[30:21], 1'b0}; // jal

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
        de.i_fence  = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (inst_de[31:28] == 4'b0000);
        de.i_fencei = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b001) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        de.i_ecall  = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        de.i_ebreak = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000001);
        de.i_csrrw  = (opcode == 7'b1110011) && (funct3 == 3'b001);
        de.i_csrrs  = (opcode == 7'b1110011) && (funct3 == 3'b010);
        de.i_csrrc  = (opcode == 7'b1110011) && (funct3 == 3'b011);
        de.i_csrrwi = (opcode == 7'b1110011) && (funct3 == 3'b101);
        de.i_csrrsi = (opcode == 7'b1110011) && (funct3 == 3'b110);
        de.i_csrrci = (opcode == 7'b1110011) && (funct3 == 3'b111);
        de.i_mul    = (opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0000001);
        de.i_mulh   = (opcode == 7'b0110011) && (funct3 == 3'b001) && (funct7 == 7'b0000001);
        de.i_mulhsu = (opcode == 7'b0110011) && (funct3 == 3'b010) && (funct7 == 7'b0000001);
        de.i_mulhu  = (opcode == 7'b0110011) && (funct3 == 3'b011) && (funct7 == 7'b0000001);
        de.i_div    = (opcode == 7'b0110011) && (funct3 == 3'b100) && (funct7 == 7'b0000001);
        de.i_divu   = (opcode == 7'b0110011) && (funct3 == 3'b101) && (funct7 == 7'b0000001);
        de.i_rem    = (opcode == 7'b0110011) && (funct3 == 3'b110) && (funct7 == 7'b0000001);
        de.i_remu   = (opcode == 7'b0110011) && (funct3 == 3'b111) && (funct7 == 7'b0000001);
    end

    // DECODE/EXECUTE pipline reg

    de_ex_pipeline_reg ex;

    always_ff@(posedge clk)begin
        if(is_jump == 1)
          ex <= 0;
        else 
          ex <= de;
    end

    // EXECUTE STATGE

    // output
    reg [63:0] mul;     
    reg is_load;
    reg is_store;
    reg write_back;             
    reg [31:0] alu_out;         
    
    always_comb begin                                      
        alu_out = 0;                                             
        mem_addr  = 0;                                     
        write_back = 0;                                    
        wmem = 0;                                          
        rmem = 0;
        store_data = ex.b;                                    
        uart_en = 0;
        uart_tx_data = 0;
        jump_addr = 0;
        mul = 0;
        is_load = 0;
        is_store = 0;
        is_jump = 0;
        
        case (1'b1)
            ex.i_add: begin                                   // add
              alu_out = ex.a + ex.b;
              write_back = 1; 
            end                           

            ex.i_sub: begin                                   // sub
              alu_out = ex.a - ex.b;
              write_back = 1;                  
            end                         

            ex.i_and: begin                                   // and
              alu_out = ex.a & ex.b;
              write_back = 1;                  
            end                          

            ex.i_or: begin                                    // or
              alu_out = ex.a | ex.b;
              write_back = 1; 
            end

            ex.i_xor: begin                                   // xor
              alu_out = ex.a ^ ex.b;
              write_back = 1;   
            end
            
            ex.i_sll: begin                                   // sll
              alu_out = ex.a << ex.b[4:0];
              write_back = 1; 
            end

            ex.i_srl: begin                                   // srl
              alu_out = ex.a >> ex.b[4:0];
              write_back = 1; 
            end

            ex.i_sra: begin                                   // sra
              alu_out = $signed(ex.a) >>> ex.b[4:0];
              write_back = 1; 
            end

            ex.i_slli: begin                                  // slli
              alu_out = ex.a << ex.shamt;
              write_back = 1; 
            end

            ex.i_srli: begin                                  // srli
              alu_out = ex.a >> ex.shamt;
              write_back = 1; 
            end

            ex.i_srai: begin                                  // srai
              alu_out = $signed(ex.a) >>> ex.shamt;
              write_back = 1; 
            end

            ex.i_slt: begin                                   // slt
              if ($signed(ex.a) < $signed(ex.b)) alu_out = 1; 
            end

            ex.i_sltu: begin                                  // sltu
              if ({1'b0,ex.a} < {1'b0,ex.b}) alu_out = 1; 
            end

            ex.i_addi: begin                                  // addi
              alu_out = ex.a + ex.simm;
              write_back = 1; 
            end

            ex.i_andi: begin                                  // andi
              alu_out = ex.a & ex.simm;
              write_back = 1; 
            end

            ex.i_ori: begin                                   // ori
              alu_out = ex.a | ex.simm;
              write_back = 1; 
            end

            ex.i_xori: begin                                  // xori
              alu_out = ex.a ^ ex.simm;
              write_back = 1; 
            end

            ex.i_slti: begin                                  // slti
              if ($signed(ex.a) < $signed(ex.simm)) alu_out = 1; 
            end

            ex.i_sltiu: begin                                 // sltiu
              if ({1'b0,ex.a} < {1'b0,ex.simm}) 
                alu_out = 1; 
                end

            ex.i_lw: begin                                    // load 4bytes
              alu_out = ex.a + ex.simm;                        
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = 5'b01111;                             
              write_back = 1;
              is_load = 1'b1;                       
            end               

            ex.i_lbu: begin                                   // load 1byte unsigned
              alu_out = ex.a + ex.simm;                        
              mem_addr  = {2'b0, alu_out[31:2]};              
              rmem = 5'b00001 << alu_out[1:0];
              write_back = 1;
              is_load = 1'b1;                     
            end

            ex.i_lb: begin                                     // load 1byte
              alu_out = ex.a + ex.simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00001 << alu_out[1:0]) | 5'b10000;
              write_back = 1; 
              is_load = 1'b1;                   
            end

            ex.i_lhu: begin                                    // load 2bytes unsigned
              alu_out = ex.a + ex.simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = 5'b00011 << {alu_out[1],1'b0}; 
              write_back = 1; 
              is_load = 1'b1;                   
            end

            ex.i_lh: begin                                     // load 2bytes 
              alu_out = ex.a + ex.simm;                         
              mem_addr  = {2'b0, alu_out[31:2]};
              rmem = (5'b00011 << {alu_out[1],1'b0}) | 5'b10000; 
              write_back = 1; 
              is_load = 1'b1;                 
            end

            ex.i_sb: begin                                    // 1 byte store
              alu_out = ex.a + ex.stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem    = 4'b0001 << alu_out[1:0];         // Which Byte position is it stored to?
              is_store = 1'b1;
              
              if(alu_out == `UART_TX_ADDR) begin
                   uart_en = 1'b1;
                   uart_tx_data = store_data[7:0];
              end
            end

            ex.i_sh: begin                                    // 2 bytes store
              alu_out = ex.a + ex.stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b0011 << {alu_out[1], 1'b0};        // Which Byte position is it sorted to?
              is_store = 1'b1;
            end

            ex.i_sw: begin                                    // 4 bytes store
              alu_out = ex.a + ex.stimm;
              mem_addr  = {2'b0, alu_out[31:2]};
              wmem = 4'b1111;                              // Which Byte position is it sorted to?
              is_store = 1'b1;
            end

            ex.i_beq: begin                                   // beq
              if (ex.a == ex.b) begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = ex.pc + ex.broffset; 
              end
            end

            ex.i_bne: begin                                   // bne
              if (ex.a != ex.b)begin
               alu_out = 1;
               is_jump = 1;
               jump_addr = ex.pc + ex.broffset; 
              end
            end

            ex.i_blt: begin                                   // blt
              if ($signed(ex.a) < $signed(ex.b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = ex.pc + ex.broffset; 
              end
            end

            ex.i_bge: begin                                   // bge
              if ($signed(ex.a) >= $signed(ex.b))begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = ex.pc + ex.broffset; 
              end
            end

            ex.i_bltu: begin                                  // bltu
              if ({1'b0,ex.a} < {1'b0,ex.b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = ex.pc + ex.broffset;
              end
               
            end

            ex.i_bgeu: begin                                  // bgeu
              if ({1'b0,ex.a} >= {1'b0,ex.b})begin
                alu_out = 1;
                is_jump = 1;
                jump_addr = ex.pc + ex.broffset;
               end
               
            end

            ex.i_auipc: begin                                 // auipc
              alu_out = ex.pc + ex.uimm;
              write_back = 1; 
            end
              
            ex.i_lui: begin                                   // lui
              alu_out = ex.uimm;
              write_back = 1; 
            end

            ex.i_jal: begin                                   
              alu_out = ex.pc_plus;                       // set pc+4 to link register
              write_back = 1;
              jump_addr = ex.pc + ex.jaloffset; 
              is_jump = 1;
            end

            ex.i_jalr: begin                                  
              alu_out = ex.pc_plus;                       // set pc+4 to link register
              write_back = 1;
              jump_addr = (ex.a + ex.simm) & 32'hfffffffe; 
              is_jump = 1;
            end
            
            ex.i_mul: begin
                mul = $signed(ex.a) * $signed(ex.b);
                alu_out = mul[31:0]; 
                write_back = 1;
            end
            
            ex.i_mulh: begin
                mul = $signed($signed(ex.a) * $signed(ex.b));
                alu_out = mul[63:32]; 
                write_back = 1;
                
            end
            
            ex.i_mulhsu: begin
                mul = $signed($signed(ex.a) * $signed({1'b0, ex.b}));
                alu_out = mul[63:32];
                write_back = 1;
            end
            
            ex.i_mulhu: begin
                mul = ex.a * ex.b;
                alu_out = mul[63:32];
                write_back = 1;
            end
            
            ex.i_div: begin
                alu_out = $signed($signed(ex.a) / $signed(ex.b));
                write_back = 1;
            end
            
            ex.i_divu: begin
                alu_out = ex.a / ex.b;
                write_back = 1;
            end
            
            ex.i_rem: begin
                alu_out = $signed($signed(ex.a) % $signed(ex.b));
                write_back = 1;
            end
            
            ex.i_remu: begin
                alu_out = ex.a % ex.b;
                write_back = 1;
            end
            default:;
 
        endcase
    end
    
    // MEM STAGE
    dmem dmem0(
        .clk(clk),
        .wmem(wmem),
        .rmem(rmem),
        .mem_addr(mem_addr),
        .store_data(store_data),
        .load_data(load_data)
    );

    // WRITE BACK STAGE
    wire [31:0] write_back_data = is_load ? load_data : alu_out;

    always_ff @ (posedge clk) begin
        if (write_back && (ex.rd != 0)) begin                 // rd = 0 is zero register, so cannot write back.
            regfile[ex.rd] <= write_back_data;                 
        end
    end

endmodule