`ifndef _define_
`define _define_

// Instruction and data memory
parameter data_width = 32;
parameter inst_addr_width = 12;   // 4k * 4 bytes = 16k
parameter total_addr_width = 15;  // 32k * 4bytes = 128k

// CPU mode
parameter USER_MODE       = 2'b00;
parameter HYPERVISOR_MODE = 2'b01;
parameter MACHINE_MODE    = 2'b11;

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
parameter INSTRUCTION_PAGE_FAULT     = 12;
parameter LOAD_PAGE_FAULT            = 13;
parameter STORE_AMO_PAGE_FAULT       = 15;
parameter NOT_DEFINED                = 16;


// memory mapped
parameter MEMMAP_BASE_ADDR  = 32'h20000000;
parameter UART_TX_ADDR      = 32'h20000010;
parameter MTIME_ADDR        = 32'h20000020;
parameter MTIMECMP_ADDR     = 32'h20000040;

// csr register
parameter MSTATUS_ADDR   = 12'h300;
parameter MISA_ADDR      = 12'h301;
parameter MIE_ADDR       = 12'h304;
parameter MTVEC_ADDR     = 12'h305;
parameter MEPC_ADDR      = 12'h341;
parameter MCAUSE_ADDR    = 12'h342;
parameter MTVAL_ADDR     = 12'h343;
parameter MIP_ADDR       = 12'h344;

parameter PMPCFG0        = 12'h3A0;
parameter PMPCFG1        = 12'h3A1;
parameter PMPCFG2        = 12'h3A2;
parameter PMPCFG3        = 12'h3A3;

parameter PMPADDR0       = 12'h3B0;
parameter PMPADDR1       = 12'h3B1;
parameter PMPADDR2       = 12'h3B2;
parameter PMPADDR3       = 12'h3B3;
parameter PMPADDR4       = 12'h3B4;
parameter PMPADDR5       = 12'h3B5;
parameter PMPADDR6       = 12'h3B6;
parameter PMPADDR7       = 12'h3B7;
parameter PMPADDR8       = 12'h3B8;
parameter PMPADDR9       = 12'h3B9;
parameter PMPADDR10      = 12'h3B10;
parameter PMPADDR11      = 12'h3B11;
parameter PMPADDR12      = 12'h3B12;
parameter PMPADDR13      = 12'h3B13;
parameter PMPADDR14      = 12'h3B14;
parameter PMPADDR15      = 12'h3B15;

parameter MVENDORID_ADDR = 12'hF11;
parameter MARCHID_ADDR   = 12'hF12;
parameter MIMPID_ADDR    = 12'hF13;
parameter MHART_ADDR     = 12'hF14;

// pmp
parameter PMP_NAPOT      = 8'h18;
parameter PMP_X          = 8'h4;
parameter PMP_W          = 8'h2;
parameter PMP_R          = 8'h1;


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
  bit [7:0] pmp3cfg;
  bit [7:0] pmp2cfg;
  bit [7:0] pmp1cfg;
  bit [7:0] pmp0cfg;
}pmpcfg;

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
  bit[31:0] pmpcfg0;  // pmp3cfg/pmp2cfg/pmp1cfg/pmp0cfg
  bit[31:0] pmpcfg1; 
  bit[31:0] pmpcfg2;  
  bit[31:0] pmpcfg3;  

  bit[31:0] pmpaddr0; 
  bit[31:0] pmpaddr1; 
  bit[31:0] pmpaddr2; 
  bit[31:0] pmpaddr3; 
  bit[31:0] pmpaddr4; 
  bit[31:0] pmpaddr5; 
  bit[31:0] pmpaddr6; 
  bit[31:0] pmpaddr7; 
  bit[31:0] pmpaddr8; 
  bit[31:0] pmpaddr9; 
  bit[31:0] pmpaddr10;
  bit[31:0] pmpaddr11;
  bit[31:0] pmpaddr12;
  bit[31:0] pmpaddr13;
  bit[31:0] pmpaddr14;
  bit[31:0] pmpaddr15;

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