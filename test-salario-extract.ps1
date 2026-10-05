$raiz = "C:\Users\Dell G3 Gaming\Documents\Default Project"
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0"

function Extraer-SalarioCdt {
  param([string]$html)
  $p1 = [regex]::Match($html, '(?is)(S/\s*[\d.,]+|No especifica[a-z]*)\s*(?:<[^>]+>\s*)*<span>\s*Remuneraci')
  if($p1.Success){ return @{v=$p1.Groups[1].Value; pat="p1"} }
  $p2 = [regex]::Match($html, '(?is)Remuneraci[óo]n:\s*(?:<[^>]+>\s*)*(S/\s*[\d.,]+|No especifica[a-z]*)')
  if($p2.Success){ return @{v=$p2.Groups[1].Value; pat="p2"} }
  $txt = $html -replace '(?is)<script[\s\S]*?</script>',' ' -replace '<[^>]+>',' ' -replace '&nbsp;',' ' -replace '\s+',' '
  $p3 = [regex]::Match($txt, '(?i)(S/\s*[\d.,]{3,})[^.]{0,60}?(remuneraci[óo]n|salario)')
  if($p3.Success){ return @{v=$p3.Groups[1].Value; pat="p3"} }
  $p4 = [regex]::Match($txt, '(?i)(remuneraci[óo]n|salario)[^a-zA-Z]{0,60}?(S/\s*[\d.,]{3,})')
  if($p4.Success){ return @{v=$p4.Groups[2].Value; pat="p4"} }
  return $null
}

$urls = @(
  @{n="medico";   u="https://www.convocatoriasdetrabajo.com/oportunidad-laboral-cas-005-codigo-airhsp-medico-especialista-red-salud-junin-633927.html"},
  @{n="agrobanco";u="https://www.convocatoriasdetrabajo.com/oportunidad-laboral-practicas-agrobanco-administracion-gestion-recursos-humanos-psicologia-setiembre-2026-624107.html"},
  @{n="auxiliar"; u="https://www.convocatoriasdetrabajo.com/oportunidad-laboral-cas-005-codigo-airhsp-auxiliar-asistencial-red-salud-junin-633935.html"}
)

foreach($x in $urls){
  Write-Output ("== " + $x.n)
  try{
    $r = Invoke-WebRequest -Uri $x.u -UserAgent $ua -TimeoutSec 40 -UseBasicParsing
    $res = Extraer-SalarioCdt $r.Content
    if($res){ Write-Output ("   " + $res.pat + " -> [" + $res.v + "]") } else { Write-Output "   NADA" }
    $jb = [regex]::Match($r.Content, '(?is)"baseSalary"\s*:\s*\{[^{}]{0,300}\}')
    if($jb.Success){ Write-Output ("   jsonld: " + ($jb.Value -replace '\s+',' ')) }
  }catch{
    Write-Output ("   ERR: " + $_.Exception.Message)
  }
}
