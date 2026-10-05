$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$salida = Join-Path $raiz "salida"
$reporte = Join-Path $raiz "reporte\qa-salida-2026-10-02.txt"

$archivos = @(Get-ChildItem (Join-Path $salida "*-entrada.html") -ErrorAction SilentlyContinue)
$total = $archivos.Count

$mojibake = @()
$sinTildes = @()
$salario10000 = @()
$postularSinLink = @()
$anexoSinLink = @()

foreach ($f in $archivos) {
    $c = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)

    if ($c -match '\uFFFD' -or $c -match 'Ã.' -or $c -match 'â€') {
        $mojibake += $f.Name
    }

    $texto = $c -replace '(?s)<style.*?</style>', ' ' -replace '(?s)<script.*?</script>', ' ' -replace '<[^>]+>', ' '
    if ($texto.Length -gt 400 -and -not ($texto -match '[\u00E1\u00E9\u00ED\u00F3\u00FA\u00F1\u00C1\u00C9\u00CD\u00D3\u00DA\u00D1]')) {
        $sinTildes += $f.Name
    }

    if ($c -match 'S/\s*10000(?!\d)' -or $c -match '10000\s+soles') {
        $salario10000 += $f.Name
    }

    if ($c -match 'POSTULAR' -and $c -notmatch '<a[^>]+href="[^"]+"[^>]*>[^<]*POSTULAR') {
        $postularSinLink += $f.Name
    }

    if ($c -match '(?i)anexo' -and $c -notmatch '<a[^>]+href="[^"]+"[^>]*>[^<]*(?i:anexo)') {
        $anexoSinLink += $f.Name
    }
}

$ln = @()
$ln += "QA salida - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$ln += "total archivos: $total"
$ln += "mojibake (Ã/â€/FFFD): $($mojibake.Count)"
$ln += "sin ninguna tilde: $($sinTildes.Count)"
$ln += "salario 10000: $($salario10000.Count)"
$ln += "POSTULAR sin link: $($postularSinLink.Count)"
$ln += "anexo sin link: $($anexoSinLink.Count)"
$ln += ""
foreach ($g in @(@("mojibake", $mojibake), @("sinTildes", $sinTildes), @("salario10000", $salario10000), @("postularSinLink", $postularSinLink), @("anexoSinLink", $anexoSinLink))) {
    $ln += "--- $($g[0]) (hasta 15) ---"
    $ln += @($g[1] | Select-Object -First 15)
    $ln += ""
}
[IO.File]::WriteAllLines($reporte, $ln, (New-Object Text.UTF8Encoding($false)))
Write-Output "total=$total mojibake=$($mojibake.Count) sinTildes=$($sinTildes.Count) salario10000=$($salario10000.Count) postularSinLink=$($postularSinLink.Count) anexoSinLink=$($anexoSinLink.Count)"
