$ErrorActionPreference = "Stop"
$ruta = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$lineas = [System.IO.File]::ReadAllLines($ruta, [System.Text.Encoding]::UTF8)
$p = 0; $ll = 0; $minP = 0; $minL = 0
$saltosP = @(); $saltosL = @()
for($i=0; $i -lt $lineas.Length; $i++){
  $ln = $lineas[$i]
  foreach($c in $ln.ToCharArray()){
    if($c -eq "("){ $p++ }
    elseif($c -eq ")"){ $p--; if($p -lt $minP){ $minP = $p } }
    elseif($c -eq "{"){ $ll++ }
    elseif($c -eq "}"){ $ll--; if($ll -lt $minL){ $minL = $ll } }
  }
  if($p -ne 0 -or $ll -ne 0){
    if($saltosP.Count -lt 14 -and ($($saltosP|ForEach-Object{$_.p}) -notcontains $p) -or $saltosP.Count -lt 8){
      $saltosP += [pscustomobject]@{ l=$i+1; p=$p; ll=$ll }
    }
  }
}
"TOTAL: parens=$p  llaves=$ll  minP=$minP  minL=$minL"
"Saltos (linea real : parens/laves) -> ultimas 12 lineas con saldo distinto:"
$saltosP | Select-Object -Last 12 | ForEach-Object { "  linea $($_.l):  p=$($_.p)  ll=$($_.ll)" }
