$ErrorActionPreference = "Stop"
$f = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$lin = Get-Content -LiteralPath $f
$abre="//<![CDATA["; $cierra="//]]>"
$bi=-1
for($i=0;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $abre){ $bi=$i } }
$ej=-1
for($i=$bi+1;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $cierra){ $ej=$i; break } }
$js = ($lin[($bi+1)..($ej-1)]) -join "`n"

$bP=0; $bL=0; $negAt=-1; $minBalP=0
for($k=0;$k -lt $js.Length;$k++){
  $ch=$js[$k]
  if($ch -eq '('){$bP++}
  elseif($ch -eq ')'){ $bP-- }
  if($ch -eq '{'){$bL++}
  elseif($ch -eq '}'){$bL--}
  if($bP -lt $minBalP){ $minBalP=$bP }
}
"JS total: paréntesis balance = $bP   llaves balance = $bL   mínimo nivel paréntesis = $minBalP"
if($bP -eq 0 -and $bL -eq 0){ "==> JS BALANCEADO CORRECTAMENTE (sin desequilibrios) ==" }
elseif($bP -ne 0){ "==> DESEQUILIBRIO: parens $bP / llaves $bL ==" }
else{ "==> DESEQUILIBRIO llaves: $bL ==" }

"enlazarCabecera definida: $($js.Contains('function enlazarCabecera'))  |  llamada en arranque: $($js.Contains('enlazarCabecera();'))"
"enlazarContacto definida: $($js.Contains('function enlazarContacto'))  |  llamada en arranque: $($js.Contains('enlazarContacto();'))"
"cantidad 'async': $(([regex]::Matches($js,'\basync\b')).Count)  |  cantidad 'await': $(([regex]::Matches($js,'\bawait\b')).Count)"
