$ErrorActionPreference = 'Stop'
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$rxTitulo = [regex]'TITULO_BLOGGER\s*=\s*(.*?)\s*-->'

# --- mapa de salida: titulo exacto y normalizado -> archivo ---
$mapExacto = @{}
$mapNorm = @{}
function Norm([string]$s) {
    $s = $s -replace '\s+', ' '
    $s = $s.ToLower()
    $s = $s -replace [char]0x00E1,'a' -replace [char]0x00E9,'e' -replace [char]0x00ED,'i' -replace [char]0x00F3,'o' -replace [char]0x00FA,'u' -replace [char]0x00F1,'n' -replace [char]0x00FC,'u'
    return $s.Trim()
}
foreach ($f in [IO.Directory]::GetFiles("$raiz\salida", "*-entrada.html")) {
    $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
    $m = $rxTitulo.Match($t)
    if (-not $m.Success) { continue }
    $tt = $m.Groups[1].Value.Trim()
    if ($tt -and -not $mapExacto.ContainsKey($tt)) { $mapExacto[$tt] = $f }
    $n = Norm $tt
    if ($n -and -not $mapNorm.ContainsKey($n)) { $mapNorm[$n] = $f }
}
Write-Output ("salida: exacto=" + $mapExacto.Count + " norm=" + $mapNorm.Count)

function Buscar-Archivo([string]$titulo) {
    if ($mapExacto.ContainsKey($titulo)) { return $mapExacto[$titulo] }
    # variantes sin 'para' despues del primer ':'
    $v = $titulo -replace '^([^:]+:\s*)para\s+', '$1'
    if ($mapExacto.ContainsKey($v)) { return $mapExacto[$v] }
    $n = Norm $titulo
    if ($mapNorm.ContainsKey($n)) { return $mapNorm[$n] }
    $n2 = Norm $v
    if ($mapNorm.ContainsKey($n2)) { return $mapNorm[$n2] }
    return $null
}

# --- recorrer TODOS los posts (feed sin etiqueta) ---
$idx = 1; $pg = 0
$total = 0
$sinAcentos = @(); $paraTitulo = @(); $sinLabel = @(); $con10000 = @(); $otroSalarioRaro = @()
$sinArchivo = @(); $conCdt = @(); $reparables = 0
do {
    $r = Invoke-RestMethod -Uri "https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=$idx" -Method Get
    $e = @($r.feed.entry)
    if ($e.Count -eq 0 -or $null -eq $e[0]) { break }
    foreach ($x in $e) {
        $total++
        $tt = [string]$x.title.'$t'
        $c = [string]$x.content.'$t'
        $id = [regex]::Match([string]$x.id.'$t','post-(\d+)$').Groups[1].Value
        $labs = @()
        if ($x.category) { $labs = @($x.category | ForEach-Object { [string]$_.term }) }
        $tieneLabel = ($labs -contains 'Empleo')
        $sinAc = ($c -match 'Categor a:') -or ($c -match 'Ubicaci n:') -or ($c -match 'postulaci n') -or ($c -match 'Remuneraci n:')
        $esPara = ($tt -match '^[^:]+:\s*para\s')
        $cdt = ($c -match 'convocatoriasdetrabajo')
        $m10000 = [regex]::Match($c, 'Salario:</strong>\s*S/\s*10000\.?')
        $mOtro = [regex]::Match($c, 'Salario:</strong>\s*S/\s*([\d.,]+)')
        $arch = $null
        if ($sinAc -or $esPara -or $cdt -or $m10000.Success -or (-not $tieneLabel) -or $mOtro.Success) {
            $arch = Buscar-Archivo $tt
        }
        $necesita = $sinAc -or $esPara -or $cdt -or (-not $tieneLabel) -or $m10000.Success -or $mOtro.Success
        if ($necesita) {
            $reg = "$id`t$tt`t" + $(if($arch){"OK"}else{"SIN-ARCHIVO"})
            if ($sinAc) { $sinAcentos += $reg }
            if ($esPara) { $paraTitulo += $reg }
            if (-not $tieneLabel) { $sinLabel += $reg }
            if ($cdt) { $conCdt += $reg }
            if ($m10000.Success) { $con10000 += $reg }
            elseif ($mOtro.Success) {
                $val = $mOtro.Groups[1].Value
                $num = 0.0
                $limpio = $val -replace '[^\d.,]','' -replace '\.','' -replace ',','.'
                [double]::TryParse($limpio, [ref]$num) | Out-Null
                if ($num -gt 0 -and $num -lt 1500) { $otroSalarioRaro += ($reg + "`t" + $val) }
            }
            if ($arch) { $reparables++ } else { $sinArchivo += $reg }
        }
    }
    $idx += $e.Count; $pg++
} while ($pg -lt 25)

Write-Output ("TOTAL posts=" + $total)
Write-Output ("sinAcentos=" + $sinAcentos.Count + " paraTitulo=" + $paraTitulo.Count + " sinLabel=" + $sinLabel.Count + " cdt=" + $conCdt.Count)
Write-Output ("salario10000=" + $con10000.Count + " salarioRaro<1500=" + $otroSalarioRaro.Count)
Write-Output ("acciones con archivo=" + $reparables + " sin archivo=" + $sinArchivo.Count)
$out = "$raiz\reporte\diagnostico-general.txt"
$lines = @("=== DIAG " + (Get-Date -Format 'dd/MM/yyyy HH:mm') + " ===")
$lines += "TOTAL=$total sinAcentos=$($sinAcentos.Count) para=$($paraTitulo.Count) sinLabel=$($sinLabel.Count) cdt=$($conCdt.Count) sal10000=$($con10000.Count) salRaro=$($otroSalarioRaro.Count) sinArchivo=$($sinArchivo.Count)"
$lines += ""; $lines += "--- SIN LABEL ---"; $lines += $sinLabel
$lines += ""; $lines += "--- PARA TITULO ---"; $lines += $paraTitulo
$lines += ""; $lines += "--- SIN ARCHIVO (no reparables por archivo) ---"; $lines += ($sinArchivo | Select-Object -Unique)
$lines += ""; $lines += "--- SALARIO 10000 ---"; $lines += $con10000
$lines += ""; $lines += "--- SALARIO RARO <1500 ---"; $lines += $otroSalarioRaro
[IO.File]::WriteAllLines($out, $lines, (New-Object Text.UTF8Encoding($false)))
Write-Output ("guardado: " + $out)
