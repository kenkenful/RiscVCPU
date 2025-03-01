`ifndef _define_
`define _define_


typedef struct packed{
    reg [31:0]  a;
    reg [31:0]  b;
    reg [31:0]  jaloffset;
    reg [31:0]  broffset;
    reg [4:0]   shamt; 
    reg [31:0]  simm;
    reg [31:0]  uimm; 
    reg [31:0]  stimm; 

    reg [31:0] pc;
    reg [31:0] pc_plus;
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

}de_ex_pipeline_reg;



 
`endif