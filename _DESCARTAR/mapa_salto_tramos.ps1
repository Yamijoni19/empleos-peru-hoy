$ErrorActionPreference = "Stop"
$ruta = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$salida = "C:\Users\Dell G3 Gaming\Documents\Default Project\mapa_salto_tramos.txt"
$lineas = [System.IO.File]::ReadAllLines($ruta, [System.Text.Encoding]::UTF8)
$total = $lineas.Length

$p = 0; $ll = 0; $minP = 0; $minL = 0
$saltos = New-Object System.Collections.ArrayList
for($i=0;$i -lt $total;$i++){
  $ln = $lineas[$i]
  foreach($c in $ln.ToCharArray()){
    if($c -eq "("){ $p++ }
    elseif($c -eq ")"){ $p--; if($p -lt $minP){ $minP = $p } }
    elseif($c -eq "{"){ $ll++ }
    elseif($c -eq "}"){ $ll--; if($ll -lt $minL){ $minL = $ll } }
  }
  if(($p -ne 0 -or $ll -ne 0) -and $i -ge 7280){
    [void]$saltos.Add("L$($i+1) p=$p ll=$ll")
  }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("Archivo: $($lineas.Length) lineas  TOTAL p=$p ll=$ll minP=$minP minL=$minL")
for($inicio=7300; $inicio -le $total; $inicio+=25){
  $p2=0; $ll2=0; $minp2=0; $minl2=0
  $fin = $inicio+24
  if($fin -gt $total){ $fin = $total }
  for($i=$inicio-1;$i -lt $fin;$i++){
    $ln = $lineas[$i]
    foreach($c in $ln.ToCharArray()){
      if($c -eq "("){ $p2++ }
      elseif($c -eq ")"){ $p2--; if($p2 -lt $minp2){ $minp2 = $p2 } }
      elseif($c -eq "{"){ $ll2++ }
      elseif($c -eq "}"){ $ll2--; if($ll2 -lt $minl2){ $minl2 = $ll2 } }
    }
  }
  [void]$sb.AppendLine(("Tramo {0,4}-{1,4}:  p={2,3}  ll={3,3}  minP={4,2}  minL={5,2}" -f $inicio,$fin,$p2,$ll2,$minp2,$minl2))
}
[System.IO.File]::WriteAllText($salida, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"Mapa escrito en: $salida"