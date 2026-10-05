# obtener-urls-privado.ps1 - rastrea ofertas del SECTOR PRIVADO nuevas.
#
# USO (PowerShell):
#   .\obtener-urls-privado.ps1               # ultimos 4 dias (semilla) -> urls-privado.txt
#   .\obtener-urls-privado.ps1 -Dias 3       # barrido diario (overlap)
#   .\obtener-urls-privado.ps1 -SoloBuscojobs
#   .\obtener-urls-privado.ps1 -SoloComputrabajo
#
# FUENTES:
#   - BuscoJobs: sitemap-jobs.xml con <lastmod> (filtra por fecha).
#   - Computrabajo: listados por ciudad (fechas "Hace X ..." por oferta).
#
# Usa historial-urls.txt como memoria de lo ya procesado (mismo historial
# que el flujo del Estado, asi ninguna URL se procesa dos veces).
# Sale 0 = OK, 1 = error.

param(
    [int]$Dias = 4,
    [string]$Salida = "",
    [switch]$SoloBuscojobs,
    [switch]$SoloComputrabajo,
    [int]$MaxPaginasCiudad = 12
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($Salida -eq '') { $Salida = Join-Path $raiz 'urls-privado.txt' }
$historialPath = Join-Path $raiz 'historial-urls.txt'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

function Get2([string]$u) {
    try {
        $r = [Net.WebRequest]::Create($u)
        $r.UserAgent = $ua
        $r.Accept = 'text/html,application/xml,text/xml,*/*'
        $r.Headers.Add('Accept-Language', 'es-PE,es;q=0.9')
        $r.Headers.Add('Accept-Encoding', 'identity')
        $r.AllowAutoRedirect = $true
        $resp = $r.GetResponse()
        $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
        $b = $sr.ReadToEnd()
        $sr.Close(); $resp.Close()
        return $b
    } catch {
        Write-Host ("  (fallo al bajar " + $u + ": " + $_.Exception.Message + ")")
        return $null
    }
}

function Sin-Acentos([string]$s) {
    $x = ([string]$s).ToLower().Normalize([Text.NormalizationForm]::FormD)
    return [regex]::Replace($x, '[\u0300-\u036f]', '')
}

# "Hace 3 dias" / "Hace 5 horas" -> dias transcurridos (99 = no interpretable)
function Dias-Desde([string]$txt) {
    $t = Sin-Acentos $txt
    $m = [regex]::Match($t, 'hace\s+(\d+)\s*(minuto|hora|dia|semana|mes)')
    if (-not $m.Success) {
        if ($t -match 'ayer') { return 1 }
        return 99
    }
    $n = [int]$m.Groups[1].Value
    switch -Regex ($m.Groups[2].Value) {
        'minuto' { return 0 }
        'hora'   { return 0 }
        'dia'    { return $n }
        'semana' { return $n * 7 }
        'mes'    { return $n * 30 }
    }
    return 99
}

# ---------------------------------------------------------------- historial
$historial = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
if (Test-Path $historialPath) {
    foreach ($l in [IO.File]::ReadAllLines($historialPath)) { $l = $l.Trim(); if ($l -ne '') { [void]$historial.Add($l) } }
}
Write-Host ("Historial: " + $historial.Count + " URLs ya procesadas")
Write-Host ("Ventana: ultimos " + $Dias + " dias")

$nuevas = New-Object 'System.Collections.Generic.List[string]'
$vistas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$corte = (Get-Date).Date.AddDays(-$Dias)

function Agregar([string]$u) {
    $u = $u.Trim()
    if ($u -eq '' -or $u -notmatch '^https?://') { return $false }
    if ($historial.Contains($u)) { return $false }
    if (-not $vistas.Add($u)) { return $false }
    $nuevas.Add($u)
    return $true
}

# --------------------------------------------------------------- BUSCOJOBS
if (-not $SoloComputrabajo) {
    Write-Host ''
    Write-Host '== BUSCOJOBS (sitemap-jobs.xml) =='
    $sm = Get2 'https://www.buscojobs.pe/sitemap/sitemaps/bjpe/sitemap-jobs.xml'
    if (-not $sm) { Write-Host '  ERROR: no se pudo bajar el sitemap' }
    else {
        $total = 0; $enVentana = 0; $conocidas = 0; $nuevasBj = 0
        foreach ($m in [regex]::Matches($sm, '<loc>([^<]+)</loc>\s*<lastmod>([^<]+)</lastmod>')) {
            $total++
            $loc = $m.Groups[1].Value.Trim()
            $lm = $m.Groups[2].Value.Trim()
            if ($lm -lt $corte.ToString('yyyy-MM-dd')) { continue }
            $enVentana++
            if ($historial.Contains($loc)) { $conocidas++; continue }
            if (Agregar $loc) { $nuevasBj++ }
        }
        Write-Host ("  en el sitemap: " + $total)
        Write-Host ("  con lastmod en la ventana: " + $enVentana)
        Write-Host ("  ya procesadas: " + $conocidas + " | nuevas: " + $nuevasBj)
    }
}

# ------------------------------------------------------------ COMPUTRABAJO
if (-not $SoloBuscojobs) {
    Write-Host ''
    Write-Host '== COMPUTRABAJO (listados por ciudad) =='
    $ciudades = @('lima', 'callao', 'arequipa', 'piura', 'cusco', 'ica', 'tacna',
                  'ayacucho', 'la-libertad', 'lambayeque', 'junin', 'ancash',
                  'puno', 'cajamarca', 'ucayali', 'san-martin', 'amazonas',
                  'loreto', 'huanuco', 'pasco', 'moquegua', 'tumbes',
                  'apurimac', 'huancavelica')
    foreach ($ciudad in $ciudades) {
        $nuevasCiudad = 0
        $paginas = 0
        for ($pag = 1; $pag -le $MaxPaginasCiudad; $pag++) {
            $u = 'https://pe.computrabajo.com/empleos-en-' + $ciudad
            if ($pag -gt 1) { $u += ('?page=' + $pag) }
            $h = Get2 $u
            if (-not $h) { break }
            $paginas++

            # empareja cada "Hace X" con el href de oferta mas cercano hacia atras
            $hrefMs = [regex]::Matches($h, 'href="(/ofertas-de-trabajo/oferta-de-trabajo-de-[^"]+)"')
            $fechaMs = [regex]::Matches($h, '(?i)Hace\s+\d+\s*\w+')
            if ($hrefMs.Count -eq 0) { break }

            $enPagina = 0
            $nuevasPag = 0
            $viejas = 0
            $iH = 0
            foreach ($fm in $fechaMs) {
                while ($iH -lt $hrefMs.Count -and $hrefMs[$iH].Index -lt $fm.Index) { $iH++ }
                if ($iH -eq 0) { continue }
                $href = $hrefMs[$iH - 1].Groups[1].Value
                $corteFrag = $href.IndexOf('#')
                if ($corteFrag -ge 0) { $href = $href.Substring(0, $corteFrag) }
                $dias = Dias-Desde $fm.Value
                $enPagina++
                if ($dias -gt $Dias) { $viejas++; continue }
                $full = 'https://pe.computrabajo.com' + $href
                if (Agregar $full) { $nuevasPag++ }
            }
            $nuevasCiudad += $nuevasPag
            # sin fechas nuevas (paginacion ignorada) o todo fuera de la ventana -> para
            if ($fechaMs.Count -eq 0) { break }
            if ($nuevasPag -eq 0 -and $pag -gt 1) { break }
            if ($enPagina -gt 0 -and $viejas -ge $enPagina) { break }
            Start-Sleep -Milliseconds 400
        }
        Write-Host ("  " + $ciudad + ": paginas=" + $paginas + " nuevas=" + $nuevasCiudad)
    }
}

# ------------------------------------------------------------------ salida
if ($nuevas.Count -eq 0) {
    Write-Host ''
    Write-Host 'No hay ofertas nuevas en la ventana.'
    exit 0
}
$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($Salida, $nuevas, $enc)
Write-Host ''
Write-Host '== RESUMEN =='
Write-Host ("  URLs nuevas: " + $nuevas.Count + " -> " + $Salida)
Write-Host '  Siguiente paso: generar-lote.cmd -Urls urls-privado.txt -Generador generar-entrada-privado.ps1'
exit 0
