# generar-backup-blogger.ps1 - crea un XML de respaldo de Blogger (formato
# Atom/Takeout que produce "Crear una copia de seguridad del contenido")
# con las entradas pendientes de salida\ ya integradas.
#
# USO:
#   .\generar-backup-blogger.ps1            # 174 actuales + pendientes
#   .\generar-backup-blogger.ps1 -MarcarImportados  # despues de importar
#
# Salida: xml\backup-importar.zip (misma estructura que el Takeout de Blogger)

param(
    [string[]]$Excluir = @('bj-*', 'ct-*', 'art-*'),
    [switch]$MarcarImportados
)

$ErrorActionPreference = "Stop"
$raiz    = Split-Path -Parent $MyInvocation.MyCommand.Path
$bak     = "C:\Users\Dell G3 Gaming\AppData\Local\Temp\opencode\blogger-bak\Takeout"
$dirSal  = Join-Path $raiz "salida"
$logPath = Join-Path $raiz "publicaciones.txt"
$dirXml  = Join-Path $raiz "xml"
$zipOut  = Join-Path $dirXml "backup-importar.zip"
$blogId  = "448950430489176641"
$BLOG    = "tag:blogger.com,1999:blog-" + $blogId

function Sin-Comentarios([string]$h) { return [regex]::Replace($h, '(?s)<!--.*?-->', '') }
function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}
function Fecha-De([string]$h, [datetime]$porDefecto) {
    $m = [regex]::Match($h, '(?i)Fecha (?:de )?publicaci(?:ó|o)n[^0-9]{0,30}(\d{2}/\d{2}/\d{4})')
    if ($m.Success) { try { return [datetime]::ParseExact($m.Groups[1].Value, 'dd/MM/yyyy', $null) } catch { } }
    return $porDefecto
}

# --------------------------------------------------------------- pendientes
$ya = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $logPath) {
    foreach ($l in [IO.File]::ReadAllLines($logPath)) {
        if ($l -match '\|\s*([^\|]+\.html)\s*$' -and $l -notmatch '\|\s*ERROR\s*\|') { [void]$ya.Add($Matches[1].Trim()) }
    }
}
$pendientes = @()
Get-ChildItem $dirSal -Filter '*-entrada.html' | ForEach-Object {
    foreach ($pat in $Excluir) { if ($pat -and $_.Name -like $pat) { return } }
    if ($ya.Contains($_.Name)) { return }
    $script:pendientes += $_
}
$pendientes = @($pendientes | Sort-Object Name)
Write-Host ("Pendientes: " + $pendientes.Count)

if ($MarcarImportados) {
    $hoy = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $nuevas = @()
    foreach ($f in $pendientes) {
        $raw = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        $m = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
        $tit = $(if ($m.Success) { $m.Groups[1].Value.Trim() } else { $f.BaseName })
        $nuevas += ($hoy + " | " + $tit + " | (importado-backup) | " + $f.Name)
    }
    [IO.File]::AppendAllLines($logPath, $nuevas, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("Marcados " + $nuevas.Count + " archivos.")
    exit 0
}
if ($pendientes.Count -eq 0) { Write-Host "Nada pendiente."; exit 0 }

# ------------------------------------------------------------ feed original
$feedPath = Join-Path $bak "Blogger\Blogs\Empleos Perú Hoy\feed.atom"
if (-not (Test-Path -LiteralPath $feedPath)) { Write-Host "ERROR: no encuentro el backup $feedPath"; exit 1 }
$feed = [IO.File]::ReadAllText($feedPath, [Text.Encoding]::UTF8)
$iPri = $feed.IndexOf('<entry>')
$iUlt = $feed.LastIndexOf('</entry>') + '</entry>'.Length
if ($iPri -lt 0 -or $iUlt -lt $iPri) { Write-Host "ERROR: feed sin entries"; exit 1 }
$header   = $feed.Substring(0, $iPri)
$originales = $feed.Substring($iPri, $iUlt - $iPri)
$footer   = $feed.Substring($iUlt)
Write-Host ("Feed original: " + ([regex]::Matches($originales, '<entry>')).Count + " entries")

# --------------------------------------------------------- nuevas entries
$sb = New-Object System.Text.StringBuilder
$n = 0
foreach ($f in $pendientes) {
    $n++
    $raw  = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $mt   = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
    $tit  = $(if ($mt.Success) { $mt.Groups[1].Value.Trim() } else { $f.BaseName })
    $body = Sin-Comentarios $raw
    $fPub = Fecha-De $body (Get-Date)
    $slug = $f.BaseName -replace '-entrada$', ''
    $id   = 910000000000000000 + $n
    $iso  = $fPub.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
    $arch = "/" + $fPub.ToString('yyyy/MM') + "/" + $slug + ".html"

    [void]$sb.Append("  <entry>`n")
    [void]$sb.Append("    <id>" + $BLOG + ".post-" + $id + "</id>`n")
    [void]$sb.Append("    <blogger:type>POST</blogger:type>`n")
    [void]$sb.Append("    <blogger:status>LIVE</blogger:status>`n")
    [void]$sb.Append("    <author>`n")
    [void]$sb.Append("      <name>Empleos Perú Hoy</name>`n")
    [void]$sb.Append("      <blogger:type>BLOGGER</blogger:type>`n")
    [void]$sb.Append("    </author>`n")
    [void]$sb.Append("    <title>" + (Esc $tit) + "</title>`n")
    [void]$sb.Append("    <content type='html'>" + (Esc $body) + "</content>`n")
    [void]$sb.Append("    <blogger:metaDescription/>`n")
    [void]$sb.Append("    <blogger:created>" + $iso + "</blogger:created>`n")
    [void]$sb.Append("    <published>" + $iso + "</published>`n")
    [void]$sb.Append("    <updated>" + $iso + "</updated>`n")
    [void]$sb.Append("    <blogger:location/>`n")
    [void]$sb.Append("    <category scheme='" + $BLOG + "' term='Empleo'/>`n")
    [void]$sb.Append("    <blogger:filename>" + (Esc $arch) + "</blogger:filename>`n")
    [void]$sb.Append("    <link/>`n")
    [void]$sb.Append("    <enclosure/>`n")
    [void]$sb.Append("    <blogger:trashed/>`n")
    [void]$sb.Append("  </entry>`n")
}
$nuevasEntries = $sb.ToString()
Write-Host ("Nuevas entries: " + $n)

# ------------------------------------------------------------------ escribir
$nuevoFeed = $header + $originales + "`n" + $nuevasEntries + $footer
$tmpFeed = Join-Path $dirXml "feed.atom"
[IO.File]::WriteAllText($tmpFeed, $nuevoFeed, (New-Object System.Text.UTF8Encoding($false)))
try { $chk = New-Object xml; $chk.Load($tmpFeed) } catch { Write-Host ("ERROR: feed invalido: " + $_.Exception.Message); exit 1 }
$total = $chk.SelectNodes("//*[local-name()='entry']").Count
Write-Host ("feed.atom nuevo: " + $total + " entries, XML valido")

# zip con la misma estructura del Takeout
$work = Join-Path $dirXml "zipwork"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
Copy-Item $bak -Recurse -Destination (Join-Path $work "Takeout")
$dest = Join-Path $work "Takeout\Blogger\Blogs\Empleos Perú Hoy\feed.atom"
Copy-Item $tmpFeed $dest -Force
if (Test-Path $zipOut) { Remove-Item $zipOut -Force }
Compress-Archive -Path (Join-Path $work "Takeout") -DestinationPath $zipOut -Force
Remove-Item $work -Recurse -Force
$kb = [Math]::Round((Get-Item $zipOut).Length / 1KB, 1)
Write-Host ""
Write-Host "== LISTO =="
Write-Host ("  " + $zipOut + "  (" + $kb + " KB)")
Write-Host "  Subelo en: Configuracion -> Administrar blog -> Importar contenido"
exit 0
