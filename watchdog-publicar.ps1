# watchdog-publicar.ps1 - relanza publicar-blogger.ps1 si murio y quedan
# pendientes. Corre cada 15 min via tarea programada EmpleosPublicarWatchdog.
$raiz = 'C:\Users\Dell G3 Gaming\Documents\Default Project'
$log  = Join-Path $raiz 'reporte\watchdog.log'

function Apuntar([string]$m) {
    Add-Content -Path $log -Value ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + $m) -Encoding UTF8
}

# 1) si ya hay una instancia corriendo, no hago nada
$corriendo = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -match 'publicar-blogger\.ps1' }
if ($corriendo) { exit 0 }

# 2) cuento pendientes (archivos de salida sin registrar en publicaciones.txt)
$pub = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
$pubPath = Join-Path $raiz 'publicaciones.txt'
if (Test-Path $pubPath) {
    foreach ($l in [IO.File]::ReadAllLines($pubPath)) {
        if ($l -match '\|\s*([^\|]+\.html)\s*$') { [void]$pub.Add($Matches[1].Trim()) }
    }
}
$pend = @(Get-ChildItem (Join-Path $raiz 'salida') -Filter '*-entrada.html' -ErrorAction SilentlyContinue |
    Where-Object { -not $pub.Contains($_.Name) })

if ($pend.Count -eq 0) {
    Apuntar "sin pendientes: todo publicado"
    exit 0
}

Apuntar ("relanzando publicar-blogger, pendientes=" + $pend.Count)
$out = Join-Path $raiz 'reporte\watchdog-publicar.log'
Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f (Join-Path $raiz 'publicar-blogger.ps1')), '-Si') `
    -RedirectStandardOutput $out -RedirectStandardError ($out + '.err') -WindowStyle Minimized
