module decode(
    inst,
    //opcode,
    rs1,
    rs2,
    rd,
    
    shamt,
    broffset,
    simm,
    stimm,
    uimm,
    jaloffset,
    
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
    );
    
    input wire [31:0] inst;
    
    output reg [4:0] rd;  
    output reg [4:0] rs1; 
    output reg [4:0] rs2; 
    
    output reg [4:0] shamt;
    output reg [31:0] broffset;
    output reg [31:0] simm; 
    output reg [31:0] stimm;   
    output reg [31:0] uimm;   
    output reg [31:0] jaloffset;
    
    output reg i_auipc ;
    output reg i_lui   ;
    output reg i_jal   ;
    output reg i_jalr  ;
    output reg i_beq   ;
    output reg i_bne   ;
    output reg i_blt   ;
    output reg i_bge   ;
    output reg i_bltu  ;
    output reg i_bgeu  ;
    output reg i_lb    ;
    output reg i_lh    ;
    output reg i_lw    ;
    output reg i_lbu   ;
    output reg i_lhu   ;
    output reg i_sb    ;
    output reg i_sh    ;
    output reg i_sw    ;
    output reg i_addi  ;
    output reg i_slti  ;
    output reg i_sltiu ;
    output reg i_xori  ;
    output reg i_ori   ;
    output reg i_andi  ;
    output reg i_slli  ;
    output reg i_srli  ;
    output reg i_srai  ;
    output reg i_add   ;
    output reg i_sub   ;
    output reg i_sll   ;
    output reg i_slt   ;
    output reg i_sltu  ;
    output reg i_xor   ;
    output reg i_srl   ;
    output reg i_sra   ;
    output reg i_or    ;
    output reg i_and   ;

    output reg i_fence  ;
    output reg i_fencei ;
    output reg i_ecall  ;
    output reg i_ebreak ;
   
    // rv32 zicsr
    output reg i_csrrw  ;
    output reg i_csrrs  ;
    output reg i_csrrc  ;
    output reg i_csrrwi ;
    output reg i_csrrsi ;
    output reg i_csrrci ;

    // rv32m
    output reg i_mul    ;
    output reg i_mulh   ;
    output reg i_mulhsu ;
    output reg i_mulhu  ;
    output reg i_div    ;
    output reg i_divu   ;
    output reg i_rem    ;
    output reg i_remu   ;
    
    reg [6:0] opcode;  
    reg [2:0] funct3; 
    reg [6:0] funct7; 
   
    reg sign;
    reg [11:0] imm;
    
    always_comb begin
        opcode = inst[6:0];
        rd     = inst[11:7];
        rs1     = inst[19:15];
        rs2     = inst[24:20];
        shamt  = inst[24:20];
    
        funct3  = inst[14:12]; 
        funct7  = inst[31:25]; 
   
        sign   = inst[31];
        imm    = inst[31:20];
    
         // branch offset            31:13          12      11       10:5         4:1     0
        broffset  = {{19{sign}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};   // beq, bne,  blt,  bge,   bltu, bgeu
    
        simm      = {{20{sign}},inst[31:20]};                                    // lw,  addi, slti, sltiu, xori, ori,  andi, jalr
    
        stimm     = {{20{sign}},inst[31:25],inst[11:7]};                         // store word    memory address
    
        uimm      = {inst[31:12],12'h0};                                         // lui, auipc
    
        jaloffset = {{11{sign}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0}; // jal
        // jal target               31:21          20       19:12       11       10:1      0

        i_auipc = (opcode == 7'b0010111);
        i_lui   = (opcode == 7'b0110111);
        i_jal   = (opcode == 7'b1101111);
        i_jalr  = (opcode == 7'b1100111) & (funct3 == 3'b000);
        i_beq   = (opcode == 7'b1100011) & (funct3 == 3'b000);
        i_bne   = (opcode == 7'b1100011) & (funct3 == 3'b001);
        i_blt   = (opcode == 7'b1100011) & (funct3 == 3'b100);
        i_bge   = (opcode == 7'b1100011) & (funct3 == 3'b101);
        i_bltu  = (opcode == 7'b1100011) & (funct3 == 3'b110);
        i_bgeu  = (opcode == 7'b1100011) & (funct3 == 3'b111);
        i_lb    = (opcode == 7'b0000011) & (funct3 == 3'b000);
        i_lh    = (opcode == 7'b0000011) & (funct3 == 3'b001);
        i_lw    = (opcode == 7'b0000011) & (funct3 == 3'b010);
        i_lbu   = (opcode == 7'b0000011) & (funct3 == 3'b100);
        i_lhu   = (opcode == 7'b0000011) & (funct3 == 3'b101);
        i_sb    = (opcode == 7'b0100011) & (funct3 == 3'b000);
        i_sh    = (opcode == 7'b0100011) & (funct3 == 3'b001);
        i_sw    = (opcode == 7'b0100011) & (funct3 == 3'b010);
        i_addi  = (opcode == 7'b0010011) & (funct3 == 3'b000);
        i_slti  = (opcode == 7'b0010011) & (funct3 == 3'b010);
        i_sltiu = (opcode == 7'b0010011) & (funct3 == 3'b011);
        i_xori  = (opcode == 7'b0010011) & (funct3 == 3'b100);
        i_ori   = (opcode == 7'b0010011) & (funct3 == 3'b110);
        i_andi  = (opcode == 7'b0010011) & (funct3 == 3'b111);
        i_slli  = (opcode == 7'b0010011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        i_srli  = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        i_srai  = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        i_add   = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000000);
        i_sub   = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0100000);
        i_sll   = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);
        i_slt   = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000000);
        i_sltu  = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000000);
        i_xor   = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000000);
        i_srl   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);
        i_sra   = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);
        i_or    = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000000);
        i_and   = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000000);

        i_fence  = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (inst[31:28] == 4'b0000);
        i_fencei = (opcode == 7'b0001111) & (rd == 5'b00000) & (funct3 == 3'b001) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        i_ecall  = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000000);
        i_ebreak = (opcode == 7'b1110011) & (rd == 5'b00000) & (funct3 == 3'b000) & (rs1 == 5'b00000) & (imm == 12'b000000000001);
    
        // rv32 zicsr
        i_csrrw  = (opcode == 7'b1110011) && (funct3 == 3'b001);
        i_csrrs  = (opcode == 7'b1110011) && (funct3 == 3'b010);
        i_csrrc  = (opcode == 7'b1110011) && (funct3 == 3'b011);
        i_csrrwi = (opcode == 7'b1110011) && (funct3 == 3'b101);
        i_csrrsi = (opcode == 7'b1110011) && (funct3 == 3'b110);
        i_csrrci = (opcode == 7'b1110011) && (funct3 == 3'b111);

        // rv32m
        i_mul    = (opcode == 7'b0110011) && (funct3 == 3'b000) && (funct7 == 7'b0000001);
        i_mulh   = (opcode == 7'b0110011) && (funct3 == 3'b001) && (funct7 == 7'b0000001);
        i_mulhsu = (opcode == 7'b0110011) && (funct3 == 3'b010) && (funct7 == 7'b0000001);
        i_mulhu  = (opcode == 7'b0110011) && (funct3 == 3'b011) && (funct7 == 7'b0000001);
        i_div    = (opcode == 7'b0110011) && (funct3 == 3'b100) && (funct7 == 7'b0000001);
        i_divu   = (opcode == 7'b0110011) && (funct3 == 3'b101) && (funct7 == 7'b0000001);
        i_rem    = (opcode == 7'b0110011) && (funct3 == 3'b110) && (funct7 == 7'b0000001);
        i_remu   = (opcode == 7'b0110011) && (funct3 == 3'b111) && (funct7 == 7'b0000001);

    end
endmodule