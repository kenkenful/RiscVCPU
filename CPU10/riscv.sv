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

    // Distributed RAM
    localparam data_width = 32;
    localparam addr_width = 11;
     
    reg [data_width-1:0] mem [2**addr_width-1:0];  // instruction and data melmory
    
    initial begin 
        integer i = 0;
        //csr_reg_t test;
        //test.mtvec = 32'h03300001; 
        //$display("base =%x, mode=%d\n", test.mtvec.base_addr, test.mtvec.mode);  
        //test.mstatus = 32'h0000000f; 
        //$display("sd=%d, wpri4=%d, s=%d, u=%d\n", test.mstatus.sd, test.mstatus.wpri4 , test.mstatus.sie, test.mstatus.uie);  

        $readmemh("/home/ttt/Desktop/riscv/RISCV/RISCV.srcs/sources_1/new/soft/test.hex", mem);
        
        for(i=0; i<100; i=i+1) $display( "%x: %x",i*4, mem[i]);
        
    end
    
    reg [31:0] pc;             
    reg [31:0] jump_addr;
    reg is_jump;     

    wire [31:0] timer_int_addr = (csr_reg.mtvec.mode == VECTOR_MODE) ? {csr_reg.mtvec.base_addr, 2'b00} + 28 : {csr_reg.mtvec.base_addr, 2'b00};
    wire [31:0] exception_addr = {csr_reg.mtvec.base_addr, 2'b00};

    wire [31:0] pc_plus = pc + 4;
    
    reg [31:0] next_pc;

    always_comb begin
      if(raise_exception) next_pc = exception_addr;
      else if(rise_timer_interrupt) next_pc = timer_int_addr;
      else if(is_mret)         next_pc = csr_reg.mepc;      
      else if(is_jump)         next_pc = jump_addr;
      else                     next_pc = pc_plus;
    end

    // pc
    always_ff @ (posedge clk) begin
        if (reset) pc <= 0;
        else       pc <= next_pc;
    end
    
    // fetch
    wire [31:0] inst = mem[pc[31:2]];

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

    wire   [31:0] broffset  = {{19{sign}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};       
    wire   [31:0] simm      = {{20{sign}},inst[31:20]};                                     
    wire   [31:0] stimm     = {{20{sign}},inst[31:25],inst[11:7]};                         
    wire   [31:0] uimm      = {inst[31:12],12'h0};                                         
    wire   [31:0] jaloffset = {{11{sign}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0}; 

    wire   [11:0] csr       = inst[31:20];
    wire   [31:0] zimm      = {27'h0, inst[19:15]};

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

    reg    [31:0] regfile [1:31];                  //  regfile[0] is zero register.  
    wire   [31:0] a = (rs1==0) ? 0 : regfile[rs1]; //  index 0 is zero register, so return 0. 
    wire   [31:0] b = (rs2==0) ? 0 : regfile[rs2]; //  index 0 is zero register, so return 0.
    
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

    reg raise_exception;
    reg ecall_exception;
    reg load_addr_miss_align;
    reg store_atomic_addr_miss_align;
    reg atomin_addr_miss_aligned;

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
      is_mret = 0;
      is_csr = 0;
      is_atomic = 0;
      raise_exception = 0;
      load_addr_miss_align = 0;
      store_atomic_addr_miss_align = 0;
      ecall_exception = 0;

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
            raise_exception = 1;
            load_addr_miss_align = 1;
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
            raise_exception = 1;
            load_addr_miss_align = 1;
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
            raise_exception = 1;
            load_addr_miss_align = 1;
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
            raise_exception = 1;
            store_atomic_addr_miss_align = 1;
          end

        end

        i_sw: begin                                    // 4 bytes store
          alu_out = a + stimm;
          mem_addr  = {2'b0, alu_out[31:2]};
          wmem = 4'b1111;                              // Which Byte position is it sorted to?
          is_store = 1;
          if(alu_out[1:0] != 2'b00)begin               // miss aligned
            is_store = 0;
            raise_exception = 1;
            store_atomic_addr_miss_align = 1;
          end
        
        end

        i_beq: begin                                   
          if (a == b) begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset; 
          end
        end

        i_bne: begin                                   
          if (a != b)begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset; 
          end
        end

        i_blt: begin                                   
          if ($signed(a) < $signed(b))begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset; 
          end
        end

        i_bge: begin                                   
          if ($signed(a) >= $signed(b))begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset; 
          end
        end

        i_bltu: begin                                  
          if ({1'b0,a} < {1'b0,b})begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset;
          end
        end

        i_bgeu: begin                                  
          if ({1'b0,a} >= {1'b0,b})begin
            alu_out = 1;
            is_jump = 1;
            jump_addr = pc + broffset;
           end 
        end

        i_auipc: begin                                 
          alu_out = pc + uimm;
          is_write_back = 1; 
        end
          
        i_lui: begin                                   
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

        i_csrrw, i_csrrs, i_csrrc, i_csrrwi, i_csrrsi, i_csrrci:begin
          is_csr = 1;
        end

        i_mret:begin
          is_mret = 1;
        end

        i_amoadd, i_amoand, i_amomax, i_amomaxu, i_amomin, i_amominu, i_amomor, i_amoswap, i_amoxor, i_sc, i_lr:begin
          is_atomic = 1;  
          if(a[1:0] != 2'b00)begin
            raise_exception = 1;
            store_atomic_addr_miss_align = 1;
            is_atomic = 0;
          end 
        end

        i_ecall:begin
          raise_exception = 1;
          ecall_exception = 1;
        end

        default:;
      endcase
    end

    // load
    reg [31:0] load_data;  

    always_comb begin
      case (rmem) 
        // unsgigned 1 byte
        5'b00001: load_data = {24'h0, mem[mem_addr][7:0]};
        5'b00010: load_data = {24'h0, mem[mem_addr][15:8]};
        5'b00100: load_data = {24'h0, mem[mem_addr][23:16]};
        5'b01000: load_data = {24'h0, mem[mem_addr][31:24]};
        // signed 1 byte
        5'b10001: load_data = {{24{mem[mem_addr][7]}}, mem[mem_addr][7:0]};
        5'b10010: load_data = {{24{mem[mem_addr][15]}}, mem[mem_addr][15:8]};
        5'b10100: load_data = {{24{mem[mem_addr][23]}}, mem[mem_addr][23:16]};
        5'b11000: load_data = {{24{mem[mem_addr][31]}}, mem[mem_addr][31:24]};
        // unsigned 2 bytes
        5'b00011: load_data = {16'b0, mem[mem_addr][15:0]};  
        5'b01100: load_data = {16'h0, mem[mem_addr][31:16]}; 
        // signed 2 bytes
        5'b10011: load_data = {{16{mem[mem_addr][15]}}, mem[mem_addr][15:0]};  
        5'b11100: load_data = {{16{mem[mem_addr][31]}}, mem[mem_addr][31:16]}; 
        // 4 bytes
        5'b01111: load_data = mem[mem_addr];
        default: load_data = 0;    
      endcase
    end
    
    wire rise_timer_interrupt = (mtimecmp == mtime && !csr_reg.mip.mtip && csr_reg.mie.mtie && csr_reg.mstatus.mie) ? 1: 0;
                                                    //   not pending     enable timer interrupt   emable interrupt
    reg [63:0] mtime = 0;
    reg [63:0] mtimecmp = 0;

    reg [31:0] reservation_reg = 0;   // for sc/lr operation

  // store
  always_ff@(posedge clk)begin
    if(reset)begin
      mtime <= 0;
    end else begin
      if(is_store && alu_out == MTIME_ADDR) mtime <= store_data; 
      else if(!(is_store && alu_out == MTIME_ADDR) && !csr_reg.mip.mtip && csr_reg.mie.mtie) mtime <= mtime + 1;
    end
  end

  always_ff@(posedge clk)begin
    if(reset)
      mtimecmp <= 0;
    else begin
      if(is_store && alu_out == MTIMECMP_ADDR) mtimecmp <= store_data;
    end  
  end

  always_ff@(posedge clk)begin
    if(is_store && alu_out < MEMMAP_BASE_ADDR)  
      mem[mem_addr] <= store_data;
    else if(is_atomic)begin
      case(1'b1)
        i_amoadd:  mem[a] <= mem[a] + b;    
        i_amoand:  mem[a] <= mem[a] & b;
        i_amomax:  mem[a] <= ($signed(mem[a]) > $signed(b)) ? mem[a] : mem[b];
        i_amomaxu: mem[a] <= (a > b) ? mem[a] : mem[b];
        i_amomin:  mem[a] <= ($signed(mem[a]) > $signed(b)) ? mem[b] : mem[a];
        i_amominu: mem[a] <= (a > b) ? mem[b] : mem[a];
        i_amomor:  mem[a] <= mem[a] | b;
        i_amoswap: mem[a] <= b;
        i_amoxor:  mem[a] <= mem[a] ^ b;
        i_sc: if(reservation_reg == a) mem[a] <= b;            
        default:;
      endcase
    end
  end

  // control csr register
  csr_reg_t csr_reg = {0,0,0,0,0,0,0};

  always_ff @ (posedge clk) begin
    if(reset)begin
      csr_reg.mstatus.mpp <= MACHINE_MODE; // machine mode only
    end else if(is_csr)begin
      case(1'b1)
        i_csrrw:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus  <= a; 
            MIE_ADDR:     csr_reg.mie      <= a; 
            MTVEC_ADDR:   csr_reg.mtvec    <= a; 
            MEPC_ADDR:    csr_reg.mepc     <= a;
            MCAUSE_ADDR:  csr_reg.mcause   <= a;
            MTVAL_ADDR:   csr_reg.mtval    <= a;
            MIP_ADDR:     csr_reg.mip      <= a;
            PMPCFG0:      csr_reg.pmpcfg0  <= a;
            PMPADDR0:     csr_reg.pmpaddr0 <= a;
            default:;
          endcase
        end

        i_csrrs:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus  <= csr_reg.mstatus | a; 
            MIE_ADDR:     csr_reg.mie      <= csr_reg.mie | a; 
            MTVEC_ADDR:   csr_reg.mtvec    <= csr_reg.mtvec | a; 
            MEPC_ADDR:    csr_reg.mepc     <= csr_reg.mepc | a;
            MCAUSE_ADDR:  csr_reg.mcause   <= csr_reg.mcause | a;
            MTVAL_ADDR:   csr_reg.mtval    <= csr_reg.mtval | a;
            MIP_ADDR:     csr_reg.mip      <= csr_reg.mip | a;
            PMPCFG0:      csr_reg.pmpcfg0  <= csr_reg.pmpcfg0 | a;
            PMPADDR0:     csr_reg.pmpaddr0 <= csr_reg.pmpaddr0 |a;
            default:;
          endcase
        end

        i_csrrc :begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus <= csr_reg.mstatus &~ a; 
            MIE_ADDR:     csr_reg.mie     <= csr_reg.mie &~ a; 
            MTVEC_ADDR:   csr_reg.mtvec   <= csr_reg.mtvec &~ a; 
            MEPC_ADDR:    csr_reg.mepc    <= csr_reg.mepc &~ a;
            MCAUSE_ADDR:  csr_reg.mcause  <= csr_reg.mcause &~ a;
            MTVAL_ADDR:   csr_reg.mtval   <= csr_reg.mtval &~ a;
            MIP_ADDR:     csr_reg.mip     <= csr_reg.mip &~ a;
            PMPCFG0:      csr_reg.pmpcfg0  <= csr_reg.pmpcfg0 &~ a;
            PMPADDR0:     csr_reg.pmpaddr0 <= csr_reg.pmpaddr0 &~ a;
            default:;
          endcase
        end

        i_csrrwi:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus <= zimm; 
            MIE_ADDR:     csr_reg.mie     <= zimm; 
            MTVEC_ADDR:   csr_reg.mtvec   <= zimm; 
            MEPC_ADDR:    csr_reg.mepc    <= zimm;
            MCAUSE_ADDR:  csr_reg.mcause  <= zimm;
            MTVAL_ADDR:   csr_reg.mtval   <= zimm;
            MIP_ADDR:     csr_reg.mip     <= zimm;
            PMPCFG0:      csr_reg.pmpcfg0  <= zimm;
            PMPADDR0:     csr_reg.pmpaddr0 <= zimm;
            default:;
          endcase         
        end

        i_csrrsi:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus <= csr_reg.mstatus | zimm; 
            MIE_ADDR:     csr_reg.mie     <= csr_reg.mstatus | zimm; 
            MTVEC_ADDR:   csr_reg.mtvec   <= csr_reg.mstatus | zimm; 
            MEPC_ADDR:    csr_reg.mepc    <= csr_reg.mstatus | zimm;
            MCAUSE_ADDR:  csr_reg.mcause  <= csr_reg.mstatus | zimm;
            MTVAL_ADDR:   csr_reg.mtval   <= csr_reg.mstatus | zimm;
            MIP_ADDR:     csr_reg.mip     <= csr_reg.mstatus | zimm;
            PMPCFG0:      csr_reg.pmpcfg0  <= csr_reg.mstatus | zimm;
            PMPADDR0:     csr_reg.pmpaddr0 <= csr_reg.mstatus | zimm;
            default:;
          endcase         
        end

        i_csrrci:begin
          case(csr)
            MSTATUS_ADDR: csr_reg.mstatus <= csr_reg.mstatus &~ zimm; 
            MIE_ADDR:     csr_reg.mie     <= csr_reg.mie &~ zimm; 
            MTVEC_ADDR:   csr_reg.mtvec   <= csr_reg.mtvec &~ zimm; 
            MEPC_ADDR:    csr_reg.mepc    <= csr_reg.mepc &~ zimm;
            MCAUSE_ADDR:  csr_reg.mcause  <= csr_reg.mcause &~ zimm;
            MTVAL_ADDR:   csr_reg.mtval   <= csr_reg.mtval &~ zimm;
            MIP_ADDR:     csr_reg.mip     <= csr_reg.mip &~ zimm;
            PMPCFG0:      csr_reg.pmpcfg0  <= csr_reg.mstatus &~ zimm;
            PMPADDR0:     csr_reg.pmpaddr0 <= csr_reg.mstatus &~ zimm;
            default:;
          endcase
        end
        default:;
      endcase      
    end else begin
      case(1'b1)
        i_mret:begin
          csr_reg.mstatus.mpp <= MACHINE_MODE;  // machine mode only
          csr_reg.mstatus.mie <= csr_reg.mstatus.mpie;
          csr_reg.mstatus.mpie <= 1;  // enable insterrupt again
        end
        //i_ecall:begin
        //  csr_reg.mcause.exception_code <= (csr_reg.mstatus.mpp == MACHINE_MODE) ? ECALL_ENVIROMENT_FROM_M : 
        //                                    (csr_reg.mstatus.mpp == USER_MODE) ? ECALL_ENVIROMENT_FROM_U : ECALL_ENVIROMENT_FROM_S;
        //  csr_reg.mstatus.mpp <= MACHINE_MODE;
        //  csr_reg.mepc <= pc;
        //  csr_reg.mstatus.mpie <= csr_reg.mstatus.mie; 
        //  csr_reg.mstatus.mie <= 0;    // nested interrupt is not supported.
        //end
        default:;
      endcase
    end

     if(load_addr_miss_align)begin
      csr_reg.mcause.exception_code <= LOAD_ADDR_MISSALIGNED;
      csr_reg.mstatus.mpp <= MACHINE_MODE;
      csr_reg.mepc <= pc;
      csr_reg.mstatus.mpie <= csr_reg.mstatus.mie; 
      csr_reg.mstatus.mie <= 0;    // nested interrupt is not supported.
    end else 
    if(store_atomic_addr_miss_align)begin
      csr_reg.mcause.exception_code <= STORE_AMO_ADDR_MISSALIGN;
      csr_reg.mstatus.mpp <= MACHINE_MODE;
      csr_reg.mepc <= pc;
      csr_reg.mstatus.mpie <= csr_reg.mstatus.mie; 
      csr_reg.mstatus.mie <= 0;    // nested interrupt is not supported.
    end else 
    if(ecall_exception)begin
      csr_reg.mcause.exception_code <= (csr_reg.mstatus.mpp == MACHINE_MODE) ? ECALL_ENVIROMENT_FROM_M : 
                                        (csr_reg.mstatus.mpp == USER_MODE) ? ECALL_ENVIROMENT_FROM_U : ECALL_ENVIROMENT_FROM_S;
      csr_reg.mstatus.mpp <= MACHINE_MODE;
      csr_reg.mepc <= pc;
      csr_reg.mstatus.mpie <= csr_reg.mstatus.mie; 
      csr_reg.mstatus.mie <= 0;    // nested interrupt is not supported.
    end
    else if(rise_timer_interrupt) begin  
      if(csr_reg.mtvec.mode == 0) csr_reg.mcause.exception_code <= MACHINE_TIMER_INTERRUPT;
      csr_reg.mstatus.mpp <= MACHINE_MODE;
      csr_reg.mcause.interrupt <= 1;
      csr_reg.mepc <= pc;
      csr_reg.mstatus.mpie <= csr_reg.mstatus.mie; 
      csr_reg.mstatus.mie <= 0;    // nested interrupt is not supported.
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
      case(csr)
        MSTATUS_ADDR: if(rd != 0) regfile[rd] <= csr_reg.mstatus; 
        MIE_ADDR:     if(rd != 0) regfile[rd] <= csr_reg.mie; 
        MTVEC_ADDR:   if(rd != 0) regfile[rd] <= csr_reg.mtvec;
        MEPC_ADDR:    if(rd != 0) regfile[rd] <= csr_reg.mepc;
        MCAUSE_ADDR:  if(rd != 0) regfile[rd] <= csr_reg.mcause;
        MTVAL_ADDR:   if(rd != 0) regfile[rd] <= csr_reg.mtval;
        MIP_ADDR:     if(rd != 0) regfile[rd] <= csr_reg.mip;
        PMPCFG0:      if(rd != 0) regfile[rd] <= csr_reg.pmpcfg0;
        PMPADDR0:     if(rd != 0) regfile[rd] <= csr_reg.pmpaddr0;
        default:;
      endcase        
    end else if(is_atomic)begin
    // atomic operation
      case(1'b1)
        i_amoadd, i_amoand, i_amomax, i_amomaxu, i_amomin, i_amominu, i_amomor, i_amoswap, i_amoxor:  if(rd != 0) regfile[rd] <= mem[a]; 
        i_sc:begin
          if(reservation_reg == a) if(rd != 0) regfile[rd] <= 0;         
          else if(rd != 0) regfile[rd] <= 1;       
        end
        i_lr:begin
          reservation_reg <= a;
          if(rd != 0) regfile[rd] <= mem[a];
        end
        default:;
      endcase
    end
  end

endmodule  