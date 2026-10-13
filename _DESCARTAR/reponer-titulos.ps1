param([switch]$Ejecutar, [switch]$Force)
$ErrorActionPreference = "Stop"
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$blogId = "448950430489176641"
$logPath = "$raiz\reporte\reponer-titulos-2026-10-01.log"

function Esc([string]$s) {
    if ($null -eq $s) { return "" }
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $s.Length; $i++) {
        $c = [int][char]$s[$i]
        if ($c -lt 32) { [void]$sb.Append('\u' + $c.ToString('x4')) }
        elseif ($c -eq 34) { [void]$sb.Append('\"') }
        elseif ($c -eq 92) { [void]$sb.Append('\\') }
        elseif ($c -gt 126) { [void]$sb.Append('\u' + $c.ToString('x4')) }
        else { [void]$sb.Append($s[$i]) }
    }
    $sb.ToString()
}

Write-Host "=== REPONER TITULOS Y LABELS ==="
$snap = @{}
foreach ($l in [IO.File]::ReadAllLines("$raiz\reporte\snapshot-pre-import.txt")) {
    $p = $l -split "`t", 2
    if ($p.Count -eq 2 -and $p[0] -and $p[1]) { $snap[$p[0]] = $p[1] }
}
Write-Host ("1/4 snapshot: " + $snap.Count + " titulos")

$idx = 1; $tr = 0; $pgn = 0
$objetos = New-Object System.Collections.Generic.List[string]
do {
    $r = Invoke-RestMethod -Uri "https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=$idx" -Method Get
    if ($tr -eq 0) { $tr = [int]$r.feed.'openSearch$totalResults'.'$t' }
    $e = @($r.feed.entry)
    if ($e.Count -eq 0 -or $null -eq $e[0]) { break }
    foreach ($x in $e) {
        $m = [regex]::Match([string]$x.id.'$t', 'post-(\d+)$')
        if ($m.Success -and $snap.ContainsKey($m.Groups[1].Value)) { $objetos.Add($m.Groups[1].Value) }
    }
    $idx += $e.Count; $pgn++
} while ($idx -le $tr -and $pgn -lt 90)
Write-Host ("2/4 posts vivos del snapshot: " + $objetos.Count)

if (-not $Ejecutar) {
    Write-Host "SIMULACION: se repondra title+labels=Empleo donde title vacio (content se conserva)."
    exit 0
}

$tok = ([IO.File]::ReadAllText("$raiz\token-blogger.json") | ConvertFrom-Json).access_token
$h = @{ Authorization = "Bearer $tok" }
$log = New-Object System.Collections.Generic.List[string]
$restaurados = 0; $okYa = 0; $fallos = 0
$n = 0
foreach ($id in $objetos) {
    $n++
    $intento = 0; $done = $false
    while (-not $done -and $intento -lt 4) {
        $intento++
        try {
            $post = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $id) -Headers $h -Method Get
            if ($post.title -and $post.title.Length -gt 0) { $okYa++; $done = $true; $log.Add("OKYA`t$id`t$($post.title)"); break }
            $titulo = $snap[$id]
            if (-not $titulo) { $fallos++; $done = $true; $log.Add("SINSNAP`t$id"); break }
            $labs = '["Empleo"]'
            if ($post.labels -and @($post.labels).Count -gt 0) {
                $arr = @($post.labels | ForEach-Object { '"' + (Esc ([string]$_)) + '"' })
                $labs = '[' + ($arr -join ',') + ']'
            }
            $body = '{"title":"' + (Esc $titulo) + '","labels":' + $labs + ',"content":"' + (Esc ([string]$post.content)) + '"}'
            $resp = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $id) -Headers $h -Method Put -Body $body -ContentType "application/json"
            if ($resp.title -and $resp.title.Length -gt 0) { $restaurados++; $done = $true; $log.Add("PUT`t$id`t$titulo") }
            else { throw "respuesta sin titulo" }
        } catch {
            $code = 0
            if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
            if ($code -eq 401) {
                [IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
                Write-Host "TOKEN INVALIDO, guardo avance"; exit 1
            }
            if ($code -eq 429) { Start-Sleep -Seconds 45; continue }
            if ($intento -ge 4) { $log.Add("ERR$code`t$id`t" + $_.Exception.Message.Substring(0, [Math]::Min(100, $_.Exception.Message.Length))) }
            Start-Sleep -Seconds 2
        }
    }
    if (-not $done) { $fallos++; $log.Add("FAIL`t$id") }
    if ($n % 50 -eq 0) { Write-Host ("   ... " + $n + " / " + $objetos.Count) }
    Start-Sleep -Milliseconds 200
}
[IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
Write-Host ""
Write-Host ("LISTO. restaurados: " + $restaurados + " | ya tenian titulo: " + $okYa + " | fallos: " + $fallos)
