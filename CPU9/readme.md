5段のパイプラインになります。命令メモリとデータメモリをマージしました。</br>

if分の条件式の順序は、
jumpよりstollを先に書いてあげないと、ただしく条件付き分岐が判定されないためNGです。

```
 //FETCH/DECODE pipeline reg
    always_ff@(posedge clk)begin
      if(is_stoll)begin
        pc_de <= pc_de;
        pc_plus_de <= pc_plus_de;
      end else if(is_jump)begin
        pc_de <= 0;
        pc_plus_de <= 0;
      end else begin
        pc_de <= pc;
        pc_plus_de <= pc_plus;
      end
    end

```
