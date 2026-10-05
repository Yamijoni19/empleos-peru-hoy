$ErrorActionPreference = "Stop"
$f = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$out = "C:\Users\Dell G3 Gaming\Documents\Default Project\probar-js-sinbom.js"
$lin = Get-Content -LiteralPath $f
$abre  = "//<![CDATA["
$cierra = "//]]>"
$bi = -1
for($i=0;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $abre){ $bi=$i } }
$ej = -1
for($i=$bi+1;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $cierra){ $ej=$i; break } }
if($bi -lt 0 -or $ej -lt 0){ throw "CDATA no encontrado" }
$js = ($lin[($bi+1)..($ej-1)] -join "`r`n")
$tmpAbs = (Resolve-Path -LiteralPath $out).Path
[string]::Join("", @()) > $null
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tmpAbs, $js, $enc)
$primeros = [System.IO.File]::ReadAllBytes($tmpAbs)[0..2]
"BOM bytes: $($primeros[0]) $($primeros[1]) $($primeros[2])"
$salida = cmd /c "cscript //nologo //E:jscript `"$tmpAbs`" 2>&1"
foreach($l in $salida){ Write-Output $l }
"EXIT: $LASTEXITCODE"
