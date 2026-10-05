param([switch]$Ejecutar, [switch]$Force)
$ErrorActionPreference = "Stop"
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$blogId = "448950430489176641"
$tok = ([IO.File]::ReadAllText("$raiz\token-blogger.json") | ConvertFrom-Json).access_token
$h = @{ Authorization = "Bearer $tok" }
$logPath = "$raiz\reporte\limpieza-duplicados-2026-10-01.log"

function Traer-Posts {
    $rows = New-Object System.Collections.Generic.List[string]
    $idx = 1; $tr = 0; $pages = 0
    do {
        $u = "https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=$idx"
        $r = Invoke-RestMethod -Uri $u -Method Get
        if ($tr -eq 0) { $tr = [int]$r.feed.'openSearch$totalResults'.'$t' }
        $e = @($r.feed.entry)
        if ($e.Count -eq 0) { break }
        foreach ($x in $e) {
            $m = [regex]::Match([string]$x.id.'$t', 'post-(\d+)$')
            $tid = if ($m.Success) { $m.Groups[1].Value } else { "" }
            $tt = ([string]$x.title.'$t') -replace "`r|`n", ' '
            $rows.Add($tid + "`t" + $tt)
        }
        $idx += $e.Count; $pages++
    } while ($idx -le $tr -and $pages -lt 90)
    return $rows
}

function Traer-Paginas {
    $rows = New-Object System.Collections.Generic.List[object]
    $idx = 1; $tr = 0; $pg = 0
    do {
        $u = "https://empleosperuhoy.blogspot.com/feeds/pages/default?alt=json&max-results=100&start-index=$idx"
        $r = Invoke-RestMethod -Uri $u -Method Get
        if ($tr -eq 0) { $tr = [int]$r.feed.'openSearch$totalResults'.'$t' }
        $e = @($r.feed.entry)
        if ($e.Count -eq 0 -or $null -eq $e[0]) { break }
        foreach ($x in $e) {
            $m = [regex]::Match([string]$x.id.'$t', 'page-(\d+)')
            $pgid = if ($m.Success) { $m.Groups[1].Value } else { "" }
            if (-not $pgid) { continue }
            $pt = ([string]$x.title.'$t') -replace "`r|`n", ' '
            $rows.Add([pscustomobject]@{ Id = $pgid; Titulo = $pt })
        }
        $idx += $e.Count; $pg++
    } while ($idx -le $tr -and $pg -lt 40)
    $unicos = @($rows | Group-Object Id | ForEach-Object { $_.Group[0] })
    return ,$unicos
}

Write-Host "=== LIMPIEZA DE DUPLICADOS ==="
Write-Host "1/4 trayendo inventario de posts (feed)..."
$inv = Traer-Posts
Write-Host ("   posts: " + $inv.Count)

$snapIds = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($l in [IO.File]::ReadAllLines("$raiz\reporte\snapshot-pre-import.txt")) {
    $id = ($l -split "`t", 2)[0]
    if ($id) { [void]$snapIds.Add($id) }
}
Write-Host ("   snapshot viejos: " + $snapIds.Count)

$porTitulo = [ordered]@{}
foreach ($l in $inv) {
    $p = $l -split "`t", 2
    if ($p.Count -lt 2) { continue }
    $id = $p[0]; $t = $p[1]
    if (-not $porTitulo.Contains($t)) { $porTitulo[$t] = New-Object System.Collections.Generic.List[string] }
    [void]$porTitulo[$t].Add($id)
}

$borrarPosts = New-Object System.Collections.Generic.List[object]
$keeps = New-Object System.Collections.Generic.List[string]
foreach ($t in $porTitulo.Keys) {
    $cands = @($porTitulo[$t])
    $nuevos = @($cands | Where-Object { -not $snapIds.Contains($_) })
    $keep = if ($nuevos.Count -gt 0) { $nuevos[0] } else { $cands[0] }
    $keeps.Add($keep)
    foreach ($c in $cands) { if ($c -ne $keep) { $borrarPosts.Add([psobject]@{ Id = $c; Titulo = $t; Keep = $keep }) } }
}
Write-Host ("   titulos: " + $porTitulo.Count + " | conservar: " + $keeps.Count + " | borrar posts: " + $borrarPosts.Count)

Write-Host "2/4 trayendo paginas..."
$snapPag = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($l in [IO.File]::ReadAllLines("$raiz\reporte\snapshot-pre-import-pages.txt")) {
    $id = ($l -split "`t", 2)[0]
    if ($id) { [void]$snapPag.Add($id) }
}
$pags = Traer-Paginas
$porTitPag = [ordered]@{}
foreach ($p in $pags) {
    $pgid = [string]$p.Id; $pt = [string]$p.Titulo
    if (-not $porTitPag.Contains($pt)) { $porTitPag[$pt] = New-Object System.Collections.Generic.List[string] }
    [void]$porTitPag[$pt].Add($pgid)
}
$borrarPags = New-Object System.Collections.Generic.List[object]
foreach ($t in $porTitPag.Keys) {
    $cands = @($porTitPag[$t])
    if ($cands.Count -lt 2) { continue }
    $nuevos = @($cands | Where-Object { -not $snapPag.Contains($_) })
    $keep = if ($nuevos.Count -gt 0) { $nuevos[0] } else { $cands[0] }
    foreach ($c in $cands) { if ($c -ne $keep) { $borrarPags.Add([psobject]@{ Id = $c; Titulo = $t; Keep = $keep }) } }
}
Write-Host ("   paginas vivas: " + $pags.Count + " | borrar paginas: " + $borrarPags.Count)

$totalBorrar = $borrarPosts.Count + $borrarPags.Count
Write-Host ""
Write-Host ("TOTAL A ELIMINAR: " + $totalBorrar + "  (posts " + $borrarPosts.Count + ", paginas " + $borrarPags.Count + ")")
Write-Host ("DESPUES QUEDARAN: " + $keeps.Count + " posts (1 por titulo)")

if (-not $Ejecutar) {
    Write-Host ""
    Write-Host "SIMULACION. Usa -Ejecutar para borrar de verdad."
    $borrarPosts | Select-Object -First 8 | ForEach-Object { Write-Host ("  borraria [" + $_.Id + "] " + $_.Titulo.Substring(0, [Math]::Min(55, $_.Titulo.Length))) }
    exit 0
}

if ($totalBorrar -gt 4500) { Write-Host "ERROR: mas de 4500 borrados, aborto por seguridad"; exit 1 }
if (-not $Force) {
    $r = Read-Host ("  Se eliminaran " + $totalBorrar + " entradas del blog. Continuar? (s/N)")
    if ($r -notmatch '^[sS]') { Write-Host "Cancelado."; exit 0 }
}

$log = New-Object System.Collections.Generic.List[string]
$hechos = 0; $err404 = 0; $fallos = 0
$todos = @($borrarPosts | ForEach-Object { [psobject]@{ Kind = "post"; Id = $_.Id; Titulo = $_.Titulo; Keep = $_.Keep } }) +
         @($borrarPags  | ForEach-Object { [psobject]@{ Kind = "page"; Id = $_.Id; Titulo = $_.Titulo; Keep = $_.Keep } })

foreach ($d in $todos) {
    $ok = $false; $intento = 0
    while (-not $ok -and $intento -lt 5) {
        $intento++
        try {
            $u = "https://www.googleapis.com/blogger/v3/blogs/$blogId/$($d.Kind)s/$($d.Id)"
            Invoke-RestMethod -Uri $u -Headers $h -Method Delete | Out-Null
            $ok = $true; $hechos++
            $log.Add("DEL`t$($d.Kind)`t$($d.Id)`tkeep=$($d.Keep)`t$($d.Titulo)")
        } catch {
            $code = 0
            if ($_.Exception.Response) { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
            if ($code -eq 404) { $ok = $true; $err404++; $log.Add("404`t$($d.Kind)`t$($d.Id)`t$($d.Titulo)"); break }
            if ($code -eq 429) { Start-Sleep -Seconds (60 * $intento); continue }
            if ($code -eq 401) {
                [IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
                Write-Host "TOKEN INVALIDO: guardo avance y salgo. Relanza con token nuevo."
                exit 1
            }
            Start-Sleep -Seconds (3 * $intento)
        }
    }
    if (-not $ok) { $fallos++; $log.Add("FAIL`t$($d.Kind)`t$($d.Id)`t$($d.Titulo)") }
    if ($hechos % 100 -eq 0 -and $hechos -gt 0) { Write-Host ("   ... " + $hechos + " / " + $totalBorrar) }
    Start-Sleep -Milliseconds 200
}

[IO.File]::AppendAllLines($logPath, $log, (New-Object Text.UTF8Encoding($false)))
Write-Host ""
Write-Host ("LISTO. borrados: " + $hechos + " | 404 ya-iban: " + $err404 + " | fallos: " + $fallos)
