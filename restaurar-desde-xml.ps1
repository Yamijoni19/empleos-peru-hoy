# restaurar-desde-xml.ps1 - restaura salida\*.html desde xml\rebuild.xml
# (contenido previo a fix-cdt, con meta ETIQUETA/TITULO reconstruido)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirSal = Join-Path $raiz "salida"
$x = New-Object xml
$x.Load((Join-Path $raiz "xml\rebuild.xml"))
$n = 0; $faltaMeta = 0
foreach ($e in $x.SelectNodes("//*[local-name()='entry']")) {
    $fnN = $e.SelectSingleNode("*[local-name()='filename']")
    if (-not $fnN -or -not $fnN.InnerText) { continue }
    $slug = [IO.Path]::GetFileNameWithoutExtension($fnN.InnerText)
    $dest = Join-Path $dirSal ($slug + "-entrada.html")
    if (-not (Test-Path -LiteralPath $dest)) { continue }
    $cN = $e.SelectSingleNode("*[local-name()='content']")
    if (-not $cN) { continue }
    $body = [Net.WebUtility]::HtmlDecode($cN.InnerText)
    # meta reconstruida si el contenido viene sin ella
    if ($body -notmatch 'ETIQUETA_BLOGGER') {
        $tit = $e.SelectSingleNode("*[local-name()='title']").InnerText
        $etq = 'Empleo'
        $cats = $e.SelectNodes("*[local-name()='category']")
        if ($cats.Count -gt 0) { $etq = $cats[0].GetAttribute('term') }
        $body = "<!-- ETIQUETA_BLOGGER = $etq`n     TITULO_BLOGGER = " + $tit + " -->`n`n" + $body
        $faltaMeta++
    }
    [IO.File]::WriteAllText($dest, $body, (New-Object Text.UTF8Encoding($false)))
    $n++
}
Write-Host "== restaurados desde rebuild.xml: $n archivos (meta reconstruida: $faltaMeta)"
