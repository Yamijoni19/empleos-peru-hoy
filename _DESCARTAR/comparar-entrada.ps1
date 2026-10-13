# comparar-entrada.ps1 - comprueba que los datos duros de una entrada HTML
# coinciden con los datos reales guardados en el archivo de la fuente.
#
# USO (PowerShell):
#   .\comparar-entrada.ps1 -Fuente "fuentes\pepito.txt" -Html "salida\pepito-entrada.html"
#
# Sirve tambien para entradas hechas con IA: si la IA invento un dato
# (vacantes, salario, ciudad, fechas, entidad, contrato), aqui aparece.
# Devuelve exit code 0 = TODO COINCIDE, 1 = hay discrepancias.

param(
    [Parameter(Mandatory = $true)][string]$Fuente,
    [Parameter(Mandatory = $true)][string]$Html
)

$ErrorActionPreference = "Stop"

try {

if (-not (Test-Path -LiteralPath $Fuente)) { Write-Host "ERROR: no existe el archivo $Fuente"; exit 1 }
if (-not (Test-Path -LiteralPath $Html))   { Write-Host "ERROR: no existe el archivo $Html";   exit 1 }

$datos = @{}
foreach ($linea in [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Fuente), [System.Text.Encoding]::UTF8)) {
    $i = $linea.IndexOf(':')
    if ($i -lt 1) { continue }
    $k = $linea.Substring(0, $i).Trim().ToUpper()
    $v = $linea.Substring($i + 1).Trim()
    if ($v -ne "") { $datos[$k] = $v }
}

$contenido = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Html), [System.Text.Encoding]::UTF8)
$cuerpo = $contenido -replace '<!--[\s\S]*?-->', ''

$campos = @(
    @{ k = 'VACANTES';     etiqueta = 'Vacantes';             campo = $true  },
    @{ k = 'SALARIO';      etiqueta = 'Salario';              campo = $true  },
    @{ k = 'CIUDAD';       etiqueta = 'Ciudad';               campo = $true  },
    @{ k = 'ENTIDAD';      etiqueta = 'Empresa';              campo = $true  },
    @{ k = 'CONTRATO';     etiqueta = 'Contrato';             campo = $true  },
    @{ k = 'FECHA CIERRE'; etiqueta = 'Fecha de cierre';      campo = $true  }
)

Write-Host "== COMPARANDO =="
Write-Host "   fuente: $Fuente"
Write-Host "   html  : $Html"
Write-Host ""

$fallos = New-Object System.Collections.Generic.List[string]

foreach ($c in $campos) {
    $esperado = ""
    if ($datos.ContainsKey($c.k)) { $esperado = $datos[$c.k] }
    if ($esperado -eq "" -or $esperado -eq "No especificado") {
        Write-Host ("  [----] " + $c.etiqueta + ": sin dato en la fuente (se omite)")
        continue
    }
    $ok = $false
    if ($c.campo) {
        # dentro del bloque oculto / recuadro: "Etiqueta: valor"
        $patron = '<strong>' + [regex]::Escape($c.etiqueta) + ':</strong>\s*' + [regex]::Escape($esperado)
        $ok = [regex]::IsMatch($cuerpo, $patron)
        if (-not $ok) {
            # el valor puede ir separado por saltos de linea o etiquetas
            $mCerca = [regex]::Match($cuerpo, [regex]::Escape($c.etiqueta) + ':</strong>([\s\S]{0,120})')
            if ($mCerca.Success -and $mCerca.Groups[1].Value.IndexOf($esperado) -ge 0) { $ok = $true }
        }
    }
    if ($ok) {
        Write-Host ("  [OK  ] " + $c.etiqueta + ": " + $esperado)
    } else {
        $encontrado = "NO aparece"
        $mEtq = [regex]::Match($cuerpo, '<strong>' + [regex]::Escape($c.etiqueta) + ':</strong>\s*([^<]{0,60})')
        if ($mEtq.Success) { $encontrado = ($mEtq.Groups[1].Value -replace '\s+', ' ').Trim() }
        Write-Host ("  [DIFF] " + $c.etiqueta + ": ESPERABA [" + $esperado + "] / ENCONTRÓ [" + $encontrado + "]")
        $fallos.Add($c.etiqueta)
    }
}

Write-Host ""
if ($fallos.Count -gt 0) {
    Write-Host ("RESULTADO: " + $fallos.Count + " discrepancia(s) (" + ($fallos -join ", ") + "). NO pegues esta entrada en Blogger.")
    exit 1
}
Write-Host "RESULTADO: OK - todos los datos coinciden con la fuente."
exit 0

} catch {
    Write-Host ("ERROR: " + $_.Exception.Message)
    exit 1
}
