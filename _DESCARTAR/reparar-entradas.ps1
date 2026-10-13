# reparar-entradas.ps1 - repara las entradas VIVAS del blog usando como
# fuente los archivos canonicos de salida\ (acentos, salario, enlaces de
# anexos, boton Postular, titulos). Solo toca las que difieren de verdad.
#
# USO:
#   .\reparar-entradas.ps1 -Simular            # cuenta que haria (no escribe)
#   .\reparar-entradas.ps1                     # repara todo lo que difiere
#   .\reparar-entradas.ps1 -Limite 50          # reparacion gradual
param(
    [switch]$Simular,
    [int]$Limite = 0,
    [int]$PausaMs = 2000
)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirSalida = Join-Path $raiz "salida"
$credPath = Join-Path $raiz "credentials.json"
$tokenPath = Join-Path $raiz "token-blogger.json"
$logPath = Join-Path $raiz "reporte\reparar-entradas.log"
$sinArchivoPath = Join-Path $raiz "reporte\sin-archivo.txt"
$blogId = "448950430489176641"

function Apuntar([string]$m) {
    $l = "[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + $m
    Add-Content -Path $logPath -Value $l -Encoding UTF8
    Write-Host $l
}

# --------------------------------------------------------------- token
if (-not (Test-Path $tokenPath)) { Write-Host "ERROR: falta token-blogger.json"; exit 1 }
$script:token = Get-Content $tokenPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $script:token.refresh_token) { Write-Host "ERROR: el token no tiene refresh_token"; exit 1 }

$cred = Get-Content $credPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inst = $cred
if ($cred.installed) { $inst = $cred.installed } elseif ($cred.web) { $inst = $cred.web }
$clientId = [string]$inst.client_id
$clientSec = [string]$inst.client_secret

function Refrescar([string]$refresh) {
    return Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id = $clientId; client_secret = $clientSec
        refresh_token = $refresh; grant_type = "refresh_token"
    }
}
$venc = [datetime]::Parse($script:token.expires_at, $null, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
if ($venc -lt (Get-Date).ToUniversalTime().AddMinutes(2)) {
    $t = Refrescar $script:token.refresh_token
    $script:token.access_token = $t.access_token
    $script:token.expires_at = (Get-Date).ToUniversalTime().AddSeconds([int]$t.expires_in).ToString('o')
    [IO.File]::WriteAllText($tokenPath, ($script:token | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    Apuntar "token refrescado"
}

function Api([string]$Metodo, [string]$Uri, $Cuerpo, [int]$Reintentos = 8) {
    $intento = 0
    while ($true) {
        $intento++
        try {
            $p = @{ Method = $Metodo; Uri = $Uri; Headers = @{ Authorization = "Bearer " + $script:token.access_token }; ContentType = "application/json; charset=utf-8" }
            if ($null -ne $Cuerpo) { $p.Body = [Text.Encoding]::UTF8.GetBytes(($Cuerpo | ConvertTo-Json -Depth 6)) }
            return Invoke-RestMethod @p
        } catch {
            $cod = 0
            if ($_.Exception.Response) { $cod = [int]$_.Exception.Response.StatusCode }
            if ($cod -eq 401 -and $intento -eq 1) {
                $t = Refrescar $script:token.refresh_token
                $script:token.access_token = $t.access_token
                continue
            }
            if ($cod -eq 429 -and $intento -le $Reintentos) {
                $z = [Math]::Min(90, 15 * $intento)
                Apuntar ("  429 (" + $intento + "/" + $Reintentos + "), espero " + $z + "s")
                Start-Sleep -Seconds $z
                continue
            }
            if ($cod -eq 403 -and $intento -le $Reintentos) {
                Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $intento)))
                continue
            }
            throw
        }
    }
}

# --------------------------------------------------------------- utilidades
$rxMeta = [regex]'(?s)<!--\s*ETIQUETA_BLOGGER\s*=\s*(?<et>[^\r\n]*?)\s+TITULO_BLOGGER\s*=\s*(?<ti>.*?)\s*-->'
$rxH1 = [regex]'(?is)<h1[^>]*>(.*?)</h1>'

function Dec([string]$s) { return [Net.WebUtility]::HtmlDecode($s) }

function Norm([string]$s) {
    if ($null -eq $s) { return "" }
    $s = Dec $s
    $s = $s -replace '\s+', ' '
    $s = $s.Trim().ToLowerInvariant()
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return ($sb.ToString().Normalize([Text.NormalizationForm]::FormC))
}

# contenido comparable: sin el comentario meta y con espacios colapsados
function Cont([string]$html) {
    if ($null -eq $html) { return "" }
    $s = $rxMeta.Replace($html, ' ')
    $s = $s -replace '\s+', ' '
    return $s.Trim()
}

function Prefijo([string]$a, [string]$b) {
    $i = 0
    $min = [Math]::Min($a.Length, $b.Length)
    while ($i -lt $min -and $a[$i] -ceq $b[$i]) { $i++ }
    return $i
}

function ExtraerDe([string]$html) {
    $et = ""
    $ti = ""
    $m = $rxMeta.Match($html)
    if ($m.Success) {
        $et = $m.Groups['et'].Value.Trim()
        $ti = Dec $m.Groups['ti'].Value.Trim()
    }
    if ($ti -eq "") {
        $mh = $rxH1.Match($html)
        if ($mh.Success) { $ti = (Dec ($mh.Groups[1].Value -replace '<[^>]+>', '')).Trim() }
    }
    return @{ et = $et; ti = $ti }
}

# --------------------------------------------------------------- mapas de salida\
Apuntar "indexando archivos de salida\ ..."
$mapUrl = @{}
$mapTit = @{}
$dupTit = @{}
$pubPath = Join-Path $raiz "publicaciones.txt"
foreach ($l in [IO.File]::ReadAllLines($pubPath)) {
    $ps = $l -split ' \| '
    if ($ps.Count -ge 4) {
        $u = $ps[$ps.Count - 2].Trim()
        $f = $ps[$ps.Count - 1].Trim()
        if ($u -match '^https?://' -and $f -like '*.html' -and -not $mapUrl.ContainsKey($u)) {
            $mapUrl[$u] = $f
        }
    }
}
$archivos = @(Get-ChildItem $dirSalida -Filter '*-entrada.html')
foreach ($a in $archivos) {
    $fs = [IO.File]::OpenRead($a.FullName)
    $buf = New-Object byte[] 4096
    $n = $fs.Read($buf, 0, 4096)
    $fs.Close()
    $head = [Text.Encoding]::UTF8.GetString($buf, 0, $n)
    $metas = ExtraerDe $head
    $ti = $metas.ti
    if ($ti -eq "") { $ti = $a.BaseName -replace '-entrada$', '' }
    $k = Norm $ti
    if ($mapTit.ContainsKey($k)) {
        $dupTit[$k] = $true
        $mapTit[$k] = @($mapTit[$k]) + $a.Name
    } else {
        $mapTit[$k] = @($a.Name)
    }
}
foreach ($k in @($dupTit.Keys)) { $dupTit[$k] = $true }
Apuntar ("  archivos=" + $archivos.Count + "  url->archivo=" + $mapUrl.Count + "  titulos unicos=" + ($mapTit.Count - $dupTit.Count) + "  titulos repetidos=" + $dupTit.Count)

# --------------------------------------------------------------- posts vivos (feed)
Apuntar "leyendo posts vivos via feed ..."
$vivos = @()
$ini = 1
while ($true) {
    $j = $null
    try {
        $j = Invoke-RestMethod ("https://empleosperuhoy.blogspot.com/feeds/posts/default?alt=json&max-results=150&start-index=" + $ini)
    } catch { break }
    $ents = @()
    if ($j -and $j.feed -and $j.feed.entry) { $ents = @($j.feed.entry) }
    if ($ents.Count -eq 0 -or $null -eq $ents[0]) { break }
    foreach ($e in $ents) {
        $id = [string]$e.id.'$t'
        $id = $id -replace '^.*\.post-', ''
        $tit = ""
        try { $tit = Dec ([string]$e.title.'$t') } catch { }
        $url = ""
        foreach ($lk in @($e.link)) { if ($lk.rel -eq 'alternate') { $url = [string]$lk.href } }
        $cont = ""
        if ($e.content -and $e.content.'$t') { $cont = [string]$e.content.'$t' }
        elseif ($e.summary -and $e.summary.'$t') { $cont = [string]$e.summary.'$t' }
        $labs = @()
        foreach ($c in @($e.category)) { if ($c.term) { $labs += [string]$c.term } }
        $vivos += [pscustomobject]@{ id = $id; title = $tit; url = $url; content = $cont; labels = $labs }
    }
    $ini += $ents.Count
    if ($ents.Count -lt 150) { break }
    if ($ini -gt 6000) { break }
}
Apuntar ("  posts vivos=" + $vivos.Count)

# --------------------------------------------------------------- comparar y reparar
$iguales = 0
$fixTit = 0
$fixCon = 0
$fixAmbos = 0
$putOk = 0
$putFail = 0
$sinArchivo = New-Object System.Collections.Generic.List[string]
$ambiguos = New-Object System.Collections.Generic.List[string]
$ejemplos = 0

foreach ($post in $vivos) {
    $liveCont = Cont ([string]$post.content)
    $liveTit = Dec ([string]$post.title)
    $liveNormTit = Norm $liveTit

    $candidatos = $null
    if ($mapUrl.ContainsKey($post.url)) { $candidatos = @($mapUrl[$post.url]) }
    if ($null -eq $candidatos -and $mapTit.ContainsKey($liveNormTit)) { $candidatos = $mapTit[$liveNormTit] }

    if ($null -eq $candidatos) {
        $sinArchivo.Add(($post.url + "`t" + $liveTit))
        continue
    }

    # si hay varios archivos con el mismo titulo, elegir el mas parecido
    $fn = $null
    if ($candidatos.Count -eq 1) {
        $fn = $candidatos[0]
    } else {
        $best = 0
        $bestLen = -1
        foreach ($c in $candidatos) {
            $hc = Cont ([IO.File]::ReadAllText((Join-Path $dirSalida $c)))
            $pl = Prefijo $hc $liveCont
            $ratio = $pl / [double]([Math]::Min($hc.Length, [Math]::Max(1, $liveCont.Length)))
            if (($ratio -gt $best) -or ($ratio -eq $best -and $pl -gt $bestLen)) { $best = $ratio; $bestLen = $pl; $fn = $c }
        }
        if ($best -lt 0.4) {
            $ambiguos.Add(($post.url + "`t" + $liveTit))
            continue
        }
    }

    $path = Join-Path $dirSalida $fn
    if (-not (Test-Path $path)) { $sinArchivo.Add(($post.url + "`t" + $liveTit)); continue }

    $html = [IO.File]::ReadAllText($path)
    $meta = ExtraerDe $html
    $nuevoTitulo = $meta.ti
    if ($nuevoTitulo -eq "") { $nuevoTitulo = $liveTit }
    $difiereTit = ((Norm $nuevoTitulo) -cne $liveNormTit)
    $difiereCont = ((Cont $html) -cne $liveCont)

    if (-not $difiereTit -and -not $difiereCont) { $iguales++; continue }

    if ($difiereTit -and $difiereCont) { $fixAmbos++ }
    elseif ($difiereTit) { $fixTit++ }
    else { $fixCon++ }

    if ($ejemplos -lt 10) {
        $ejemplos++
        $mot = @()
        if ($difiereTit) { $mot += "titulo" }
        if ($difiereCont) { $mot += "contenido" }
        Apuntar ("  DEFECTO [" + ($mot -join '+') + "] " + $nuevoTitulo + "  <- " + $fn)
    }

    if ($Limite -gt 0 -and ($fixTit + $fixCon + $fixAmbos) -gt $Limite) { break }
    if ($Simular) { continue }

    $labels = @()
    if ($meta.et -ne "") { $labels = @($meta.et) } elseif ($post.labels) { $labels = @($post.labels) }
    if ($labels.Count -eq 0) { $labels = @("Empleo") }

    try {
        $r = Api PUT ("https://www.googleapis.com/blogger/v3/blogs/" + $blogId + "/posts/" + $post.id + "?fields=id,title") @{
            id = $post.id; title = $nuevoTitulo; content = $html; labels = $labels
        }
        if ($r.id -eq $post.id) { $putOk++ } else { $putFail++; Apuntar ("  PUT raro (id distinto) " + $fn) }
        $script:seq429 = 0
        Start-Sleep -Milliseconds $PausaMs
    } catch {
        $putFail++
        Apuntar ("  PUT ERROR " + $fn + " - " + $_.Exception.Message)
        $m = $_.Exception.Message
        if ($m -match '429') {
            $zz = [Math]::Min(300, 60 * (1 + $(if ($script:seq429) { $script:seq429 } else { 0 })))
            $script:seq429 = 1 + $(if ($script:seq429) { $script:seq429 } else { 0 })
            Apuntar ("  (429 seguido, espero " + $zz + "s)")
            Start-Sleep -Seconds $zz
        } else { $script:seq429 = 0 }
    }
    if (($putOk + $putFail) % 50 -eq 0) {
        Apuntar ("  progreso: PUT ok=" + $putOk + " fail=" + $putFail + " | difieren titulo=" + $fixTit + " contenido=" + $fixCon + " ambos=" + $fixAmbos + " | iguales=" + $iguales + " | sin archivo=" + $sinArchivo.Count)
    }
}

$sinArchivo | Set-Content -Path $sinArchivoPath -Encoding UTF8
$ambiguos | Set-Content -Path ($sinArchivoPath -replace 'sin-archivo', 'ambiguos') -Encoding UTF8

Apuntar "===== RESUMEN ====="
Apuntar ("  posts vivos: " + $vivos.Count)
Apuntar ("  iguales al archivo (sin tocar): " + $iguales)
Apuntar ("  con defectos -> " + $(if ($Simular) { "REPARARIAMOS" } else { "reparados" }) + ": titulo=" + $fixTit + " contenido=" + $fixCon + " ambos=" + $fixAmbos)
if (-not $Simular) { Apuntar ("  PUT ok=" + $putOk + "  PUT fallidos=" + $putFail) }
Apuntar ("  sin archivo: " + $sinArchivo.Count + "  -> " + $sinArchivoPath)
Apuntar ("  titulo repetido ambiguo: " + $ambiguos.Count)
exit $(if ($putFail -gt 0 -and -not $Simular) { 1 } else { 0 })
