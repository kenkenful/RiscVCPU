5段のパイプラインになります。命令メモリとデータメモリをマージしました。</br>
ロード命令がレジスタファイルに書き戻されるのに3サイクルかかるので、Decode/Executeパイプラインレジスタで+1サイクルして</br>4サイクル後にExecute Stageで書き戻した値を使う場合は更新された値を使うことができて問題なしです。</br>
普通のコンパイラはそんな忖度をしてくれないので、
1サイクル後、2サイクル後、3サイクル後にExecute Stageで、書き戻された値を使う場合をフォワーディングを使ってCPU側で対処して上げないといけないです。</br>
ただし、1サイクル後については、ロード自体が完了しておらず原理的にフォワーディング不可能なため、パイプラインレジスタをストールさせます。


```
// Decode Stage
                          　　　　　 3サイクル後に対処        
a_de = (rs1_de == 0) ? 0 : (is_write_back_wb & (rd_wb == rs1_de)) ? write_back_data : regfile[rs1_de]; 
b_de = (rs2_de == 0) ? 0 : (is_write_back_wb & (rd_wb == rs2_de)) ? write_back_data : regfile[rs2_de];  
```


```
// Execute Stage
　　　　　　　1サイクル後に対処（ただし、load命令は除外）　　　　　　　　　　　　　　　　　　　　　　2サイクル後に対処　 
a = (!is_load_mem & is_write_back_mem & (rd_mem == rs1_ex)) ? alu_out_mem : (is_write_back_wb & (rd_wb == rs1_ex)) ? write_back_data : a_ex;
b = (!is_load_mem & is_write_back_mem & (rd_mem == rs2_ex)) ? alu_out_mem : (is_write_back_wb & (rd_wb == rs2_ex)) ? write_back_data : b_ex;

　　　　　　　　　1サイクル後にロード命令を使用する場合は、ストールさせる。　　　
is_stoll = (is_load_mem & ((rd_mem == rs1_ex) | (rd_mem == rs2_ex)));
```
