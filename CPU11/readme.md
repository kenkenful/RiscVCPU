CPU4をベースにcsrとアトミック命令、タイマー割り込みを追加しました。</br>
割り込みから復帰するアドレスは、jumpのときはjump先のアドレスを指定するようにしています。

```
csr_reg.mepc             <= is_jump ? jump_addr : pc;
```

データメモリは、クロックの立ち下がりでデータをロードし、半サイクル後のクロックの立ち上がりでデータをストアすることで
アトミック命令を実現しています。
```
// load
always_ff@(negedge clk) begin
  if(is_load) load_data = mem[mem_addr];
end
    
// store
always_ff@(posedge clk)begin
  if(is_store) mem[mem_addr] <= store_data;
end
```

csrとアトミック命令をサポートするため、ソフトウェアのビルド時のオプションを変更しています。
```
-march=rv32ima_zicsr
```
