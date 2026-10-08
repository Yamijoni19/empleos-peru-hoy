# lib\categoria.ps1 - Clasificador CANONICO de categorias del blog (Fase A).
#
# El blog tiene 7 botones/filtros con estas etiquetas EXACTAS (con tildes):
#   Ingenieria | Salud | Ventas y Servicios | Administracion y Finanzas |
#   Derecho | Educacion | Otros
# (en la pagina y el tema van con tildes: "Ingenieria", "Administracion y
# Finanzas", "Educacion" => ver EMPLEOS-PAGE.html data-categoria y
# normalizarCategoria() del tema: con esas 7 cadenas el tema hace round-trip
# exacto y la entrada queda en su seccion).
#
# BUG QUE CORRIGE: los generadores usaban regex por orden de aparicion
# ('contabil' no matchea "contable"; el orden Ingenieria antes que Admin
# hacia que "Analista Contable" cayera en Ingenieria/Otros) y Bumeran devolvia
# nombres NO canonicos ('Tecnologia', 'Legal', 'Operaciones y Logistica'...)
# que el tema reclasificaba a "Otros" o por titulo.
#
# METODO: scoring titulo x3 (frases x6) + cuerpo x1 (frases x2); a igualdad
# manda el orden de prioridad; con SOLO coincidencias de cuerpo (titulo sin
# keyword) hace falta puntaje >= 2; sin coincidencias => 'Otros'.
#
# USO:
#   . .\lib\categoria.ps1
#   Obtener-CategoriaExacta -Titulo $titulo -Texto ($cuerpo -join ' ')

$script:CatCanonicas = @(
    'Ingeniería',
    'Salud',
    'Ventas y Servicios',
    'Administración y Finanzas',
    'Derecho',
    'Educación',
    'Otros'
)

# prioridad ante empate (mas especifica primero)
$script:CatOrden = @(
    'Derecho',
    'Administración y Finanzas',
    'Salud',
    'Ventas y Servicios',
    'Ingeniería',
    'Educación'
)

# keywords FUERTES: pesan en titulo (x3; frases x6) y en cuerpo (x1; x2)
$script:CatKeywords = @{
    'Derecho' = @(
        'abogad', 'derecho', 'juridic', 'legal', 'notari', 'compliance',
        'procurador', 'arbitraj', 'asesoria legal', 'asesor legal',
        'contratos laborales', 'litig', 'defensa legal', 'régimen laboral'
    )
    'Administración y Finanzas' = @(
        'administr', 'contable', 'contabil', 'contador', 'contadora',
        'contabilidad', 'analista contable', 'analista de cuentas',
        'cuentas por cobrar', 'cuentas por pagar', 'costos', 'presupuesto',
        'impuestos', 'sunat', 'tributario', 'planilla', 'remuneraciones',
        'sueldos', 'finanz', 'financier', 'recursos humanos', 'rrhh',
        'talento humano', 'tesorer', 'cobrador', 'cobranz', 'facturac',
        'compras', 'banco', 'banca', 'credito', 'auditor', 'nomina',
        'data entry', 'secretar', 'oficinist', 'archivo', 'recepcion',
        'asistente administrativ', 'auxiliar administrativ', 'back office',
        'control interno', 'contable tributario'
    )
    'Salud' = @(
        'salud', 'medic', 'enfermer', 'odontolog', 'farmac', 'nutricion',
        'psicolog', 'fisioterap', 'obstetr', 'kinesi', 'dentista',
        'laboratorio', 'laboratorist', 'quirur', 'optometr', 'ambulanc',
        'podolog', 'tecnologo medico', 'epidemiolog', 'estomatolog'
    )
    'Ventas y Servicios' = @(
        'venta', 'comercial', 'marketing', 'publicid', 'promotor',
        'vendedor', 'asesor comercial', 'asesor de ventas', 'ejecutivo de cuenta',
        'ejecutivo comercial', 'televenta', 'call center', 'atencion al cliente',
        'servicio al cliente', 'cliente', 'negocio', 'seguros', 'retail',
        'tienda', 'cajero', 'mozo', 'mesero', 'cociner', 'barista',
        'repartidor', 'chofer', 'hostel', 'hotel', 'restaurante', 'turismo',
        'anfitriona', 'vigilante', 'guardia de seguridad', 'seguridad privada',
        'serenazgo', 'limpieza', 'limpiador', 'aseo', 'conserje',
        'recepcionista', 'telefonista', 'animacion', 'eventos', 'fotografo',
        'estilista', 'gastronomic', 'cocina', 'deliver', 'reparto'
    )
    'Ingeniería' = @(
        'ingenier', 'arquitect', 'urbanism', 'construccion', 'civil',
        'electric', 'mecanic', 'industrial', 'mineri', 'mina', 'ambiental',
        'sistema', 'software', 'programad', 'desarroll', 'telecomunic',
        'computa', 'umbraco', 'devops', 'backend', 'frontend', 'tecnolog',
        'analista de datos', 'business intelligence', 'power bi', 'datos',
        'ciberseguridad', 'bases de datos', 'servidores', 'infraestructura',
        'nube', 'redes', 'topograf', 'mantenimiento', 'produccion',
        'procesos', 'logistica', 'almacen', 'operaciones', 'calidad',
        'transporte', 'distribucion', 'supply chain', 'cadena de suministro',
        'ssoma', 'seguridad industrial', 'seguridad ocupacional',
        'seguridad e higiene', 'higiene industrial', 'hse', 'ehs',
        'prevencion de riesgos', 'medio ambiente', 'electrico',
        'gestion de activos', 'planta', 'metalurg', 'quimic', 'petroleo',
        'agroindustrial', 'maquinaria', 'instrumentacion', 'automatizacion',
        'robotic', 'jefe de proyecto', 'gerente de proyecto',
        'administracion de proyectos', 'project manager', 'operario',
        'operador de planta', 'maestro de obra'
    )
    'Educación' = @(
        'docente', 'profesor', 'educacion', 'instituto', 'colegio',
        'escolar', 'pedagog', 'tutor', 'maestro', 'catedratic', 'docencia',
        'capacitador', 'instructor', 'escuela', 'ense anza', 'aula',
        'alumnos', 'academico'
    )
}

# keywords DEBILES: solo cuentan en el cuerpo (x1; frases x2); en el titulo
# se ignoran (p.ej. "Jefe de Marketing en Clinica" no debe caer en Salud
# solo por la palabra "Clinica" en el titulo).
$script:CatDebiles = @{
    'Salud' = @('clinica', 'hospital', 'paciente')
}

function Normalizar-Clave([string]$s) {
    $x = [string]$s
    $x = $x.ToLowerInvariant()
    $x = $x.Normalize([Text.NormalizationForm]::FormD)
    $x = [regex]::Replace($x, '[\u0300-\u036f]', '')
    $x = [regex]::Replace($x, '[^a-z0-9]+', ' ')
    return ($x -replace '\s+', ' ').Trim()
}

function Es-CategoriaCanonica([string]$c) {
    return ($script:CatCanonicas -contains ([string]$c))
}

function Obtener-CategoriaExacta([string]$Titulo, [string]$Texto) {
    $t = Normalizar-Clave $Titulo
    $cuerpo = Normalizar-Clave $Texto
    $mejor = 'Otros'
    $mejorPuntaje = 0
    foreach ($cat in $script:CatOrden) {
        $puntaje = 0
        foreach ($kw in $script:CatKeywords[$cat]) {
            $k = Normalizar-Clave $kw
            if ($k -eq '') { continue }
            $esFrase = $k.Contains(' ')
            if ($cuerpo -ne '' -and $cuerpo.Contains($k)) { $puntaje += $(if ($esFrase) { 2 } else { 1 }) }
            if ($t -ne '' -and $t.Contains($k)) { $puntaje += $(if ($esFrase) { 6 } else { 3 }) }
        }
        if ($script:CatDebiles.ContainsKey($cat)) {
            foreach ($kw in $script:CatDebiles[$cat]) {
                $k = Normalizar-Clave $kw
                if ($k -eq '') { continue }
                $esFrase = $k.Contains(' ')
                if ($cuerpo -ne '' -and $cuerpo.Contains($k)) { $puntaje += $(if ($esFrase) { 2 } else { 1 }) }
            }
        }
        if ($puntaje -gt $mejorPuntaje) {
            $mejorPuntaje = $puntaje
            $mejor = $cat
        }
    }
    # solo cuerpo (titulo sin keyword): hace falta evidencia real (>= 2)
    if ($mejorPuntaje -lt 2) { return 'Otros' }
    return $mejor
}
