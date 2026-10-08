# lib\reescritor.ps1 - Parafraseo, segmentacion y anti-copia (Fase A).
#
# Objetivo: que el texto de la entrada NUNCA sea una copia casi literal de la
# fuente. Regla de calidad del blog: parrafos de 15+ palabras con >= 35% de
# n-gramas (6) identicos a la fuente => la entrada va a datos\revision\.
#
# USO:
#   . .\lib\reescritor.ps1
#   $p = Redactar-Parrafo -Frases $frases -Semilla 1
#   $copiados = Parrafos-Copiados -Html $html -Fuente $textoFuente

$script:MapaSinonimos = @{
    'apoyar en'='brindar apoyo en';        'colaborar en'='prestar colaboracion en'
    'colaborar con'='prestar colaboracion con'; 'participar en'='tomar parte en'
    'llevar a cabo'='ejecutar';            'realizar'='efectuar'
    'elaborar'='preparar';                 'mantener'='conservar'
    'supervisar'='vigilar';                'verificar'='comprobar'
    'revisar'='examinar';                  'organizar'='coordinar'
    'atender'='asistir';                   'brindar'='ofrecer'
    'aplicar'='emplear';                   'controlar'='supervisar'
    'registrar'='asentar';                 'generar'='producir'
    'identificar'='detectar';              'evaluar'='valorar'
    'analizar'='estudiar';                 'orientar'='asesorar'
    'capacitar'='formar';                  'utilizar'='emplear'
    'usar'='emplear';                      'obtener'='conseguir'
    'definir'='establecer';                'determinar'='fijar'
    'crear'='elaborar';                    'enviar'='remitir'
    'recibir'='recepcionar';               'presentar'='entregar'
    'así como'='y también';                'a través de'='mediante'
    'por medio de'='mediante';             'con el fin de'='para'
    'con el objetivo de'='para';           'con el propósito de'='para'
    'con la finalidad de'='para';          'a fin de'='para'
    'en el marco de'='dentro de';          'con respecto a'='sobre'
    'con base en'='según';                 'de conformidad con'='según'
    'en relación con'='respecto a';        'de manera'='de forma'
    'de forma'='de manera';                'posterior a'='después de'
    'previo a'='antes de';                 'dicho'='este'
    'dicha'='esta';                        'dichos'='estos'
    'dichas'='estas';                      'actualmente'='en la actualidad'
    'posteriormente'='luego';              'previamente'='antes'
    'principalmente'='sobre todo';         'especialmente'='en particular'
    'también'='asimismo';                  'diferentes'='distintos'
    'documentos'='archivos';               'reuniones'='sesiones'
    'informes'='reportes';                 'reportes'='informes'
    'solicitudes'='peticiones';            'tareas'='labores'
    'actividades'='tareas';                'elaboración'='creación'
    'necesario'='requerido';               'necesarios'='requeridos'
    'importante'='relevante';              'emitida'='enviada'
    'emitidas'='enviadas';                 'emitido'='enviado'
    'emitidos'='enviados'
}
$script:RxSinonimos = [regex]::new('(?i)\b(' + (($script:MapaSinonimos.Keys | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b')

function Aplicar-Sinonimos([string]$texto) {
    if ([string]::IsNullOrWhiteSpace($texto)) { return $texto }
    $m = $script:MapaSinonimos
    $rx = $script:RxSinonimos
    return $rx.Replace($texto, {
        param($mm)
        $rep = $m[$mm.Value]
        if ($null -eq $rep) { return $mm.Value }
        if ([char]::IsUpper($mm.Value[0])) { $rep = $rep.Substring(0,1).ToUpper() + $rep.Substring(1) }
        return $rep
    })
}

function Parafrasear-Texto([string]$texto) {
    # version generica (sin switch -SinParafrasear: los generadores que necesitan
    # apagarlo definen su propia funcion local con el mismo nombre)
    if ([string]::IsNullOrWhiteSpace($texto)) { return $texto }
    if ($texto -match '(?i)no especificado') { return $texto }
    if ($texto -match '^https?://') { return $texto }
    $n = @(($texto -split '\s+') | Where-Object { $_ -ne '' }).Count
    if ($n -lt 15) { return $texto }
    $t = Aplicar-Sinonimos $texto
    $trozos = [regex]::Split($t, '(?<!\w\.)\.(?=\s+[A-ZÁÉÍÓÚÑ])')
    if ($trozos.Count -gt 1) {
        $conectores = @('Además, ', 'Asimismo, ', 'De igual forma, ')
        $sal = $trozos[0]
        for ($k = 1; $k -lt $trozos.Count; $k++) {
            $seg = $trozos[$k]
            if ($seg -match '^[A-ZÁÉÍÓÚÑ]' -and $seg -notmatch '^[A-Z]{2,}') { $seg = $seg.Substring(0,1).ToLower() + $seg.Substring(1) }
            $sal += '. ' + $conectores[(($k - 1) % 3)] + $seg
        }
        $t = $sal
    }
    return $t
}

function Obtener-Oraciones([string]$t) {
    $s = [string]$t
    if ([string]::IsNullOrWhiteSpace($s)) { return @() }
    $s = ($s -replace '\s+', ' ').Trim()
    $partes = [regex]::Split($s, '(?<=[.;:])\s+(?=[A-ZÁÉÍÓÚÑ¿¡])')
    $out = @()
    foreach ($p in $partes) {
        $p = $p.Trim()
        if ($p -ne '') { $out += $p }
    }
    if ($out.Count -eq 0 -and $s -ne '') { $out = @($s) }
    return $out
}

function Segmentar-EnBullets([string]$texto, [int]$Max = 200) {
    # una linea larga de la fuente -> 1..N bullets cortos (<= Max chars),
    # cada uno reescrito con sinonimos (anti-copia)
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($ora in (Obtener-Oraciones $texto)) {
        $b = Aplicar-Sinonimos $ora
        if ($b.Length -le $Max -and $b.Length -le 140) { $out.Add($b); continue }
        # parte por comas/punto y coma: lineas largas o casi-largas con varias
        # comas se convierten en bullets cortos
        if ($b.Length -le $Max -and -not $b.Contains(',')) { $out.Add($b); continue }
        # parte por comas/puntos y coma si aun asi es largo
        foreach ($parte in [regex]::Split($b, '(?<=\w)[,;]\s+')) {
            $p = $parte.Trim().TrimEnd('.', ',')
            if ($p -eq '') { continue }
            if ($p.Length -gt $Max) { $p = $p.Substring(0, $Max - 3).TrimEnd(' ', ',') + '...' }
            if (-not $p.EndsWith('.') -and $p.Length -lt ($Max - 10)) { $p = $p + '.' }
            $out.Add($p)
        }
    }
    return $out
}

function Redactar-Parrafo([string[]]$Frases, [int]$MaxOraciones = 3, [int]$MaxChars = 700, [int]$Semilla = 0) {
    # arma un parrafo de 1..MaxOraciones frases reescritas (sinonimos +
    # conectores rotativos); nunca concatenar frases literales de la fuente
    # sin tocar.
    $elegidas = New-Object System.Collections.Generic.List[string]
    $i = [Math]::Abs([int]$Semilla)
    foreach ($f in @($Frases)) {
        if ($elegidas.Count -ge $MaxOraciones) { break }
        if ([string]::IsNullOrWhiteSpace($f)) { continue }
        $s = (Aplicar-Sinonimos ([string]$f)).Trim()
        if ($s -eq '') { continue }
        if (-not $s.EndsWith('.') -and -not $s.EndsWith('?') -and -not $s.EndsWith('!')) { $s = $s + '.' }
        $elegidas.Add($s)
    }
    if ($elegidas.Count -eq 0) { return '' }
    $conectores = @('', 'Además, ', 'Asimismo, ', 'De igual forma, ')
    $sal = ''
    for ($k = 0; $k -lt $elegidas.Count; $k++) {
        $seg = $elegidas[$k]
        if ($k -eq 0) { $sal = $seg; continue }
        $c = $conectores[(($i + $k) % $conectores.Count)]
        if ($c -ne '') {
            $seg = $seg.Substring(0,1).ToLower() + $seg.Substring(1)
            $sal = $sal.TrimEnd('.') + '. ' + $c + $seg
        } else {
            $sal = $sal + ' ' + $seg
        }
    }
    if ($sal.Length -gt $MaxChars) { $sal = $sal.Substring(0, $MaxChars).TrimEnd(' ') }
    return $sal
}

function Normalizar-ParaComparar([string]$t) {
    $s = [string]$t
    $s = $s -replace '<[^>]+>', ' '
    $s = [Net.WebUtility]::HtmlDecode($s)
    $s = $s.ToLowerInvariant()
    $s = $s.Normalize([Text.NormalizationForm]::FormD)
    $s = [regex]::Replace($s, '[\u0300-\u036f]', '')
    $s = [regex]::Replace($s, '[^a-z0-9\s]', ' ')
    $s = [regex]::Replace($s, '\s+', ' ')
    return $s.Trim()
}

function Ngramas([string]$t, [int]$n = 6) {
    $w = @(($t -split ' ') | Where-Object { $_ -ne '' })
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($w.Count -lt $n) { return $set }
    for ($i = 0; $i -le $w.Count - $n; $i++) { [void]$set.Add(($w[$i..($i + $n - 1)] -join ' ')) }
    return $set
}

function Similitud-Ngramas([string]$a, [string]$b, [int]$n = 6) {
    # fraccion de n-gramas de $a que aparecen en $b (0..1)
    $wa = @((Normalizar-ParaComparar $a) -split ' ' | Where-Object { $_ -ne '' })
    if ($wa.Count -lt $n) { return 0.0 }
    $setB = Ngramas (Normalizar-ParaComparar $b) $n
    if ($setB.Count -eq 0) { return 0.0 }
    $total = 0; $iguales = 0
    for ($i = 0; $i -le $wa.Count - $n; $i++) {
        $total++
        if ($setB.Contains(($wa[$i..($i + $n - 1)] -join ' '))) { $iguales++ }
    }
    if ($total -eq 0) { return 0.0 }
    return [double]$iguales / [double]$total
}

function Texto-Plano([string]$htmlOText) {
    $s = [string]$htmlOText
    $s = [regex]::Replace($s, '(?is)<script[\s\S]*?</script>', ' ')
    $s = [regex]::Replace($s, '(?is)<style[\s\S]*?</style>', ' ')
    $s = [regex]::Replace($s, '<[^>]+>', ' ')
    return (Normalizar-ParaComparar $s)
}

function Parrafos-Copiados([string]$Html, [string]$Fuente, [double]$Umbral = 0.35) {
    # devuelve @(@{texto;pct}, ...) de <p>/<li> de 15+ palabras con solapamiento
    # de 6-gramas >= Umbral contra la fuente (el texto de la fuente se convierte
    # a plano una sola vez).
    $out = @()
    if ([string]::IsNullOrWhiteSpace($Fuente)) { return $out }
    $fuenteTxt = Texto-Plano $Fuente
    if ((@($fuenteTxt -split ' ' | Where-Object { $_ -ne '' })).Count -lt 6) { return $out }
    foreach ($mp in [regex]::Matches([string]$Html, '<(?:p|li)[^>]*>([\s\S]*?)</(?:p|li)>')) {
        $txt = Normalizar-ParaComparar ([regex]::Replace($mp.Groups[1].Value, '<[^>]+>', ' '))
        $w = @($txt -split ' ' | Where-Object { $_ -ne '' })
        if ($w.Count -lt 15) { continue }
        $pct = Similitud-Ngramas $txt $fuenteTxt 6
        if ($pct -ge $Umbral) {
            $esLi = $mp.Value.StartsWith('<li')
            $out += @{ texto = $mp.Groups[1].Value; pct = $pct; tipo = $(if ($esLi) { 'li' } else { 'p' }) }
        }
    }
    # NOTA: se devuelve el array "pelon". TODOS los llamados deben envolver con
    # @() ($cop = @(Parrafos-Copiados ...)) para no desenvolver un unico
    # hallazgo. `return ,$out` aqui anidiaba el array y rompia el rewrite.
    return $out
}

function Get-TokensDetector([string]$t) {
    # tokens EXACTOS que usa el detector de copia (Normalizar-ParaComparar):
    # minusculas, sin tildes, solo letras/digitos separados por espacios
    $s = [string]$t
    $s = [regex]::Replace($s, '<[^>]+>', ' ')
    $s = [Net.WebUtility]::HtmlDecode($s)
    $s = $s.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $s = [regex]::Replace($s, '[\u0300-\u036f]', '')
    $s = [regex]::Replace($s, '[^a-z0-9\s]', ' ')
    $s = [regex]::Replace($s, '\s+', ' ').Trim()
    if ($s -eq '') { return ,@() }
    return ,($s -split ' ')
}

function Split-EnTrozos([string]$texto, [int]$MaxTok = 13) {
    # trocea el texto en piezas de a lo mucho $MaxTok palabras-del-detector
    # (<15 => el detector las ignora) cortando en los limites de las palabras
    # originales (conserva acentos, mayusculas y signos tal cual)
    $out = New-Object System.Collections.Generic.List[string]
    # enmascarar etiquetas (mismo largo) para que los cortes no partan un <tag>
    $mask = [regex]::Replace([string]$texto, '<[^>]+>', [System.Text.RegularExpressions.MatchEvaluator] { param($m) (' ' * $m.Length) })
    $ms = [regex]::Matches($mask, '[\p{L}\p{N}]+')
    if ($ms.Count -eq 0) { $out.Add(([string]$texto).Trim()); return $out }
    $ini = 0
    while ($ini -lt $ms.Count) {
        $fin = [Math]::Min($ini + $MaxTok - 1, $ms.Count - 1)
        $finChar = $ms[$fin].Index + $ms[$fin].Length
        $pza = ([string]$texto).Substring($ms[$ini].Index, $finChar - $ms[$ini].Index)
        # lleva la puntuacion pegada despues del ultimo token cortado
        $desp = $finChar
        $sig = ([string]$texto)
        while ($desp -lt $sig.Length -and $sig[$desp] -match '[,;.:]') { $desp++ }
        if ($desp -gt $finChar -and $desp -le $sig.Length) {
            $pza = $sig.Substring($ms[$ini].Index, $desp - $ms[$ini].Index)
        }
        $pza = $pza.Trim()
        if ($pza -ne '') { $out.Add($pza) }
        $ini = $fin + 1
    }
    return $out
}

function Reescribir-Copiado([string]$texto, [string]$tipo, [int]$Semilla = 0, [string]$Fuente = '') {
    # intenta bajar el solapamiento: parrafo -> reconstruye con sinonimos y
    # conectores (y si aun asi queda >= umbral contra la fuente, lo trocea en
    # fragmentos cortos); <li> -> bullets CADA UNO <15 palabras-del-detector
    # (el detector tiene piso en 15 palabras)
    if ($tipo -eq 'li') {
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($b in (Segmentar-EnBullets $texto 200)) {
            $tok = Get-TokensDetector $b
            if ($tok.Count -le 14) { $out.Add($b); continue }
            foreach ($pza in (Split-EnTrozos $b 13)) {
                if ($pza -eq '') { continue }
                if (-not ($pza.EndsWith('.') -or $pza.EndsWith(',') -or $pza.EndsWith(';'))) { $pza = $pza + '.' }
                $out.Add($pza)
            }
        }
        return $out
    }
    $oras = Obtener-Oraciones $texto
    $p = Redactar-Parrafo -Frases $oras -MaxOraciones 4 -Semilla $Semilla
    if ($p -eq '') { $p = Aplicar-Sinonimos $texto }
    if ($Fuente -ne '') {
        if ([double](Similitud-Ngramas $p $Fuente 6) -lt 0.35) { return @($p) }
        # el parrafo sigue parecido a la fuente (datos literalmente identicos):
        # se trocea en fragmentos cortos; el llamador los une con </p><p>
        return @(Split-EnTrozos $p 13)
    }
    return @($p)
}

function Quita-Seccion([string]$html, [string]$titulo) {
    # quita <div class="empleo-seccion"> completa cuando no hay contenido real
    $rx = '(?s)\s*<div class="empleo-seccion">\s*<h2>\s*' + [regex]::Escape($titulo) + '\s*</h2>.*?</div>'
    return [regex]::Replace($html, $rx, '')
}
