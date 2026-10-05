$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$salida = Join-Path $raiz "salida"
$fixBoton = 0
$sinUrl = 0
$fixSalario = 0
$accion = 0
$ejemploBtn = ""

foreach ($f in (Get-ChildItem (Join-Path $salida "*-entrada.html"))) {
    $c = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $orig = $c

    $tag = '<a class="empleo-boton" href=""'
    $i = $c.IndexOf($tag)
    if ($i -ge 0) {
        $busca = $c.Substring([Math]::Max(0, $i - 900), [Math]::Min(900, $i))
        $ultima = -1
        $pos = 0
        while ($true) {
            $p = $busca.IndexOf("http", $pos)
            if ($p -lt 0) { break }
            $ultima = $p
            $pos = $p + 4
        }
        if ($ultima -ge 0) {
            $j = $ultima
            while ($j -lt $busca.Length -and ($busca[$j] -match '[^\s"''<>]')) { $j++ }
            $url = $busca.Substring($ultima, $j - $ultima)
            $c = $c.Replace($tag, ('<a class="empleo-boton" href="' + $url + '"'))
            $fixBoton++
            if ($ejemploBtn -eq "") { $ejemploBtn = $f.Name + " -> " + $url }
        } else {
            $sinUrl++
        }
    }

    $c2 = $c -replace 'S/\s*10000(?!\d)', 'S/ 10,000.00'
    if ($c2 -ne $c) { $fixSalario++; $c = $c2 }

    $m = [regex]::Matches($c, '(?i)\b[a-z]+cion\b')
    if ($m.Count -ge 3) { $accion++ }

    if ($c -ne $orig) {
        [IO.File]::WriteAllText($f.FullName, $c, (New-Object Text.UTF8Encoding($false)))
    }
}

Write-Output "boton href rellenado: $fixBoton | boton sin url en archivo: $sinUrl | salario 10000 formateado: $fixSalario | archivos con palabras -cion sin tilde (>=3): $accion"
Write-Output "ejemplo boton: $ejemploBtn"
