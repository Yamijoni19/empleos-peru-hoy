# prueba-fase-a.ps1 - pruebas de lib\categoria / lib\estandar / lib\reescritor
$ErrorActionPreference = 'Stop'
$raiz = 'C:\Users\Dell G3 Gaming\Documents\Default Project'
. (Join-Path $raiz 'lib\categoria.ps1')
. (Join-Path $raiz 'lib\estandar.ps1')
. (Join-Path $raiz 'lib\reescritor.ps1')

$fail = 0
function Ok([string]$nombre, $esperado, $obtenido) {
    if ("$esperado" -eq "$obtenido") { Write-Host ("  OK   {0} => {1}" -f $nombre, $obtenido) }
    else { $script:fail++; Write-Host ("  FAIL {0} => [{1}] esperado [{2}]" -f $nombre, $obtenido, $esperado) -ForegroundColor Red }
}

Write-Host "== CATEGORIA (bug Analista Contable) =="
Ok 'Analista Contable' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'ANALISTA CONTABLE' -Texto '')
Ok 'Analista Contable Sin Experiencia' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'Analista Contable (Sin Experiencia)' -Texto '')
Ok 'Analista Contable - Tributario Senior' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'Analista Contable - Tributario Senior' -Texto '')
Ok 'Asistente Contable' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'Asistente Contable' -Texto '')
Ok 'Auxiliar Contable y Administrativo' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'Auxiliar Contable y Administrativo' -Texto '')
Ok 'Auxiliar Contable y Practicante de Marketing' 'Administración y Finanzas' (Obtener-CategoriaExacta -Titulo 'Auxiliar Contable y Practicante de Marketing' -Texto '')
Ok 'Enfermera' 'Salud' (Obtener-CategoriaExacta -Titulo 'Enfermera de Hospital' -Texto '')
Ok 'Medico cirujano' 'Salud' (Obtener-CategoriaExacta -Titulo 'Médico Cirujano' -Texto '')
Ok 'Abogado laboral' 'Derecho' (Obtener-CategoriaExacta -Titulo 'Abogado Laboral' -Texto '')
Ok 'Ingeniero civil' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'Ingeniero Civil' -Texto '')
Ok 'Analista de Sistemas' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'Analista de Sistemas' -Texto '')
Ok 'Chofer - Almacenero' 'Ventas y Servicios' (Obtener-CategoriaExacta -Titulo 'Chofer - Almacenero' -Texto '')
Ok 'AISTENTE DE ALMACEN' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'AISTENTE DE ALMACEN' -Texto '')
Ok 'Estibador (cuerpo con almacen)' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'Estibador / Cargador' -Texto 'almacen logistica inventario de mercaderia')
Ok 'Estibador sin cuerpo' 'Otros' (Obtener-CategoriaExacta -Titulo 'Estibador / Cargador' -Texto '')
Ok 'Jefe de Marketing en Clinica' 'Ventas y Servicios' (Obtener-CategoriaExacta -Titulo 'Jefe de Marketing en Clínica' -Texto '')
Ok 'Profesor' 'Educación' (Obtener-CategoriaExacta -Titulo 'Profesor de Matemáticas' -Texto '')
Ok 'Vendedor' 'Ventas y Servicios' (Obtener-CategoriaExacta -Titulo 'Vendedor de Retail' -Texto '')
Ok 'Jefe de Proyecto' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'Jefe de Proyecto' -Texto '')
Ok 'cuerpo solo (2 kw)' 'Ingeniería' (Obtener-CategoriaExacta -Titulo 'Estibador' -Texto 'almacen y logistica')
Ok 'vacio' 'Otros' (Obtener-CategoriaExacta -Titulo '' -Texto '')
Ok 'canonica si' $true (Es-CategoriaCanonica 'Administración y Finanzas')
Ok 'canonica no' $false (Es-CategoriaCanonica 'Administracion y Finanzas')
Ok 'round-trip tema (todas canonicas)' 7 (@($script:CatCanonicas | Where-Object { (Es-CategoriaCanonica $_) }).Count)

Write-Host "== ESTANDAR: salario =="
Ok 'S/ simple'        'S/ 1,800' (Est-Salario 'S/ 1,800')
Ok 'decimales'        'S/ 1,450' (Est-Salario 'S/ 1,450.00')
Ok 'soles'            'S/ 1,800' (Est-Salario '1800 soles')
Ok 'coma miles'       'S/ 1,800' (Est-Salario '1,800')
Ok 'punto miles coma dec' 'S/ 1,450' (Est-Salario '1.450,00')
Ok 'rango guion'      'S/ 1,800 - S/ 2,200' (Est-Salario 'S/ 1,800 - S/ 2,200')
Ok 'rango a'          'S/ 1,800 - S/ 2,200' (Est-Salario 'Entre S/ 1,800 a S/ 2,200 al mes')
Ok 'rango y soles'    'S/ 1,500 - S/ 2,000' (Est-Salario '1500 y 2000 soles')
Ok 'por hora'         'S/ 12 por hora' (Est-Salario 'S/ 12 por hora')
Ok 'por hora 2'       'S/ 15 por hora' (Est-Salario '15 soles la hora')
Ok 'a convenir'       'A convenir' (Est-Salario 'Salario a convenir')
Ok 'negociable'       'Negociable' (Est-Salario 'Negociable segun experiencia')
Ok 'vacio'            'No especificado' (Est-Salario '')
Ok 'basura'           'No especificado' (Est-Salario 'No especificado')
Ok 'fuera de rango'   'No especificado' (Est-Salario 'S/ 50')
Ok 'min/max bumeran'  'S/ 1,500 - S/ 2,000' (Est-Salario '' -Min 1500 -Max 2000)
Ok 'solo min'         'S/ 1,500' (Est-Salario '' -Min 1500)
Ok 'idempotente'      'S/ 1,800 - S/ 2,200' (Est-Salario (Est-Salario 'Entre S/ 1800 y S/ 2200'))

Write-Host "== ESTANDAR: catalogos =="
Ok 'FULL_TIME jornada'    'Full-time' (Est-Jornada 'FULL_TIME')
Ok 'full-time'            'Full-time' (Est-Jornada 'Full-time')
Ok 'part time'            'Part-time' (Est-Jornada 'PART_TIME')
Ok 'contrato FULL_TIME'   'No especificado' (Est-Contrato 'FULL_TIME')
Ok 'contrato indefinido'  'Indefinido' (Est-Contrato 'Indefinido')
Ok 'contrato temporal'    'Temporal' (Est-Contrato 'TEMPORARY')
Ok 'modalidad remoto'     'Remoto' (Est-Modalidad 'TELECOMMUTE')
Ok 'modalidad hibrido'    'Híbrido' (Est-Modalidad 'Híbrido')
Ok 'vacantes 01'          '1' (Est-Vacantes '01')
Ok 'vacantes Nro'         '4' (Est-Vacantes 'Nro. de vacantes: 4')
Ok 'vacantes texto'       '3' (Est-Vacantes '3 vacantes')
Ok 'vacantes anyo'        'No especificado' (Est-Vacantes '2026')
Ok 'fecha iso'            '02/10/2026' (Est-Fecha '2026-10-02')
Ok 'fecha ya ok'          '02/10/2026' (Est-Fecha '02/10/2026')
Ok 'ubicacion + peru'     'Lima, Perú' (Est-Ubicacion 'Lima')
Ok 'ubicacion ya peru'    'Lima, Lima, Perú' (Est-Ubicacion 'Lima, Lima, Perú')
Ok 'ciudad'               'Lima' (Est-Ciudad 'Lima, Lima, Perú')

Write-Host "== EST-PORQUE =="
$bullets = Est-Porque @{ titulo='Analista Contable'; empresa='ACME S.A.C.'; ubicacion='Lima, Perú'; modalidad='Presencial'; contrato='Indefinido'; jornada='Full-time'; salario='S/ 1,800'; experiencia='2 años'; sector='Comercio'; ciudad='Lima'; beneficios=@('Salud y pensión','Colación') } -Semilla 1
Ok 'porque >= 3' $true ($bullets.Count -ge 3)
Ok 'porque <= 4' $true ($bullets.Count -le 4)
Ok 'porque sin No especificado' $false (@($bullets | Where-Object { $_ -match 'No especificado' }).Count -gt 0)
Ok 'porque sin li >180' $false (@($bullets | Where-Object { $_.Length -gt 180 }).Count -gt 0)
$bullets | ForEach-Object { Write-Host ("     - " + $_) }
$bullets2 = Est-Porque @{ titulo='Estibador'; empresa=''; ubicacion=''; modalidad='No especificado'; contrato='No especificado'; jornada='No especificado'; salario='No especificado'; experiencia='No especificado'; sector='No especificado'; ciudad=''; beneficios=@() } -Semilla 0
Ok 'porque fallback >= 2' $true ($bullets2.Count -ge 2)
$bullets2 | ForEach-Object { Write-Host ("     - " + $_) }

Write-Host "== REESCRITOR =="
Ok 'sinonimos' 'efectuar la revisión de archivos' (Aplicar-Sinonimos 'realizar la revisión de documentos')
$oras = Obtener-Oraciones 'Primera frase de prueba. Segunda frase aqui. Tercera frase final.'
Ok 'oraciones' 3 $oras.Count
$bul = Segmentar-EnBullets 'Se encarga de realizar la verificación de todos los documentos, archivos, reportes, solicitudes, actividades, tareas y demás labores del área durante la semana completa sin falta.' 200
Ok 'segmenta en >1 bullets' $true ($bul.Count -gt 1)
Ok 'bullets <= 200' $false (@($bul | Where-Object { $_.Length -gt 200 }).Count -gt 0)
$parr = Redactar-Parrafo -Frases @('Realizar el control diario de asistencia del personal del área.','Verificar que los reportes semanales estén completos antes de enviarlos.') -Semilla 2
Ok 'parrafo no vacio' $true ($parr.Length -gt 30)
Write-Host ("     parrafo: " + $parr)
$fuente = 'El candidato debera realizar el control diario de asistencia del personal del area y verificar que los reportes semanales esten completos antes de enviarlos al jefe de area, ademas de elaborar los archivos de gestion correspondientes.'
$noCopiado = 'La vacante corresponde al puesto de Analista Contable en la empresa ACME del distrito de Miraflores.'
Ok 'similitud copia alta' $true ((Similitud-Ngramas 'realizar el control diario de asistencia del personal del area y verificar que los reportes semanales esten completos antes de enviarlos' $fuente) -ge 0.5)
Ok 'similitud original baja' $true ((Similitud-Ngramas $noCopiado $fuente) -lt 0.1)
$htmlPrueba = '<p>realizar el control diario de asistencia del personal del area y verificar que los reportes semanales esten completos antes de enviarlos al jefe de area</p><p>' + $noCopiado + '</p>'
$copiados = @(Parrafos-Copiados -Html $htmlPrueba -Fuente $fuente -Umbral 0.35)
Ok 'detecta 1 copiado' 1 $copiados.Count
$reesc = Reescribir-Copiado -Texto 'realizar el control diario de asistencia del personal del area y verificar que los reportes semanales esten completos antes de enviarlos al jefe de area' -Tipo 'p'
Ok 'reescribe a algo' $true ((@($reesc) -join ' ').Length -gt 20)

Write-Host ""
if ($fail -eq 0) { Write-Host 'TODO OK (0 fallos)' -ForegroundColor Green; exit 0 }
else { Write-Host ("FALLOS: " + $fail) -ForegroundColor Red; exit 1 }
