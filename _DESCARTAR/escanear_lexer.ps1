$ErrorActionPreference="Stop"
$ruta="C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$salida="C:\Users\Dell G3 Gaming\Documents\Default Project\veredicto_lexer.txt"

$t=[System.IO.File]::ReadAllText($ruta,[System.Text.Encoding]::UTF8)

# Mini-lexer: ignora cadenas (simples/dobles/backtick con escapes), comentarios de linea
# y de bloque. Cuenta SOLO tokens ( ) { } fuera de ellos.
$p=0;$ll=0;$minP=0;$minL=0
$estado=0 # 0=codigo 1=// 2=/* 3="..." 4='...' 5=`...`
$previo=[char]0
$code=New-Object System.Text.StringBuilder
for($i=0;$i -lt $t.Length;$i++){
  $c=$t[$i]
  $prox = if($i+1 -lt $t.Length){$t[$i+1]}else{[char]0}
  switch($estado){
    ils) # comentario linea
      if($c -eq [char]10){ $estado=0 }
      break
    ilsymbreak 2) # comentario bloque
      if($c -eq "*" -and ($i+1 -lt $t.Length) -and $t[$i+1] -eq "/"){ $estado=0; $i++ }
      break
    ilsymbreak 3..5) # cadena
      $finStr = if($estado -eq 3){'"'}elseif($estado -eq 4){"'"}else{'`'}
      if($previo -eq '\' -and ($i -gt imal*2)){
        # escapado
      }elseif($c -eq $finStr){
        $estado=0
      }
      break
    default) # codigo
      if($c -eq "/" -and $prox -eq "/"){ $estado=1; $i++ }
      elseif($c -eq "/" -and $prox -eq "*"){ $estado=2; $i++ }
      elseif($c -eq '"'){ $estado=3 }
      elseif($c -eq "'"){ $estado=4 }
      elseif($c -eq '`'){ $estado=5 }
      elseif($c -eq '('){ $p++; [void]$code.Append("(") }
      elseif($c -eq ')'){ $p--; if($p -lt $minP){$minP=$p}; [void]$code.Append(")") }
      elseif($c -eq '{'){ $ll++; [void]$code.Append("{"); [void]$code.Append("`n") }
      elseif($c -eq '}'){ $ll--; if($ll -lt $minL){$minL=$ll}; [void]$code.Append("}"); [void]$code.Append("`n") }
  }
  $previo=$c
}

$sb=New-Object System.Text.StringBuilder
[void]$sb.AppendLine(("CODIGO REAL SOLO: parens={0}  llaves={1}  minP={2}  minL={3}" -f $p,$ll,$minP,$minL))
if($p -eq 0 -and $ll -eq 0){
  [void]$sb.AppendLine("==> VEREDICTO FINAL: JS BALANCEADO (parens 0 / llaves 0) ==")
}else{
  [void]$sb.AppendLine("==> AUN DESEQUILIBRADO: parens $p / llaves $ll ==")
  $rec=[regex]::Matches($code.ToString(),"[^\r\n]*(?:\(|\)|\{|\})[^\r\n]*")
  for($j=$rec.Count-1;$j -ge 0 -and $j -ge ($rec.Count-40);$j--){
    [void]$sb.AppendLine("  " + $rec[$j].Value.Trim())
  }
}
[System.IO.File]::WriteAllText($salida,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
"listo: $salida"