param(
  [Parameter(Mandatory=$true)][string]$URL,
  [string]$Salida = ""
)

$bin = "C:\Users\Dell G3 Gaming\AppData\Local\Temp\opencode\poppler\extract\poppler-24.08.0\Library\bin\pdftotext.exe"
$out = "C:\Users\Dell G3 Gaming\AppData\Local\Temp\opencode\pdfs"

New-Item -ItemType Directory -Force -Path $out | Out-Null

$nombre = [System.IO.Path]::GetFileName([Uri]::new($URL).LocalPath)
if(-not $nombre.EndsWith(".pdf")){ $nombre = "beca_" + (Get-Date -Format "yyyyMMddHHmmss") + ".pdf" }
$pdf = Join-Path $out $nombre

Write-Host "Descargando PDF..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $URL -OutFile $pdf -UseBasicParsing
Write-Host "PDF descargado: $pdf" -ForegroundColor Green

$txt = $pdf -replace "\.pdf$", ".txt"
& $bin -layout $pdf $txt

Write-Host ""
Write-Host "TEXTO EXTRAIDO:" -ForegroundColor Cyan
Write-Host "========================================"
Get-Content $txt -Raw
Write-Host "========================================"
Write-Host "Archivo generado: $txt" -ForegroundColor Green