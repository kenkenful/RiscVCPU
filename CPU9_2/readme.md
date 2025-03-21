JUMP命令をDECODEステージで実施するようにしています。
JUMPの判定に使用するレジスタファイルの値で、間に合わないものはフォワーディングで対処します。
また、ロード命令など原理的に間に合わない場合は、ストールさせます。

```
 a_j = (rs1_de == 0) ? 0 : (!is_load_ex & is_write_back_ex & (rd_ex == rs1_de)) ? alu_out_ex : 
                                (!is_load_mem & is_write_back_mem & (rd_mem == rs1_de)) ? alu_out_mem : 
                                (is_write_back_wb & (rd_wb == rs1_de)) ? write_back_data : regfile[rs1_de]; 
      
b_j = (rs2_de == 0) ? 0 : (!is_load_ex & is_write_back_ex & (rd_ex == rs2_de)) ? alu_out_ex : 
                                (!is_load_mem & is_write_back_mem & (rd_mem == rs2_de)) ? alu_out_mem :
                                (is_write_back_wb & (rd_wb == rs2_de)) ? write_back_data : regfile[rs2_de];  

is_stoll_j  = ((de.i_beq | de.i_bne | de.i_blt | de.i_bge | de.i_bltu | de.i_bgeu) & is_load_ex & ((rd_ex == rs1_de) | (rd_ex == rs2_de)))  |
                    ((de.i_beq | de.i_bne | de.i_blt | de.i_bge | de.i_bltu | de.i_bgeu) & is_load_mem & ((rd_mem == rs1_de) | (rd_mem == rs2_de))) |
                    (de.i_jalr & is_load_ex & (rd_ex == rs1_de)) |
                    (de.i_jalr & is_load_mem & (rd_mem == rs1_de)); 

```
