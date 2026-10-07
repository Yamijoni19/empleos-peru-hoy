# lib\salario.ps1 - EXTRACCION DE SALARIO compartida (Bumeran + pruebas).
#
# Regla absoluta: si hay un monto real NUNCA se escribe 'A convenir'.
# Sin monto interpretable => 'No especificado' (unico fallback).
#
# USO:
#   . .\lib\salario.ps1          # trae Convertir-Monto / Buscar-Montos / Extraer-Salario
#   Extraer-Salario    

function Convertir-Monto([string]$s) {
    $t = ([string]$s).Trim() -replace '[^\d\.,]', ''
    if ($t -eq '') { return $null }
    # 1.450 o 1.450,50 -> miles con punto
    if ($t -match '^\d{1,3}(\.\d{3})+(,\d{1,2})?$') { $t = ($t -replace '\.', '') -replace ',', '.' }
    # 3.140.00 -> miles con punto y decimal con punto (3140.00, NO 314000)
    elseif ($t -match '^\d{1,3}(?:\.\d{3})+\.\d{2}$') { $t = ($t -replace '\.', '') -replace '(\d{2})$', '.$1' }
    # 1,450 o 1,450.50 -> miles con coma
    elseif ($t -match '^\d{1,3}(,\d{3})+(\.\d{1,2})?$') { $t = ($t -replace ',', '') }
    # 6,624,00 -> miles con coma y decimal con coma (6624.00, NO 662400)
    elseif ($t -match '^\d{1,3}(?:,\d{3})+,\d{2}$') { $t = ($t -replace ',', '') -replace '(\d{2})$', '.$1' }
    # 2500,50 -> decimal con coma
    elseif ($t -match '^\d+,\d{1,2}$' -and $t.Length -le 6) { $t = $t -replace ',', '.' }
    # 4500.00 -> decimal con punto (NO tratarlo como miles: 4500.00 != 450000)
    elseif ($t -match '^\d+\.\d{1,2}$') { }
    else { $t = $t -replace '[^\d]', '' }
    if ($t -eq '') { return $null }
    $v = $null
    if (-not [double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)) { return $null }
    if ($v -lt 100 -or $v -gt 100000) { return $null }   # fuera de rango razonable mensual
    return [double]$v
}

function Buscar-Montos([string]$texto) {
    # devuelve lista de @{v; txt}
    $res = @()
    if (-not $texto) { return $res }
    $patrones = @(
        'S/\s*\.?\s*(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{3,6})',
        '(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{3,6})\s*soles',
        '(?:sueldo|salario|remuneraci[oó]n)[^0-9S]{0,20}(\d{3,6})',
        '(\d{3,6})\s*\+\s*EPS'
    )
    foreach ($p in $patrones) {
        foreach ($m in [regex]::Matches($texto, '(?i)' + $p)) {
            $v = Convertir-Monto $m.Groups[1].Value
            if ($null -ne $v) {
                $res += @{ v = $v; txt = $m.Value.Trim() }
            }
        }
    }
    return $res
}

function Extraer-Salario([string]$ldJson, [string]$html, [string]$titulo, [string]$descripcion) {
    $r = [pscustomobject]@{
        min = $null; max = $null; moneda = 'PEN'; especificado = $false
        texto_original = 'No especificado'; fuente_salario = ''
    }
    $vistos = @()

    # 1) JSON-LD JobPosting / baseSalary
    try {
        $ld = $ldJson | ConvertFrom-Json
        $bs = $ld.baseSalary
        if ($bs) {
            $val = $bs.value
            if ($val -is [string] -or $val -is [double] -or $val -is [int]) {
                $v = Convertir-Monto ([string]$val)
                if ($null -ne $v) { $r.min = $v; $r.max = $v; $r.especificado = $true; $r.texto_original = ('S/ ' + $v.ToString('N0')); $r.fuente_salario = 'jsonld' ; $vistos += $v }
            } elseif ($val) {
                $mn = $null; $mx = $null
                if ($val.minValue) { $mn = Convertir-Monto ([string]$val.minValue) }
                if ($val.maxValue) { $mx = Convertir-Monto ([string]$val.maxValue) }
                if ($null -eq $mn -and $val.value) { $mn = Convertir-Monto ([string]$val.value) }
                if ($null -ne $mn -and $null -ne $mx) { $r.min=$mn; $r.max=$mx; $r.especificado=$true; $r.texto_original=('S/ ' + $mn.ToString('N0') + ' - S/ ' + $mx.ToString('N0')); $r.fuente_salario='jsonld'; $vistos += $mn }
                elseif ($null -ne $mn) { $r.min=$mn; $r.max=$mn; $r.especificado=$true; $r.texto_original=('S/ ' + $mn.ToString('N0')); $r.fuente_salario='jsonld'; $vistos += $mn }
            }
        }
    } catch { }

    # 2) campos estructurados del HTML (JSON embebido de la SPA)
    if (-not $r.especificado) {
        foreach ($p in @('"(?:salary|sueldo|salario)"\s*:\s*"([^"]{1,40})"', '"(?:salary|sueldo|salario)"\s*:\s*(\d{3,6})')) {
            foreach ($m in [regex]::Matches($html, '(?i)' + $p)) {
                $v = Convertir-Monto $m.Groups[1].Value
                if ($null -ne $v) { $r.min=$v; $r.max=$v; $r.especificado=$true; $r.texto_original=('S/ ' + $v.ToString('N0')); $r.fuente_salario='campo-estructurado'; $vistos += $v; break }
            }
            if ($r.especificado) { break }
        }
    }

    # 3) HTML visible: etiqueta con dos puntos ("Salario: S/ 1,450")
    if (-not $r.especificado) {
        $mL = [regex]::Match($html, '(?is)(salario|sueldo|remuneraci[oó]n)(?:\s*(?:mensual|nominal|base))?\s*[:\-]?\s*(?:<[^>]+>\s*){0,5}(S/\s*\.?\s*\d[\d.,]*|\d[\d.,]{2,6}\s*soles)')
        if ($mL.Success) {
            $v = Convertir-Monto ($mL.Groups[2].Value -replace '(?i)soles', '')
            if ($null -ne $v) { $r.min=$v; $r.max=$v; $r.especificado=$true; $r.texto_original=$mL.Value.Trim(); $r.fuente_salario='html'; $vistos += $v }
        }
    }

    # 4) titulo   5) descripcion
    foreach ($par in @(@('titulo', $titulo), @('descripcion', $descripcion))) {
        if ($r.especificado) { break }
        $montos = @(Buscar-Montos $par[1])
        if ($montos.Count -gt 0) {
            $r.min = $montos[0].v; $r.max = $montos[0].v
            $r.especificado = $true; $r.texto_original = $montos[0].txt; $r.fuente_salario = $par[0]
            $vistos += $montos[0].v
        }
    }

    # 6) regex general sobre todo el documento
    if (-not $r.especificado) {
        $montos = @(Buscar-Montos ($html -replace '<[^>]+>', ' '))
        if ($montos.Count -gt 0) {
            $r.min = $montos[0].v; $r.max = $montos[0].v
            $r.especificado = $true; $r.texto_original = $montos[0].txt; $r.fuente_salario = 'regex'
            $vistos += $montos[0].v
        }
    }

    # rangos explicitos sobre el texto ya detectado ("S/ 2,500 - S/ 3,500", "hasta S/ 3,500")
    if ($r.especificado -and $r.texto_original -ne 'No especificado') {
        $txt = $titulo + ' ' + $descripcion + ' ' + $r.texto_original
        $mR = [regex]::Match($txt, '(?i)S/\s*\.?\s*(\d[\d.,]{2,8})\s*(?:-|a|hasta)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
        if ($mR.Success) {
            $mn = Convertir-Monto $mR.Groups[1].Value; $mx = Convertir-Monto $mR.Groups[2].Value
            if ($null -ne $mn -and $null -ne $mx -and $mx -ge $mn) { $r.min=$mn; $r.max=$mx; $r.texto_original=$mR.Value.Trim(); $r.fuente_salario='rango' }
        } else {
            $mH = [regex]::Match($txt, '(?i)(hasta|tope de)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
            $mM = [regex]::Match($txt, '(?i)(m[aá]s de|desde|desde solo)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
            if ($mH.Success) { $mx = Convertir-Monto $mH.Groups[2].Value; if ($null -ne $mx) { $r.min=$null; $r.max=$mx; $r.texto_original=$mH.Value.Trim(); $r.fuente_salario='hasta' } }
            elseif ($mM.Success) { $mn = Convertir-Monto $mM.Groups[2].Value; if ($null -ne $mn) { $r.min=$mn; $r.max=$null; $r.texto_original=$mM.Value.Trim(); $r.fuente_salario='desde' } }
        }
    }

    if (-not $r.especificado) {
        $r.min = $null; $r.max = $null
        $r.texto_original = 'No especificado'
        $r.fuente_salario = ''
    }
    return $r
}
