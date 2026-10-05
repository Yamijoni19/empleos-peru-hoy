$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$salida = Join-Path $raiz "salida"
$limite = 0
if ($env:ACENTUAR_LIMITE) { $limite = [int]$env:ACENTUAR_LIMITE }

$rxCion = [regex]'(?i)\b([a-z]+)(cion|sion|gion)\b'
$rxScript = [regex]'(?s)<script.*?</script>'
$rxPartes = [regex]'(?s)<[^>]*>|[^<]+'
$rxMarca = [regex](([char]1) + '(\d+)' + ([char]1))

$palabras = @("ademas","tambien","dia","dias","ultimo","ultima","ultimos","ultimas","numero","numeros","area","areas","unico","unica","unicos","unicas","economico","economica","economicos","tecnica","tecnicas","tecnico","tecnicos","academica","academicas","academico","academicos","garantia","garantias","informatica","informaticas","basica","basicas","basico","basicos","publicos","publicas")
$traducciones = @{
    "ademas"="además"; "tambien"="también"; "dia"="día"; "dias"="días";
    "ultimo"="último"; "ultima"="última"; "ultimos"="últimos"; "ultimas"="últimas";
    "numero"="número"; "numeros"="números"; "area"="área"; "areas"="áreas";
    "unico"="único"; "unica"="única"; "unicos"="únicos"; "unicas"="únicas";
    "economico"="económico"; "economica"="económica"; "economicos"="económicos";
    "tecnica"="técnica"; "tecnicas"="técnicas"; "tecnico"="técnico"; "tecnicos"="técnicos";
    "academica"="académica"; "academicas"="académicas"; "academico"="académico"; "academicos"="académicos";
    "garantia"="garantía"; "garantias"="garantías";
    "informatica"="informática"; "informaticas"="informáticas";
    "basica"="básica"; "basicas"="básicas"; "basico"="básico"; "basicos"="básicos";
    "publicos"="públicos"; "publicas"="públicas"
}
$pares = New-Object System.Collections.ArrayList
foreach ($w in $palabras) {
    $v = $traducciones[$w]
    $cap = [char]([int][char]$v[0] - 32) + $v.Substring(1)
    [void]$pares.Add(@($w, $v))
    [void]$pares.Add(@($w.Substring(0,1).ToUpper() + $w.Substring(1), $cap))
    [void]$pares.Add(@($w.ToUpper(), $v.ToUpper()))
}

$evaluador = {
    param($m)
    $base = $m.Groups[1].Value
    $suf = $m.Groups[2].Value
    switch -Regex ($suf) {
        '(?i)^cion$' { $s = 'ción'; break }
        '(?i)^sion$' { $s = 'sión'; break }
        '(?i)^gion$' { $s = 'gión'; break }
    }
    if ($m.Value -cnotmatch '[a-z]') { $s = $s.ToUpper() }
    $base + $s
}

$ErrorActionPreference = 'Stop'
$cambiados = 0
$totales = 0
$marcador = [char]1
if ($limite -gt 0) { $lista = @(Get-ChildItem (Join-Path $salida "*-entrada.html") | Select-Object -First $limite) } else { $lista = @(Get-ChildItem (Join-Path $salida "*-entrada.html")) }
foreach ($f in $lista) {
    $totales++
    $c = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    if ($c -notmatch 'cion|sion|gion|ademas|tambien|dias|ultimo|numero|area|tecnico|academica') { continue }
    $scripts = New-Object System.Collections.ArrayList
    $c2 = $rxScript.Replace($c, {
        param($m)
        $idx = $scripts.Add($m.Value)
        ([char]1).ToString() + "$idx" + ([char]1).ToString()
    })
    $partes = $rxPartes.Matches($c2)
    $sb = New-Object System.Text.StringBuilder
    foreach ($p in $partes) {
        if ($p.Value[0] -eq '<') { [void]$sb.Append($p.Value) }
        else {
            $t = $rxCion.Replace($p.Value, $evaluador)
            foreach ($par in $pares) { $t = $t.Replace($par[0], $par[1]) }
            [void]$sb.Append($t)
        }
    }
    $c3 = $sb.ToString()
    if ($scripts.Count -gt 0) {
        $c3 = $rxMarca.Replace($c3, {
            param($m)
            $scripts[[int]$m.Groups[1].Value]
        })
    }
    if ($c3 -cne $c) {
        [IO.File]::WriteAllText($f.FullName, $c3, (New-Object Text.UTF8Encoding($false)))
        $cambiados++
    }
}
Write-Output "archivos procesados: $totales | corregidos: $cambiados"
