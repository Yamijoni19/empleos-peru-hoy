# lib/catalogo.ps1 - Detector de paginas-recopilatorio (varias ofertas en 1 articulo).
#
# Reglas (validadas contra muestras reales de convocatoriasdetrabajo.com):
#   A. >=2 encabezados h2/h3 que empiezan con CAS/CONV + numero  (digestos tipicos)
#   B. >=2 encabezados h2/h3 numerados: "276 N° 001-...", "001 CÓDIGO 03315: ..."
#      (series DIRESA/Poder Judicial: cada sub-oferta es un encabezado con enlace)
#   C. >=5 menciones de "CÓDIGO DE PLAZA" en la pagina (catalogos con tabla de plazas)
# Paginas-individuales con widget de "relacionadas" (10-13 enlaces h2 a otras
# ofertas) NO activan estas reglas: sus encabezados no son numerados.

function Test-EsCatalogoHtml {
    param([Parameter(Mandatory = $true)][string]$Html)

    $encCas = 0
    $encNum = 0
    foreach ($mh in [regex]::Matches($Html, '(?is)<h([23])[^>]*>([\s\S]*?)</h\1>')) {
        $tx = ($mh.Groups[2].Value -replace '(?is)<[^>]+>', ' ')
        $tx = ($tx -replace '\s+', ' ').Trim()
        if ($tx -match '(?i)^\s*C(?:AS|ONV)\b[^0-9]{0,12}[0-9]{2,4}') { $encCas++ }
        if ($tx -match '^\s*\d{2,4}\s*(N[°º]|C[OÓ]DIGO\b)') { $encNum++ }
    }
    $codigos = ([regex]::Matches($Html, '(?i)C[OÓ]DIGO DE PLAZA')).Count
    $enlaces  = ([regex]::Matches($Html, 'href="https?://(?:www\.)?convocatoriasdetrabajo\.com/(?:oportunidad-laboral|oferta-de-empleo)[^"]*"')).Count

    $motivos = @()
    if ($encCas -ge 2) { $motivos += "encabezados CAS/CONV numerados x$encCas" }
    if ($encNum -ge 2) { $motivos += "encabezados numerados (serie N Codigo) x$encNum" }
    if ($codigos -ge 5) { $motivos += "CÓDIGO DE PLAZA repetido x$codigos" }

    [pscustomobject]@{
        EsCatalogo    = ($motivos.Count -gt 0)
        Motivo        = ($motivos -join '; ')
        EncCas        = $encCas
        EncNumerados  = $encNum
        CodigoPlaza   = $codigos
        EnlacesOferta = $enlaces
    }
}
