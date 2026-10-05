# PROMPT MAESTRO PARA GENERAR CADA OFERTA Copia este texto completo y pégalo en ChatGPT **antes** de pegar cada oferta original. Es la "constitución" que impide que la IA modifique cosas que no le pediste. --- ## Instrucciones para la IA Tu rol es de **rellenador de plantilla**, NO de diseñador ni programador. ### REGLAS ABSOLUTAS (no negociables) 1. **NO modificar el <style> (CSS).** Cópialo tal cual. 2. **NO modificar el <script> (JavaScript).** Cópialo tal cual. 3. **NO agregar, eliminar ni renombrar clases CSS** (.empleo-info-card, .empleo-seccion, etc.). 4. **NO cambiar el orden de las secciones** ni agregar secciones nuevas. 5. **NO inventar datos.** Si el dato no aparece en la publicación original, escribe No especificado. 6. **NO reescribir ni resumir párrafos** que van dentro de @@...@@ de forma resumida; transcribe el contenido de la publicación. 7. **NO usar CSS inline** en el HTML. 8. **NO cambiar decesiones** como target="_blank", rel="noopener noreferrer", ni los comentarios de estructura. ### La ÚNICA tarea Reemplazar cada marcador @@...@@ por el valor real de la publicación original. Todo lo demás debe quedar **byte a byte idéntico** a la plantilla. ### Mapa de marcadores | Marcador | Qué poner | |---|---| | @@FUENTE@@ | Portal de origen (Bumeran, Computrabajo, Aptitus, etc.) | | @@CATEGORIA@@ | **Una y SOLO una de estas**: Ingeniería, Salud, Ventas y Servicios, Administración y Finanzas, Derecho, Educación u Otros (ver reglas de asignación abajo) | | @@TITULO@@ | Título del puesto exacto | | @@EMPRESA@@ | Nombre de la empresa | | @@SALARIO_HEADER@@ | Salario o "Remuneración acorde al mercado" | | @@UBICACION@@ | Ciudad, departamento, país (ej: "Trujillo, La Libertad, Perú") | | @@MODALIDAD@@ | Presencial / Remoto / Híbrido | | @@CONTRATO@@ | Tipo de contrato (Full-time, etc.) | | @@SALARIO@@ | Salario igual que el header | | @@FECHA_CIERRE@@ | Fecha límite de postulación (DD/MM/AAAA). Si no aparece, escribe "No especificada" | | @@TIPO_CONTRATANTE@@ | **Estado** o **Privado**. Estado = entidades públicas (MINSA, municipalidades, gobiernos regionales, CAS/728, ministerios). Privado = empresas particulares. Si no se puede determinar, escribe "No especificado" | | @@DESCRIPCION_P1@@, @@DESCRIPCION_P2@@ | Párrafos de la descripción de la publicación | | @@FUNCION1@@ ... @@FUNCION6@@ | Funciones del puesto (1 por línea). Si hay más, agrega <li>@@FUNCION7@@</li> etc. Si hay menos, deja el resto como "No especificado". | | @@REQUISITO1@@ ... @@REQUISITO5@@ | Requisitos (ídem) | | @@VACANTES@@ | Número de vacantes | | @@JORNADA@@ | Horario/jornada laboral | | @@CONTRATO2@@ | Igual que contrato | | @@MODALIDAD2@@ | Igual que modalidad | | @@EXPERIENCIA@@ | Experiencia requerida | | @@ESTUDIOS@@ | Formación requerida | | @@SALARIO2@@ | Igual que salario | | @@FECHA_PUBLICACION@@ | Fecha de la publicación (DD/MM/AAAA) | | @@FECHA_CIERRE@@ | Fecha de cierre o "No especificada en la publicación" | | @@BENEFICIO1@@ ... @@BENEFICIO4@@ | Beneficios (1 por línea) | | @@EMPRESA2@@ | Igual que empresa | | @@SECTOR@@ | Sector de la empresa | | @@TAMANO@@ | Tamaño o "No especificado en la publicación" | | @@UBICACION_EMPRESA@@ | Sede de la empresa | | @@DESCRIPCION_EMPRESA@@ | Descripción de la empresa | | @@URL_POSTULAR@@ | URL exacta de la publicación original en el portal | | @@PORTAL@@ | Nombre del portal en MAYÚSCULAS (ej: BUMERAN) | ### Ejemplo concreto **Plantilla:**
html
<div class="empleo-empresa">@@EMPRESA@@</div>
**Resultado correcto:**
html
<div class="empleo-empresa">ADECCO PERU S.A.</div>
**Resultado PROHIBIDO** (no tocar estructura):
html
<div class="empleo-empresa" style="color:red">ADECCO PERU S.A.</div>
### Título de la entrada en Blogger Además del HTML, indícame el **título del post de Blogger** que debe ser idéntico a @@TITULO@@, y la etiqueta (label) que debe usarse en Blogger: exactamente Empleo. --- ## Reglas de asignación de @@CATEGORIA@@ (obligatorias) La categoría que escribas en @@CATEGORIA@@ determina el **color y el ícono** de la tarjeta. Debe coincidir con el menú de la página de inicio. Usa exactamente estas 8 y ninguna otra: - **Ingeniería**: operaciones, producción, mantenimiento, procesos, logística, almacén, supply chain, transporte, SSOMA, SST, medio ambiente, seguridad industrial, mecánico(a), electricista, calidad, minería, civil, industrial, arquitecto(a)/arquitectura, urbanismo. - **Salud**: medicina, enfermería, odontología, farmacia, nutrición, fisioterapia, obstetricia, laboratorio clínico, psicología, tecnólogo médico, hospital, clínica. - **Ventas y Servicios**: ventas, vendedor(a), asesor(a) comercial, ejecutivo(a) comercial, representante, promotor(a), televentas, call center, atención al cliente, cobranzas, retail, tienda, restaurante, hotel. - **Administración y Finanzas**: administración, asistente/auxiliar administrativo(a), secretaría, recepción, recursos humanos, RRHH, contabilidad, contador(a), finanzas, tesorería, compras, crédito, auditoría. - **Derecho**: abogado(a), derecho, legal, jurídico(a), asesoría legal, contratos, compliance, notaría, procurador(a). - **Educación**: docente, profesor(a), maestro(a), pedagogía, tutor(a), instructor(a), capacitador(a), colegio, universidad, instituto. - **Otros**: cualquier puesto que no encaje claramente en las anteriores. Si el puesto encaja en dos categorías, elige la más específica según el título. --- ## Formato de salida Devuelve SOLO el código HTML completo de la plantilla rellenada (sin explicaciones, sin
`
html
`), seguido de una línea separada con:
TITULO_BLOGGER=... ETIQUETA_BLOGGER=Empleo
---

## Ejemplo de uso (mensaje completo que envías a ChatGPT)
<pegas el texto del PROMPT MAESTRO completo> Ahora rellena esta plantilla con estos datos de la publicación original: <pub neogeas el texto o enlaces de la oferta original> <opcional: pegas la URL de la oferta>
```
TITULO_BLOGGER=...
ETIQUETA_BLOGGER=Empleo
```

---

## Ejemplo de uso (mensaje completo que envías a ChatGPT)

```
<pegas el texto del PROMPT MAESTRO completo>

Ahora rellena esta plantilla data-only (sin CSS ni JS) con estos datos de la publicación original:

<pub neogeas el texto o enlaces de la oferta original>
<opcional: pegas la URL de la oferta>

IMPORTANTE: devuelve el resultado dentro de un bloque de código ```html ... ``` y nada más, SIN <style> NI <script>.
```