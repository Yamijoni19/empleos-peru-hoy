param(
  [switch]$Aplicar,
  [switch]$SoloDiag
)

$ErrorActionPreference = "Stop"
$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$salida = Join-Path $raiz "salida"
$reporte = Join-Path $raiz "reporte"
if(-not (Test-Path $reporte)){ New-Item -ItemType Directory -Path $reporte | Out-Null }

$fecha = Get-Date -Format "yyyy-MM-dd"
$logPath = Join-Path $reporte "salarios-10000-$fecha.txt"
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

function Obtener-Numero {
  param([string]$txt)
  if(-not $txt){ return $null }
  if($txt -match 'millones|mill\.|billones'){ return $null }
  $limpio = $txt.Trim()
  if($limpio -notmatch '^[\d.,]+$'){ return $null }
  if($limpio -match ',\d{1,2}$'){
    $v = [double]($limpio -replace '\.','' -replace ',','.')
  }else{
    $v = [double]($limpio -replace '[^\d]','')
  }
  if($v -ge 500 -and $v -le 50000){ return $v }
  return $null
}

function Buscar-SalarioEnPagina {
  param([string]$html)
  $resultados = @()

  # 1) JSON-LD baseSalary
  try{
    $m = [regex]::Match($html, '(?is)"baseSalary"\s*:\s*\{[^{}]{0,400}\}')
    if($m.Success){
      $bloque = $m.Value
      $mv = [regex]::Match($bloque, '"value"\s*:\s*"?([\d.,]+)"?')
      if(-not $mv.Success){ $mv = [regex]::Match($bloque, '"minValue"\s*:\s*"?([\d.,]+)"?') }
      if($mv.Success){
        $n = Obtener-Numero $mv.Groups[1].Value
        if($n){ $resultados += @{v=$n; origen="jsonld"} }
      }
    }
  }catch{}

  # 2) Ventanas con palabras clave
  $pats = @(
    '(?is)(remuneraci[óo]n|salario|sueldo|haberes)[^<>]{0,80}?S/\s*([\d.,]{3,})',
    '(?is)S/\s*([\d.,]{3,})\s*(?:mensuales?|al mes|mensual)'
  )
  foreach($p in $pats){
    foreach($mm in [regex]::Matches($html, $p)){
      $cand = if($mm.Groups.Count -ge 3 -and $mm.Groups[2].Value){ $mm.Groups[2].Value } else { $mm.Groups[1].Value }
      $n = Obtener-Numero $cand
      if($n){
        $resultados += @{v=$n; origen="clave"}
        break
      }
    }
    if($resultados.Count -gt 0){ break }
  }

  return $resultados
}

function Formatear-Salario {
  param([double]$v)
  if($v -eq [math]::Floor($v)){
    if($v -ge 1000){ return ("S/ " + $v.ToString("N0")) }
    return ("S/ " + $v.ToString("0"))
  }
  return ("S/ " + $v.ToString("N2"))
}

$archivos = Get-ChildItem (Join-Path $salida "*-entrada.html") | Where-Object {
  $t = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  $t -match '(?s)<strong>Salario:</strong>\s*S/ ?10[.,]?000\b'
}

$lineas = @()
$lineas += "=== Revisar salarios 10000 - $fecha - archivos: $($archivos.Count) - aplicar=$Aplicar ==="
$stats = @{ok=0; noespec=0; nofetch=0; sinvalor=0}

foreach($f in $archivos){
  $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $mu = [regex]::Match($t, '(?s)<strong>Fuente:</strong>\s*(https?://[^\s<]+)')
  $url = if($mu.Success){ $mu.Groups[1].Value.TrimEnd('.',';',')') } else { $null }

  if(-not $url){
    $stats.sinvalor++
    $lineas += "SIN-URL | $($f.Name)"
    continue
  }

  $html = $null
  $intento = 0
  while($intento -lt 3 -and -not $html){
    $intento++
    try{
      $resp = Invoke-WebRequest -Uri $url -UserAgent $ua -TimeoutSec 40 -UseBasicParsing -MaximumRedirection 5
      if($resp.Content){ $html = [string]$resp.Content }
    }catch{
      if($intento -ge 3){ $lineas += "NO-FETCH($($_.Exception.Message.Substring(0,[Math]::Min(80,$_.Exception.Message.Length)))) | $($f.Name) | $url" }
      Start-Sleep -Milliseconds 1200
    }
  }

  if(-not $html){
    $stats.nofetch++
    continue
  }

  $enc = Buscar-SalarioEnPagina -html $html

  if($enc.Count -eq 0){
    $stats.sinvalor++
    $lineas += "SIN-VALOR | $($f.Name) | $url"
    $nuevo = $null
  }else{
    $nuevo = Formatear-Salario $enc[0].v
    $stats.ok++
    $lineas += "VALOR($($enc[0].origen))=$nuevo | $($f.Name) | $url"
  }

  if(-not $Aplicar){ Start-Sleep -Milliseconds 300; continue }

  $orig = $t

  if($nuevo){
    $t = $t -replace 'S/ 10000\.', ($nuevo + '.')
    $t = $t -replace 'S/ 10\.000\.', ($nuevo + '.')
    $t = $t -replace 'S/ 10000(?=[^.\d])', $nuevo
  }else{
    $t = [regex]::Replace($t, '(?s)<p><strong>Salario:</strong>\s*S/ ?10[.,]?000\.?\s*</p>', "<p><strong>Salario:</strong> No especificado</p>")
    $t = [regex]::Replace($t, '(?s)\s*<div class="empleo-salario-header">\s*S/ ?10[.,]?000\.?\s*</div>', '')
    $t = [regex]::Replace($t, '(?s)\s*<p><strong>Remuneraci[óo]n:</strong>\s*S/ ?10[.,]?000\.?\s*</p>', '')
    $t = [regex]::Replace($t, ',\s*con una remuneracion de S/ ?10[.,]?000\.', '')
    $stats.noespec++
  }

  if($t -ne $orig){
    [IO.File]::WriteAllText($f.FullName, $t, (New-Object Text.UTF8Encoding($false)))
    if($Aplicar){ $lineas += "PATCHED | $($f.Name)" }
  }

  Start-Sleep -Milliseconds 300
}

$lineas += "=== stats: ok=$($stats.ok) noespec=$($stats.noespec) nofetch=$($stats.nofetch) sinvalor=$($stats.sinvalor) ==="
[IO.File]::WriteAllText($logPath, ($lineas -join "`r`n"), (New-Object Text.UTF8Encoding($true)))
Write-Host ($lineas -join "`r`n")
