$ErrorActionPreference = "Stop"
$f = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$out = "C:\Users\Dell G3 Gaming\Documents\Default Project\comprobar-js-final.js"
$lin = Get-Content -LiteralPath $f
$abre = "//<![CDATA["
$cierra = "//]]>"
$bi = -1
for($i=0;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $abre){ $bi=$i } }
if($bi -lt 0){ throw "no hay CDATA" }
$ej = -1
for($i=$bi+1;$i -lt $lin.Count;$i++){ if($lin[$i].TrimEnd() -eq $cierra){ $ej=$i; break } }
if($ej -lt 0){ throw "no hay cierre CDATA despues de $($bi+1)" }
"CDATA inicio: linea archivo $($bi+1)  -> cierre: linea $($ej+1)"
$js = ($lin[($bi+1)..($ej-1)] -join "`r`n")
$bytes = [System.Text.Encoding]::UTF8.GetBytes($js)
[System.IO.File]::WriteAllBytes($out, $bytes)
$prev = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$res = cmd /c "cscript //nologo //E:jscript `"$out`" 2>&1"
[Console]::OutputEncoding = $prev
$found = $false
foreach($linea in $res){
  if($linea -match '\.js\((\d+),\s*(\d+)\)'){
    $linNum = [int]$matches[1]
    $colNum = [int]$matches[2]
    $archivo = $bi + 1 + $linNum + 1 - 1
    $archivo = $bi + $linNum + 1
    "ERROR en JS linea $linNum col $colNum => archivo linea $archivo"
    for($k=[Math]::Max(1,$archivo-3);$k -le [Math]::Min($lin.Count,$archivo+3);$k++){ "{0}: {1}" -f $k, $lin[$k-1] }
    $found = $true
    break
  }
}
if(-not $found){
  "COMPILACION OK (sin errores de sintaxis)"
}
