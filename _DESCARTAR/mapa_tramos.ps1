$ErrorActionPreference = "Stop"
$ruta   = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$salida = "C:\Users\Dell G3 Gaming\Documents\Default Project\mapa_tramos_salida.txt"

$t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)

$curados = 0
if($t.IndexOf("86400000ork") -ge 0){ $t = $t.Replace("86400000ork", "86400000"); $curados++ }
if($t.IndexOf("fichaapse")    -ge 0){ $t = $t.Replace("fichaapse", "ficha");       $curados++ }

$lineas = $t -split "`n"
$total = $lineas.Length

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("archivo: $total lineas  |  reparaciones aplicadas: $curados")

$p=0; $ll=0; $minp=0; $minll=0
for($tramo=1; $tramo -le [math]::Ceiling($total/20); $tramo++){
  $p0=$p; $ll0=$ll
  $ini = (($tramo-1)*20)
  $fin = ($tramo*20)-1
  if($fin -ge $total){ $fin = $total-1 }
  for($i=$ini;$i -le $fin;$i++){
    foreach($c in $lineas[$i].ToCharArray()){
      if($c -eq "("){ $p++ } elseif($c -eq ")"){ $p--; if($p -lt $minp){ $minp=$p } }
      elseif($c -eq "{"){ $ll++ } elseif($c -eq "}"){ $ll--; if($ll -lt $minll){ $minll=$ll } }
    }
  }
  [void]$sb.AppendLine(("tramo {0,3}  lineas {1,4}-{2,4}  acumulado parens={3,4} llaves={4,4}" -f $tramo, ($ini+1), ($fin+1), $p, $ll))
}

[void]$sb.AppendLine("==> FINAL parens=$p  llaves=$ll  minParens=$minp  minLlaves=$minll")
[void]$sb.AppendLine(($curados -gt 0) ? "==> HUBO correcciones literales aplicadas arriba" : "==> Sin corrupciones literales pendientes")

[System.IO.File]::WriteAllText($salida, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"Mapa escrito a: $salida"
