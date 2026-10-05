$ErrorActionPreference = "Stop"
$ruta = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"

$t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)

$antes = $t
$curados = 0

if($t.IndexOf("86400000ork") -ge 0){
  $t = $t.Replace("86400000ork", "86400000")
  $curados++
}
if($t.IndexOf("fichaapse") -ge 0){
  $t = $t.Replace("fichaapse", "ficha")
  $curados++
}

if($curados -gt 0){
  [System.IO.File]::WriteAllText($ruta, $t, (New-Object System.Text.UTF8Encoding($false)))
}

$js = $t
$bi = $js.IndexOf("//<![CDATA[")
$ei = $js.LastIndexOf("//]]>")
if($bi -ge 0 -and $ei -gt $bi){
  $js = $js.Substring($bi, $ei - $bi)
}

$np = 0; $minp = 0; $p = 0
for($i=0; $i -lt $js.Length; $i++){
  $c = $js[$i]
  if($c -eq "("){ $p++; }
  elseif($c -eq ")"){ $p--; if($p -lt $minp){ $minp = $p } }
}
$np = $p
$nl = 0; $l = 0
for($i=0; $i -lt $js.Length; $i++){
  $c = $js[$i]
  if($c -eq "{"){ $l++ }
  elseif($c -eq "}"){ $l-- }
}
$nl = $l

"Reparaciones aplicadas: $curados"
"par[...] $np  llaves $nl  minParen $minp"
if($np -eq 0 -and $nl -eq 0){
  "==> BALANCE OK"
}else{
  "==> PENDIENTE: parens=$np llaves=$nl"
}
"queda 'ork)': " + ([regex]::Matches($js, "ork\)").Count)
"queda 'apse)': " + ([regex]::Matches($js, "apse\)").Count)
