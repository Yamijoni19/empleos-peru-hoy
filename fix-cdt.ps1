# fix-cdt.ps1 - elimina TODO enlace/referencia a convocatoriasdetrabajo.com
# en los HTML de salida\ (no se redirige jamas a la fuente de scraping).
param([string]$Dir = "$PSScriptRoot\salida")
$ErrorActionPreference = "Stop"
$files = @(Get-ChildItem $Dir -Filter '*-entrada.html')
$nA = 0; $nLi = 0; $nFu = 0; $nCom = 0; $nBtn = 0; $nBtnRet = 0; $nVac = 0; $nArch = 0
foreach ($f in $files) {
    $h = [IO.File]::ReadAllText($f.FullName)
    if ($h -notmatch 'convocatoriasdetrabajo') { continue }
    $orig = $h

    # 0) boton POSTULA con href cdt: apunta al primer enlace oficial postulacion
    #    (no-cdt, no-pdf, con pista de portal), si no, se borra el boton
    $mBtn = [regex]::Matches($h, '(?is)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo[^"'']*["''][^>]*>\s*POSTULA[\s\S]*?</a>')
    foreach ($b in $mBtn) {
        # candidato: hrefs del archivo no-cdt, no .pdf, con pista de portal
        $cand = $null; $cand2 = $null
        foreach ($mm in [regex]::Matches($h, 'href\s*=\s*["''](https?://[^"'']+)["'']')) {
            $u = $mm.Groups[1].Value
            if ($u -match 'convocatoriasdetrabajo') { continue }
            if ($u -match '(?i)\.pdf($|\?)') { continue }
            if ($u -match '(?i)postul|wfrm|portal|form|inscri|registro|sia\.|tramit|convoca.*gob') { $cand = $u; break }
            if (-not $cand2) { $cand2 = $u }
        }
        $target = $cand; if (-not $target) { $target = $cand2 }
        if ($target) {
            $nb = [regex]::Replace($b.Value, 'href\s*=\s*(["''])[^"'']*convocatoriasdetrabajo[^"'']*\1', ('href="' + $target + '"'))
            $h = $h.Replace($b.Value, $nb); $nBtnRet++
        } else {
            $h = $h.Replace($b.Value, ''); $nBtn++
        }
    }

    # 1) <li> que envuelve SOLO el enlace cdt (bases)
    $h2 = [regex]::Replace($h, '(?is)<li>\s*<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo[^"'']*["''][\s\S]*?</a>\s*</li>\s*', '')
    if ($h2 -ne $h) { $nLi += ([regex]::Matches($h, '(?is)<li>\s*<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo')).Count; $h = $h2 }

    # 2) cualquier anchor cdt restante (texto plano dentro del <a>)
    $h2 = [regex]::Replace($h, '(?is)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo[^"'']*["''][^>]*>[\s\S]*?</a>', '')
    if ($h2 -ne $h) { $nA += ([regex]::Matches($h, '(?is)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo')).Count; $h = $h2 }

    # 3) seccion 'Bases' que quedo con <ul> vacio
    $h2 = [regex]::Replace($h, '(?is)<h2>\s*Bases y anexos oficiales\s*</h2>\s*<ul>\s*</ul>\s*', '')
    if ($h2 -ne $h) { $nVac++; $h = $h2 }

    # 4) parrafo Fuente (bloque oculto)
    $h2 = [regex]::Replace($h, '(?is)<p>\s*<strong>\s*Fuente\s*:</strong>\s*https?://(www\.)?convocatoriasdetrabajo\.com/[^<]*</p>\s*', '')
    if ($h2 -ne $h) { $nFu += ([regex]::Matches($h, '(?is)<strong>\s*Fuente\s*:</strong>[^<]*convocatoriasdetrabajo')).Count; $h = $h2 }

    # 5) lo que quede (comentarios, texto plano) => URL_ORIGEN
    $h2 = [regex]::Replace($h, '(?i)https?://(www\.)?convocatoriasdetrabajo\.com/[^\s"''<>)]*', 'URL_ORIGEN')
    if ($h2 -ne $h) { $nCom += ([regex]::Matches($h, '(?i)convocatoriasdetrabajo\.com')).Count - ([regex]::Matches($h2, '(?i)convocatoriasdetrabajo\.com')).Count; $h = $h2 }

    if ($h -ne $orig) { [IO.File]::WriteAllText($f.FullName, $h, (New-Object Text.UTF8Encoding($false))); $nArch++ }
}
Write-Host "== fix-cdt =="
Write-Host "  archivos tocados: $nArch"
Write-Host "  anchors POSTULA re-targetados: $nBtnRet | borrados: $nBtn"
Write-Host "  <li> bases eliminados: $nLi | anchors sueltos: $nA"
Write-Host "  secciones vacias: $nVac | parrafos Fuente: $nFu | restos en comentarios: $nCom"
$check = 0
foreach ($f in $files) {
    $h = [IO.File]::ReadAllText($f.FullName)
    $m = [regex]::Matches($h, '(?i)<a\s[^>]*href\s*=\s*["''][^"'']*convocatoriasdetrabajo')
    if ($m.Count -gt 0) { $check += $m.Count }
}
Write-Host "  VERIFICACION anchors cdt restantes: $check"
