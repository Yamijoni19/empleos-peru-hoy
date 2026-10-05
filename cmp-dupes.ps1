$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tok = Get-Content (Join-Path $raiz 'token-blogger.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$venc = [datetime]::Parse($tok.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) {
    $cred = Get-Content (Join-Path $raiz 'credentials.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $inst = $(if ($cred.installed) { $cred.installed } else { $cred.web })
    $n = Invoke-RestMethod -Uri 'https://oauth2.googleapis.com/token' -Method Post -Body @{ client_id=[string]$inst.client_id; client_secret=[string]$inst.client_secret; refresh_token=$tok.refresh_token; grant_type='refresh_token' }
    $tok.access_token = $n.access_token
    $tok.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$n.expires_in).ToString('o')
    [IO.File]::WriteAllText((Join-Path $raiz 'token-blogger.json'), ($tok | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
}
$h = @{ Authorization = "Bearer " + $tok.access_token }
$bid = (Invoke-RestMethod -Uri 'https://www.googleapis.com/blogger/v3/blogs/byurl?url=https%3A%2F%2Fempleosperuhoy.blogspot.com&fields=id' -Headers $h).id
$posts = @()
$u = "https://www.googleapis.com/blogger/v3/blogs/$bid/posts?status=live&maxResults=500&fields=items(id,title,published),nextPageToken"
while ($u) {
    $r = Invoke-RestMethod -Uri $u -Headers $h
    $posts += $r.items
    $u = $(if ($r.nextPageToken) { $u + "&pageToken=" + $r.nextPageToken } else { $null })
}
Write-Host ("total posts: " + $posts.Count)
$grupos = @($posts | Group-Object title | Where-Object { $_.Count -gt 1 })
Write-Host ("grupos duplicados por titulo: " + $grupos.Count)
$g = $grupos | Sort-Object Count -Descending | Select-Object -First 1
Write-Host ("grupo prueba: [" + $g.Count + "] " + $g.Name)
$hashes = @{}
foreach ($p in $g.Group) {
    $d = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/$bid/posts/" + $p.id + "?fields=id,published,content") -Headers $h
    $md5 = [Security.Cryptography.MD5]::Create()
    $hh = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($d.content))).Replace('-','')
    if (-not $hashes.ContainsKey($hh)) { $hashes[$hh] = @() }
    $hashes[$hh] += $p.id
    Write-Host ("  id=" + $p.id + " pub=" + $d.published + " hash=" + $hh.Substring(0,12) + " len=" + $d.content.Length)
}
Write-Host "--- comparacion con fuentes ---"
$src = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($l in [IO.File]::ReadAllLines((Join-Path $raiz 'publicaciones.txt'))) {
    if ($l -match 'importado') { $p = $l.Split('|'); if ($p.Length -ge 2) { [void]$src.Add($p[1].Trim()) } }
}
$blog = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($p in $posts) { [void]$blog.Add($p.title) }
$faltan = @($src | Where-Object { -not $blog.Contains($_) })
$sobra = @($blog | Where-Object { -not $src.Contains($_) })
Write-Host ("fuente titulos: " + $src.Count + " | blog titulos: " + $blog.Count)
Write-Host ("en fuente pero NO en blog: " + $faltan.Count)
$faltan | Select-Object -First 5 | ForEach-Object { Write-Host ("   FALTA: " + $_) }
Write-Host ("en blog pero NO en fuente marcada: " + $sobra.Count)
$sobra | Select-Object -First 8 | ForEach-Object { Write-Host ("   EXTRA: " + $_) }

Write-Host "--- busqueda parcial de faltantes ---"
foreach ($ft in @($faltan | Select-Object -First 6)) {
    $tail = $ft
    if ($ft -match ':\s*(.+)$') { $tail = $Matches[1] }
    $tail = $tail -replace '^\(?\d+\)?\s*', ''
    if ($tail.Length -gt 30) { $tail = $tail.Substring(0,30) }
    $cand = @($blog | Where-Object { $_ -like ("*" + $tail + "*") })
    Write-Host ("FALTA: " + $ft.Substring(0, [Math]::Min(60, $ft.Length)))
    if ($cand.Count -eq 0) { Write-Host "    -> NINGUNA coincidencia parcial en el blog" }
    else { $cand | Select-Object -First 2 | ForEach-Object { Write-Host ("    -> blog tiene: " + $_.Substring(0, [Math]::Min(70, $_.Length))) } }
}
Write-Host "--- estados no-live ---"
foreach ($st in @('scheduled','draft','soft_trashed')) {
    try {
        $r2 = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/$bid/posts?status=" + $st + "&maxResults=500&fields=items(id,title,published,status),nextPageToken") -Headers $h
        $cnt = @($r2.items).Count
        Write-Host ("status " + $st + ": " + $cnt)
        if ($cnt -gt 0) { @($r2.items) | Select-Object -First 4 | ForEach-Object { Write-Host ("    " + $_.title.Substring(0,[Math]::Min(70,$_.title.Length)) + " [" + $_.status + "] " + $_.published) } }
    } catch { Write-Host ("status " + $st + ": ERROR " + $_.Exception.Message.Substring(0,120)) }
}
Write-Host "--- escaneo blog vivo ---"
$all = @()
$u2 = "https://www.googleapis.com/blogger/v3/blogs/$bid/posts?status=live&maxResults=500&fields=items(id,title,content),nextPageToken"
while ($u2) {
    $r3 = Invoke-RestMethod -Uri $u2 -Headers $h
    $all += $r3.items
    $u2 = $(if ($r3.nextPageToken) { $u2 + "&pageToken=" + $r3.nextPageToken } else { $null })
}
Write-Host ("posts escaneados: " + $all.Count)
$conv = @($all | Where-Object { $_.content -match '(?i)convocatorias\.com' })
Write-Host ("con convocatorias.com en el contenido: " + $conv.Count)
$conv | Select-Object -First 5 | ForEach-Object { Write-Host ("   " + $_.id + " | " + $_.title.Substring(0,[Math]::Min(60,$_.title.Length))) }
$par = @($all | Where-Object { $_.title -match '(?i)^\s*para\s+' -or $_.title -match '(?i):\s*para\s+\p{Lu}' })
Write-Host ("titulos con 'para' sospechoso: " + $par.Count)
$par | Select-Object -First 10 | ForEach-Object { Write-Host ("   " + $_.title) }
$parIds = $par | ForEach-Object { $_.id }
if ($parIds.Count -gt 0) { $parIds -join ',' | Out-File (Join-Path $raiz 'reporte\titulos-para-ids.txt') -Encoding UTF8 }