param([switch]$Ejecutar, [switch]$Force)
$ErrorActionPreference = "Stop"
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$blogId = "448950430489176641"
$logPath = "$raiz\reporte\limpieza-cdt707-2026-10-01.log"

$rxMeta = [regex]'(?s)<!--\s*ETIQUETA_BLOGGER\s*=\s*[^\r\n]*?\s+TITULO_BLOGGER\s*=\s*.*?\s*-->'
$rxEnlace = [regex]'(?is)<a\b[^>]*href\s*=\s*["'']https?://(?:www\.)?convocatoriasdetrabajo\.com[^"'']*["''][^>]*>(.*?)</a>'
$rxUrl = [regex]'(?i)https?://(?:www\.)?convocatoriasdetrabajo\.com[^\s<"'']*'

function Esc([string]$s) {
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

function DesengancharCdt([string]$html) {
    $a = $rxEnlace.Replace($html, '$1')
    $b = $rxUrl.Replace($a, '')
    return $b
}

Write-Host "=== FIX CDT EN POSTS VIEJOS (707) ==="
Write-Host "1/3 cargando titulos de salida..."
$map = @{}
foreach ($f in [IO.Directory]::GetFiles("$raiz\salida", "*-entrada.html")) {
    $t = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
    $m = $rxMeta.Match($t)
    if ($m.Success) {
        $ti = $m.Groups[0].Value
        $mm = [regex]::Match($t, 'TITULO_BLOGGER\s*=\s*(.*?)\s*-->')
        if ($mm.Success) {
            $tt = $mm.Groups[1].Value.Trim()
            if ($tt -and -not $map.ContainsKey($tt)) { $map[$tt] = $f }
        }
    }
}
Write-Host ("   titulos unicos: " + $map.Count)

Write-Host "2/3 identificando posts viejos conservados..."
$snap = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($l in [IO.File]::ReadAllLines("$raiz\reporte\snapshot-pre-import.txt")) {
    $id = ($l -split "`t", 2)[0]
    if ($id) { [void]$snap.Add($id) }
}
$viejos = New-Object System.Collections.Generic.List[object]
$idx = 1; $tr = 0; $pg = 0
do {
    $r = Invoke-RestMethod -Uri "https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=$idx" -Method Get
    if ($tr -eq 0) { $tr = [int]$r.feed.'openSearch$totalResults'.'$t' }
    $e = @($r.feed.entry)
    if ($e.Count -eq 0 -or $null -eq $e[0]) { break }
    foreach ($x in $e) {
        $m = [regex]::Match([string]$x.id.'$t', 'post-(\d+)$')
        if ($m.Success -and $snap.Contains($m.Groups[1].Value)) {
            $viejos.Add([pscustomobject]@{ Id = $m.Groups[1].Value; Titulo = ([string]$x.title.'$t') })
        }
    }
    $idx += $e.Count; $pg++
} while ($idx -le $tr -and $pg -lt 90)
Write-Host ("   posts viejos: " + $viejos.Count)

if (-not $Ejecutar) {
    $conArchivo = @($viejos | Where-Object { $map.ContainsKey($_.Titulo) }).Count
    Write-Host ("SIMULACION: con archivo limpio: " + $conArchivo + " | sin archivo (solo desenganchar): " + ($viejos.Count - $conArchivo))
    exit 0
}

$tok = ([IO.File]::ReadAllText("$raiz\token-blogger.json") | ConvertFrom-Json).access_token
$h = @{ Authorization = "Bearer $tok" }

if (-not $Force) {
    $r = Read-Host ("  Se actualizan " + $viejos.Count + " posts. Continuar? (s/N)")
    if ($r -notmatch '^[sS]') { Write-Host "Cancelado."; exit 0 }
}

$log = New-Object System.Collections.Generic.List[string]
$desdeArchivo = 0; $desenganchados = 0; $sinCambio = 0; $fallos = 0; $hechos = 0
foreach ($p in $viejos) {
    $ok = $false; $intento = 0
    while (-not $ok -and $intento -lt 4) {
        $intento++
        try {
            $post = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $p.Id) -Headers $h -Method Get
            $actual = [string]$post.content
            if ($actual -notmatch 'convocatoriasdetrabajo') { $sinCambio++; $ok = $true; $log.Add("SKIP`t$($p.Id)`t$($p.Titulo)"); break }
            $origen = ""
            if ($map.ContainsKey($p.Titulo)) {
                $ft = [IO.File]::ReadAllText($map[$p.Titulo], [Text.Encoding]::UTF8)
                $nuevoContenido = $rxMeta.Replace($ft, '')
                if ($nuevoContenido -match 'convocatoriasdetrabajo') { $nuevoContenido = DesengancharCdt $nuevoContenido }
                $origen = "archivo"
            } else {
                $nuevoContenido = DesengancharCdt $actual
                $origen = "desenganche"
            }
            $labs = '["Empleo"]'
            if ($post.labels -and @($post.labels).Count -gt 0) {
                $arr = @($post.labels | ForEach-Object { '"' + (Esc ([string]$_)) + '"' })
                $labs = '[' + ($arr -join ',') + ']'
            }
            $body = '{"title":"' + (Esc ([string]$post.title)) + '","labels":' + $labs + ',"content":"' + (Esc $nuevoContenido) + '"}'
            Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $p.Id) -Headers $h -Method Put -Body $body -ContentType "application/json" | Out-Null
            $ok = $true; $hechos++
            if ($origen -eq "archivo") { $desdeArchivo++ } else { $desenganchados++ }
            $log.Add("PUT`t$origen`t$($p.Id)`t$($p.Titulo)")
        } catch {
            $code = 0
            if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
            if ($code -eq 401) {
                [IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
                Write-Host "TOKEN INVALIDO: guardo avance y salgo."
                exit 1
            }
            if ($code -eq 404) { $ok = $true; $log.Add("404`t$($p.Id)`t$($p.Titulo)"); break }
            if ($code -eq 429) { Start-Sleep -Seconds (45 * $intento); continue }
            if ($intento -ge 4) { $log.Add("ERR$code`t$($p.Id)`t" + $_.Exception.Message.Substring(0, [Math]::Min(120, $_.Exception.Message.Length))) }
            Start-Sleep -Seconds (3 * $intento)
        }
    }
    if (-not $ok) { $fallos++; $log.Add("FAIL`t$($p.Id)`t$($p.Titulo)") }
    $hechosTot = $desdeArchivo + $desenganchados + $sinCambio + $fallos
    if ($hechosTot % 50 -eq 0) { Write-Host ("   ... " + $hechosTot + " / " + $viejos.Count) }
    Start-Sleep -Milliseconds 250
}

[IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
Write-Host ""
Write-Host ("LISTO. contenido desde archivo: " + $desdeArchivo + " | solo desenganche: " + $desenganchados + " | sin cdt ya: " + $sinCambio + " | fallos: " + $fallos)
