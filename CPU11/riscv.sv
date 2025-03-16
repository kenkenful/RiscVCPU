`default_nettype none
`include "define.sv"

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

  function [3:0] ex_order(input [4:0] ex_code);
  begin
    case (ex_code)
      BREAKPOINT: ex_order = 10;
      INSTRUCTION_PAGE_FAULT: ex_order = 9;
      INSTRUCTION_ACCESS_FAULT: ex_order = 8;
      ILLEGAL_INSTRUCTION, INSTRUCTION_ADDR_MISSALIGN, ECALL_ENVIROMENT_FROM_U, ECALL_ENVIROMENT_FROM_S, ECALL_ENVIROMENT_FROM_M, BREAKPOINT: ex_order = 7;
      STORE_AMO_ADDR_MISSALIGN, LOAD_ADDR_MISSALIGNED: ex_order = 6;
      LOAD_PAGE_FAULT, STORE_AMO_PAGE_FAULT: ex_order = 5;
      LOAD_ACCESS_FAULT, STORE_AMO_ACCESS_FAULT: ex_order = 4;
      default: ex_order = 0;
    endcase
  end
  endfunction
  
  reg [31:0] pc = 0;             
  reg [31:0] jump_addr = 0;
  reg is_jump = 0;  
  reg is_stoll = 0;

  wire [31:0] timer_int_addr = (csr_reg.mtvec.mode == VECTOR_MODE) ? {csr_reg.mtvec.base_addr, 2'b00} + 28 : {csr_reg.mtvec.base_addr, 2'b00};
  wire [31:0] exception_addr = {csr_reg.mtvec.base_addr, 2'b00};
  wire [31:0] pc_plus = pc + 4;    
  reg  [31:0] next_pc;

  always_comb begin
    if(is_exception)               next_pc = exception_addr;
    else if(raise_timer_interrupt) next_pc = timer_int_addr;
    else if(is_mret)               next_pc = csr_reg.mepc;      
    else if(is_jump)               next_pc = jump_addr;
    else                           next_pc = pc_plus;
  end

  // pc
  always_ff @ (posedge clk) begin
      if (reset) pc <= 0;
      else       pc <= next_pc;
  end
  
  // fetch
  wire [31:0] inst;
  reg [31:0] pc_de;
  reg [31:0] pc_plus_de;

  // fetch 
  imem imem0(
      .clk(clk),
      .is_flush(is_jump | raise_timer_interrupt),
      .is_stoll(is_stoll),
      .pc(pc),
      .inst(inst)   // FETCH/DECODE pipline      
  );

  //FETCH/DECODE pipeline reg
  always_ff@(posedge clk)begin
    if(is_jump | raise_timer_interrupt)begin
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

  // decode
  wire [6:0]  opcode = inst[6:0];  
  wire [2:0]  funct3 = inst[14:12]; 
  wire [6:0]  funct7 = inst[31:25]; 
  wire [4:0]  rd     = inst[11:7];  
  wire [4:0]  rs1    = inst[19:15]; 
  wire [4:0]  rs2    = inst[24:20]; 
  wire [4:0]  rs3    = inst[31:27];
  wire [4:0]  shamt  = inst[24:20]; 
  wire        sign   = inst[31];
  wire [11:0] imm    = inst[31:20];

  wire [31:0] broffset  = {{19{sign}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};       
  wire [31:0] simm      = {{20{sign}},inst[31:20]};                                     
  wire [31:0] stimm     = {{20{sign}},inst[31:25],inst[11:7]};                         
  wire [31:0] uimm      = {inst[31:12],12'h0};                                         
  wire [31:0] jaloffset = {{11{sign}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0}; 
  wire [11:0] csr       = inst[31:20];
  wire [31:0] zimm      = {27'h0, inst[19:15]};

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
  wire i_mret   = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b001100000010);

  // rv32m
  wire i_mul    = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000001);
  wire i_mulh   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000001);
  wire i_mulhsu = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000001);
  wire i_mulhu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000001);
  wire i_div    = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000001);
  wire i_divu   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000001);
  wire i_rem    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000001);
  wire i_remu   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000001);

  // atomic
  wire i_amoadd  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b00000); 
  wire i_amoand  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b01100);
  wire i_amomax  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b10100);
  wire i_amomaxu = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b11100);
  wire i_amomin  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b10000);
  wire i_amominu = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b11000);
  wire i_amomor  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b01000);
  wire i_amoswap = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b00001);
  wire i_amoxor  = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b00100);
  wire i_sc      = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b00011);
  wire i_lr      = (opcode == 7'b0101111) & (funct3 == 3'b010) & (rs3 == 5'b00010);

  reg  [31:0] regfile [1:31];                  // regfile[0] is zero register.  
  wire [31:0] a = (rs1==0) ? 0 : regfile[rs1]; // index 0 is zero register, so return 0. 
  wire [31:0] b = (rs2==0) ? 0 : regfile[rs2]; // index 0 is zero register, so return 0.
  
  // execute
  reg [31:0] store_data;
  reg [31:0] mem_addr;    
  reg [3:0] wmem;            
  reg [4:0] rmem;
  
  reg [63:0] mul;   
  reg is_load;
  reg is_store;
  reg is_write_back;
  reg [31:0] alu_out;
  reg is_mret;
  reg is_csr;
  reg is_atomic;
  reg is_exception = 0; 
  reg [30:0] exception_code = NOT_DEFINED;

  always_comb begin        
    alu_out        = 0;         
    mem_addr       = 0;   
    is_write_back  = 0;   
    wmem           = 0;            
    rmem           = 0;
    store_data     = b; 
    uart_en        = 0;
    uart_tx_data   = 0;
    jump_addr      = 0;
    mul            = 0;
    is_load        = 0;
    is_store       = 0;
    is_jump        = 0;
    is_mret        = 0;
    is_csr         = 0;
    is_atomic      = 0;
    is_exception   = 0;
    exception_code = NOT_DEFINED;

    if(pc_de[1:0] != 0)begin
      is_exception = 1;
      exception_code = (ex_order(INSTRUCTION_ADDR_MISSALIGN) > ex_order(exception_code)) ? INSTRUCTION_ADDR_MISSALIGN : exception_code;
    end 
    //else if(raise_timer_interrupt)begin
    //  is_load       = 0;
    //  is_store      = 0;
    //  is_csr        = 0;
    //  is_atomic     = 0;
    //  is_write_back = 0;
    //end 
    else begin
      case (1'b1)
        i_add: begin                                   
          alu_out = a + b;
          is_write_back = 1;
        end   

        i_sub: begin                                   
          alu_out = a - b;
          is_write_back = 1;                 
        end

        i_and: begin                                   
          alu_out = a & b;
          is_write_back = 1;                  
        end

        i_or: begin                                    
          alu_out = a | b;
          is_write_back = 1; 
        end

        i_xor: begin                                   
          alu_out = a ^ b;
          is_write_back = 1;   
        end

        i_sll: begin                                   
          alu_out = a << b[4:0];
          is_write_back = 1; 
        end

        i_srl: begin                                   
          alu_out = a >> b[4:0];
          is_write_back = 1; 
        end

        i_sra: begin                                   
          alu_out = $signed(a) >>> b[4:0];
          is_write_back = 1; 
        end

        i_slli: begin                                  
          alu_out = a << shamt;
          is_write_back = 1; 
        end

        i_srli: begin                                  
          alu_out = a >> shamt;
          is_write_back = 1; 
        end

        i_srai: begin                                  
          alu_out = $signed(a) >>> shamt;
          is_write_back = 1; 
        end

        i_slt: begin                                   
          if ($signed(a) < $signed(b)) alu_out = 1; 
        end

        i_sltu: begin                                  
          if ({1'b0,a} < {1'b0,b}) alu_out = 1; 
        end

        i_addi: begin                                  
          alu_out = a + simm;
          is_write_back = 1; 
        end

        i_andi: begin                                  
          alu_out = a & simm;
          is_write_back = 1; 
        end

        i_ori: begin                                   
          alu_out = a | simm;
          is_write_back = 1; 
        end

        i_xori: begin                                  
          alu_out = a ^ simm;
          is_write_back = 1; 
        end

        i_slti: begin                                  
          if ($signed(a) < $signed(simm)) alu_out = 1; 
        end

        i_sltiu: begin                                 
          if ({1'b0,a} < {1'b0,simm}) 
            alu_out = 1; 
        end

        i_lw: begin                                    // load 4bytes
          alu_out = a + simm;                        
          mem_addr  = {2'b0, alu_out[31:2]};
          rmem = 5'b01111;                             
          is_write_back = 1;
          is_load = 1;         
          if(alu_out[1:0] != 2'b00)begin              // miss aligned
            is_write_back = 0;
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ADDR_MISSALIGNED) > ex_order(exception_code)) ? LOAD_ADDR_MISSALIGNED : exception_code;
          end else if(curr_cpu_mode != MACHINE_MODE && (alu_out == MTIME_ADDR || alu_out == MTIMECMP_ADDR))begin
            is_write_back = 0; 
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ACCESS_FAULT) > ex_order(exception_code)) ? LOAD_ACCESS_FAULT : exception_code;
          end          
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
          if(rmem == 5'b00110)begin   // miss aligned
            is_write_back = 0; 
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ADDR_MISSALIGNED) > ex_order(exception_code)) ? LOAD_ADDR_MISSALIGNED : exception_code;
          end else if(curr_cpu_mode != MACHINE_MODE && (alu_out == MTIME_ADDR || alu_out == MTIMECMP_ADDR))begin
            is_write_back = 0; 
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ACCESS_FAULT) > ex_order(exception_code)) ? LOAD_ACCESS_FAULT : exception_code;
          end
        end

        i_lh: begin                                     // load 2bytes 
          alu_out = a + simm;                         
          mem_addr  = {2'b0, alu_out[31:2]};
          rmem = (5'b00011 << {alu_out[1],1'b0}) | 5'b10000; 
          is_write_back = 1; 
          is_load = 1; 
          if(rmem == 5'b10110)begin     // miss aligned
            is_write_back = 0; 
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ADDR_MISSALIGNED) > ex_order(exception_code)) ? LOAD_ADDR_MISSALIGNED : exception_code;
          end else if(curr_cpu_mode != MACHINE_MODE && (alu_out == MTIME_ADDR || alu_out == MTIMECMP_ADDR))begin
            is_write_back = 0; 
            is_load = 0;
            is_exception = 1;
            exception_code = (ex_order(LOAD_ACCESS_FAULT) > ex_order(exception_code)) ? LOAD_ACCESS_FAULT : exception_code;
          end         
        end

        i_sb: begin                                    // 1 byte store
          alu_out = a + stimm;
          mem_addr  = {2'b0, alu_out[31:2]};
          wmem    = 4'b0001 << alu_out[1:0];           // Which Byte position is it stored to?
          is_store = 1;

          case(wmem)
            4'b0001: store_data = {24'b0, b[7:0]};
            4'b0010: store_data = {16'b0, b[7:0], 8'b0};
            4'b0100: store_data = {8'b0, b[7:0], 16'b0};
            4'b1000: store_data = {b[7:0], 24'b0};
            default: store_data = 0;
          endcase

          if(alu_out == UART_TX_ADDR) begin
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
          if(wmem == 4'b0110)begin                     // miss aligned
            is_store = 0;
            is_exception = 1;
            exception_code = (ex_order(STORE_AMO_ADDR_MISSALIGN) > ex_order(exception_code)) ? STORE_AMO_ADDR_MISSALIGN : exception_code;
          end else if(curr_cpu_mode != MACHINE_MODE && (alu_out == MTIME_ADDR || alu_out == MTIMECMP_ADDR))begin
            is_store = 0;
            is_exception = 1;
            exception_code = (ex_order(STORE_AMO_ACCESS_FAULT) > ex_order(exception_code)) ? STORE_AMO_ACCESS_FAULT : exception_code;
          end 
        end

        i_sw: begin                                    // 4 bytes store
          alu_out = a + stimm;
          mem_addr  = {2'b0, alu_out[31:2]};
          wmem = 4'b1111;                              // Which Byte position is it sorted to?
          is_store = 1;
          if(alu_out[1:0] != 2'b00)begin               // miss aligned
            is_store = 0;
            is_exception = 1;
            exception_code = (ex_order(STORE_AMO_ADDR_MISSALIGN) > ex_order(exception_code)) ? STORE_AMO_ADDR_MISSALIGN : exception_code;
          end else if(curr_cpu_mode != MACHINE_MODE && (alu_out == MTIME_ADDR || alu_out == MTIMECMP_ADDR))begin
            is_store = 0;
            is_exception = 1;
            exception_code = (ex_order(STORE_AMO_ACCESS_FAULT) > ex_order(exception_code)) ? STORE_AMO_ACCESS_FAULT : exception_code;
          end
        end

        i_beq: begin                                   
          if (a == b) begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset; 
          end
        end

        i_bne: begin                                   
          if (a != b)begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset; 
          end
        end

        i_blt: begin                                   
          if ($signed(a) < $signed(b))begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset; 
          end
        end

        i_bge: begin                                   
          if ($signed(a) >= $signed(b))begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset; 
          end
        end

        i_bltu: begin                                  
          if ({1'b0,a} < {1'b0,b})begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset;
          end
        end

        i_bgeu: begin                                  
          if ({1'b0,a} >= {1'b0,b})begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc_de + broffset;
           end 
        end

        i_auipc: begin                                 
          alu_out = pc_de + uimm;
          is_write_back = 1; 
        end

        i_lui: begin                                   
          alu_out = uimm;
          is_write_back = 1; 
        end

        i_jal: begin                                   
          alu_out = pc_plus_de;                       // set pc_de+4 to link register
          is_write_back = 1;
          jump_addr = pc_de + jaloffset; 
          is_jump = 1;
        end

        i_jalr: begin                                  
          alu_out = pc_plus_de;                       // set pc_de+4 to link register
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

        i_csrrw, i_csrrs, i_csrrc, i_csrrwi, i_csrrsi, i_csrrci:begin
          is_csr = 1;
          if(curr_cpu_mode != MACHINE_MODE)begin
            is_csr = 0;            
            is_exception = 1;
            exception_code = (ex_order(ILLEGAL_INSTRUCTION) > ex_order(exception_code)) ? ILLEGAL_INSTRUCTION : exception_code;
          end
        end

        i_mret:begin
          is_mret = 1;
        end

        i_amoadd, i_amoand, i_amomax, i_amomaxu, i_amomin, i_amominu, i_amomor, i_amoswap, i_amoxor, i_sc, i_lr:begin
          is_atomic = 1;  
          mem_addr = {2'b0, a[31:2]};
          if(a[1:0] != 2'b00)begin    // miss align
            is_atomic = 0;
            is_exception = 1;
            exception_code = (ex_order(STORE_AMO_ADDR_MISSALIGN) > ex_order(exception_code)) ? STORE_AMO_ADDR_MISSALIGN : exception_code;
          end 
        end
                               //mem[x[rs1]]   x[rs2]
        i_amoadd: store_data = mem_out + b;
                               //mem[x[rs1]]   x[rs2]     
        i_amoand: store_data = mem_out & b;
          
        i_amomax: store_data = ($signed(mem_out) > $signed(b)) ? mem_out : b;
        
        i_amomaxu: store_data = ({1'b0, mem_out} > {1'b0, b}) ? mem_out : b;
        
        i_amomin: store_data = ($signed(mem_out) > $signed(b)) ? b : mem_out;
        
        i_amominu: store_data = ({1'b0, mem_out} > {1'b0, b}) ? b : mem_out;
        
        i_amomor: store_data = mem_out | b;
          
        i_amoswap: store_data = b;
       
        i_amoxor: store_data = mem_out ^ b;
        
        i_sc: if(reservation_reg == a) store_data = b; 
          
        i_ecall:begin
          is_exception = 1;
          if(curr_cpu_mode == MACHINE_MODE)
            exception_code = (ex_order(ECALL_ENVIROMENT_FROM_M) > ex_order(exception_code)) ? ECALL_ENVIROMENT_FROM_M : exception_code;
          else if(curr_cpu_mode == USER_MODE) 
            exception_code = (ex_order(ECALL_ENVIROMENT_FROM_U) > ex_order(exception_code)) ? ECALL_ENVIROMENT_FROM_U : exception_code;
        end

        i_ebreak:begin
          is_exception = 1;
          exception_code = (ex_order(BREAKPOINT) > ex_order(exception_code)) ? BREAKPOINT : exception_code;
        end

        default:;
      endcase
    end

  end

  wire [31:0] mem_out;

  // store/load
  dmem dmem0(
      .clk(clk),
      .is_store(is_store | is_atomic),
      .is_load(is_load | is_atomic),
      .mem_addr(mem_addr),
      .store_data(store_data),
      .load_data(mem_out)
  );

  reg [31:0] load_data;

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

  wire raise_timer_interrupt = (mtimecmp <= mtime) & !csr_reg.mip.mtip & csr_reg.mie.mtie & csr_reg.mstatus.mie ? 1: 0;
                                                  //                    enable timer interrupt   emable interrupt
  reg [63:0] mtime = 0;
  reg [63:0] mtimecmp = 0;
  reg [31:0] reservation_reg = 0;   // for sc/lr operation

  // store
  always_ff@(posedge clk)begin
    if(reset)begin
      mtime <= 0;
    end else begin
      if(is_store && alu_out == MTIME_ADDR) mtime <= store_data; 
      else if(!(is_store && alu_out == MTIME_ADDR) && csr_reg.mie.mtie && !csr_reg.mip.mtip) mtime <= mtime + 1;
    end
  end

  always_ff@(posedge clk)begin
    if(reset)
      mtimecmp <= 0;
    else begin
      if(is_store && alu_out == MTIMECMP_ADDR) mtimecmp <= store_data;
    end  
  end

  // csr register
  csr_reg_t csr_reg = 0;

  reg [1:0] curr_cpu_mode = MACHINE_MODE;

  always_ff @ (posedge clk) begin
    if(reset)begin
      curr_cpu_mode <= MACHINE_MODE; // machine mode
    end else if(is_exception)begin
        curr_cpu_mode                 <= MACHINE_MODE;
        csr_reg.mstatus.mpp           <= curr_cpu_mode;
        csr_reg.mstatus.mie           <= 0;    // interrupt is not supported when exception.
        csr_reg.mstatus.mpie          <= csr_reg.mstatus.mie; 
        csr_reg.mcause.interrupt      <= 0;
        csr_reg.mcause.exception_code <= exception_code;
        csr_reg.mepc                  <= is_jump ? jump_addr : pc;
        csr_reg.mtval                 <= inst;
    end
    else if(raise_timer_interrupt) begin  
      curr_cpu_mode            <= MACHINE_MODE;
      csr_reg.mstatus.mpp      <= curr_cpu_mode;
      csr_reg.mstatus.mie      <= 0;   // nested interrupt is not supported.
      csr_reg.mstatus.mpie     <= csr_reg.mstatus.mie; 
      csr_reg.mcause.interrupt <= 1;
      if(csr_reg.mtvec.mode == 0) csr_reg.mcause.exception_code <= MACHINE_TIMER_INTERRUPT;
      csr_reg.mepc             <= is_jump ? jump_addr : pc;
      csr_reg.mtval            <= 0; 
      csr_reg.mip.mtip         <= 1;    
    end 
    else if(is_mret)begin 
      curr_cpu_mode        <= csr_reg.mstatus.mpp; 
      csr_reg.mstatus.mie  <= csr_reg.mstatus.mpie;
      csr_reg.mstatus.mpie <= 1;  // enable insterrupt again
      csr_reg.mcause       <= 0;
      csr_reg.mtval        <= 0;
      csr_reg.mip.mtip     <= 0;
    end 
    else if(is_csr)begin
      case(1'b1)
        i_csrrw:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= a; 
            MIE_ADDR:     csr_reg.mie       <= a; 
            MTVEC_ADDR:   csr_reg.mtvec     <= a; 
            MEPC_ADDR:    csr_reg.mepc      <= a;
            MCAUSE_ADDR:  csr_reg.mcause    <= a;
            MTVAL_ADDR:   csr_reg.mtval     <= a;
            MIP_ADDR:     csr_reg.mip       <= a;
          
            PMPCFG0:      csr_reg.pmpcfg0   <= a;
            PMPCFG1:      csr_reg.pmpcfg1   <= a;
            PMPCFG2:      csr_reg.pmpcfg2   <= a;
            PMPCFG3:      csr_reg.pmpcfg3   <= a;
          
            PMPADDR0:     csr_reg.pmpaddr0  <= a;
            PMPADDR1:     csr_reg.pmpaddr1  <= a;
            PMPADDR2:     csr_reg.pmpaddr2  <= a;
            PMPADDR3:     csr_reg.pmpaddr3  <= a;
            PMPADDR4:     csr_reg.pmpaddr4  <= a;
            PMPADDR5:     csr_reg.pmpaddr5  <= a;
            PMPADDR6:     csr_reg.pmpaddr6  <= a;
            PMPADDR7:     csr_reg.pmpaddr7  <= a;
            PMPADDR8:     csr_reg.pmpaddr8  <= a;
            PMPADDR9:     csr_reg.pmpaddr9  <= a;
            PMPADDR10:    csr_reg.pmpaddr10 <= a;
            PMPADDR11:    csr_reg.pmpaddr11 <= a;
            PMPADDR12:    csr_reg.pmpaddr12 <= a;
            PMPADDR13:    csr_reg.pmpaddr13 <= a;
            PMPADDR14:    csr_reg.pmpaddr14 <= a;
            PMPADDR15:    csr_reg.pmpaddr15 <= a;

            default:;
          endcase
        end

        i_csrrs:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= csr_reg.mstatus   | a; 
            MIE_ADDR:     csr_reg.mie       <= csr_reg.mie       | a; 
            MTVEC_ADDR:   csr_reg.mtvec     <= csr_reg.mtvec     | a; 
            MEPC_ADDR:    csr_reg.mepc      <= csr_reg.mepc      | a;
            MCAUSE_ADDR:  csr_reg.mcause    <= csr_reg.mcause    | a;
            MTVAL_ADDR:   csr_reg.mtval     <= csr_reg.mtval     | a;
            MIP_ADDR:     csr_reg.mip       <= csr_reg.mip       | a;

            PMPCFG0:      csr_reg.pmpcfg0   <= csr_reg.pmpcfg0   | a;
            PMPCFG1:      csr_reg.pmpcfg1   <= csr_reg.pmpcfg1   | a;
            PMPCFG2:      csr_reg.pmpcfg2   <= csr_reg.pmpcfg2   | a;
            PMPCFG3:      csr_reg.pmpcfg3   <= csr_reg.pmpcfg3   | a;
            
            PMPADDR0:     csr_reg.pmpaddr0  <= csr_reg.pmpaddr0  | a;
            PMPADDR1:     csr_reg.pmpaddr1  <= csr_reg.pmpaddr1  | a;
            PMPADDR2:     csr_reg.pmpaddr2  <= csr_reg.pmpaddr2  | a;
            PMPADDR3:     csr_reg.pmpaddr3  <= csr_reg.pmpaddr3  | a;
            PMPADDR4:     csr_reg.pmpaddr4  <= csr_reg.pmpaddr4  | a;
            PMPADDR5:     csr_reg.pmpaddr5  <= csr_reg.pmpaddr5  | a;
            PMPADDR6:     csr_reg.pmpaddr6  <= csr_reg.pmpaddr6  | a;
            PMPADDR7:     csr_reg.pmpaddr7  <= csr_reg.pmpaddr7  | a;
            PMPADDR8:     csr_reg.pmpaddr8  <= csr_reg.pmpaddr8  | a;
            PMPADDR9:     csr_reg.pmpaddr9  <= csr_reg.pmpaddr9  | a;
            PMPADDR10:    csr_reg.pmpaddr10 <= csr_reg.pmpaddr10 | a;
            PMPADDR11:    csr_reg.pmpaddr11 <= csr_reg.pmpaddr11 | a;
            PMPADDR12:    csr_reg.pmpaddr12 <= csr_reg.pmpaddr12 | a;
            PMPADDR13:    csr_reg.pmpaddr13 <= csr_reg.pmpaddr13 | a;
            PMPADDR14:    csr_reg.pmpaddr14 <= csr_reg.pmpaddr14 | a;
            PMPADDR15:    csr_reg.pmpaddr15 <= csr_reg.pmpaddr15 | a;
            default:;
          endcase
        end

        i_csrrc :begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= csr_reg.mstatus   &~ a; 
            MIE_ADDR:     csr_reg.mie       <= csr_reg.mie       &~ a; 
            MTVEC_ADDR:   csr_reg.mtvec     <= csr_reg.mtvec     &~ a; 
            MEPC_ADDR:    csr_reg.mepc      <= csr_reg.mepc      &~ a;
            MCAUSE_ADDR:  csr_reg.mcause    <= csr_reg.mcause    &~ a;
            MTVAL_ADDR:   csr_reg.mtval     <= csr_reg.mtval     &~ a;
            MIP_ADDR:     csr_reg.mip       <= csr_reg.mip       &~ a;
            
            PMPCFG0:      csr_reg.pmpcfg0   <= csr_reg.pmpcfg0   &~ a;
            PMPCFG1:      csr_reg.pmpcfg1   <= csr_reg.pmpcfg1   &~ a;
            PMPCFG2:      csr_reg.pmpcfg2   <= csr_reg.pmpcfg2   &~ a;
            PMPCFG3:      csr_reg.pmpcfg3   <= csr_reg.pmpcfg3   &~ a;
            
            PMPADDR0:     csr_reg.pmpaddr0  <= csr_reg.pmpaddr0  &~ a;
            PMPADDR1:     csr_reg.pmpaddr1  <= csr_reg.pmpaddr1  &~ a;
            PMPADDR2:     csr_reg.pmpaddr2  <= csr_reg.pmpaddr2  &~ a;
            PMPADDR3:     csr_reg.pmpaddr3  <= csr_reg.pmpaddr3  &~ a;
            PMPADDR4:     csr_reg.pmpaddr4  <= csr_reg.pmpaddr4  &~ a;
            PMPADDR5:     csr_reg.pmpaddr5  <= csr_reg.pmpaddr5  &~ a;
            PMPADDR6:     csr_reg.pmpaddr6  <= csr_reg.pmpaddr6  &~ a;
            PMPADDR7:     csr_reg.pmpaddr7  <= csr_reg.pmpaddr7  &~ a;
            PMPADDR8:     csr_reg.pmpaddr8  <= csr_reg.pmpaddr8  &~ a;
            PMPADDR9:     csr_reg.pmpaddr9  <= csr_reg.pmpaddr9  &~ a;
            PMPADDR10:    csr_reg.pmpaddr10 <= csr_reg.pmpaddr10 &~ a;
            PMPADDR11:    csr_reg.pmpaddr11 <= csr_reg.pmpaddr11 &~ a;
            PMPADDR12:    csr_reg.pmpaddr12 <= csr_reg.pmpaddr12 &~ a;
            PMPADDR13:    csr_reg.pmpaddr13 <= csr_reg.pmpaddr13 &~ a;
            PMPADDR14:    csr_reg.pmpaddr14 <= csr_reg.pmpaddr14 &~ a;
            PMPADDR15:    csr_reg.pmpaddr15 <= csr_reg.pmpaddr15 &~ a;
            default:;
          endcase
        end

        i_csrrwi:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= zimm; 
            MIE_ADDR:     csr_reg.mie       <= zimm; 
            MTVEC_ADDR:   csr_reg.mtvec     <= zimm; 
            MEPC_ADDR:    csr_reg.mepc      <= zimm;
            MCAUSE_ADDR:  csr_reg.mcause    <= zimm;
            MTVAL_ADDR:   csr_reg.mtval     <= zimm;
            MIP_ADDR:     csr_reg.mip       <= zimm;

            PMPCFG0:      csr_reg.pmpcfg0   <= zimm;
            PMPCFG1:      csr_reg.pmpcfg1   <= zimm;
            PMPCFG2:      csr_reg.pmpcfg2   <= zimm;
            PMPCFG3:      csr_reg.pmpcfg3   <= zimm;

            PMPADDR0:     csr_reg.pmpaddr0  <= zimm;
            PMPADDR1:     csr_reg.pmpaddr1  <= zimm;
            PMPADDR2:     csr_reg.pmpaddr2  <= zimm;
            PMPADDR3:     csr_reg.pmpaddr3  <= zimm;
            PMPADDR4:     csr_reg.pmpaddr4  <= zimm;
            PMPADDR5:     csr_reg.pmpaddr5  <= zimm;
            PMPADDR6:     csr_reg.pmpaddr6  <= zimm;
            PMPADDR7:     csr_reg.pmpaddr7  <= zimm;
            PMPADDR8:     csr_reg.pmpaddr8  <= zimm;
            PMPADDR9:     csr_reg.pmpaddr9  <= zimm;
            PMPADDR10:    csr_reg.pmpaddr10 <= zimm;
            PMPADDR11:    csr_reg.pmpaddr11 <= zimm;
            PMPADDR12:    csr_reg.pmpaddr12 <= zimm;
            PMPADDR13:    csr_reg.pmpaddr13 <= zimm;
            PMPADDR14:    csr_reg.pmpaddr14 <= zimm;
            PMPADDR15:    csr_reg.pmpaddr15 <= zimm;

            default:;
          endcase         
        end

        i_csrrsi:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= csr_reg.mstatus   | zimm; 
            MIE_ADDR:     csr_reg.mie       <= csr_reg.mie       | zimm; 
            MTVEC_ADDR:   csr_reg.mtvec     <= csr_reg.mtvec     | zimm; 
            MEPC_ADDR:    csr_reg.mepc      <= csr_reg.mepc      | zimm;
            MCAUSE_ADDR:  csr_reg.mcause    <= csr_reg.mcause    | zimm;
            MTVAL_ADDR:   csr_reg.mtval     <= csr_reg.mtval     | zimm;
            MIP_ADDR:     csr_reg.mip       <= csr_reg.mip       | zimm;
            
            PMPCFG0:      csr_reg.pmpcfg0   <= csr_reg.pmpcfg0   | zimm;
            PMPCFG1:      csr_reg.pmpcfg1   <= csr_reg.pmpcfg1   | zimm;
            PMPCFG2:      csr_reg.pmpcfg2   <= csr_reg.pmpcfg2   | zimm;
            PMPCFG3:      csr_reg.pmpcfg3   <= csr_reg.pmpcfg3   | zimm;
            
            PMPADDR0:     csr_reg.pmpaddr0  <= csr_reg.pmpaddr0  | zimm;
            PMPADDR1:     csr_reg.pmpaddr1  <= csr_reg.pmpaddr1  | zimm;
            PMPADDR2:     csr_reg.pmpaddr2  <= csr_reg.pmpaddr2  | zimm;
            PMPADDR3:     csr_reg.pmpaddr3  <= csr_reg.pmpaddr3  | zimm;
            PMPADDR4:     csr_reg.pmpaddr4  <= csr_reg.pmpaddr4  | zimm;
            PMPADDR5:     csr_reg.pmpaddr5  <= csr_reg.pmpaddr5  | zimm;
            PMPADDR6:     csr_reg.pmpaddr6  <= csr_reg.pmpaddr6  | zimm;
            PMPADDR7:     csr_reg.pmpaddr7  <= csr_reg.pmpaddr7  | zimm;
            PMPADDR8:     csr_reg.pmpaddr8  <= csr_reg.pmpaddr8  | zimm;
            PMPADDR9:     csr_reg.pmpaddr9  <= csr_reg.pmpaddr9  | zimm;
            PMPADDR10:    csr_reg.pmpaddr10 <= csr_reg.pmpaddr10 | zimm;
            PMPADDR11:    csr_reg.pmpaddr11 <= csr_reg.pmpaddr11 | zimm;
            PMPADDR12:    csr_reg.pmpaddr12 <= csr_reg.pmpaddr12 | zimm;
            PMPADDR13:    csr_reg.pmpaddr13 <= csr_reg.pmpaddr13 | zimm;
            PMPADDR14:    csr_reg.pmpaddr14 <= csr_reg.pmpaddr14 | zimm;
            PMPADDR15:    csr_reg.pmpaddr15 <= csr_reg.pmpaddr15 | zimm;

            default:;
          endcase         
        end

        i_csrrci:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus   <= csr_reg.mstatus   &~ zimm; 
            MIE_ADDR:     csr_reg.mie       <= csr_reg.mie       &~ zimm; 
            MTVEC_ADDR:   csr_reg.mtvec     <= csr_reg.mtvec     &~ zimm; 
            MEPC_ADDR:    csr_reg.mepc      <= csr_reg.mepc      &~ zimm;
            MCAUSE_ADDR:  csr_reg.mcause    <= csr_reg.mcause    &~ zimm;
            MTVAL_ADDR:   csr_reg.mtval     <= csr_reg.mtval     &~ zimm;
            MIP_ADDR:     csr_reg.mip       <= csr_reg.mip       &~ zimm;
            
            PMPCFG0:      csr_reg.pmpcfg0   <= csr_reg.pmpcfg0   &~ zimm;
            PMPCFG1:      csr_reg.pmpcfg1   <= csr_reg.pmpcfg1   &~ zimm;
            PMPCFG2:      csr_reg.pmpcfg2   <= csr_reg.pmpcfg2   &~ zimm;
            PMPCFG3:      csr_reg.pmpcfg3   <= csr_reg.pmpcfg3   &~ zimm;
            
            PMPADDR0:     csr_reg.pmpaddr0  <= csr_reg.pmpaddr0  &~ zimm;
            PMPADDR1:     csr_reg.pmpaddr1  <= csr_reg.pmpaddr1  &~ zimm;
            PMPADDR2:     csr_reg.pmpaddr2  <= csr_reg.pmpaddr2  &~ zimm;
            PMPADDR3:     csr_reg.pmpaddr3  <= csr_reg.pmpaddr3  &~ zimm;
            PMPADDR4:     csr_reg.pmpaddr4  <= csr_reg.pmpaddr4  &~ zimm;
            PMPADDR5:     csr_reg.pmpaddr5  <= csr_reg.pmpaddr5  &~ zimm;
            PMPADDR6:     csr_reg.pmpaddr6  <= csr_reg.pmpaddr6  &~ zimm;
            PMPADDR7:     csr_reg.pmpaddr7  <= csr_reg.pmpaddr7  &~ zimm;
            PMPADDR8:     csr_reg.pmpaddr8  <= csr_reg.pmpaddr8  &~ zimm;
            PMPADDR9:     csr_reg.pmpaddr9  <= csr_reg.pmpaddr9  &~ zimm;
            PMPADDR10:    csr_reg.pmpaddr10 <= csr_reg.pmpaddr10 &~ zimm;
            PMPADDR11:    csr_reg.pmpaddr11 <= csr_reg.pmpaddr11 &~ zimm;
            PMPADDR12:    csr_reg.pmpaddr12 <= csr_reg.pmpaddr12 &~ zimm;
            PMPADDR13:    csr_reg.pmpaddr13 <= csr_reg.pmpaddr13 &~ zimm;
            PMPADDR14:    csr_reg.pmpaddr14 <= csr_reg.pmpaddr14 &~ zimm;
            PMPADDR15:    csr_reg.pmpaddr15 <= csr_reg.pmpaddr15 &~ zimm;

            default:;
          endcase
        end
        default:;
      endcase      
    end
  end
    
  reg [31:0] write_back_data ;

  // select write back data
  always_comb begin
    if(is_load) begin
      if(alu_out == MTIME_ADDR) write_back_data = mtime;
      else if(alu_out == MTIMECMP_ADDR) write_back_data = mtimecmp;
      else write_back_data = load_data;
    end else
      write_back_data = alu_out;     
  end

  // write back
  always_ff @ (posedge clk) begin
    if (is_write_back && (rd != 0)) begin   // rd = 0 is zero register, so cannot write back.
      regfile[rd] <= write_back_data;                 
    end else if(is_csr)begin
      case(csr)  // i_csrrw, i_csrrs, i_csrrc, i_csrrwi, i_csrrsi, i_csrrci
        MSTATUS_ADDR: if(rd != 0) regfile[rd] <= csr_reg.mstatus; 
        MIE_ADDR:     if(rd != 0) regfile[rd] <= csr_reg.mie; 
        MTVEC_ADDR:   if(rd != 0) regfile[rd] <= csr_reg.mtvec;
        MEPC_ADDR:    if(rd != 0) regfile[rd] <= csr_reg.mepc;
        MCAUSE_ADDR:  if(rd != 0) regfile[rd] <= csr_reg.mcause;
        MTVAL_ADDR:   if(rd != 0) regfile[rd] <= csr_reg.mtval;
        MIP_ADDR:     if(rd != 0) regfile[rd] <= csr_reg.mip;

        PMPCFG0:      if(rd != 0) regfile[rd] <= csr_reg.pmpcfg0;
        PMPCFG1:      if(rd != 0) regfile[rd] <= csr_reg.pmpcfg1;
        PMPCFG2:      if(rd != 0) regfile[rd] <= csr_reg.pmpcfg2;
        PMPCFG3:      if(rd != 0) regfile[rd] <= csr_reg.pmpcfg3;

        PMPADDR0:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr0;
        PMPADDR1:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr1;
        PMPADDR2:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr2;
        PMPADDR3:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr3;
        PMPADDR4:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr4;
        PMPADDR5:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr5;
        PMPADDR6:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr6;
        PMPADDR7:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr7;
        PMPADDR8:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr8;
        PMPADDR9:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr9;
        PMPADDR10:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr10;
        PMPADDR11:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr11;
        PMPADDR12:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr12;
        PMPADDR13:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr13;
        PMPADDR14:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr14;
        PMPADDR15:    if(rd != 0) regfile[rd] <= csr_reg.pmpaddr15;
        default:;
      endcase        
    end 
    else if(is_atomic)begin
      case(1'b1)
        i_amoadd, i_amoand, i_amomax, i_amomaxu, i_amomin, i_amominu, i_amomor, i_amoswap, i_amoxor:  
          if(rd != 0) regfile[rd] <= mem_out; 
        i_sc:begin                   // x[rs1]
          if(reservation_reg == a)
            if(rd != 0) regfile[rd] <= 0;         
          else             // x[rd]
            if(rd != 0) regfile[rd] <= 1;       
        end
        i_lr:begin
          reservation_reg <= a;
          if(rd != 0) regfile[rd] <= mem_out;
        end                          // x[rs1]
        default:;
      endcase
    end
  end

endmodule  