# obtener-urls.ps1 - extrae las convocatorias NUEVAS de convocatoriasdetrabajo.com
#
# USO (PowerShell):
#   .\obtener-urls.ps1                        # diario: solo las nuevas de cada listado
#                                             #   (pagina 1 en adelante y para al chocar
#                                             #    con una URL ya conocida)
#   .\obtener-urls.ps1 -Full                  # backfill: TODAS las paginas de TODOS los listados
#   .\obtener-urls.ps1 -Listados cas          # solo un listado (portada, cas, practicas,
#                                             #   728, 276, scivil, locacion, consultoria)
#   .\obtener-urls.ps1 -Full -MaxPaginas 5    # como mucho 5 paginas por listado
#   .\obtener-urls.ps1 -Salida "cola.txt"     # archivo de salida distinto
#
# Escribe urls.txt (solo las NUEVAS, una URL por linea, en orden de publicacion)
# y usa historial-urls.txt como memoria de lo ya procesado.

param(
    [string]$Listados = "portada,cas,practicas,728,276,scivil,locacion,consultoria",
    [switch]$Full,
    [int]$MaxPaginas = 0,
    [string]$Salida = ""
)

$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Salida.Trim() -eq "") { $Salida = Join-Path $raiz "urls.txt" }
$historialPath = Join-Path $raiz "historial-urls.txt"

$sitio = "www.convocatoriasdetrabajo.com"
$base  = "https://" + $sitio

$fuentesListado = [ordered]@{
    portada     = "/"
    cas         = "/convocatorias-cas-vigentes.php"
    practicas   = "/convocatorias-practicas-profesionales-preprofesionales-vigentes.php"
    "728"       = "/contrataciones-empleo-728-vigentes-estado-peruano.php"
    "276"       = "/contrataciones-regimen-276-empleos-estado.php"
    scivil      = "/contrataciones-regimen-servicio-civil-30057-empleos-estado.php"
    locacion    = "/contrataciones-empleo-locacion-servicios-sector-publico.php"
    consultoria = "/contrataciones-consultorias-individuales-instituciones-estado.php"
}

$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

function Bajar([string]$u) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers['User-Agent'] = $ua
    $bytes = $wc.DownloadData($u)
    $wc.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

# anclado al titulo de la tarjeta: evita enlaces de compartir/redes y de navegacion
$rxItem = [regex]'(?s)<h2 class="convocatoria__title">\s*<a href="(?<url>https://www\.convocatoriasdetrabajo\.com/[^"]+\.html)"[^>]*>(?<tit>.*?)</a>'
$rxTag  = [regex]'(?s)<[^>]+>'

function ExtraerItems([string]$html) {
    $lista = @()
    foreach ($m in $rxItem.Matches($html)) {
        $u = $m.Groups['url'].Value
        if ($u -notmatch ('^https://' + [regex]::Escape($sitio) + '/')) { continue }
        $t = $rxTag.Replace($m.Groups['tit'].Value, '')
        $t = [Net.WebUtility]::HtmlDecode($t)
        $t = ($t -replace '\s+', ' ').Trim()
        $ini = [Math]::Max(0, $m.Index - 1700)
        $fin = [Math]::Min($html.Length, $m.Index + 3000)
        $ventana = $html.Substring($ini, $fin - $ini)
        $dias = ""
        $mds = [regex]::Matches($ventana, 'Finaliza en\s+(\d+)\s+d[i\u00e1]as')
        if ($mds.Count -gt 0) { $dias = $mds[$mds.Count - 1].Groups[1].Value }
        $vig = ""
        $mv = [regex]::Match($ventana, 'Vigente hasta:</span>\s*([0-9]{1,2}\s+\w{3}\s+\d{4})')
        if ($mv.Success) { $vig = $mv.Groups[1].Value }
        $lista += [pscustomobject]@{ url = $u; titulo = $t; dias = $dias; vigente = $vig }
    }
    return $lista
}

# ---------------------------------------------------------------- historial
$historial = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $historialPath) {
    foreach ($l in [IO.File]::ReadAllLines($historialPath)) {
        $l = $l.Trim()
        if ($l -ne "") { [void]$historial.Add($l) }
    }
}
Write-Host ("Historial: " + $historial.Count + " convocatorias ya procesadas")

# ---------------------------------------------------------------- rastreo
$nombres = @()
foreach ($n in ($Listados -split ',')) { $n2 = $n.Trim().ToLower(); if ($n2 -ne "") { $nombres += $n2 } }

$vistas      = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$nuevos      = New-Object System.Collections.Generic.List[string]
$titulos     = @{}
$porListado  = @{}
$paginasOk   = 0

foreach ($n in $nombres) {
    if (-not $fuentesListado.Contains($n)) {
        Write-Host ("  AVISO: listado desconocido '" + $n + "' (usa: " + (($fuentesListado.Keys) -join ', ') + ")")
        continue
    }
    $urlBase = $base + $fuentesListado[$n]
    Write-Host ""
    Write-Host ("== " + $n.ToUpper() + " ==")
    try { $pg1 = Bajar $urlBase } catch { Write-Host ("  ERROR: no se pudo bajar " + $urlBase + " - " + $_.Exception.Message); continue }
    $paginasOk++

    $totalPag = 1
    foreach ($mp in [regex]::Matches($pg1, '[&?]page=(\d+)')) {
        $v = [int]$mp.Groups[1].Value
        if ($v -gt $totalPag) { $totalPag = $v }
    }
    if ($MaxPaginas -gt 0 -and $totalPag -gt $MaxPaginas) { $totalPag = $MaxPaginas }
    Write-Host ("  paginas: " + $totalPag + $(if ($Full) { " (full)" } else { " (diario, para al chocar con lo conocido)" }))

    $parados = $false
    for ($p = 1; $p -le $totalPag -and -not $parados; $p++) {
        try {
            $html = if ($p -eq 1) { $pg1 } else { Start-Sleep -Milliseconds 300; Bajar ($urlBase + "?page=" + $p) }
        } catch { Write-Host ("  ERROR: pagina " + $p + " - " + $_.Exception.Message); break }
        $items = ExtraerItems $html
        if ($items.Count -eq 0) {
            Write-Host ("  AVISO: la pagina " + $p + " no trajo resultados (¿cambio el HTML del sitio?)")
            break
        }
        $conocidas = 0
        $nuevosPag = 0
        foreach ($it in $items) {
            if (-not $vistas.Add($it.url)) { continue }
            if ($historial.Contains($it.url)) { $conocidas++; continue }
            $nuevos.Add($it.url)
            $titulos[$it.url] = $it
            $nuevosPag++
        }
        Write-Host ("  pagina " + $p + "/" + $totalPag + ": " + $items.Count + " enlaces, " + $nuevosPag + " nuevos, " + $conocidas + " ya conocidas")
        if (-not $Full -and $conocidas -gt 0) { $parados = $true }
        $porListado[$n] = [int]($porListado[$n]) + $nuevosPag
    }
    Start-Sleep -Milliseconds 300
}

# ---------------------------------------------------------------- salida
$enc = New-Object System.Text.UTF8Encoding($false)
if ($nuevos.Count -gt 0) {
    [IO.File]::WriteAllText($Salida, (($nuevos -join "`n") + "`n"), $enc)
} else {
    [IO.File]::WriteAllText($Salida, "", $enc)
}

Write-Host ""
Write-Host "== RESUMEN =="
foreach ($k in $porListado.Keys) { if ($porListado[$k] -gt 0) { Write-Host ("  " + $k + ": " + $porListado[$k] + " nuevas") } }
Write-Host ("  TOTAL NUEVAS: " + $nuevos.Count)
Write-Host ("  vistas: " + $vistas.Count + " | conocidas: " + $historial.Count + " | paginas descargadas: " + $paginasOk)

if ($nuevos.Count -gt 0) {
    Write-Host ""
    Write-Host "== CONVOCATORIAS NUEVAS =="
    $i = 0
    foreach ($u in $nuevos) {
        $i++
        $it = $titulos[$u]
        $t = $it.titulo
        if ($t.Length -gt 78) { $t = $t.Substring(0, 75) + "..." }
        $extra = ""
        if ($it.vigente -ne "") { $extra = "  [vigente hasta " + $it.vigente + "]" }
        elseif ($it.dias -ne "") { $extra = "  [finaliza en " + $it.dias + " dias]" }
        Write-Host ("{0,4}. {1}{2}" -f $i, $t, $extra)
        if ($i -ge 60) { Write-Host ("     ... y " + ($nuevos.Count - 60) + " mas (lista completa en " + $Salida + ")"); break }
    }
    Write-Host ""
    Write-Host ("URLs nuevas escritas en: " + $Salida)
    Write-Host "Siguiente paso: ejecutar generar-lote.cmd para generar las entradas."
} else {
    Write-Host ""
    Write-Host "Sin convocatorias nuevas: ya has procesado todo lo publicado hasta ahora."
}
exit 0
