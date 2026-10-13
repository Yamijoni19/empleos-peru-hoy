# reparar-mapa.ps1 - normaliza mapa-entidades-gobpe.json:
#   claves exactamente = entidades TITULO_BLOGGER de salida\ (fuente de verdad)
#   repara mojibake (doble/triple codificacion) y deduplica por forma normalizada
$ErrorActionPreference = "Stop"
$raiz  = Split-Path -Parent $MyInvocation.MyCommand.Path
$mpPath = Join-Path $raiz 'mapa-entidades-gobpe.json'
$dirSal = Join-Path $raiz 'salida'

function Nor([string]$s) {
    if (-not $s) { return '' }
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            if ([char]::IsLetterOrDigit($ch)) { [void]$sb.Append([char]::ToLowerInvariant($ch)) } else { [void]$sb.Append(' ') }
        }
    }
    return (($sb.ToString() -replace '\s+', ' ').Trim())
}
function Reparar([string]$s) {
    $cur = $s
    for ($i = 0; $i -lt 3; $i++) {
        if ($cur -notmatch '[\u00C2\u00C3\u00E2\uFFFD]') { break }
        try {
            $lat = [Text.Encoding]::GetEncoding(28591)
            $nx  = [Text.Encoding]::UTF8.GetString($lat.GetBytes($cur))
            if ($nx -eq $cur) { break }
            $cur = $nx
        } catch { break }
    }
    return $cur
}

# entidades reales de los archivos
$ents = New-Object 'System.Collections.Generic.List[string]'
Get-ChildItem $dirSal -Filter '*-entrada.html' | ForEach-Object {
    $raw = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    $mt = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
    if ($mt.Success) {
        $t = $mt.Groups[1].Value.Trim()
        $e = [regex]::Match($t, '^([^:]+):').Groups[1].Value.Trim()
        if ($e -and -not $ents.Contains($e)) { $ents.Add($e) }
    }
}
Write-Host ("entidades en archivos: " + $ents.Count)

$old = @{}
(Get-Content $mpPath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $old[$_.Name] = $_.Value }

# indice de claves viejas reparadas -> url
$idxRep = @{}
$reparadas = 0
foreach ($k in @($old.Keys)) {
    $r = Reparar $k
    if ($r -ne $k) { $reparadas++ }
    if (-not $idxRep.ContainsKey($r)) { $idxRep[$r] = $old[$k] }
}
Write-Host ("claves originales: " + $old.Count + " | mojibake reparadas: " + $reparadas)

# por Nor: clave vieja (reparada o original) -> url
$porNor = @{}
foreach ($k in @($old.Keys)) {
    $r = Reparar $k
    foreach ($c in @($k, $r)) {
        $n = Nor $c
        if ($n -and -not $porNor.ContainsKey($n)) { $porNor[$n] = $old[$k] }
    }
}

$nuevo = @{}
$sinUrl = 0
foreach ($e in ($ents | Sort-Object)) {
    $n = Nor $e
    if ($porNor.ContainsKey($n)) { $nuevo[$e] = $porNor[$n] }
    else { $sinUrl++ }
}
Write-Host ("mapa resultante: " + $nuevo.Count + " | sin url: " + $sinUrl)
if ($sinUrl -gt 0) {
    $ents | Where-Object { -not $nuevo.ContainsKey($_) } | ForEach-Object { Write-Host ("  sin url: " + $_) }
}
[IO.File]::WriteAllText($mpPath, ($nuevo | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
Write-Host "mapa reparado y guardado"
