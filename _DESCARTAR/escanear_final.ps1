$ErrorActionPreference="Stop"
$ruta="C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$salida="C:\Users\Dell G3 Gaming\Documents\Default Project\veredicto_final.txt"
$lineas=[System.IO.File]::ReadAllLines($ruta,[System.Text.Encoding]::UTF8)

$curados=0
for($i=0;$i -lt $lineas.Length;$i++){
  if($lineas[$i].IndexOf("86400000ork") -ge 0){
    $lineas[$i]=$lineas[$i].Replace("86400000ork","86400000"); $curados++
  }
  if($lineas[$i].IndexOf("fichaapse") -ge 0){
    $lineas[$i]=$lineas[$i].Replace("fichaapse","ficha"); $curados++
  }
}

$p=0;$ll=0;$minP=0;$minL=0
$sb=New-Object System.Text.StringBuilder
[void]$sb.AppendLine("Inicio analisis. Reparaciones idempotentes aplicadas: $curados")
[void]$sb.AppendLine("Linea | saldoP | saldoL | contenido")
for($i=7380;$i -lt $lineas.Length;$i++){
  $aP=$p;$aL=$ll
  foreach($c in $lineas[$i].ToCharArray()){
    if($c -eq "("){$p++}
    elseif($c -eq ")"){$p--;if($p -lt $minP){$minP=$p}}
    elseif($c -eq "{"){$ll++}
    elseif($c -eq "}"){$ll--;if($ll -lt $minL){$minL=$ll}}
  }
  if($p -ne 0 -or $ll -ne 0){
    $texto=($lineas[$i].Trim())
    if($texto.Length -gt 90){$texto=$texto.Substring(0,90)}
    [void]$sb.AppendLine(("L{0,5}  p={1,4}  ll={2,4}  | {3}" -f ($i+1),$p,$ll,$texto))
  }
}
[void]$sb.AppendLine(("FINAL  p={0}  ll={1}  minP={2}  minL={3}   totalLineas={4}" -f $p,$ll,$minP,$minL,$lineas.Length))
[System.IO.File]::WriteAllText($salida,$sb.ToString(),(New-Object System.Text.UTF8Encoding($false)))
"OK -> veredicto_final.txt"