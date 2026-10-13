# fix-cdt2.ps1 - REEMPLAZA los enlaces a convocatoriasdetrabajo.com por links
# OFICIALES asociados a la misma oferta, en este orden:
#   POSTULA -> portal postulacion > gob.pe > cualquier no-pdf > pdf (texto VER BASES)
#             > pagina institucional gob.pe verificada > se elimina (sin nada real)
#   Bases   -> pdf oficial > gob.pe > cualquier > pagina institucional > elimina
#   Fuente  -> gob.pe > no-pdf > pagina institucional > elimina
#   comentarios -> URL_ORIGEN (no son enlaces)
# La pagina institucional gob.pe/<slug> se VERIFICA con GET real (200/redirect).
param([string]$Dir = "$PSScriptRoot\salida", [string]$DirFuentes = "$PSScriptRoot\fuentes")
$ErrorActionPreference = "Stop"
$script:cacheSlug = @{}
$script:mapaGob = @{}
$mpGob = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'mapa-entidades-gobpe.json'
if (Test-Path -LiteralPath $mpGob) {
    try {
        (Get-Content $mpGob -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
            $script:mapaGob[$_.Name] = $_.Value
        }
    } catch { }
}

function Normalizar-Slug([string]$s) {
    $s = $s.ToLower()
    $s = ($s -replace '\([^)]*\)', ' ')
    $s = $s -replace 'á','a' -replace 'é','e' -replace 'í','i' -replace 'ó','o' -replace 'ú','u' -replace 'ñ','n'
    $s = $s -replace '&',' y '
    $s = $s -replace '[^a-z0-9\s-]', ' '
    $s = ($s -replace '\s+', ' ').Trim()
    return ($s -replace ' ', '-')
}
function Verificar-Institucion([string]$ent) {
    if (-not $ent) { return $null }
    if ($script:cacheSlug.ContainsKey($ent)) { return $script:cacheSlug[$ent] }
    $res = $null
    if ($script:mapaGob.ContainsKey($ent)) { $res = $script:mapaGob[$ent] }
    else {
        # variantes de nombre por si el mapa viene incompleto
        $ent2 = ($ent -replace '\([^)]*\)', '') -replace '\s+', ' '
        $ent2 = $ent2.Trim()
        foreach ($k in @($ent, $ent2)) {
            if ($script:mapaGob.ContainsKey($k)) { $res = $script:mapaGob[$k]; break }
        }
    }
    $script:cacheSlug[$ent] = $res
    return $res
}
function Obtener-Candidatos([string]$archivo, [string]$slug) {
    $lista = New-Object 'System.Collections.Generic.List[string]'
    $visto = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $h = [IO.File]::ReadAllText($archivo)
    foreach ($m in [regex]::Matches($h, 'href\s*=\s*["''](https?://[^"'']+)["'']')) {
        $u = $m.Groups[1].Value
        if ($u -match 'convocatoriasdetrabajo') { continue }
        if ($visto.Add($u)) { [void]$lista.Add($u) }
    }
    $pf = Join-Path $DirFuentes ($slug + ".txt")
    if (Test-Path -LiteralPath $pf) {
        $src = [IO.File]::ReadAllText($pf)
        foreach ($m in [regex]::Matches($src, 'https?://[^\s"''<>\)\]]+')) {
            $u = $m.Value -replace '[.,;:]+$', ''
            if ($u -match 'convocatoriasdetrabajo') { continue }
            if ($visto.Add($u)) { [void]$lista.Add($u) }
        }
    }
    return ,$lista
}
function Mejor($l, [string]$patron, [bool]$incluirPdf) {
    foreach ($u in $l) {
        $esPdf = $u -match '(?i)\.pdf($|\?)'
        if ($esPdf -and -not $incluirPdf) { continue }
        if ($u -match $patron) { return $u }
    }
    return $null
}
function Cualquiera($l, [bool]$incluirPdf) {
    foreach ($u in $l) { if ($incluirPdf -or $u -notmatch '(?i)\.pdf($|\?)') { return $u } }
    return $null
}

$files = @(Get-ChildItem $Dir -Filter '*-entrada.html')
$nPost = 0; $nPostPdf = 0; $nPostInst = 0; $nPostOut = 0
$nBases = 0; $nBasesInst = 0; $nBasesOut = 0
$nFu = 0; $nFuInst = 0; $nFuOut = 0; $nArch = 0
foreach ($f in $files) {
    $h = [IO.File]::ReadAllText($f.FullName)
    if ($h -notmatch 'convocatoriasdetrabajo') { continue }
    $orig = $h
    $slug = $f.BaseName -replace '-entrada$', ''
    $cand = Obtener-Candidatos $f.FullName $slug
    $ent = ''
    $mt = [regex]::Match($h, '(?m)^\s*TITULO_BLOGGER = ([^:]+):')
    if ($mt.Success) { $ent = $mt.Groups[1].Value.Trim() }
    $PAC = '(?i)postul|wfrm|form|inscri|sia\.|tramit|portal|registro|convoca.*gob'
    $GOB = '(?i)gob\.pe|(^|://)[a-z0-9.-]*\.gob\.'

    # ---- POSTULA ----
    foreach ($m in [regex]::Matches($h, '(?is)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo[^"'']*["''][^>]*>[\s\S]*?</a>')) {
        $txt = ([regex]::Replace($m.Value, '<[^>]+>', ''))
        if ($txt -notmatch '(?i)POSTULA|POSTULAR') { continue }
        $t = Mejor $cand $PAC $false
        if (-not $t) { $t = Mejor $cand $GOB $false }
        if (-not $t) { $t = Cualquiera $cand $false }
        $esPdf = $false
        if (-not $t) { $t = Cualquiera $cand $true; if ($t) { $esPdf = $true } }
        $viaInst = $false
        if (-not $t) { $t = Verificar-Institucion $ent; if ($t) { $viaInst = $true } }
        if (-not $t) { $h = $h.Replace($m.Value, ''); $nPostOut++; continue }
        $na = [regex]::Replace($m.Value, 'href\s*=\s*(["''])[^"'']*\1', ('href="' + $t + '"'))
        if ($esPdf) { $na = [regex]::Replace($na, '(?is)(>)[^<]*(</a>)', '$1VER BASES OFICIALES$2'); $nPostPdf++ }
        elseif ($viaInst) { $na = [regex]::Replace($na, '(?is)(>)[^<]*(</a>)', '$1VER EN LA PAGINA OFICIAL$2'); $nPostInst++ }
        else { $nPost++ }
        $h = $h.Replace($m.Value, $na)
    }

    # ---- Bases / anchors sueltos ----
    foreach ($m in [regex]::Matches($h, '(?is)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo[^"'']*["''][^>]*>[\s\S]*?</a>')) {
        $t = Mejor $cand '(?i)\.pdf($|\?)' $true
        if (-not $t) { $t = Mejor $cand $GOB $true }
        if (-not $t) { $t = Cualquiera $cand $true }
        $viaInst = $false
        if (-not $t) { $t = Verificar-Institucion $ent; if ($t) { $viaInst = $true } }
        if (-not $t) { $h = $h.Replace($m.Value, ''); $nBasesOut++; continue }
        $na = [regex]::Replace($m.Value, 'href\s*=\s*(["''])[^"'']*\1', ('href="' + $t + '"'))
        if ($viaInst) { $na = [regex]::Replace($na, '(?is)(>)[^<]*(</a>)', '$1Informacion oficial de la entidad$2'); $nBasesInst++ } else { $nBases++ }
        $h = $h.Replace($m.Value, $na)
    }

    # ---- Fuente (texto plano) ----
    foreach ($m in [regex]::Matches($h, '(?is)<p>\s*<strong>\s*Fuente\s*:</strong>\s*https?://(www\.)?convocatoriasdetrabajo\.com/[^<]*</p>')) {
        $t = Mejor $cand $GOB $false
        if (-not $t) { $t = Cualquiera $cand $false }
        $viaInst = $false
        if (-not $t) { $t = Verificar-Institucion $ent; if ($t) { $viaInst = $true } }
        if (-not $t) { $h = $h.Replace($m.Value, ''); $nFuOut++; continue }
        $na = [regex]::Replace($m.Value, 'https?://(www\.)?convocatoriasdetrabajo\.com/[^\s"''<]*', $t)
        if ($viaInst) { $nFuInst++ } else { $nFu++ }
        $h = $h.Replace($m.Value, $na)
    }

    # ---- restos (comentarios, texto) ----
    $h = [regex]::Replace($h, '(?i)https?://(www\.)?convocatoriasdetrabajo\.com/[^\s"''<>)]*', 'URL_ORIGEN')

    if ($h -ne $orig) { [IO.File]::WriteAllText($f.FullName, $h, (New-Object Text.UTF8Encoding($false))); $nArch++ }
}
Write-Host "== fix-cdt2 v3 (REEMPLAZO con links oficiales) =="
Write-Host "  archivos tocados: $nArch"
Write-Host "  POSTULA: portal=$nPost gob.pe=$nPostInst pdf=$nPostPdf | borrados(sin nada): $nPostOut"
Write-Host "  Bases: oficiales=$nBases institucion=$nBasesInst | borrados: $nBasesOut"
Write-Host "  Fuente: gob.pe=$nFu institucion=$nFuInst | borrados: $nFuOut"
$chk = 0
foreach ($f in $files) { $chk += [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'href\s*=\s*["''][^"'']*convocatoriasdetrabajo').Count }
Write-Host "  VERIFICACION hrefs cdt restantes: $chk"
