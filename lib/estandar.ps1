# lib\estandar.ps1 - GLOSARIO y parsers de campos del blog (Fase A).
#
# Regla unica: TODA entrada nueva escribe los campos en sus formas CANONICAS.
# Si un valor no entiende el parser => 'No especificado' (unico fallback),
# salvo Jornada/Contrato/Modalidad donde el texto real se respeta (el parser
# solo normaliza los casos conocidos).
#
# Formas canonicas:
#   Salario   : 'S/ 1,800' | 'S/ 1,800 - S/ 2,200' | 'S/ 12 por hora' |
#               'No especificado' | 'A convenir' | 'Negociable'
#   Jornada   : 'Full-time' | 'Part-time' | 'Por horario' | 'Flexible' |
#               'No especificado' (+ texto libre corto si no esta en catalogo)
#   Contrato  : 'Indefinido' | 'Temporal' | 'Por proyecto' | 'Consultoria' |
#               'Freelance' | 'Practicas' | 'Voluntariado' | 'No especificado'
#               (+ texto libre corto)
#   Modalidad : 'Presencial' | 'Remoto' | 'Hibrido' | 'No especificado'
#   Vacantes  : '1'..'99' | 'No especificado'      (variantes: 01, Nro. de
#               vacantes, Cantidad de vacantes, 3 vacantes, totalJobOpenings)
#   Fechas    : 'dd/MM/yyyy' | 'No especificado'
#   Ubicacion : 'Ciudad, Region, Peru' | 'No especificado'
#   Categoria : las 7 canonicas de lib\categoria.ps1
#
# USO:
#   . .\lib\estandar.ps1
#   Est-Salario -Texto 'Entre S/ 1,800 y S/ 2,200 al mes'

. (Join-Path $PSScriptRoot 'salario.ps1')

function Est-Formato-Monto([double]$v) {
    return $v.ToString('N0', [Globalization.CultureInfo]::InvariantCulture)
}

function Est-Salario([string]$Texto, [double]$Min = -1, [double]$Max = -1, [switch]$PorHora) {
    # 1) rango explicito por montos ya conocidos (bumeran/privado)
    if ($Min -ge 0 -and $Max -ge 0 -and $Max -gt $Min) {
        $s = 'S/ ' + (Est-Formato-Monto $Min) + ' - S/ ' + (Est-Formato-Monto $Max)
        return $s
    }
    if ($Min -ge 0) { return ('S/ ' + (Est-Formato-Monto $Min)) }
    $txt = [string]$Texto
    if ([string]::IsNullOrWhiteSpace($txt)) { return 'No especificado' }
    $t = $txt.Trim()
    if ($t -match '(?i)no especificado') { return 'No especificado' }

    # 2) monto POR HORA (numeros cortos que otros patrones ignoran):
    #    'S/ 12 por hora', '15 soles la hora', '12/hora'
    $mHo = [regex]::Match($t, '(?i)(?:S/\s*\.?\s*)?(\d{1,3}(?:[.,]\d{3})*)\s*(?:soles\s*)?(?:por hora|la hora|/hora|cada hora)')
    if ($mHo.Success) {
        # parseo directo: Convertir-Monto descarta montos < 100 (rango mensual),
        # pero la tarifa por hora si puede ser 12, 15, 25...
        $vh = $null
        $vTxt = ($mHo.Groups[1].Value -replace '[^\d]', '')
        if ($vTxt -ne '') { [void][double]::TryParse($vTxt, [ref]$vh) }
        if ($null -ne $vh -and $vh -ge 10 -and $vh -le 999) {
            return ('S/ ' + (Est-Formato-Monto $vh) + ' por hora')
        }
    }

    # 3) rango explicito en el texto: 'S/ 1800 - S/ 2200', 'de S/ 1800 a S/ 2200',
    #    'entre S/ 1800 y S/ 2200', '1500 y 2000 soles'
    $mR = [regex]::Match($t, '(?i)S/\s*\.?\s*(\d[\d.,]{2,8})\s*(?:-|a|al|hasta|y)\s*S/\s*\.?\s*(\d[\d.,]{2,8})')
    if (-not $mR.Success) { $mR = [regex]::Match($t, '(?i)(\d[\d.,]{2,8})\s*(?:-|a|al|hasta|y)\s*(\d[\d.,]{2,8})\s*soles') }
    if ($mR.Success) {
        $mn = Convertir-Monto $mR.Groups[1].Value
        $mx = Convertir-Monto $mR.Groups[2].Value
        if ($null -ne $mn -and $null -ne $mx -and $mx -ge $mn) {
            return ('S/ ' + (Est-Formato-Monto $mn) + ' - S/ ' + (Est-Formato-Monto $mx))
        }
    }

    # 4) monto unico (patrones de lib\salario.ps1: 'S/ 1,450', '1800 soles',
    #    'sueldo: 1800', ...) y, si no, patron generico ('1,800', '1.450,00')
    $montos = @(Buscar-Montos $t)
    if ($montos.Count -eq 0) {
        $mG = [regex]::Match($t, '(?i)(?<!\d)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{3,6})(?!\d)')
        if ($mG.Success) {
            $vg = Convertir-Monto $mG.Groups[1].Value
            if ($null -ne $vg) { $montos = @(@{ v = $vg; txt = $mG.Value }) }
        }
    }
    if ($montos.Count -gt 0) {
        $v = [double]$montos[0].v
        $s = 'S/ ' + (Est-Formato-Monto $v)
        # contexto de hora en el texto del salario ('S/ 12 por hora', '/hora')
        $esHora = $PorHora.IsPresent
        if (-not $esHora -and $t -match '(?i).{0,40}(por hora|la hora|/hora|cada hora|hour).{0,20}') { $esHora = $true }
        if ($esHora) { $s = $s + ' por hora' }
        return $s
    }

    # 4) sin monto: catalogo cerrado de la fuente
    if ($t -match '(?i)a convenir') { return 'A convenir' }
    if ($t -match '(?i)negociable') { return 'Negociable' }
    # la fuente habla de salario pero sin monto interpretable
    if ($t -match '(?i)seg[uú]n convenio|seg[uú]n experiencia|competitiv|seg[uú]n perfil') { return 'A convenir' }
    return 'No especificado'
}

function Est-Jornada([string]$s) {
    $t = (Normalizar-Clave $s)
    if ($t -eq '' -or $t -match 'no espec') { return 'No especificado' }
    if ($t -match 'full[\s_-]*time|jornada completa|tiempo completo|completo') { return 'Full-time' }
    if ($t -match 'part[\s_-]*time|medio tiempo|parcial') { return 'Part-time' }
    if ($t -match 'por horario|horario flexible|flexible|turnos? rotativo') { return 'Por horario' }
    if ($t -match 'nocturno|noche') { return 'Nocturno' }
    if ($t -match 'diurno|manana') { return 'Diurno' }
    if ($s.Length -le 60) { return $s.Trim() }
    return 'No especificado'
}

function Est-Contrato([string]$s) {
    $t = (Normalizar-Clave $s)
    if ($t -eq '' -or $t -match 'no espec') { return 'No especificado' }
    if ($t -match 'indefinido|permanente|open[\s_]*ended') { return 'Indefinido' }
    if ($t -match 'temporal|temporary|determinado|eventual|por temporada') { return 'Temporal' }
    if ($t -match 'proyecto|obra') { return 'Por proyecto' }
    if ($t -match 'consultoria|consultor') { return 'Consultoría' }
    if ($t -match 'freelance|independiente|autonomo|honorarios') { return 'Freelance' }
    if ($t -match 'practica|pasantia|pre[\s_]*profesional|practicante|intern') { return 'Prácticas' }
    if ($t -match 'voluntar') { return 'Voluntariado' }
    if ($t -match 'contract') { return 'Por contrato' }
    if ($t -match 'locacion de servicios') { return 'Locación de servicios' }
    # FULL_TIME/PART_TIME son JORNADA, no contrato (bug conocido)
    if ($t -match 'full[\s_]*time|part[\s_]*time') { return 'No especificado' }
    if ($s.Length -le 60) { return $s.Trim() }
    return 'No especificado'
}

function Est-Modalidad([string]$s) {
    $t = (Normalizar-Clave $s)
    if ($t -eq '' -or $t -match 'no espec') { return 'No especificado' }
    if ($t -match 'remoto|teletrabajo|home office|remote|telecommute') { return 'Remoto' }
    if ($t -match 'hibrido') { return 'Híbrido' }
    if ($t -match 'presencial|on site|onsite|oficina') { return 'Presencial' }
    if ($s.Length -le 60) { return $s.Trim() }
    return 'No especificado'
}

function Est-Vacantes([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return 'No especificado' }
    $t = $s.Trim()
    if ($t -match '(?i)no especificado') { return 'No especificado' }
    # 'Nro. de vacantes: 3', 'Cantidad de vacantes 3', '01', '3 vacantes', '3'
    $m = [regex]::Match($t, '(?<!\d)(\d{1,3})(?!\d)')
    if ($m.Success) {
        $n = 0
        if ([int]::TryParse($m.Groups[1].Value, [ref]$n) -and $n -ge 1 -and $n -le 99) { return [string]$n }
    }
    return 'No especificado'
}

function Est-Fecha([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return 'No especificado' }
    $t = $s.Trim()
    if ($t -match '(?i)no especificado') { return 'No especificado' }
    if ($t -match '^(\d{2})/(\d{2})/(\d{4})$') { return $t }
    foreach ($fmt in @('yyyy-MM-dd', 'yyyy-MM-ddTHH:mm:ss', 'dd-MM-yyyy')) {
        try {
            $d = [datetime]::ParseExact($t.Substring(0, [Math]::Min($t.Length, $fmt.Length)), $fmt, [Globalization.CultureInfo]::InvariantCulture)
            return $d.ToString('dd/MM/yyyy')
        } catch { }
    }
    try {
        $d = [datetime]::Parse($t, [Globalization.CultureInfo]::InvariantCulture)
        return $d.ToString('dd/MM/yyyy')
    } catch { }
    if ($t -match '^\d{2}/\d{2}/\d{4}') { return $Matches[0] }
    return 'No especificado'
}

function Est-Ubicacion([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return 'No especificado' }
    $t = ($s -replace '\s+', ' ').Trim()
    if ($t -match '(?i)no especificado') { return 'No especificado' }
    $t = $t.TrimEnd(',', ' ')
    if ($t -notmatch '(?i),\s*per[uú]$') { $t = $t + ', Perú' }
    return $t
}

function Est-Ciudad([string]$ubi) {
    if ([string]::IsNullOrWhiteSpace($ubi)) { return 'No especificado' }
    $t = ($ubi -replace '\s+', ' ').Trim()
    if ($t -match '(?i)no especificado') { return 'No especificado' }
    $p = ($t -split ',')[0].Trim()
    if ($p -eq '') { return 'No especificado' }
    return $p
}

# ------------------------------------------------------------------ seccion nueva
function Est-Porque([hashtable]$c, [int]$Semilla = 0) {
    # bullets de '¿Por qué postular?' construidos SOLO con datos reales ya
    # extraidos (nunca inventa): modalidad, ubicacion, salario, contrato,
    # jornada, experiencia, beneficios, empresa/sector.
    $b = New-Object System.Collections.Generic.List[string]
    $rot = [Math]::Abs([int]$Semilla)
    function Pk([string[]]$v) { return $v[$script:rotIdx++ % $v.Count] }
    $script:rotIdx = $rot

    $m = [string]$c['modalidad']
    if ($m -ne '' -and $m -ne 'No especificado') {
        $v = @("Modalidad ${m}: el puesto se ejerce de esa forma.",
               "La vacante es $m, según la publicación.")
        $b.Add((Pk $v))
    }
    $u = [string]$c['ubicacion']
    if ($u -ne '' -and $u -ne 'No especificado') {
        $uCorta = ($u -replace ',\s*Perú$', '')
        $v = @("Ubicación: $uCorta.",
               "Se desarrolla en $uCorta.")
        $b.Add((Pk $v))
    }
    $s = [string]$c['salario']
    if ($s -ne '' -and $s -ne 'No especificado') {
        $v = @("Remuneración $s según la publicación.",
               "Ofrecen $s de remuneración.")
        $b.Add((Pk $v))
    }
    $ct = [string]$c['contrato']; $jn = [string]$c['jornada']
    $det = @()
    if ($ct -ne '' -and $ct -ne 'No especificado') { $det += "contrato $ct" }
    if ($jn -ne '' -and $jn -ne 'No especificado') { $det += "jornada $jn" }
    if ($det.Count -gt 0) { $b.Add(("Condiciones: " + ($det -join ' y ') + '.')) }

    $ex = [string]$c['experiencia']
    if ($ex -ne '' -and $ex -ne 'No especificado' -and $ex.Length -le 120) {
        $b.Add("Se pide $ex de experiencia.")
    }
    $ben = @($c['beneficios'] | Where-Object { $_ -and $_ -ne 'No especificado' })
    if ($ben.Count -gt 0) {
        $v = @("La empresa ofrece: " + [string]$ben[0].TrimEnd('.') + '.',
               "Entre los beneficios: " + [string]$ben[0].TrimEnd('.') + '.')
        $b.Add((Pk $v))
    }
    $emp = [string]$c['empresa']; $sec = [string]$c['sector']
    if ($emp -ne '' -and $emp -ne 'No especificado' -and $emp -ne 'No especificada') {
        if ($sec -ne '' -and $sec -ne 'No especificado' -and $sec.Length -le 60) {
            $b.Add("La contratación es con $emp, del sector $sec.")
        } else {
            $b.Add("La vacante es con $emp.")
        }
    }
    if ($b.Count -lt 2) {
        $tt = [string]$c['titulo']
        $cc = [string]$c['ciudad']
        if ($cc -ne '' -and $cc -ne 'No especificado') { $b.Add("Vacante de $tt en $cc.") }
        else { $b.Add("Vacante de $tt publicada en el portal.") }
        $b.Add("La oferta está activa; revisa los requisitos antes de postular.")
    }
    # recorte: maximo 4 bullets, cada uno corto y sin 'No especificado'
    $sal = New-Object System.Collections.Generic.List[string]
    foreach ($x in $b) {
        if ($sal.Count -ge 4) { break }
        $t = ([string]$x -replace '\s+', ' ').Trim()
        if ($t -eq '' -or $t -match '(?i)no especificado') { continue }
        if ($t.Length -gt 180) { $t = $t.Substring(0, 177).TrimEnd(' ', ',') + '...' }
        $sal.Add($t)
    }
    return $sal
}
