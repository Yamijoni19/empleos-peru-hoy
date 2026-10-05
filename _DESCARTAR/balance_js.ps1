$ErrorActionPreference = "SilentlyContinue"
$f = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$lin = Get-Content -LiteralPath $f
$abre = "//<![CDATA["
$cierra = "//]]>"
$bi = -1
for($i=0;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $abre){ $bi=$i } }
$ej = -1
for($i=$bi+1;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $cierra){ $ej=$i; break } }
"CDATA JS start file line $($bi+1) / end $($ej+1)"
$bA=0; $bC=0; $bL=0; $bQ=0
$sinCerrar=-1
for($n=$bi+1;$n -lt $ej;$n++){
  $t = $lin[$n]
  $chars = $t.ToCharArray()
  for($k=0;$k -lt $chars.Count;$k++){
    $ch = $chars[$k]
    if($ch -eq '('){ $bA++ }
    elseif($ch -eq ')'){ $bA--; if($bA -lt 0){ $sinCerrar=$n+1; break } }
    if($ch -eq '{'){ $bL++ }
    elseif($ch -eq '}'){ $bL-- }
  }
  if($sinCerrar -gt 0){ break }
}
"balance final ( ) = $bA  { } = $bL"
if($sinCerrar -gt 0){
  "PRIMER DESBALANCE: file line $sinCerrar (un ')' de sobra)"
  for($k=$sinCerrar-2;$k -le $sinCerrar+2;$k++){ "{0}: {1}" -f $k, $lin[$k-1] }
} else {
  "Sin ')' de sobra. Verifico ahora desbalance de '(' sin cerrar hasta el final:"
}
$bA2=0;$bL2=0;$qfin=-1
for($n=$bi+1;$n -lt $ej;$n++){
  $t=$lin[$n]; $chars=$t.ToCharArray()
  foreach($ch in $chars){
    if($ch -eq '('){$bA2++} elseif($ch -eq ')'){$bA2--}
    if($ch -eq '{'){$bL2++} elseif($ch -eq '}'){$bL2--}
  }
}
"balance real al cierre: ( ) = $bA2  { } = $bL2"
if($bA2 -ne 0){ "( ) no balanceado en $bA2" }
if($bL2 -ne 0){ "{ } no balanceado en $bL2" }
