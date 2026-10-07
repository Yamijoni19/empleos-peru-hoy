# lib\bumeran-parser.ps1 - parseo enriquecido privado
# Sin llamadas de red: recibe HTML y JSON-LD, devuelve objeto con campos.

function Get-Text-Html {
    param([string]$h)
    $s = $h
    $s = $s -replace '<\s*br\s*/?\s*>', "`n"
    $s = $s -replace '<p[^>]*>', "`n"
    $s = $s -replace '</p>', "`n"
    $s = $s -replace '<ul[^>]*>', "`n"
    $s = $s -replace '</ul>', "`n"
    $s = $s -replace '<li[^>]*>', "`n* "
    $s = $s -replace '</li>', "`n"
    $s = $s -replace '(?i)</strong>', ''
    $s = $s -replace '(?i)<strong[^>]*>', ''
    $s = $s -replace '(?i)</?[^>]+>', ''
    $s = [System.Net.WebUtility]::HtmlDecode($s)
    $s = $s -replace '[ \t]+', ' '
    $s = $s -replace '\r', ''
    $s = $s -replace "`n+", "`n"
    return $s.Trim()
}

function Get-Secciones {
    param([string]$desc)
    $found = @()
    foreach ($m in [regex]::Matches($desc, '(?i)\b(FUNCIONES|REQUISITOS|BENEFICIOS|PERFIL|OFRECEMOS|FORMACION|FORMACION ACADEMICA|INFORMACION ADICIONAL|CONDICIONES)\s*:?\b')) {
        $found += [pscustomobject]@{ Nombre = $m.Groups[1].Value.ToUpper(); Idx = $m.Index }
    }
    $result = @{ funciones=''; requisitos=''; beneficios='' }
    if ($found.Count -eq 0) { return $result }
    for ($i=0; $i -lt $found.Count; $i++) {
        $start = $found[$i].Idx + 12
        $end = if ($i -lt $found.Count - 1) { $found[$i+1].Idx } else { $desc.Length }
        $segmento = $desc.Substring($found[$i].Idx, $end - $found[$i].Idx)
        $segmento = $segmento -replace '^\s*(FUNCIONES|REQUISITOS|BENEFICIOS|PERFIL|OFRECEMOS|FORMACION|FORMACION ACADEMICA|INFORMACION ADICIONAL|CONDICIONES)\s*:?\s*', ''
        switch ($found[$i].Nombre) {
            'FUNCIONES' { $result.funciones = $segmento }
            'REQUISITOS' { $result.requisitos = $segmento }
            'BENEFICIOS' { $result.beneficios = $segmento }
        }
    }
    return $result
}

function Get-Items {
    param([string]$texto)
    if (-not $texto) { return @() }
    # sep par parrafo / li /bullets menos
    $raw = $texto -replace '\r',''
    $lines = $raw -split "`n"
    $items = @()
    foreach ($line in $lines) {
        $v = $line.Trim(' ', '-', '*', '.', ';', ':')
        if ($v -ne '' -and $v -match '[A-Za-z0-9]') { $items += ($v -replace '\s{2,}',' ') }
    }
    if ($items.Count -eq 0) {
        # unico parrafo: split por '. ' sin mayus mas `-`
        $parts = $texto -split '(?<=\.)\s+(?=[A-Za-z0-9¿*•·\-(])'
        foreach ($p in $parts) {
            $v = $p.Trim(' ', '-', '*', '.', ';')
            if ($v -ne '' -and $v -match '[A-Za-z0-9]') { $items += $v }
        }
    }
    $textoFinal = @()
    foreach ($v in $items) {
        $textoFinal += $v.Trim() -replace '\s{2,}', ' '
    }
    return $textoFinal | Select-Object -Unique
}

function Get-Experiencia {
    param([string]$texto)
    $mBase = $null
    if ($texto -match '(?i)experiencia[^\.\r\n]{0,50}?al menos\s*(\d+)') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)experiencia[^\.\r\n]{0,50}?por lo menos\s*(\d+)') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)m.?nima\s*de\s*(\d+)') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)m.?nimum\s*de\s*(\d+)') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)(\d+)\s*a[nñ]os?\s*de\s*experiencia') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)al menos\s*(\d+)') { $mBase = $matches[1] }
    elseif ($texto -match '(?i)(\d+)\s*a[nñ]os?\s*min') { $mBase = $matches[1] }
    if ($null -eq $mBase) { return '' }
    if ([int]$mBase -eq 1) { return 'Mínimo 1 año' }
    return "Mínimo $mBase años"
}

function Get-Estudios {
    param([string]$texto)
    if ($texto -match '(?i)Formaci[oóñ]n\s*[:\-]\s*([^\.\r\n]+)') { return $matches[1].Trim() }
    if ($texto -match '(?i)Estudios?\s*[:\-]\s*([^\.\r\n]+)') { return $matches[1].Trim() }
    if ($texto -match '(?i)Tener el t[iI]tulo de\s*([^\.\,\r\n]+)') { return ('Título de ' + $matches[1].Trim()) }
    if ($texto -match '(?i)t.?tulo\s+de\s*([^\.\,\r\n]+)') { return ('Título de ' + $matches[1].Trim()) }
    return ''
}

function Get-Herramientas {
    param([string]$texto)
    if ($texto -match '(?i)Herramientas\s*[:\-]\s*([^\.\r\n]+)') { return $matches[1].Trim() }
    if ($texto -match '(?i)Conocimientos?\s*[:\-]\s*([^\.\r\n]+)') { return $matches[1].Trim() }
    return ''
}

function Get-Horario {
    param([string]$texto)
    if ($texto -match '(?i)Horario\s*[:\-]\s*([^\r\n]+)') { return $matches[1].Trim() }
    return ''
}

function Get-Turno {
    param([string]$texto)
    if ($texto -match '(?i)TURNO\s*NOCHE') { return 'Noche' }
    if ($texto -match '(?i)turno\s*nocturno') { return 'Nocturno' }
    if ($texto -match '(?i)turno\s*rotativo') { return 'Rotativo' }
    if ($texto -match '(?i)horario\s*nocturno') { return 'Nocturno' }
    return ''
}

function Get-Jornada-Contrato {
    param([string]$texto)
    $j = ''; $c = ''
    if ($texto -match '(?i)full[\s-]*time') { $j = 'Full-time' }
    elseif ($texto -match '(?i)tiempo\s*completo') { $j = 'Full-time' }
    elseif ($texto -match '(?i)medio\s*tiempo') { $j = 'Medio tiempo' }
    if ($texto -match '(?i)indetermin') { $c = 'Indeterminado' }
    elseif ($texto -match '(?i)indefin') { $c = 'Indefinido' }
    elseif ($texto -match '(?i)\btempor') { $c = 'Temporal' }
    return @{ jornada=$j; contrato=$c }
}

function Get-Vacantes {
    param([string]$texto)
    if ($texto -match '(\d+)\s*vacantes?') { return $matches[1] }
    return ''
}

function Parse-Bumeran-Page {
    param([string]$html, [object]$ld)
    $info = @{
        area=''; jornada=''; contrato=''; nivel=''; vacantes=''; publicado='';
        experiencia=''; estudios=''; herramientas=''; turno=''; horario='';
        funciones=@(); requisitos=@(); beneficios=@(); modalidad=''; descripcionTxt=''
    }

    $ldHtml = ''
    if ($ld -and $ld.description) { $ldHtml = $ld.description }
    $info.descripcionTxt = Get-Text-Html $ldHtml

    $sec = Get-Secciones $info.descripcionTxt
    $info.funciones   = Get-Items $sec.funciones
    $info.requisitos  = Get-Items $sec.requisitos
    $info.beneficios  = Get-Items $sec.beneficios

    $todos = $info.descripcionTxt + ' | REQ: ' + ($info.requisitos -join ' | ') + ' | BEN: ' + ($info.beneficios -join ' | ')
    $info.experiencia  = Get-Experiencia $todos
    $info.estudios     = Get-Estudios $todos
    $info.herramientas = Get-Herramientas $todos
    $info.turno        = Get-Turno $info.descripcionTxt
    $info.horario      = Get-Horario $info.descripcionTxt
    $jc = Get-Jornada-Contrato $todos
    $info.jornada = $jc.jornada
    $info.contrato = $jc.contrato

    $i1 = $html.IndexOf('icon-light-cube')
    $i2 = $html.IndexOf('Publicado el', [Math]::Max(0,$i1+5))
    if ($i1 -ge 0 -and $i2 -gt $i1) {
        $chunk = $html.Substring($i1, $i2 - $i1)
        $pills = @()
        foreach ($m in [regex]::Matches($chunk, '(?is)<p\s+class="sc-VigVT[^"]*"[^>]*>(?<txt>[^<]+)</p>')) {
            $pills += ($m.Groups['txt'].Value -replace '\s+', ' ').Trim()
        }
        if ($pills.Count -ge 1) { $info.area = $pills[0] }
        if ($pills.Count -ge 2) {
            if ($pills[1] -match '(?i)(Full-time|Medio tiempo|Tiempo completo)') { $info.jornada = $matches[1] }
            if ($pills[1] -match '(?i)(Indeterminado|Temporal|Indefinido|Determinado)') { $info.contrato = $matches[1] }
        }
        if ($pills.Count -ge 3) { $info.nivel = $pills[2] }
        if ($pills.Count -ge 4) { $vac = Get-Vacantes $pills[3]; if ($vac -ne '') { $info.vacantes = $vac } }
    }

    $m2 = [regex]::Match($html, '(?is)Publicado\s+el\s*([0-9]{2}/[0-9]{2}/[0-9]{4})')
    if ($m2.Success) { $info.publicado = $m2.Groups[1].Value }

    if ($html -match '(?i)modalidad-presencial') { $info.modalidad = 'Presencial' }
    elseif ($html -match '(?i)modalidad-remoto') { $info.modalidad = 'Remoto' }
    elseif ($html -match '(?i)modalidad-hibrido') { $info.modalidad = 'Híbrido' }

    return [pscustomobject]$info
}
