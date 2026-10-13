# exportar-xml.ps1 - exporta las entradas pendientes de salida\ a un XML
# formato WordPress (WXR) para importarlas en Blogger SIN pasar por la API
# (la API de Blogger tiene cuota diaria; el importador de Blogger no).
#
# USO (PowerShell):
#   .\exportar-xml.ps1                       # pendientes Estado, lotes de 800
#   .\exportar-xml.ps1 -PorLote 500          # lotes mas chicos
#   .\exportar-xml.ps1 -Excluir ""           # incluye bj-*/ct-* tambien
#   .\exportar-xml.ps1 -MarcarImportados     # DESPUES de importar en Blogger:
#                                            # registra los archivos en
#                                            # publicaciones.txt para que la
#                                            # API no los vuelva a publicar
#
# Pasos en Blogger: Configuracion -> Otro -> "Importar contenido" -> elegir
# cada XML generado (importar-1.xml, importar-2.xml, ...).
# Etiqueta: todas las entradas se importan con la etiqueta "Empleo".

param(
    [int]$PorLote = 800,
    [string[]]$Excluir = @('bj-*', 'ct-*', 'art-*'),
    [string]$Prefijo = 'importar',
    [switch]$MarcarImportados
)

$ErrorActionPreference = "Stop"
$raiz   = Split-Path -Parent $MyInvocation.MyCommand.Path
$dirOut = Join-Path $raiz "xml"
$dirSal = Join-Path $raiz "salida"
$logPath = Join-Path $raiz "publicaciones.txt"
$blogUrl = "https://empleosperuhoy.blogspot.com"

function Sin-Comentarios([string]$h) {
    return [regex]::Replace($h, '(?s)<!--.*?-->', '')
}

function Fecha-De([string]$h, [datetime]$porDefecto) {
    $m = [regex]::Match($h, 'Fecha publicaci(?:ó|o)n:</strong>\s*(\d{2}/\d{2}/\d{4})')
    if (-not $m.Success) { $m = [regex]::Match($h, 'Fecha publicaci(?:ó|o)n:\s*(\d{2}/\d{2}/\d{4})') }
    if ($m.Success) {
        try { return [datetime]::ParseExact($m.Groups[1].Value, 'dd/MM/yyyy', $null) } catch { }
    }
    return $porDefecto
}

function Cdata([string]$s) {
    return "<![CDATA[" + ($s -replace ']]>', ']]]]><![CDATA[>') + "]]>"
}

# ------------------------------------------------- pendientes (sin importar)
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
Write-Host ("Pendientes de exportar: " + $pendientes.Count)
if ($pendientes.Count -eq 0) { Write-Host "Nada pendiente."; exit 0 }

if ($MarcarImportados) {
    $hoy = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $nuevas = @()
    foreach ($f in $pendientes) {
        $raw = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        $m = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
        $tit = $(if ($m.Success) { $m.Groups[1].Value.Trim() } else { $f.BaseName })
        $nuevas += ($hoy + " | " + $tit + " | (importado-xml) | " + $f.Name)
    }
    [IO.File]::AppendAllText($logPath, (($nuevas -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("Marcados " + $nuevas.Count + " archivos en publicaciones.txt (no se volveran a publicar por API).")
    exit 0
}

# ------------------------------------------------------------------ exportar
if (-not (Test-Path $dirOut)) { New-Item -ItemType Directory -Path $dirOut | Out-Null }
Get-ChildItem $dirOut -Filter ($Prefijo + '-*.xml') -ErrorAction SilentlyContinue | Remove-Item -Force

$blogs = @{ }
$bloques = @()
for ($i = 0; $i -lt $pendientes.Count; $i += $PorLote) {
    $fin = [Math]::Min($i + $PorLote - 1, $pendientes.Count - 1)
    $bloques += ,@($pendientes[$i..$fin])
}

$n = 0
for ($b = 0; $b -lt $bloques.Count; $b++) {
    $items = New-Object System.Text.StringBuilder
    foreach ($f in $bloques[$b]) {
        $n++
        $raw  = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        $mt   = [regex]::Match($raw, 'TITULO_BLOGGER = (.+?) -->')
        $tit  = $(if ($mt.Success) { $mt.Groups[1].Value.Trim() } else { $f.BaseName })
        $body = Sin-Comentarios $raw
        $fPub = Fecha-De $body (Get-Date)
        $slug = $f.BaseName -replace '-entrada$', ''
        $id   = 900000000 + $n
        $fechaTxt  = $fPub.ToString('ddd, dd MMM yyyy 12:00:00 +0000', [Globalization.CultureInfo]::InvariantCulture)
        $fechaMysql = $fPub.ToString('yyyy-MM-dd 12:00:00')
        $fechaGmt   = $fPub.ToString('yyyy-MM-dd 17:00:00')

        [void]$items.Append("  <item>`n")
        [void]$items.Append("    <title>" + (Cdata $tit) + "</title>`n")
        [void]$items.Append("    <link>" + $blogUrl + "/" + $fPub.ToString('yyyy/MM') + "/" + $slug + ".html</link>`n")
        [void]$items.Append("    <dc:creator>" + (Cdata 'empleos') + "</dc:creator>`n")
        [void]$items.Append("    <pubDate>" + $fechaTxt + "</pubDate>`n")
        [void]$items.Append("    <guid isPermaLink=`"false`">" + $blogUrl + "/?p=" + $id + "</guid>`n")
        [void]$items.Append("    <description></description>`n")
        [void]$items.Append("    <content:encoded>" + (Cdata $body) + "</content:encoded>`n")
        [void]$items.Append("    <excerpt:encoded><![CDATA[]]></excerpt:encoded>`n")
        [void]$items.Append("    <wp:post_id>" + $id + "</wp:post_id>`n")
        [void]$items.Append("    <wp:post_date>" + $fechaMysql + "</wp:post_date>`n")
        [void]$items.Append("    <wp:post_date_gmt>" + $fechaGmt + "</wp:post_date_gmt>`n")
        [void]$items.Append("    <wp:comment_status>open</wp:comment_status>`n")
        [void]$items.Append("    <wp:ping_status>closed</wp:ping_status>`n")
        [void]$items.Append("    <wp:post_name>" + $slug + "</wp:post_name>`n")
        [void]$items.Append("    <wp:status>publish</wp:status>`n")
        [void]$items.Append("    <wp:post_parent>0</wp:post_parent>`n")
        [void]$items.Append("    <wp:menu_order>0</wp:menu_order>`n")
        [void]$items.Append("    <wp:post_type>post</wp:post_type>`n")
        [void]$items.Append("    <wp:post_password></wp:post_password>`n")
        [void]$items.Append("    <wp:is_sticky>0</wp:is_sticky>`n")
        [void]$items.Append("    <category domain=`"category`">" + (Cdata 'Empleo') + "</category>`n")
        [void]$items.Append("  </item>`n")
    }

    $xml = New-Object System.Text.StringBuilder
    [void]$xml.Append("<?xml version=`"1.0`" encoding=`"UTF-8`" ?>`n")
    [void]$xml.Append("<rss version=`"2.0`"`n")
    [void]$xml.Append("  xmlns:excerpt=`"http://wordpress.org/export/1.2/excerpt/`"`n")
    [void]$xml.Append("  xmlns:content=`"http://purl.org/rss/1.0/modules/content/`"`n")
    [void]$xml.Append("  xmlns:wfw=`"http://wellformedweb.org/CommentAPI/`"`n")
    [void]$xml.Append("  xmlns:dc=`"http://purl.org/dc/elements/1.1/`"`n")
    [void]$xml.Append("  xmlns:wp=`"http://wordpress.org/export/1.2/`">`n")
    [void]$xml.Append("<channel>`n")
    [void]$xml.Append("  <title>Empleos Peru Hoy</title>`n")
    [void]$xml.Append("  <link>" + $blogUrl + "</link>`n")
    [void]$xml.Append("  <description>Convocatorias y empleos del Peru</description>`n")
    [void]$xml.Append("  <pubDate>" + (Get-Date).ToString('ddd, dd MMM yyyy HH:mm:ss +0000', [Globalization.CultureInfo]::InvariantCulture) + "</pubDate>`n")
    [void]$xml.Append("  <language>es-PE</language>`n")
    [void]$xml.Append("  <wp:wxr_version>1.2</wp:wxr_version>`n")
    [void]$xml.Append("  <wp:base_site_url>" + $blogUrl + "</wp:base_site_url>`n")
    [void]$xml.Append("  <wp:base_blog_url>" + $blogUrl + "</wp:base_blog_url>`n")
    [void]$xml.Append("  <generator>https://wordpress.org/?v=6.0</generator>`n")
    [void]$xml.Append($items.ToString())
    [void]$xml.Append("</channel>`n")
    [void]$xml.Append("</rss>`n")

    $ruta = Join-Path $dirOut ($Prefijo + "-" + ($b + 1) + "de" + $bloques.Count + ".xml")
    [IO.File]::WriteAllText($ruta, $xml.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    $tam = [Math]::Round((Get-Item $ruta).Length / 1MB, 1)
    Write-Host ("  " + (Split-Path $ruta -Leaf) + "  -> " + $bloques[$b].Count + " posts, " + $tam + " MB")
}

Write-Host ""
Write-Host "== RESUMEN =="
Write-Host ("  exportados: " + $n + " posts en " + $bloques.Count + " XML")
Write-Host ("  carpeta: " + $dirOut)
Write-Host ""
Write-Host "Siguiente paso: Blogger -> Configuracion -> Otro -> Importar contenido -> elegir cada XML."
Write-Host "Cuando termines de importar TODOS: .\exportar-xml.ps1 -MarcarImportados"
exit 0
