


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

    reg [31:0] pc;              // program counter
    reg [31:0] jump_addr;
    reg [1:0]  jump_type;     //   00: non jump     01: non conditional jump      10 : conditional jump
          
    wire [31:0] pc_plus = pc + 4;
    wire [31:0] next_pc = (jump_type == 2'b00) ? pc_plus : jump_addr;
    
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
    
    // decode
    wire [4:0] rs1; 
    wire [4:0] rs2; 
    wire [4:0] rd;  

    wire [4:0] shamt;
    wire [31:0] broffset;
    wire [31:0] simm; 
    wire [31:0] stimm;   
    wire [31:0] uimm;   
    wire [31:0] jaloffset;
    
    wire i_auipc ;
    wire i_lui   ;
    wire i_jal   ;
    wire i_jalr  ;
    wire i_beq   ;
    wire i_bne   ;
    wire i_blt   ;
    wire i_bge   ;
    wire i_bltu  ;
    wire i_bgeu  ;
    wire i_lb    ;
    wire i_lh    ;
    wire i_lw    ;
    wire i_lbu   ;
    wire i_lhu   ;
    wire i_sb    ;
    wire i_sh    ;
    wire i_sw    ;
    wire i_addi  ;
    wire i_slti  ;
    wire i_sltiu ;
    wire i_xori  ;
    wire i_ori   ;
    wire i_andi  ;
    wire i_slli  ;
    wire i_srli  ;
    wire i_srai  ;
    wire i_add   ;
    wire i_sub   ;
    wire i_sll   ;
    wire i_slt   ;
    wire i_sltu  ;
    wire i_xor   ;
    wire i_srl   ;
    wire i_sra   ;
    wire i_or    ;
    wire i_and   ;

    wire i_fence  ;
    wire i_fencei ;
    wire i_ecall  ;
    wire i_ebreak ;
   
    // rv32 zicsr
    wire i_csrrw  ;
    wire i_csrrs  ;
    wire i_csrrc  ;
    wire i_csrrwi ;
    wire i_csrrsi ;
    wire i_csrrci ;

    // rv32m
    wire i_mul    ;
    wire i_mulh   ;
    wire i_mulhsu ;
    wire i_mulhu  ;
    wire i_div    ;
    wire i_divu   ;
    wire i_rem    ;
    wire i_remu   ;
    
    decode decode0(
        .inst   (inst  ),
        //.opcode (opcode),
        .rs1    (rs1   ),
        .rs2    (rs2   ),
        .rd     (rd    ),
        .shamt      (shamt      ),
        .broffset   (broffset   ),
        .simm       (simm       ),
        .stimm      (stimm      ),
        .uimm       (uimm       ),
        .jaloffset  (jaloffset  ),
        .i_auipc (i_auipc ),
        .i_lui   (i_lui   ),
        .i_jal   (i_jal   ),
        .i_jalr  (i_jalr  ),
        .i_beq   (i_beq   ),
        .i_bne   (i_bne   ),
        .i_blt   (i_blt   ),
        .i_bge   (i_bge   ),
        .i_bltu  (i_bltu  ),
        .i_bgeu  (i_bgeu  ),
        .i_lb    (i_lb    ),
        .i_lh    (i_lh    ),
        .i_lw    (i_lw    ),
        .i_lbu   (i_lbu   ),
        .i_lhu   (i_lhu   ),
        .i_sb    (i_sb    ),
        .i_sh    (i_sh    ),
        .i_sw    (i_sw    ),
        .i_addi  (i_addi  ),
        .i_slti  (i_slti  ),
        .i_sltiu (i_sltiu ),
        .i_xori  (i_xori  ),
        .i_ori   (i_ori   ),
        .i_andi  (i_andi  ),
        .i_slli  (i_slli  ),
        .i_srli  (i_srli  ),
        .i_srai  (i_srai  ),
        .i_add   (i_add   ),
        .i_sub   (i_sub   ),
        .i_sll   (i_sll   ),
        .i_slt   (i_slt   ),
        .i_sltu  (i_sltu  ),
        .i_xor   (i_xor   ),
        .i_srl   (i_srl   ),
        .i_sra   (i_sra   ),
        .i_or    (i_or    ),
        .i_and   (i_and   ),
        .i_fence  (i_fence  ),
        .i_fencei (i_fencei ),
        .i_ecall  (i_ecall  ),
        .i_ebreak (i_ebreak ),
        .i_csrrw  (i_csrrw ),
        .i_csrrs  (i_csrrs ),
        .i_csrrc  (i_csrrc ),
        .i_csrrwi (i_csrrwi),
        .i_csrrsi (i_csrrsi),
        .i_csrrci (i_csrrci),
        .i_mul    (i_mul   ),
        .i_mulh   (i_mulh  ),
        .i_mulhsu (i_mulhsu),
        .i_mulhu  (i_mulhu ),
        .i_div    (i_div   ),
        .i_divu   (i_divu  ),
        .i_rem    (i_rem   ),
        .i_remu   (i_remu  )
    );   
    


    reg    [31:0] regfile [1:31];                          //  regfile[0] is zero register.
    
    wire   [31:0] a = (rs1==0) ? 0 : regfile[rs1];           //  index 0 is zero register, so return 0. 
    wire   [31:0] b = (rs2==0) ? 0 : regfile[rs2];           //  index 0 is zero register, so return 0.
 
    // execute
    wire [3:0] wmem;
    wire [4:0] rmem;
    wire [31:0] mem_addr;
    wire [31:0] store_data;

    wire is_load;
    wire is_store;
    
    wire write_back;             // 
    wire [31:0] alu_out;         // alu output
    
     alu alu0(
        .a      (a      ),
        .b      (b      ),
        .pc     (pc     ),
        .pc_plus(pc_plus),
    
        .i_auipc (i_auipc),
        .i_lui   (i_lui  ),
        .i_jal   (i_jal  ),
        .i_jalr  (i_jalr ),
        .i_beq   (i_beq  ),
        .i_bne   (i_bne  ),
        .i_blt   (i_blt  ),
        .i_bge   (i_bge  ),
        .i_bltu  (i_bltu ),
        .i_bgeu  (i_bgeu ),
        .i_lb    (i_lb   ),
        .i_lh    (i_lh   ),
        .i_lw    (i_lw   ),
        .i_lbu   (i_lbu  ),
        .i_lhu   (i_lhu  ),
        .i_sb    (i_sb   ),
        .i_sh    (i_sh   ),
        .i_sw    (i_sw   ),
        .i_addi  (i_addi ),
        .i_slti  (i_slti ),
        .i_sltiu (i_sltiu),
        .i_xori  (i_xori ),
        .i_ori   (i_ori  ),
        .i_andi  (i_andi ),
        .i_slli  (i_slli ),
        .i_srli  (i_srli ),
        .i_srai  (i_srai ),
        .i_add   (i_add  ),
        .i_sub   (i_sub  ),
        .i_sll   (i_sll  ),
        .i_slt   (i_slt  ),
        .i_sltu  (i_sltu ),
        .i_xor   (i_xor  ),
        .i_srl   (i_srl  ),
        .i_sra   (i_sra  ),
        .i_or    (i_or   ),
        .i_and   (i_and  ),

        .i_fence  (i_fence ),
        .i_fencei (i_fencei),
        .i_ecall  (i_ecall ),
        .i_ebreak (i_ebreak),

        .i_csrrw  (i_csrrw ),
        .i_csrrs  (i_csrrs ),
        .i_csrrc  (i_csrrc ),
        .i_csrrwi (i_csrrwi),
        .i_csrrsi (i_csrrsi),
        .i_csrrci (i_csrrci),

        .i_mul    (i_mul   ),
        .i_mulh   (i_mulh  ),
        .i_mulhsu (i_mulhsu),
        .i_mulhu  (i_mulhu ),
        .i_div    (i_div   ),
        .i_divu   (i_divu  ),
        .i_rem    (i_rem   ),
        .i_remu   (i_remu  ),
    
        .shamt      (shamt    ),
        .broffset   (broffset ),
        .simm       (simm     ),
        .stimm      (stimm    ),   
        .uimm       (uimm     ),   
        .jaloffset  (jaloffset),
    
        .wmem       (wmem      ),
        .rmem       (rmem      ),
        .mem_addr   (mem_addr  ),
        .store_data (store_data),
        .is_load    (is_load   ),
        .is_store   (is_store  ),
        .write_back (write_back),
        .alu_out    (alu_out   ),
    
        .jump_addr  (jump_addr  ),
        .jump_type  (jump_type  ),
    
        .uart_en     (uart_en     ),
        .uart_tx_data(uart_tx_data)
    
    );
    
 
    // load/store
    dmem dmem0(
        .clk(clk),
        .wmem(wmem),
        .rmem(rmem),
        .mem_addr(mem_addr),
        .store_data(store_data),
        .load_data(load_data)
    );

    // write back
    wire [31:0] load_data;
    wire [31:0] write_back_data = is_load ? load_data : alu_out;

    always_ff @ (posedge clk) begin
        if (write_back && (rd != 0)) begin                 // rd = 0 is zero register, so cannot write back.
            regfile[rd] <= write_back_data;                 
        end
    end

endmodule