param(
  [switch]$Aplicar
)

$ErrorActionPreference = "Stop"
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$salida = Join-Path $raiz "salida"
$fuentesDir = Join-Path $raiz "fuentes"
$reporte = Join-Path $raiz "reporte"
if(-not (Test-Path $reporte)){ New-Item -ItemType Directory -Path $reporte | Out-Null }

$fecha = Get-Date -Format "yyyy-MM-dd"
$logPath = Join-Path $reporte "reparar-salarios-$fecha.txt"
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

function Obtener-Valor {
  param([string]$raw)
  if(-not $raw){ return $null }
  if($raw -match '(?i)no especifica'){ return @{tipo="noespec"} }
  if($raw -notmatch 'S/'){ return $null }
  if($raw -match '(?i)millones|billones'){ return $null }
  $num = ($raw -replace 'S/','' -replace '[^\d.,]','').Trim()
  if(-not ($num -match '^[\d.,]+$')){ return $null }
  if($num -match '^\d{1,3}(,\d{3})+(\.\d{1,2})?$'){
    $v = [double]($num -replace ',','')
  }elseif($num -match '^\d{1,3}(\.\d{3})+,\d{1,2}$'){
    $v = [double]($num -replace '\.','' -replace ',','.')
  }elseif($num -match '^\d{1,3}(,\d{3})+$'){
    $v = [double]($num -replace ',','')
  }elseif($num -match '^\d+(,\d{1,2})$'){
    $v = [double]($num -replace ',','.')
  }elseif($num -match '^\d+$'){
    $v = [double]$num
  }else{
    return $null
  }
  if($v -ge 500 -and $v -le 50000){
    return @{tipo="valor"; v=$v; txt=("S/ " + $num)}
  }
  return $null
}

function Extraer-Salario {
  param([string]$html)
  $p1 = [regex]::Match($html, '(?is)(S/\s*[\d.,]+|No especifica[a-z]*)\s*(?:<[^>]+>\s*)*<span>\s*Remuneraci')
  if($p1.Success){
    $raw = $p1.Groups[1].Value
    if($raw -match '(?i)no especifica'){ return @{tipo="noespec"; pat="p1"} }
    $o = Obtener-Valor $raw
    if($o){ return ($o + @{pat="p1"; raw=$raw}) }
    return @{tipo="revisar"; pat="p1"; raw=$raw}
  }
  $p2 = [regex]::Match($html, '(?is)Remuneraci[óo]n:\s*(?:<[^>]+>\s*)*(S/\s*[\d.,]+|No especifica[a-z]*)')
  if($p2.Success){
    $raw = $p2.Groups[1].Value
    if($raw -match '(?i)no especifica'){ return @{tipo="noespec"; pat="p2"} }
    $o = Obtener-Valor $raw
    if($o){ return ($o + @{pat="p2"; raw=$raw}) }
    return @{tipo="revisar"; pat="p2"; raw=$raw}
  }
  $txt = $html -replace '(?is)<script[\s\S]*?</script>',' ' -replace '<style[\s\S]*?</style>',' ' -replace '<[^>]+>',' ' -replace '&nbsp;',' ' -replace '\s+',' '
  $pats = @(
    '(?i)(remuneraci[óo]n|salario|sueldo|haberes)[^.]{0,70}?(S/\s*[\d.,]{3,})',
    '(?i)(S/\s*[\d.,]{3,})[^.]{0,70}?(remuneraci[óo]n|salario|sueldo)',
    '(?i)(S/\s*[\d.,]{3,})\s*(mensuales?|al mes)'
  )
  foreach($p in $pats){
    $m = [regex]::Match($txt, $p)
    if($m.Success){
      $cand = $null
      foreach($g in $m.Groups){
        if($g.Value -match 'S/'){ $cand = $g.Value; break }
      }
      if(-not $cand){ continue }
      $o = Obtener-Valor $cand
      if($o){ return ($o + @{pat="txt"}) }
      return @{tipo="revisar"; pat="txt"; raw=$cand}
    }
  }
  if($txt -match '(?i)(no especifica[^\w]{0,40}remuneraci|remuneraci[^\w]{0,40}no especifica)'){
    return @{tipo="noespec"; pat="txt"}
  }
  return $null
}

function Buscar-Fuentes {
  param([string]$nombreEntrada)
  $base = $nombreEntrada -replace '-entrada\.html$',''
  $exacto = Get-ChildItem (Join-Path $fuentesDir "*.txt") | Where-Object { $_.BaseName -eq $base }
  if($exacto.Count -eq 1){ return $exacto[0].FullName }
  if($base -match '-([a-f0-9]{4})$'){
    $hash = $Matches[1]
    $c = Get-ChildItem (Join-Path $fuentesDir "*.txt") | Where-Object { $_.BaseName -like "*-$hash" }
    if($c.Count -eq 1){ return $c[0].FullName }
  }
  $c2 = Get-ChildItem (Join-Path $fuentesDir "*.txt") | Where-Object { $_.BaseName -like "$base*" }
  if($c2.Count -eq 1){ return $c2[0].FullName }
  $pref = $base.Substring(0, [Math]::Min(50, $base.Length))
  $c3 = Get-ChildItem (Join-Path $fuentesDir "*.txt") | Where-Object { $_.BaseName -like "$pref*" }
  if($c3.Count -eq 1){ return $c3[0].FullName }
  return $null
}

function Obtener-Pagina {
  param([string]$url, [bool]$esCdt)
  for($i=1; $i -le 3; $i++){
    try{
      $r = Invoke-WebRequest -Uri $url -UserAgent $ua -TimeoutSec 40 -UseBasicParsing -MaximumRedirection 6
      $c = [string]$r.Content
      if($c.Length -lt 3000){ Start-Sleep -Milliseconds 1500; continue }
      if($esCdt -and $c -notmatch '(?i)remuneraci'){ Start-Sleep -Milliseconds 1500; continue }
      return $c
    }catch{
      Start-Sleep -Milliseconds (1000 * $i)
    }
  }
  return $null
}

$archivos = Get-ChildItem (Join-Path $salida "*-entrada.html") | Where-Object {
  $t = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  $t -match '(?s)<strong>Salario:</strong>\s*S/ ?10[.,]?000\b'
}

$lineas = @()
$lineas += "=== Reparar salarios 10000 v2 - $fecha - archivos: $($archivos.Count) - aplicar=$Aplicar ==="
$stats = @{igual=0; valor=0; noespec=0; nofetch=0; revisar=0}

foreach($f in $archivos){
  $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)

  $urls = @()
  $fPath = Buscar-Fuentes $f.Name
  if($fPath){
    $ftxt = [IO.File]::ReadAllText($fPath, [Text.Encoding]::UTF8)
    $mu0 = [regex]::Match($ftxt, '(?m)^URL:\s*(\S+)')
    if($mu0.Success){ $urls += $mu0.Groups[1].Value }
    $mu0b = [regex]::Match($ftxt, '(?m)^BASES:\s*(\S+)')
    if($mu0b.Success){ $urls += $mu0b.Groups[1].Value }
  }
  $mu = [regex]::Match($t, '(?s)<strong>Fuente:</strong>\s*(https?://[^\s<]+)')
  if($mu.Success){ $urls += $mu.Groups[1].Value.TrimEnd('.',';',')') }

  $urls = @($urls | Where-Object { $_ -match '^https?://' } | Where-Object { $_ -notmatch '\.(docx?|xlsx?|pdf)(\?|$)' } | Select-Object -Unique)

  if($urls.Count -eq 0){
    $stats.nofetch++
    $lineas += "NOFETCH(sin-url) | $($f.Name)"
    continue
  }

  $res = $null
  $fuenteOk = $null
  $htmlOk = $null
  foreach($u in $urls){
    $esCdt = $u -match 'convocatoriasdetrabajo\.com'
    $html = Obtener-Pagina $u $esCdt
    if($html){
      $htmlOk = $html
      $fuenteOk = $u
      $res = Extraer-Salario $html
      break
    }
  }

  if(-not $htmlOk){
    $stats.nofetch++
    $lineas += "NOFETCH | $($f.Name) | $($urls -join ' ; ')"
    continue
  }

  if(-not $res){
    $txt = $htmlOk -replace '(?is)<script[\s\S]*?</script>',' ' -replace '<[^>]+>',' ' -replace '\s+',' '
    if($txt -match '(?i)remuneraci' -and $txt -match 'S/\s*[\d.,]{3,}'){
      $stats.revisar++
      $lineas += "REVISAR(extraccion-fallo) | $($f.Name) | $fuenteOk"
    }else{
      $stats.noespec++
      $lineas += "NOESPEC(sin-dato) | $($f.Name) | $fuenteOk"
      $res = @{tipo="noespec"; pat="sin-dato"}
    }
    if(-not $res){ continue }
  }else{
    $lineas += "EXTR [$($res.pat)] tipo=$($res.tipo) $(if($res.tipo -eq 'valor'){$res.txt}) $(if($res.raw){'raw=' + $res.raw}) | $($f.Name) | $fuenteOk"
  }

  if($res.tipo -eq "revisar"){
    $stats.revisar++
    $lineas += "REVISAR(valor-raro) raw=[$($res.raw)] | $($f.Name) | $fuenteOk"
    continue
  }

  if($res.tipo -eq "valor"){
    if($res.txt -eq 'S/ 10000' -or $res.txt -eq 'S/ 10,000'){
      $stats.igual++
      $lineas += "IGUAL(real) | $($f.Name) | $fuenteOk"
      continue
    }
    $stats.valor++
    $accion = "valor"
  }elseif($res.tipo -eq "noespec"){
    if($res.pat -eq "sin-dato" -and -not $Aplicar){ continue }
    $stats.noespec++
    $accion = "noespec"
  }

  if(-not $Aplicar){ Start-Sleep -Milliseconds 700; continue }

  $orig = $t

  if($accion -eq "valor"){
    $v = $res.txt
    $t = [regex]::Replace($t, '(?s)(<strong>Salario:</strong>)\s*S/ ?10[.,]?000\.?', ('$1 ' + $v))
    $t = [regex]::Replace($t, '(?s)(<div class="empleo-salario-header">)\s*S/ ?10[.,]?000\.?\s*(</div>)', ('$1' + "`r`n    " + $v + "`r`n  " + '$2'))
    $t = [regex]::Replace($t, '(?s)(<strong>Remuneraci[óo]n:</strong>)\s*S/ ?10[.,]?000\.?', ('$1 ' + $v))
    $t = [regex]::Replace($t, ',\s*con una remuneracion de S/ ?10[.,]?000\.', (', con una remuneracion de ' + $v + ';'))
    $t = [regex]::Replace($t, ',\s*con una remuneracion de S/ ?10[.,]?000(?![.\d])', (', con una remuneracion de ' + $v))
  }else{
    $t = [regex]::Replace($t, '(?s)(<strong>Salario:</strong>)\s*S/ ?10[.,]?000\.?', '$1 No especificado')
    $t = [regex]::Replace($t, '(?s)\s*<div class="empleo-salario-header">\s*S/ ?10[.,]?000\.?\s*</div>', '')
    $t = [regex]::Replace($t, '(?s)\s*<p><strong>Remuneraci[óo]n:</strong>\s*S/ ?10[.,]?000\.?\s*</p>', '')
    $t = [regex]::Replace($t, ',\s*con una remuneracion de S/ ?10[.,]?000\.', '')
  }

  if($t -ne $orig){
    [IO.File]::WriteAllText($f.FullName, $t, (New-Object Text.UTF8Encoding($false)))
    $lineas += "PATCHED($accion) | $($f.Name)"
  }

  Start-Sleep -Milliseconds 700
}

$lineas += "=== stats: igual=$($stats.igual) valor=$($stats.valor) noespec=$($stats.noespec) nofetch=$($stats.nofetch) revisar=$($stats.revisar) ==="
[IO.File]::WriteAllText($logPath, ($lineas -join "`r`n"), (New-Object Text.UTF8Encoding($true)))
Write-Host ($lineas | Select-Object -Last 1)
Write-Host "log: $logPath"
