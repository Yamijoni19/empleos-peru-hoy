# reconstruir-feed.ps1 - genera xml\rebuild.xml (formato Atom de Blogger) con:
#   - las 207 entries originales del backup (los 174 posts reales + paginas + estados)
#   - las entradas de salida\ SIN duplicados por titulo (se queda la mas completa)
#   - fechas reales de publicacion (Fecha/Fecha de publicacion del cuerpo)
#   - instants unicos (segundos escalados por entry)
param(
    [switch]$SoloInfo
)
$ErrorActionPreference = "Stop"
$raiz    = Split-Path -Parent $MyInvocation.MyCommand.Path
$bak     = "C:\Users\Dell G3 Gaming\AppData\Local\Temp\opencode\blogger-bak\Takeout\Blogger\Blogs\Empleos Perú Hoy\feed.atom"
$dirSal  = Join-Path $raiz "salida"
$logPath = Join-Path $raiz "publicaciones.txt"
$out     = Join-Path $raiz "xml\rebuild.xml"
$BLOG    = "tag:blogger.com,1999:blog-448950430489176641"

function Sin-Comentarios([string]$h) { return [regex]::Replace($h, '(?s)<!--.*?-->', '') }
function Esc([string]$s) { if ($null -eq $s) { return '' }; return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Fecha-De([string]$h, [datetime]$porDefecto) {
    $m = [regex]::Match($h, '(?i)Fecha (?:de )?publicaci(?:ó|o)n[^0-9]{0,30}(\d{2}/\d{2}/\d{4})')
    if ($m.Success) { try { return [datetime]::ParseExact($m.Groups[1].Value, 'dd/MM/yyyy', $null) } catch { } }
    return $porDefecto
}
function Palabras([string]$h) {
    $t = [regex]::Replace($h, '(?s)<script[\s\S]*?</script>', ' ')
    $t = [regex]::Replace($t, '<[^>]+>', ' ')
    return @(($t -split '\s+') | Where-Object { $_ -ne '' }).Count
}

# ------------------------------------------------------- selecciones
$excluir = @('bj-*', 'ct-*', 'art-*')
$ya = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $logPath) {
    # solo excluye los que se publicaron DE VERDAD por API (linea con http);
    # los marcados (importado-xml) cuentan como pendientes otra vez
    foreach ($l in [IO.File]::ReadAllLines($logPath)) {
        if ($l -match 'https?://' -and $l -match '\|\s*([^\|]+\.html)\s*$') { [void]$ya.Add($Matches[1].Trim()) }
    }
}
$candidatos = @()
Get-ChildItem $dirSal -Filter '*-entrada.html' | ForEach-Object {
    foreach ($pat in $excluir) { if ($pat -and $_.Name -like $pat) { return } }
    if ($ya.Contains($_.Name)) { return }
    $script:candidatos += $_
}
# un archivo por TITULO: gana el que mas palabras tenga
$porTitulo = @{}
foreach ($f in $candidatos) {
    $raw = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $mt = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
    $tit = $(if ($mt.Success) { $mt.Groups[1].Value.Trim() } else { $f.BaseName })
    $w = Palabras $raw
    if (-not $porTitulo.ContainsKey($tit) -or $w -gt $porTitulo[$tit].w) {
        $porTitulo[$tit] = @{ f = $f; w = $w }
    }
}
$elegidos = @($porTitulo.Values | ForEach-Object { $_.f } | Sort-Object Name)
Write-Host ("candidatos: " + $candidatos.Count + " | sin duplicar titulo: " + $elegidos.Count + " | descartados por titulo repetido: " + ($candidatos.Count - $elegidos.Count))
if ($SoloInfo) { exit 0 }

# ------------------------------------------------------------------ feed
$feed = [IO.File]::ReadAllText($bak, [Text.Encoding]::UTF8)
$iPri = $feed.IndexOf('<entry>')
$iUlt = $feed.LastIndexOf('</entry>') + '</entry>'.Length
$header   = $feed.Substring(0, $iPri)
# solo entradas LIVE del respaldo (basura SOFT_TRASHED/DRAFT no vuelve)
$origEntradas = @([regex]::Matches($feed.Substring($iPri, $iUlt - $iPri), '<entry>[\s\S]*?</entry>') | ForEach-Object { $_.Value })
$live = @($origEntradas | Where-Object { $_ -match '<blogger:status>LIVE</blogger:status>' })
# indice titulo -> archivo de salida (para originales con filename antiguo)
$idxTitulo = @{}
Get-ChildItem $dirSal -Filter '*-entrada.html' | ForEach-Object {
    $raw = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    $mt = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
    if ($mt.Success -and $mt.Groups[1].Value.Trim() -and -not $idxTitulo.ContainsKey($mt.Groups[1].Value.Trim())) {
        $idxTitulo[$mt.Groups[1].Value.Trim()] = $_.FullName
    }
}
# mapa entidad -> URL oficial (para limpiar cdt que quede en originales del respaldo)
$mapaGob = @{}
$mpJson = Join-Path $raiz 'mapa-entidades-gobpe.json'
if (Test-Path -LiteralPath $mpJson) {
    (Get-Content $mpJson -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $mapaGob[$_.Name] = $_.Value }
}
$mapaOrden = @($mapaGob.Keys | Sort-Object { $_.Length } -Descending)
function Nor([string]$s) {
    if (-not $s) { return '' }
    $d = $s.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $d.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            if ([char]::IsLetterOrDigit($ch)) { [void]$sb.Append([char]::ToLowerInvariant($ch)) } else { [void]$sb.Append(' ') }
        }
    }
    return (($sb.ToString() -replace '\s+', ' ').Trim())
}
$vacias = @('de','del','la','el','los','las','y','en','para','con','al','un','una')
$clavesNorm = @($mapaOrden | ForEach-Object {
    $k = $_
    $toks = @((Nor $k) -split ' ' | Where-Object { $_ -and ($vacias -notcontains $_) })
    if ($toks.Count) { @{ k = $k; t = $toks } }
})
# todo POST debe tener la etiqueta Empleo + contenido desde salida\ si existe
# (los originales del respaldo quedan con el HTML ya corregido: cdt reemplazado)
$live = @($live | ForEach-Object {
    $e = $_
    if ($e -match '<blogger:type>POST</blogger:type>' -and $e -notmatch "term='Empleo'") {
        $e = $e -replace '(\s*)<link/>', ("`$1    <category scheme='" + $BLOG + "' term='Empleo'/>`n`$1<link/>")
    }
    $mf = [regex]::Match($e, '<blogger:filename>([^<]+)</blogger:filename>')
    $sf = $null
    if ($mf.Success) {
        $slug = [IO.Path]::GetFileNameWithoutExtension($mf.Groups[1].Value)
        $cand = Join-Path $dirSal ($slug + "-entrada.html")
        if (Test-Path -LiteralPath $cand) { $sf = $cand }
    }
    if (-not $sf) {
        $mt = [regex]::Match($e, '<title>([\s\S]*?)</title>')
        if ($mt.Success) {
            $tt = [Net.WebUtility]::HtmlDecode($mt.Groups[1].Value).Trim()
            if ($idxTitulo.ContainsKey($tt)) { $sf = $idxTitulo[$tt] }
        }
    }
    if ($sf) {
        $raw = [IO.File]::ReadAllText($sf, [Text.Encoding]::UTF8)
        $raw = [regex]::Replace($raw, '(?s)^\s*<!--\s*ETIQUETA_BLOGGER[\s\S]*?-->\s*', '')
        $e = [regex]::Replace($e, '(?s)(<content[^>]*>)[\s\S]*?(</content>)', {
            param($mm) $mm.Groups[1].Value + (Esc $raw) + $mm.Groups[2].Value
        })
    }
    if ($e -match 'convocatoriasdetrabajo') {
        # 1) fuera comentarios de plantilla (escapados dentro del content) que citan el dominio
        $e = [regex]::Replace($e, '(?s)&lt;!--[\s\S]*?--&gt;', '')
        $e = [regex]::Replace($e, '(?s)<!--[\s\S]*?-->', '')
    }
    if ($e -match 'convocatoriasdetrabajo') {
        $eNorm = ' ' + (Nor $e) + ' '
        $urlOf = $null
        foreach ($c in $clavesNorm) {
            $ok = $true
            foreach ($tk in $c.t) { if ($eNorm.IndexOf(' ' + $tk + ' ') -lt 0) { $ok = $false; break } }
            if ($ok) { $urlOf = $mapaGob[$c.k]; break }
        }
        if ($urlOf) {
            $ev = $urlOf
            $e = [regex]::Replace($e, 'convocatoriasdetrabajo\.com/[^"\s<>&]*?\.(?:html|htm)(?:\.(?=[\s<]|$))?', [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $ev })
        } else {
            $tt = [regex]::Match($e, '<title>([\s\S]*?)</title>')
            Write-Host ("  !! cdt sin entidad en original: " + $(if ($tt.Success) { $tt.Groups[1].Value } else { '?' }))
        }
    }
    $e
})
Write-Host ("entries backup: " + $origEntradas.Count + " | solo LIVE: " + $live.Count + " | descartadas: " + ($origEntradas.Count - $live.Count))
$originales = ($live -join "`n") + "`n"
$footer   = $feed.Substring($iUlt)

$sb = New-Object System.Text.StringBuilder
$n = 0
foreach ($f in $elegidos) {
    $n++
    $raw  = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $mt   = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
    $tit  = $(if ($mt.Success) { $mt.Groups[1].Value.Trim() } else { $f.BaseName })
    $body = Sin-Comentarios $raw
    $fPub = Fecha-De $body (Get-Date)
    $slug = $f.BaseName -replace '-entrada$', ''
    $id   = 940000000000000000 + $n
    # instante unico por entry: base 06:00 UTC + escalon de segundos
    $base = [datetime]::ParseExact($fPub.ToString('yyyy-MM-dd') + ' 06:00', 'yyyy-MM-dd HH:mm', $null)
    $iso  = $base.AddSeconds($n).ToString('yyyy-MM-ddTHH:mm:ss.000Z')
    $arch = "/" + $fPub.ToString('yyyy/MM') + "/" + $slug + ".html"

    [void]$sb.Append("  <entry>`n")
    [void]$sb.Append("    <id>" + $BLOG + ".post-" + $id + "</id>`n")
    [void]$sb.Append("    <blogger:type>POST</blogger:type>`n")
    [void]$sb.Append("    <blogger:status>LIVE</blogger:status>`n")
    [void]$sb.Append("    <author>`n      <name>Empleos Perú Hoy</name>`n      <blogger:type>BLOGGER</blogger:type>`n    </author>`n")
    [void]$sb.Append("    <title>" + (Esc $tit) + "</title>`n")
    [void]$sb.Append("    <content type='html'>" + (Esc $body) + "</content>`n")
    [void]$sb.Append("    <blogger:metaDescription/>`n")
    [void]$sb.Append("    <blogger:created>" + $iso + "</blogger:created>`n")
    [void]$sb.Append("    <published>" + $iso + "</published>`n")
    [void]$sb.Append("    <updated>" + $iso + "</updated>`n")
    [void]$sb.Append("    <blogger:location/>`n")
    [void]$sb.Append("    <category scheme='" + $BLOG + "' term='Empleo'/>`n")
    [void]$sb.Append("    <blogger:filename>" + (Esc $arch) + "</blogger:filename>`n")
    [void]$sb.Append("    <link/>`n    <enclosure/>`n    <blogger:trashed/>`n")
    [void]$sb.Append("  </entry>`n")
}

$nuevo = $header + $originales + "`n" + $sb.ToString() + $footer
[IO.File]::WriteAllText($out, $nuevo, (New-Object System.Text.UTF8Encoding($false)))
$chk = New-Object xml
$chk.Load($out)
$total = $chk.SelectNodes("//*[local-name()='entry']").Count
Write-Host ""
Write-Host "== REBUILD LISTO =="
Write-Host ("  " + $out + "  (" + [Math]::Round((Get-Item $out).Length/1MB,1) + " MB)")
Write-Host ("  entries: " + $total + " (backup originales + " + $n + " nuevas sin duplicar)")
Write-Host "  esperado tras importar (reemplazando todo): ~" + (174 + $n) + " posts"
exit 0
