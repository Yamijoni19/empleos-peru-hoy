# inspeccionar-duplicados.ps1 - SOLO LECTURA: lista posts/paginas actuales,
# agrupa por titulo y marca cuales tienen id sintetico (910...) o id original
param([switch]$Detalle)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tokenPath = Join-Path $raiz "token-blogger.json"
$credPath  = Join-Path $raiz "credentials.json"
$BlogUrl = "https://empleosperuhoy.blogspot.com"
$cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inst = $(if ($cred.installed) { $cred.installed } else { $cred.web })
$tok = Get-Content $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json
$venc = [datetime]::Parse($tok.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) {
    $t = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id = [string]$inst.client_id; client_secret = [string]$inst.client_secret
        refresh_token = $tok.refresh_token; grant_type = "refresh_token"
    }
    $tok.access_token = $t.access_token
    $tok.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$t.expires_in).ToString('o')
    [IO.File]::WriteAllText($tokenPath, ($tok | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
}
$h = @{ Authorization = "Bearer " + $tok.access_token }
$blog = Invoke-RestMethod -Uri ("https://www.googleapis.com/blogger/v3/blogs/byurl?url=" + [uri]::EscapeDataString($BlogUrl) + "&fields=id") -Headers $h
$id = [string]$blog.id

function Traer-Items($url) {
    $res = @(); $u = $url
    while ($u) {
        $r = Invoke-RestMethod -Uri $u -Headers $h
        $res += $r.items
        $u = $null
        if ($r.nextPageToken) { $u = $url + "&pageToken=" + $r.nextPageToken }
    }
    return $res
}
$posts = Traer-Items ("https://www.googleapis.com/blogger/v3/blogs/" + $id + "/posts?status=live&maxResults=500&fields=items(id,title,published,status),nextPageToken")
$pages = Traer-Items ("https://www.googleapis.com/blogger/v3/blogs/" + $id + "/pages?status=live&maxResults=500&fields=items(id,title,published,status),nextPageToken")
Write-Host ("POSTS publicados: " + $posts.Count + " | PAGINAS publicadas: " + $pages.Count)

$grupos = $posts | Group-Object -Property title | Where-Object { $_.Count -gt 1 }
Write-Host ("Titulos con mas de 1 post: " + @($grupos).Count + " (posts implicados: " + (@($grupos) | Measure-Object -Property Count -Sum).Sum + ")")
$ejemplo = @($grupos) | Select-Object -First 3
foreach ($g in $ejemplo) {
    Write-Host ("  [" + $g.Count + "] " + $g.Name)
    foreach ($p in $g.Group) {
        $tipo = $(if ($p.id -like '910*') { 'SINTETICO' } else { 'original?' })
        Write-Host ("     id=" + $p.id + " (" + $tipo + ") pub=" + $p.published)
    }
}
if ($Detalle) {
    $orig = New-Object 'System.Collections.Generic.HashSet[string]'
    $bakFeed = "C:\Users\Dell G3 Gaming\AppData\Local\Temp\opencode\blogger-bak\Takeout\Blogger\Blogs\Empleos Perú Hoy\feed.atom"
    $ft = [IO.File]::ReadAllText($bakFeed, [Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($ft, '<id>([^<]+)</id>')) { [void]$orig.Add($m.Groups[1].Value) }
    $sint = 0; $noorig = 0; $aBorrar = @()
    foreach ($g in @($grupos)) {
        foreach ($p in $g.Group) {
            $full = "tag:blogger.com,1999:blog-448950430489176641.post-" + $p.id
            if (-not $orig.Contains($full)) { $aBorrar += $p; $noorig++ }
            if ($p.id -like '910*') { $sint++ }
        }
    }
    Write-Host ""
    Write-Host ("En duplicados: con id sintetico=" + $sint + " | id no-listado-en-backup-original=" + $noorig)
    $pagGrupos = $pages | Group-Object -Property title | Where-Object { $_.Count -gt 1 }
    Write-Host ("Paginas duplicadas: " + @($pagGrupos).Count)
    foreach ($g in @($pagGrupos)) { Write-Host ("  [" + $g.Count + "] " + $g.Name) }
}
