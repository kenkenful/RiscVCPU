`ifndef _define_
`define _define_

// CPU mode
parameter USER_MODE     = 2'b00;
parameter MACHINE_MODE  = 2'b11;

//　interrupt mode
parameter VECTOR_MODE = 1;
parameter DIRECT_MODE = 0;

// INTERRUPT_CODE
parameter MACHINE_TIMER_INTERRUPT    = 7;


// Exception Code
parameter INSTRUCTION_ADDR_MISSALIGN = 0;
parameter INSTRUCTION_ACCESS_FAULT   = 1;
parameter ILLEGAL_INSTRUCTION        = 2;
parameter BREAKPOINT                 = 3;
parameter LOAD_ADDR_MISSALIGNED      = 4;
parameter LOAD_ACCESS_FAULT          = 5;
parameter STORE_AMO_ADDR_MISSALIGN   = 6;
parameter STORE_AMO_ACCESS_FAULT     = 7;
parameter ECALL_ENVIROMENT_FROM_U    = 8;
parameter ECALL_ENVIROMENT_FROM_S    = 9;
parameter ECALL_ENVIROMENT_FROM_M    = 11;


// memory mapped
parameter MEMMAP_BASE_ADDR  = 32'h20000000;
parameter UART_TX_ADDR      = 32'h20000010;
parameter MTIME_ADDR        = 32'h20000020;
parameter MTIMECMP_ADDR     = 32'h20000040;

// csr register
parameter MSTATUS_ADDR  = 32'h300;
parameter MIE_ADDR      = 32'h304;
parameter MTVEC_ADDR    = 32'h305;
parameter MEPC_ADDR     = 32'h341;
parameter MCAUSE_ADDR   = 32'h342;
parameter MTVAL_ADDR    = 32'h343;
parameter MIP_ADDR      = 32'h344;

typedef struct packed{
  bit[20:0]   reserve0;   // 13-31
  bit[1:0]    mpp;        // priviledge state
  bit[1:0]    hpp;
  bit         spp;
  bit         mpie;       // mie value before interrupt occurs
  bit         hpie;
  bit         spie;
  bit         upie;
  bit         mie;        // interrupt enable for machine mode    0: prohibit
  bit         hie;
  bit         sie;
  bit         uie;
} mstatus_t;

typedef struct packed{
  bit[29:0] base_addr;    // 2-31
  bit[1:0]  mode;         // 0-1
} mtvec_t;

typedef struct packed{
  bit       interrupt;        // 31
  bit[30:0] exception_code;   // 0-30
} mcause_t;

typedef struct packed{
  bit [19:0] reserve6; 
  bit meie;
  bit reserve5;
  bit seie;
  bit reserve4;
  bit mtie;
  bit reserve3;
  bit stie;
  bit reserve2;
  bit msie;
  bit reserve1;
  bit ssie;     
  bit reserve0;   
  
} mie_t;

typedef struct packed{
  bit [19:0] reserve6; 
  bit meip;
  bit reserve5;
  bit seip;
  bit reserve4;
  bit mtip;           // machine mode timer interrupt pending 
  bit reserve3;
  bit stip;
  bit reserve2;
  bit msip;
  bit reserve1;
  bit ssip;     
  bit reserve0;   
} mip_t;

typedef struct packed{
  mstatus_t  mstatus;
  mie_t      mie;
  mtvec_t    mtvec;
  bit[31:0]  mepc;
  mcause_t   mcause;
  bit[31:0]  mtval;
  mip_t      mip;
}csr_reg_t;

typedef struct packed{
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
    reg i_mret  ;
    reg i_amoadd;  
    reg i_amoand; 
    reg i_amomax;  
    reg i_amomaxu; 
    reg i_amomin;  
    reg i_amominu; 
    reg i_amomor;  
    reg i_amoswap; 
    reg i_amoxor;  
}de_ex_pipeline_reg;


`endif