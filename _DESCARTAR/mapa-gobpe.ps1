# mapa-gobpe.ps1 - resuelve https://www.gob.pe/institucion/<codigo>/noticias
# para cada entidad sin link oficial. Guarda mapa-entidades-gobpe.json
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirSal = Join-Path $raiz "salida"

# todas las entidades de estado (los cdt-seed no aplican)
$ents = New-Object 'System.Collections.Generic.List[string]'
Get-ChildItem $dirSal -Filter '*-entrada.html' | ForEach-Object {
    if ($_.Name -notmatch '^(oferta|oportunidad)-') { return }
    $h = [IO.File]::ReadAllText($_.FullName)
    $mt = [regex]::Match($h, '(?m)^\s*TITULO_BLOGGER = ([^:]+):')
    if ($mt.Success) {
        $e = $mt.Groups[1].Value.Trim()
        if ($e -and -not $ents.Contains($e)) { $ents.Add($e) }
    }
}
Write-Host ("entidades estado: " + $ents.Count)

# mapa existente (no repetir las ya resueltas)
$mapa = @{}
$mpPath = Join-Path $raiz 'mapa-entidades-gobpe.json'
if (Test-Path -LiteralPath $mpPath) {
    try {
        (Get-Content $mpPath -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
            $mapa[$_.Name] = $_.Value
        }
    } catch { }
}
Write-Host ("en mapa previo: " + $mapa.Count)

function Variantes([string]$e) {
    $v = New-Object 'System.Collections.Generic.List[string]'
    [void]$v.Add($e)
    $sin = ($e -replace '\([^)]*\)', '') -replace '\s+', ' '
    $sin = $sin.Trim()
    if ($sin -ne $e) { [void]$v.Add($sin) }
    $m = [regex]::Match($e, '\(([A-Za-z0-9]{2,10})\)')
    if ($m.Success) { [void]$v.Add($m.Groups[1].Value) }
    $tok = ($sin -split ' ')
    if ($tok.Count -ge 3) { [void]$v.Add((($tok[0..2]) -join ' ')) }
    if ($tok.Count -ge 2) { [void]$v.Add((($tok[0..1]) -join ' ')) }
    if ($tok[0].Length -le 8) { [void]$v.Add($tok[0]) }
    return $v
}
function Buscar-Codigo([string]$term) {
    $t = [uri]::EscapeDataString($term)
    $out = & curl.exe -s --max-time 12 ("https://www.gob.pe/searches_autocomplete.json?term=" + $t)
    if (-not $out) { return $null }
    $j = $out -join ''
    $m = [regex]::Match($j, '/institucion/([^/"]+)/')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

$ok = 0; $fail = @(); $ya = 0
foreach ($e in $ents) {
    if ($mapa.ContainsKey($e)) { $ya++; continue }
    $cod = $null
    foreach ($v in (Variantes $e)) {
        $cod = Buscar-Codigo $v
        if ($cod) { break }
    }
    if (-not $cod) { $fail += $e; continue }
    $url = "https://www.gob.pe/institucion/$cod/noticias"
    $st = & curl.exe -s -o NUL -w "%{http_code}" -L --max-time 12 $url
    if ($st -eq '200') { $mapa[$e] = $url; $ok++ }
    else { $fail += "$e (codigo $cod -> $st)" }
}
[IO.File]::WriteAllText($mpPath, ($mapa | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
Write-Host "== mapa gob.pe =="
Write-Host "  nuevas: $ok | ya tenia: $ya | total: " + $mapa.Count
Write-Host "  sin resolver: " + $fail.Count
$fail | ForEach-Object { Write-Host "    - $_" }
