$ErrorActionPreference = "Stop"
$f = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$lin = Get-Content -LiteralPath $f
$abre = "//<![CDATA["
$cierra = "//]]>"
$bi = -1
for($i=0;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $abre){ $bi=$i } }
$ej = -1
for($i=$bi+1;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $cierra){ $ej=$i; break } }
"CDATA: JS comienza archivo linea $($bi+1), cierra en $($ej+1)"

$bP = 0; $bL = 0
$primeraLineaConDefault = -1
$primeraLineaCasmuyNeg = -1
$negLinea = -1
$negCol = -1
for($n=($bi+1+1);$n -lt $ej+1;$n++){
  $t = $lin[$n-1]
  $chars = $t.ToCharArray()
  for($c=0;$c -lt $chars.Count;$c++){
    $ch = $chars[$c]
    if($ch -eq '('){ $bP++ }
    elseif($ch -eq ')'){ $bP-- ; if($bP -lt 0 -and $negLinea -lt 0){ $negLinea=$n; $negCol=$c+1 } }
    if($ch -eq '{'){ $bL++ }
    elseif($ch -eq '}'){ $bL-- ; if($bL -lt 0 -and $primeraLineaCasmuyNeg -lt 0){ $primeraLineaCasmuyNeg=$n } }
  }
  if($bP -gt 500 -and $primeraLineaConDefault -lt 0){ $primeraLineaConDefault=$n }
}
"Balance final al cierre  ( ) = $bP     { } = $bL"
if($negLinea -ge 0){ "culpable: PARENTESIS ')' en exceso en archivo linea $negLinea (col $negCol)" }
if($primeraLineaConDefault -ge 0){ "desborde de ( >500 detectado en linea $primeraLineaConDefault (falta cerrar mucho antes)" }
if($negLinea -lt 0 -and $primeraLineaConDefault -lt 0){
  "BALANCE SIEMPRE >=0 al inicio; si el total final es 0 => JS balanceado correctamente"
}
