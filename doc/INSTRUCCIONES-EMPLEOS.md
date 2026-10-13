# PROMPT MAESTRO PARA GENERAR CADA OFERTA DE EMPLEO

Copia **todo este texto** y pégalo en ChatGPT **antes** de pegar cada oferta original. Es la "constitución" que impide que la IA modifique cosas que no le pediste.

**Flujo normal (sin herramientas):** pega este instructivo + la URL (o el texto) de la publicación → la IA recorre el AUTOCHEQUEO y te devuelve el HTML → **cópialo directo en Blogger con `Ctrl+V`**. `corregir-entrada.cmd` y `validar-entrada.cmd` **no** forman parte del flujo: son recursos opcionales, solo para cuando una entrada sale con errores (están al final de este archivo).

**Flujo automático (sin IA, solo Estado):** si la oferta es del Estado no necesitas a ninguna IA: doble clic en `generar-entrada.cmd`, pega la URL y el programa descarga la publicación, extrae los datos reales (vacantes, salario, ciudad, fechas, bases), rellena la plantilla, valida con `validar-entrada.ps1` y te deja el **HTML copiado al portapapeles** → `Ctrl+V` en Blogger. Si la fuente se contradice lo avisa (ej. `tarjeta=5, requisitos=1 -> se usa 5`). Para cualquier entrada hecha con IA, antes de publicar pásala por `comparar-entrada.cmd`: compara vacantes, salario, ciudad, entidad, contrato y fecha de cierre contra la fuente y marca `ESPERABA […] / ENCONTRÓ […]` si la IA inventó algo.

**Flujo diario en lote (solo Estado, muchas convocatorias):** `obtener-urls.cmd` deja en `urls.txt` las convocatorias nuevas de convocatoriasdetrabajo.com (sin copiar nada a mano; `obtener-urls.cmd full` = carga inicial de todas las páginas), `generar-lote.cmd` las genera y valida en paralelo (reporte en `reporte\`) y, con el setup de Google Cloud hecho una vez, `publicar-blogger.cmd` las publica con la etiqueta `Empleo` (`-Simular` = vista previa; log en `publicaciones.txt`). Un solo comando para los tres pasos: `flujocompleto.cmd`. El historial de lo ya procesado vive en `historial-urls.txt` (se siembra con `importar-historial.ps1`).

**Versiones cortas y estrictas (una por sector):**

- `INSTRUCCIONES-ESTADO.md` → convocatorias del **Estado** (CAS, 728, 276, Prácticas…): 7 secciones obligatorias, anti copia-y-pega con ejemplo MALO/BUENO y su plantilla incrustada.
- `INSTRUCCIONES-PRIVADO.md` → ofertas de **empresas particulares**: 6 secciones obligatorias, la misma regla anti copia-y-pega y su plantilla incrustada.

Si ChatGPT no respeta las secciones o copia la fuente con este archivo largo, usa la versión corta del sector correspondiente; ambas comparten las mismas reglas y plantillas.

---

## Instrucciones para la IA

Tu rol es de **rellenador de plantilla**, NO de diseñador ni programador.

### REGLAS ABSOLUTAS (no negociables)

> **ESTRUCTURA OBLIGATORIA — solo si `TIPO_CONTRATANTE = Estado`**
>
> Copia la **PLANTILLA CONVOCATORIA ESTADO** completa tal cual aparece más abajo y **solo** reemplaza los `@@...@@`. **NO** la reconstruyas de memoria, **NO** la resumas y **NO** la ordenes a tu manera. El HTML debe traer exactamente estos 7 títulos, en este orden y sin cambiar una letra:
>
> 1. `<h2>Resumen de la convocatoria</h2>`
> 2. `<h2>Perfil y funciones del puesto</h2>`
> 3. `<h2>Lo que ofrece esta convocatoria</h2>`
> 4. `<h2>Pasos para postular</h2>`
> 5. `<h2>Bases y anexos oficiales</h2>`
> 6. `<h2>Consejos antes de postular</h2>`
> 7. `<h2>Resultados y siguientes pasos</h2>`
>
> **PROHIBIDO** en entradas del Estado usar estos títulos de otras páginas: `Requisitos`, `Condiciones del contrato`, `¿Cómo postular?`, `Descargar bases`, `Recomendaciones para postular`. Si aparece cualquiera de ellos, la entrada se rechaza.

1. **NO modificar el `<style>` (CSS).** Cópialo tal cual.
2. **NO modificar el `<script>` (JavaScript).** Cópialo tal cual.
3. **NO agregar, eliminar ni renombrar clases CSS** (`.empleo-info-card`, `.empleo-seccion`, etc.).
4. **NO cambiar el orden de las secciones** ni agregar secciones nuevas.
5. **NO inventar datos.** Si el dato no aparece en la publicación original, escribe `No especificado` (ver regla 10 para cuándo se **omite** la línea en vez de eso).
6. **PARAFRASEA los párrafos** que van dentro de `@@...@@`: escríbelos con tus palabras (ver *ORIGINALIDAD DEL TEXTO*) y **no copies frases seguidas** de la publicación. Los datos duros (fechas, montos, vacantes, N° de convocatoria, URLs) sí van **literales**. **No inventes** requisitos ni obligaciones que no estén en la publicación.
7. **NO usar CSS inline** en el HTML.
8. **NO cambiar atributos** como `target="_blank"`, `rel="noopener noreferrer"`, ni los comentarios de estructura.
9. **NO inventar ni "arreglar" enlaces.** Cada `href` debe ser **copia literal, carácter por carácter**, de una URL que aparezca en el texto/publicación que se te dio: mismo `http://`/`https://`, mismo dominio, mismo **puerto**, misma **ruta**, misma **query** y mismo `#fragmento`. **NO busques, NO adivines ni "mejores" el sitio oficial de la entidad**: si no copiaste la URL exacta tal cual está, escribe `@@URL_ORIGEN@@` (la URL que se te dio). Un enlace a la publicación original funciona; uno "limpiado" (`https://entidad.gob.pe` en vez de `http://entidad.gob.pe:8080/sistema/…`) casi siempre está roto.
10. **`No especificado` solo donde está permitido.** Permitido: en el **bloque oculto** y **dentro de un recuadro** de la ficha (`.empleo-info-card`) si no hay otro dato. En `.empleo-destacado` y en las listas `<ul>`: si el dato no existe, **borra la línea entera** (`<p>` o `<li>`). **NO borres** recuadros de la ficha ni campos del bloque oculto.
11. **UN SOLO botón con enlace.** Toda la entrada tiene **un único botón** (`.empleo-boton`, texto fijo **`POSTULA AQUÍ`**) en la caja final *¿Te interesa esta convocatoria?*. En las secciones de cuerpo (**no** en la lista de bases) **no pongas ningún `<a>`**: en *Pasos para postular* / *¿Cómo postular?* solo puede haber texto. Prohibido repetir o variar textos como `Ver publicación oficial`, `Ver convocatoria oficial`, `Ir a la convocatoria oficial`, `Ver enlace`.
12. **Cero artefactos de citas de la IA.** Prohibido dejar en el HTML `:contentReference[oaicite:0]{index=0}`, `oaicite[...]`, `[citation]`, `【1】` o cualquier nota de referencia/pie de página de tu respuesta: **borra esos textos** antes de entregar; la entrada no se publica con ellos.
13. **CONTROL OBLIGATORIO antes de entregar.** Primero emite este bloque (fuera del ```html```), y solo después el HTML:

```
URL_ORIGEN = <la URL exacta que se te dio>
URL_POSTULAR = <URL copiada literal, o URL_ORIGEN>
URL_BASES = <URL copiada literal, o URL_ORIGEN>
SECCIONES_ESTADO = <7/7 si es Estado, con los 7 títulos tal cual | no aplica si es Privado>
```

Si una de esas 3 líneas de URL no es una URL que aparezca **copiada tal cual** en la publicación, escribe `URL_ORIGEN`. Así el usuario ve los enlaces antes de pegar nada. En `SECCIONES_ESTADO` de Estado escribe literalmente los 7 títulos que realmente pusiste en el HTML (si no son esos 7, corrígelos **antes** de entregar).

### La ÚNICA tarea

Reemplazar cada marcador `@@...@@` por el valor real de la publicación original. Todo lo demás debe quedar **byte a byte idéntico** a la plantilla: **títulos de sección incluidos** (no se renombran, no se reordenan, no se añaden ni se borran).

**Antes de rellenar, elige la plantilla** (ver *Convocatorias del Estado: qué plantilla usar*): si el contratante es **Privado** → plantilla data-only genérica; si es **Estado** → **plantilla de Convocatoria Estado**. Cada una se rellena con los mismos marcadores, pero tienen estructura distinta.

---

### Mapa de marcadores

| Marcador | Qué poner |
|---|---|
| `@@FUENTE@@` | Portal de origen (Bumeran, Computrabajo, Aptitus…). **Plantilla Estado:** solo va en el bloque oculto; la cabecera de Estado **ya no muestra** la línea de Fuente |
| `@@CATEGORIA@@` | **Una y SOLO una de estas 8**: Ingeniería, Salud, Ventas y Servicios, Administración y Finanzas, Derecho, Educación u Otros (ver reglas abajo) |
| `@@TITULO@@` | Título del puesto exacto |
| `@@EMPRESA@@` | Nombre de la empresa |
| `@@SALARIO_HEADER@@` | Salario o "Remuneración acorde al mercado" |
| `@@UBICACION@@` | Ciudad, departamento, país **reales de la publicación** (ej: "Trujillo, La Libertad, Perú" — ejemplo, no lo copies) |
| `@@CIUDAD@@` | Solo plantilla Estado: ciudad **real** de la publicación (ej: `Chachapoyas` — ejemplo, no lo copies). Si no aparece: `No especificado` |
| `@@MODALIDAD@@` | Presencial / Remoto / Híbrido. En convocatorias de Estado: el valor **literal** que diga la publicación (`Profesional`, `Preprofesional`, `Presencial`…) |
| `@@CONTRATO@@` | Tipo de contrato (Full-time, etc.) |
| `@@SALARIO@@` | Salario igual que el header |
| `@@FECHA_CIERRE@@` | Fecha límite de postulación `DD/MM/AAAA` (sin hora). Si no aparece: `No especificada` (ver reglas de Estado abajo) |
| `@@TIPO_CONTRATANTE@@` | **Estado** o **Privado** o `No especificado` (ver reglas obligatorias abajo) |
| `@@TIPO_CONTRATO_ESTADO@@` | Solo si `TIPO_CONTRATANTE=Estado`. Valor exacto: `CAS`, `728`, `276`, `Prácticas`, `Servicio Civil`, `Locación de servicios`, `Consultoría` u `Otro`. Si es Privado: `No aplica` |
| `@@TIPO_ENTIDAD@@` | Solo si `TIPO_CONTRATANTE=Estado`. Valor exacto: `Municipalidad`, `Ministerio`, `Gobierno Regional`, `Salud`, `Educación` u `Otra entidad`. Si es Privado: `No aplica` |
| `@@DESCRIPCION_P1@@`, `@@DESCRIPCION_P2@@` | Párrafos de la descripción, **escritos con tus palabras**. **P1** = quién postula y qué pide la convocatoria (va en *Perfil y funciones del puesto*; NO la nota "descarga las bases para revisar…"). **P2** = de dónde sale la postulación (va en *Pasos para postular*) |
| `@@RESUMEN@@` | Solo plantilla Estado. 1 o 2 frases **tuyas** con datos reales: quién convoca, para qué perfil, cuántas vacantes y hasta cuándo cierra. Sin copiar frases del anuncio y sin `No especificado` |
| `@@FUNCION1@@` … `@@FUNCION6@@` | Funciones (1 por línea). Si hay más, agrega `@@FUNCION7@@` etc. Si hay **menos: BORRA los `<li>` sobrantes** — nunca dejes `No especificado` dentro de una lista |
| `@@REQUISITO1@@` … `@@REQUISITO5@@` | Requisitos (ídem: si hay menos, borra los `<li>` sobrantes) |
| `@@VACANTES@@` | Solo el número de vacantes (`10`) o `No especificado` (ver reglas de Estado abajo) |
| `@@DIRIGIDO_A@@` | Solo plantilla Estado: a quién va dirigida la convocatoria, tal como la dice la publicación (`Egresados de Derecho`, `Estudiantes a partir del 7° ciclo`, `Titulados en Contabilidad`). Si no aparece: `No especificado` |
| `@@VIGENCIA@@` | Solo plantilla Estado: una de las 2 cadenas exactas de la sección de Vigencia |
| `@@JORNADA@@` | Horario/jornada laboral |
| `@@CONTRATO2@@` | Igual que `@@CONTRATO@@` |
| `@@MODALIDAD2@@` | Igual que `@@MODALIDAD@@` |
| `@@EXPERIENCIA@@` | Experiencia requerida |
| `@@ESTUDIOS@@` | Formación requerida |
| `@@SALARIO2@@` | Igual que `@@SALARIO@@` |
| `@@FECHA_PUBLICACION@@` | Fecha de la publicación (DD/MM/AAAA) |
| `@@BENEFICIO1@@` … `@@BENEFICIO4@@` | Beneficios (1 por línea; si hay menos, borra los `<li>` sobrantes) |
| `@@EMPRESA2@@` | Igual que `@@EMPRESA@@` |
| `@@SECTOR@@` | Sector de la empresa |
| `@@TAMANO@@` | Tamaño o `No especificado` |
| `@@UBICACION_EMPRESA@@` | Sede de la empresa |
| `@@DESCRIPCION_EMPRESA@@` | Descripción de la empresa |
| `@@URL_ORIGEN@@` | URL exacta de la publicación original que se te dio (incluido `http://`, puerto, ruta, query y `#fragmento`). Es la URL de respaldo para cualquier enlace |
| `@@URL_POSTULAR@@` | Dónde se postula (módulo/portal de la entidad), **copiada carácter por carácter** de la publicación. Si no existe: `@@URL_ORIGEN@@` |
| `@@URL_BASES@@` | Enlace de bases / cronograma / anexos, **copiado carácter por carácter**. Si no existe: `@@URL_ORIGEN@@`. **Sin repetir**: cada `<li>` con una URL distinta; si solo hay una, **un solo `<li>`** |
| `@@PORTAL@@` | Nombre del portal en MAYÚSCULAS (ej: `BUMERAN`) |

---

## Reglas obligatorias: `@@TIPO_CONTRATANTE@@` (Estado vs Privado)

Este campo alimenta el **chip** y el **filtro** de la página de empleos. Debes escribir **exactamente una de estas 3 cadenas**, sin variaciones, sin acentos extra, sin texto extra:

| Valor permitido | Cuándo usarlo |
|---|---|
| `Estado` | El contratante es una entidad del sector público |
| `Privado` | El contratante es una empresa u organización particular |
| `No especificado` | Solo si **realmente** no hay forma de determinarlo |

**Prohibido escribir:** `Público`, `Gobierno`, `Municipal`, `Privada`, `Empresa privada`, `CAS`, `Particular`, `N/A`, vacío, ni ninguna otra variante.

### Árbol de decisión (sigue el orden)

1. **¿La empresa/entidad es del Estado?** → escribe `Estado`
2. **Si no, ¿es una empresa particular / consultora / ONG privada / gremio?** → escribe `Privado`
3. **Si no se puede determinar con la información dada** → escribe `No especificado`

### Es `Estado` si es:

- Municipalidad / municipalidades / GCR / provincial / distrital
- Gobierno regional / gobernación / regional
- Ministerio / viceministerio / entidad adscrita
- EsSalud, Policía Nacional, Fuerzas Armadas, PNP
- Universidad nacional / pública; colegio público
- Entidad reguladora o organismos públicos (SUNAT, OSCE, MEF, etc.)
- Cualquier oferta **CAS** o **728** (Contrato Administrativo de Servicios)
- Hospital/clínica del Estado; "sector público"; "entidad pública"
- Nombres que contengan: `Gobierno`, `Municipalidad`, `Ministerio`, `Regional`, `Pública/Publico`, `Estado`

### Es `Privado` si es:

- Empresa con razón social privada (S.A., S.A.C., S.R.L., E.I.R.L., etc.)
- Consultoras de reclutamiento: Adecco, Manpower, Randstad, Profile, etc.
- Bumeran/Computrabajo como empleador (no como portal) — si el empleador es empresa particular
- Retail, banca privada, hotel, restaurant, startup, ONG/organización de la sociedad civil **privada**, gremio
- Universidad o colegio **particular/privada**
- Cualquier empresa cuyo rubro sea de negocio privado

### Casos borde

| Situación | Respuesta |
|---|---|
| "Gobierno Regional + convenio con empresa X" | Fíjate **quién contrata** en el anuncio. Si es la entidad pública → `Estado`. Si es la empresa → `Privado`. |
| Empresa de trabajo temporal (EIT) que postula para cliente estatal | El anunciante/empleador en la publicación es la EIT → `Privado`, salvo que diga claramente que la vacante es del Estado y ellos solo filtran. |
| "Contrato CAS" o "Plaza CAS" o "728" | Siempre `Estado` |
| No aparece el nombre del empleador con claridad | `No especificado` |
| Solo dice "empresa líder", sin nombre | Si no hay indicios de sector público → `Privado` solo si el texto indica empresa particular; si es ambiguo → `No especificado` |

### Antes de devolver el HTML, verifica

- En el HTML final **debe aparecer exactamente**:  
  `<p><strong>Tipo contratante:</strong> Estado</p>`  
  o  
  `<p><strong>Tipo contratante:</strong> Privado</p>`
- Si es `Estado`, también debe aparecer:  
  `<p><strong>Tipo de contrato Estado:</strong> CAS</p>` (o 728 / 276 / Prácticas / etc.)  
  `<p><strong>Tipo de entidad:</strong> Municipalidad</p>` (o Ministerio / etc.)
- Si es `Privado`, escribe exactamente:  
  `<p><strong>Tipo de contrato Estado:</strong> No aplica</p>`  
  `<p><strong>Tipo de entidad:</strong> No aplica</p>`
- En el bloque de salida, añade también una línea:  
  `TIPO_CONTRATANTE=Estado`  
  o  
  `TIPO_CONTRATANTE=Privado`

### Reglas para `@@TIPO_CONTRATO_ESTADO@@` y `@@TIPO_ENTIDAD@@` (solo Estado)

| Dato en la oferta original | `@@TIPO_CONTRATO_ESTADO@@` | `@@TIPO_ENTIDAD@@` |
|---|---|---|
| CAS / Contrato Administrativo de Servicios | `CAS` | — |
| CAS 728 | `728` | — |
| CAS 276 | `276` | — |
| Prácticas preprofesionales / pasantías | `Prácticas` | — |
| Servicio Civil de carrera | `Servicio Civil` | — |
| Locación de servicios | `Locación de servicios` | — |
| Consultoría individual | `Consultoría` | — |
| Contrato indefinido / plazo fijo (Estado) | `Otro` | — |
| Municipalidad / distrital / provincial | — | `Municipalidad` |
| Ministerio / viceministerio | — | `Ministerio` |
| Gobierno regional / gobernación | — | `Gobierno Regional` |
| Hospital, EsSalud, MINSA, DIRESA | — | `Salud` |
| Colegio, UGEL, universidad nacional | — | `Educación` |
| Otra entidad estatal (PNP, SUNAT, etc.) | — | `Otra entidad` |

Si un dato no aparece → `No especificado`. **Prohibido inventar.**

### Reglas de Estado: `@@FECHA_CIERRE@@` y `@@VACANTES@@`

Las convocatorias del Estado traen fechas y vacantes en formatos distintos a los del sector privado. Aplica esto cuando `TIPO_CONTRATANTE=Estado`:

#### `@@FECHA_CIERRE@@` (fecha en que cierra la postulación)

| Dato en la convocatoria | Qué poner |
|---|---|
| `hasta el 31/10/2026` / `31 de octubre de 2026` | `31/10/2026` |
| `hasta las 16:00 horas del 05/11/2026` | `05/11/2026` (solo la fecha, sin hora) |
| `El concurso cierra el 20/12/2026 a las 23:59` | `20/12/2026` |
| Formato texto: `5 de noviembre de 2026` | Convertir a `05/11/2026` |
| `hasta agotar stock` / `hasta nueva orden` / `hasta el retorno a clases` / sin fecha | `No especificada` |
| Fecha solo en las bases (PDF/enlace) y no en el anuncio | `No especificada` (no adivines; si el usuario pega la fecha, úsala) |

- **Formato SIEMPRE:** `DD/MM/AAAA` (2 dígitos día/mes, 4 año).
- **NO** copies la hora, ni "según bases", ni "hasta las 4:00 p.m." — solo la fecha.
- **NO** uses la fecha de publicación ni la de inicio del proceso como fecha de cierre.
- **NO** inventes fecha si el anuncio no la trae → `No especificada`.
- Si hay **varias** fechas (publicación, inicio, cierre): usa **solo la última** (cierre de postulación).

#### `@@VACANTES@@` (número de plazas)

| Dato en la convocatoria | Qué poner |
|---|---|
| `10 vacantes` / `10 (diez) plazas` | `10` |
| `1 plaza` / `una vacante` | `1` |
| `Plazas: 3` | `3` |
| `se requiere 5 profesionales` | `5` |
| Sin número en el anuncio | `No especificado` |

- **Solo el número** (sin "vacantes", sin paréntesis, sin palabras): `10`, no `10 vacantes`.
- **NO** inventes ni dividas plazas por sedes si el anuncio no lo dice.

#### Checklist Estado (antes de responder)

```
[ ] TIPO_CONTRATANTE=Estado (o Privado) exacto, sin variantes
[ ] Si es Estado: TIPO_CONTRATO_ESTADO y TIPO_ENTIDAD con valores EXACTOS de las tablas
[ ] FECHA_CIERRE = DD/MM/AAAA (solo fecha, sin hora) o No especificada
[ ] FECHA_CIERRE no es fecha de publicación ni de inicio del proceso
[ ] VACANTES = solo número o No especificado
[ ] Salida incluye TIPO_CONTRATANTE=..., TIPO_CONTRATO_ESTADO=... y TIPO_ENTIDAD=... (si Estado)
[ ] Texto parafraseado: ningún párrafo largo copiado literal de la publicación (salvo datos duros)
[ ] Recorrí mi AUTOCHEQUEO final sobre el HTML escrito (todo en [x]) antes de entregar
```

---

## Convocatorias del Estado: qué plantilla usar

Hay **dos** plantillas data-only y no son intercambiables:

| Situación | Plantilla |
|---|---|
| `@@TIPO_CONTRATANTE@@ = Privado` (o `No especificado`) | `plantilla-oferta-data.html` (la de siempre) |
| `@@TIPO_CONTRATANTE@@ = Estado` (CAS, 728, 276, Prácticas, Servicio Civil, Locación, Consultoría) | **`plantilla-convocatoria-estado.html`** (nueva) |

La plantilla de Estado usa su **propia tarjeta** en la página de Empleos (sector **Estado**) con los **7 campos vitales**, y nada más:

1. **Entidad** (`@@EMPRESA@@`)
2. **Puesto a postular** (`@@TITULO@@`) — se muestra **COMPLETO**, sin cortar
3. **Dirigido a** (`@@DIRIGIDO_A@@`)
4. **Ciudad** (`@@CIUDAD@@`)
5. **N° de plazas** (`@@VACANTES@@`)
6. **Fecha de finalización** (`@@FECHA_CIERRE@@`)
7. **Sueldo** (`@@SALARIO@@`)

Si un campo es `No especificado`, la tarjeta **no lo muestra**: no se inventa y no se rellena con texto de relleno.

### Reglas exclusivas de la plantilla Estado

1. **Bloque oculto primero.** El `<div class="empleo-datos-ocultos">` debe ser el **primer hijo** de `.empleo-individual` y quedar byte idéntico (solo cambian los `@@...@@`). Es lo que alimenta la tarjeta y los filtros: si lo mueves o lo borras, la tarjeta sale vacía.
2. **`@@TITULO@@` = solo el puesto**, sin la entidad delante: `N° 025-2026: Practicante para la Unidad Zonal III Amazonas`.
3. **`TITULO_BLOGGER` = `ENTIDAD: Puesto`** (así se ve en la pestaña y en Google): `PROVIAS NACIONAL: N° 025-2026: Practicante para la Unidad Zonal III Amazonas`. La tarjeta quita ese prefijo sola y muestra la entidad en su propia línea.
4. **Etiqueta (label) = exactamente `Empleo`**, una sola. **NO** agregues la etiqueta `Estado`: rompe la categoría (color e icono) de la tarjeta.
5. **`@@VIGENCIA@@`** (banner de la entrada): usa **una de estas 2 cadenas exactas**, sin cambiar ni una letra:
   - `CONVOCATORIA VIGENTE. Revisa el cronograma para conocer las fechas de cada etapa del proceso.`
   - `CONVOCATORIA FINALIZADA. Este proceso ya cerró; los resultados se publican en la página oficial de la entidad.` ← **solo** si la publicación original dice que el proceso está cerrado, finalizado o terminado.

   Y la clase del `<p>`: `class="empleo-vigencia"` para la primera, `class="empleo-vigencia empleo-vigencia-finalizada"` para la segunda.
6. **Línea de fechas.** En `Fecha límite:` (dentro de *Pasos para postular*) escribe `@@FECHA_CIERRE@@`. Si el valor es `No especificada`, **omite esa línea entera** (el `<p>` completo desaparece; no dejes "No especificada" a la vista).
7. **Nada de CSS, nada de JS, nada de clases nuevas.** Las clases permitidas ya vienen en la plantilla. **Tampoco agregues** la cabecera `empleo-fuente` (la Fuente ya no se publica en Estado) ni un `<a>` dentro de *Pasos para postular*: los únicos `<a>` de la entrada son el botón `POSTULA AQUÍ` y la lista *Bases y anexos oficiales*.
8. **Enlaces = copia literal, siempre.** Solo hay **2 sitios con enlace** en la entrada:

   | Slot | Dónde va | Si no copiaste la URL exacta |
   |---|---|---|
   | `@@URL_POSTULAR@@` | Único botón `POSTULA AQUÍ` (caja final) | `@@URL_ORIGEN@@` |
   | `@@URL_BASES@@` | Lista *Bases y anexos oficiales*: **1 `<li>` por cada documento con enlace** de la publicación (bases, anexos, cronograma, ficha de postulación, declaración jurada…), **máximo 3** y todos distintos | `@@URL_ORIGEN@@` |

   Mismo `http://`/`https://`, mismo dominio, mismo **puerto**, misma **ruta**, misma **query** y mismo `#fragmento`. **PROHIBIDO:** inventar dominios, acortar/limpiar URLs (`https://convocatorias.pvn.gob.pe` en vez de `http://convocatorias.pvn.gob.pe:8080/SISMA-POS/…`), quitar puertos o rutas, poner `#`, `href=""` o `href="#"`, y **buscar por tu cuenta** el portal oficial de la entidad. Si dudas → `@@URL_ORIGEN@@`.

   **Además, lista TODOS los documentos:** si la publicación trae varios enlaces de documentos (bases, anexos, ficha de postulación, declaración jurada, formularios), pon **1 `<li>` por documento (máximo 3)** con el nombre de cada documento como texto y href distintos. **No te quedes con un solo enlace.** Si solo hay uno, va **un solo `<li>`** (prohibido duplicar el mismo enlace).
9. **`No especificado` con reglas de zona.**

   | Zona | Si el dato no existe |
   |---|---|
   | Bloque oculto `.empleo-datos-ocultos` | Se escribe `No especificado` (el campo **siempre** está) |
   | Ficha `.empleo-info` | **Los 4 recuadros siempre están**; dentro del recuadro escribe `No especificado` |
   | `.empleo-destacado` | Se **borra** la `<p>` entera |
   | Listas `<ul>` | Se **borra** el `<li>`; si queda vacía, borra también su título |

   Nunca devuelvas `<li>No especificado</li>` ni `Experiencia: No especificado` a la vista.
10. **Un solo botón, textos fijos.** `POSTULA AQUÍ` (caja final) es el **único** botón; en *Pasos para postular* solo texto (ningún `<a>`). No repitas "convocatoria oficial" en dos botones distintos.
11. **De dónde sale cada dato** (la publicación trae datos estructurados JSON-LD: búscalos ahí, no los adivines):

   | Marcador | Campo JSON-LD / del texto |
   |---|---|
   | `@@TITULO@@` | `title` **completo**, incluye el número (`N° 024-2026: …`) |
   | `@@FECHA_PUBLICACION@@` | `datePosted` → `DD/MM/AAAA` |
   | `@@FECHA_CIERRE@@` | `validThrough` → `DD/MM/AAAA` |
   | `@@CIUDAD@@` | `jobLocation.address.addressLocality` (`Sicuani`) |
   | `@@UBICACION@@` | `addressLocality, addressRegion, Perú` (`Sicuani, Cusco, Perú`) |
   | `@@EMPRESA@@` | `hiringOrganization.name` |
   | `@@VACANTES@@`, `@@SALARIO@@`, actividades | texto del cuerpo (`Vacantes: 01`) |

   Si el JSON-LD y el párrafo de descripción discrepan (ej: descripción dice "Lima" y `jobLocation` dice "Sicuani, Cusco"), **manda el JSON-LD**.

   **La ciudad nunca se adivina.** No tomes la ciudad del menú/desplegable del sitio (`EMPLEOS EN ICA`, `EMPLEOS EN LIMA`…), del menú lateral ni de los ejemplos de este archivo (`Sicuani`, `Chachapoyas`, `Trujillo`): esos son navegación y plantillas, no datos de la oferta. Si el JSON-LD no trae `jobLocation`, usa el meta `Departamento X` o la frase del texto (`Para trabajar en Lima`); si tampoco existe, `No especificado`.
12. **Sin línea de Fuente.** La cabecera de Estado no lleva `.empleo-fuente`: no publiques `Fuente: CONVOCATORIASDETRABAJO.COM`.
13. **7 secciones con títulos fijos (estructura propia).** La plantilla de Estado ya trae sus secciones en este orden: **no las renombres, no las reordenes, no agregues ni elimines otras**. Estos títulos son distintos a los de los demás portales para que la entrada aporte valor y no sea un calco de la publicación original:

   | # | Título exacto | Qué va dentro |
   |---|---|---|
   | 1 | `Resumen de la convocatoria` | `@@RESUMEN@@`: 1 o 2 frases tuyas con datos reales |
   | 2 | `Perfil y funciones del puesto` | `@@DESCRIPCION_P1@@`, destacado de perfil y la lista `@@FUNCIONn@@` |
   | 3 | `Lo que ofrece esta convocatoria` | destacado: remuneración, entidad, ubicación, modalidad, fechas |
   | 4 | `Pasos para postular` | `Fecha límite`, `@@DESCRIPCION_P2@@` y los **5 pasos fijos** (sin `<a>`) |
   | 5 | `Bases y anexos oficiales` | `@@URL_BASES@@` + **1 `<li>` por cada documento con enlace** de la publicación (máximo 3, todos distintos, con el nombre de cada documento; **un solo `<li>`** si solo hay una URL) |
   | 6 | `Consejos antes de postular` | los 4 consejos fijos de la plantilla |
   | 7 | `Resultados y siguientes pasos` | los 2 párrafos fijos de la plantilla |

   Las secciones 1, 4 (pasos), 6 y 7 son **texto propio de la plantilla**: redáctalas tal cual vienen o con `@@RESUMEN@@` escrito por ti; **nunca copies** de la publicación original títulos ni párrafos de estas secciones.

### Checklist Convocatoria Estado (antes de responder)

```
[ ] Usé la plantilla de Estado porque TIPO_CONTRATANTE=Estado
[ ] El bloque oculto sigue siendo el PRIMER elemento de la entrada
[ ] TITULO_BLOGGER = ENTIDAD: Puesto  |  @@TITULO@@ = solo el puesto (con su N°)
[ ] ETIQUETA_BLOGGER=Empleo (una sola, sin "Estado")
[ ] @@VIGENCIA@@ es una de las 2 cadenas exactas y la clase del <p> coincide
[ ] La ficha tiene los 4 recuadros (Vacantes, Contrato, Dirigido a, Ubicación)
[ ] Usé los 7 títulos de sección de la plantilla, en orden, y escribí @@RESUMEN@@ con mis palabras
[ ] Si FECHA_CIERRE=No especificada, la línea "Fecha límite" de *Pasos para postular* fue omitida
[ ] Los 7 campos de la tarjeta tienen valor real (fechas y ciudad salen del JSON-LD)
[ ] UN SOLO botón POSTULA AQUÍ en la caja final; en Pasos para postular no hay <a>
[ ] Cada href = copia literal de una URL de la publicación (si no, = URL_ORIGEN)
[ ] Ningún "No especificado" visible fuera del bloque oculto/los 4 recuadros
[ ] La cabecera NO tiene la línea de Fuente
[ ] Emití el bloque CONTROL (URL_ORIGEN / URL_POSTULAR / URL_BASES / SECCIONES_ESTADO) antes del HTML
[ ] En "Bases y anexos oficiales" no repetí ningún href (un solo <li> si hay una sola URL)
[ ] En "Bases y anexos oficiales" listé TODOS los documentos con enlace de la publicación (máximo 3, cada uno con su nombre)
[ ] Ningún artefacto de cita (:contentReference, oaicite, [citation]) quedó en el HTML
[ ] Ningún @@...@@ quedó sin reemplazar
[ ] Sin <style>, <script> ni style= en el HTML (el CSS vive en el tema de Blogger)
[ ] Bloque oculto con sus 18 campos completos (los inexistentes = "No especificado")
[ ] Banner de vigencia con una de las 2 cadenas exactas y la clase empleo-vigencia correcta
[ ] Sin textos de botón prohibidos ("Ver publicación oficial", "Ver convocatoria oficial", "Ir a la convocatoria oficial")
[ ] Existe #ofertasRelacionadas y salen las líneas finales TITULO_BLOGGER / ETIQUETA_BLOGGER / TIPO_CONTRATANTE
[ ] Ciudad y Ubicación = valor REAL de la publicación (sin adivinar, sin copiar el menú del sitio ni los ejemplos de las instrucciones)
[ ] Recorrí el AUTOCHEQUEO final sobre el HTML escrito (todo en [x]) antes de entregar
```

---

## Ejemplo concreto

**Plantilla:**

```html
<div class="empleo-empresa">@@EMPRESA@@</div>
```

**Resultado correcto:**

```html
<div class="empleo-empresa">ADECCO PERU S.A.</div>
```

**Resultado PROHIBIDO** (no tocar estructura):

```html
<div class="empleo-empresa" style="color:red">ADECCO PERU S.A.</div>
```

---

## Título de la entrada en Blogger

Además del HTML, indica:

1. **Título del post** = idéntico a `@@TITULO@@`
   - **Si es Estado:** `TITULO_BLOGGER` = `ENTIDAD: Puesto` (ej: `PROVIAS NACIONAL: N° 025-2026: Practicante para la Unidad Zonal III Amazonas`), mientras que `@@TITULO@@` dentro del HTML queda **solo con el puesto**.
2. **Etiqueta (label)** = exactamente `Empleo` (una sola; nunca agregues `Estado`)

---

## Reglas de asignación de `@@CATEGORIA@@` (obligatorias)

La categoría determina el **color y el ícono** de la tarjeta. Debe coincidir con el menú de la página de inicio. Usa **exactamente estas 8** y ninguna otra:

- **Ingeniería**: operaciones, producción, mantenimiento, procesos, logística, almacén, supply chain, transporte, SSOMA, SST, medio ambiente, seguridad industrial, mecánico(a), electricista, calidad, minería, civil, industrial, arquitecto(a)/arquitectura, urbanismo.
- **Salud**: medicina, enfermería, odontología, farmacia, nutrición, fisioterapia, obstetricia, laboratorio clínico, psicología, tecnólogo médico, hospital, clínica.
- **Ventas y Servicios**: ventas, vendedor(a), asesor(a) comercial, ejecutivo(a) comercial, representante, promotor(a), televentas, call center, atención al cliente, cobranzas, retail, tienda, restaurante, hotel.
- **Administración y Finanzas**: administración, asistente/auxiliar administrativo(a), secretaría, recepción, recursos humanos, RRHH, contabilidad, contador(a), finanzas, tesorería, compras, crédito, auditoría.
- **Derecho**: abogado(a), derecho, legal, jurídico(a), asesoría legal, contratos, compliance, notaría, procurador(a).
- **Educación**: docente, profesor(a), maestro(a), pedagogía, tutor(a), instructor(a), capacitador(a), colegio, universidad, instituto.
- **Otros**: cualquier puesto que no encaje claramente en las anteriores.

Si el puesto encaja en dos categorías, elige la **más específica** según el título.

---

## Formato de salida

Devuelve **SOLO**:

1. **Primero**, el bloque de CONTROL (fuera de cualquier bloque de código):

```
URL_ORIGEN=...
URL_POSTULAR=...
URL_BASES=...
SECCIONES_ESTADO=7/7 (los 7 títulos, en orden) o SECCIONES_ESTADO=no aplica
```

2. **Después**, el código HTML completo de la plantilla rellenada (sin explicaciones fuera del bloque), dentro de un bloque:

```html
...HTML aquí...
```

2. Después del bloque, estas líneas exactas:

```
TITULO_BLOGGER=...
ETIQUETA_BLOGGER=Empleo
TIPO_CONTRATANTE=Estado
TIPO_CONTRATO_ESTADO=CAS
TIPO_ENTIDAD=Municipalidad
```

(o `TIPO_CONTRATANTE=Privado` con `TIPO_CONTRATO_ESTADO=No aplica` y `TIPO_ENTIDAD=No aplica`)

---

## PLANTILLA DATA-ONLY — COPIA Y RELLENA (la única válida)

Esta es la plantilla oficial. **NO crees otra, NO agregues CSS/JS, NO cambies clases.** Solo reemplaza los `@@...@@`.

```html
<div class="empleo-individual">

<div class="empleo-cabecera">
  <div class="empleo-fuente">Fuente: @@FUENTE@@</div>
  <div class="empleo-categoria">@@CATEGORIA@@</div>
  <h1>@@TITULO@@</h1>
  <div class="empleo-empresa">@@EMPRESA@@</div>
  <div class="empleo-salario-header">
    @@SALARIO_HEADER@@
  </div>
</div>

<div class="empleo-info">
  <div class="empleo-info-card">
    <div class="empleo-info-label">Ubicación</div>
    <div class="empleo-info-value">@@UBICACION@@</div>
  </div>
  <div class="empleo-info-card">
    <div class="empleo-info-label">Modalidad</div>
    <div class="empleo-info-value">@@MODALIDAD@@</div>
  </div>
  <div class="empleo-info-card">
    <div class="empleo-info-label">Contrato</div>
    <div class="empleo-info-value">@@CONTRATO@@</div>
  </div>
  <div class="empleo-info-card">
    <div class="empleo-info-label">Salario</div>
    <div class="empleo-info-value">@@SALARIO@@</div>
  </div>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Descripción del puesto</h2>
  <p>
    @@DESCRIPCION_P1@@
  </p>
  <p>
    @@DESCRIPCION_P2@@
  </p>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Funciones</h2>
  <ul>
    <li>@@FUNCION1@@</li>
    <li>@@FUNCION2@@</li>
    <li>@@FUNCION3@@</li>
    <li>@@FUNCION4@@</li>
    <li>@@FUNCION5@@</li>
    <li>@@FUNCION6@@</li>
  </ul>
</div>

<div class="empleo-seccion">
  <h2>Requisitos</h2>
  <ul>
    <li>@@REQUISITO1@@</li>
    <li>@@REQUISITO2@@</li>
    <li>@@REQUISITO3@@</li>
    <li>@@REQUISITO4@@</li>
    <li>@@REQUISITO5@@</li>
  </ul>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Información de la oferta</h2>
  <div class="empleo-destacado">
    <p><strong>Vacantes:</strong> @@VACANTES@@</p>
    <p><strong>Jornada:</strong> @@JORNADA@@</p>
    <p><strong>Contrato:</strong> @@CONTRATO2@@</p>
    <p><strong>Modalidad:</strong> @@MODALIDAD2@@</p>
    <p><strong>Experiencia:</strong> @@EXPERIENCIA@@</p>
    <p><strong>Estudios:</strong> @@ESTUDIOS@@</p>
    <p><strong>Salario:</strong> @@SALARIO2@@</p>
    <p><strong>Fecha publicación:</strong> @@FECHA_PUBLICACION@@</p>
    <p><strong>Fecha cierre:</strong> @@FECHA_CIERRE@@</p>
    <p><strong>Tipo contratante:</strong> @@TIPO_CONTRATANTE@@</p>
    <p><strong>Tipo de contrato Estado:</strong> @@TIPO_CONTRATO_ESTADO@@</p>
    <p><strong>Tipo de entidad:</strong> @@TIPO_ENTIDAD@@</p>
  </div>
</div>

<div class="empleo-seccion">
  <h2>Beneficios</h2>
  <ul>
    <li>@@BENEFICIO1@@</li>
    <li>@@BENEFICIO2@@</li>
    <li>@@BENEFICIO3@@</li>
    <li>@@BENEFICIO4@@</li>
  </ul>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Información de la empresa</h2>
  <div class="empleo-destacado">
    <p><strong>Empresa:</strong> @@EMPRESA2@@</p>
    <p><strong>Sector:</strong> @@SECTOR@@</p>
    <p><strong>Tamaño:</strong> @@TAMANO@@</p>
    <p><strong>Ubicación:</strong> @@UBICACION_EMPRESA@@</p>
    <p>
      <strong>Descripción:</strong>
      @@DESCRIPCION_EMPRESA@@
    </p>
  </div>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-postular">
  <h2>¿Te interesa esta oferta?</h2>
  <a
    class="empleo-boton"
    href="@@URL_POSTULAR@@"
    target="_blank"
    rel="noopener noreferrer"
  >
    POSTULAR EN @@PORTAL@@
  </a>
  <div class="empleo-aviso">
    La postulación se realiza directamente en la plataforma de origen.
  </div>
</div>

<div class="ofertas-relacionadas">
  <h2>Ofertas recomendadas para ti</h2>
  <div id="ofertasRelacionadas" class="relacionados-grid"></div>
</div>

</div>
```

---

## PLANTILLA CONVOCATORIA ESTADO — COPIA Y RELLENA (solo si TIPO_CONTRATANTE=Estado)

Esta es la plantilla oficial de las convocatorias del Estado. **NO crees otra, NO agregues CSS/JS, NO cambies clases, NO muevas el bloque oculto de sitio.** Solo reemplaza los `@@...@@`.

```html
<!-- =========================================================
     PLANTILLA DE CONVOCATORIA DEL ESTADO - VERSION DATA-ONLY
     USO: solo cuando TIPO_CONTRATANTE=Estado
     (CAS, 728, 276, Prácticas, Servicio Civil, Locación,
     Consultoría, u otro contrato público).
     El CSS y el JS viven en el tema de Blogger.
     (Blogger > Tema > Editar HTML: Bloque-Tema-Blogger)
     Solamente reemplaza los textos marcados con @@...@@

     ESTRUCTURA PROPIA (7 secciones, EN ESTE ORDEN, títulos
     fijos — no los renombres ni los reordenes):
       1) Resumen de la convocatoria
       2) Perfil y funciones del puesto
       3) Lo que ofrece esta convocatoria
       4) Pasos para postular
       5) Bases y anexos oficiales
       6) Consejos antes de postular
       7) Resultados y siguientes pasos

     6 REGLAS DURO (revisar antes de responder):
     1) Todo href = URL copiada LITERAL de la publicación/oficial.
        Nada de dominios inventados, acortados, completados ni
        "buscados". Si no la copiaste carácter por carácter: usa
        @@URL_ORIGEN@@ (la URL que se te dio).
     2) "No especificado" solo vive en el bloque oculto de arriba y,
        si hace falta, en un recuadro de la ficha. En los bloques
        .empleo-destacado y en las listas <ul>: BORRA la línea/<li>.
        Los 4 recuadros de la ficha NUNCA se borran.
     3) El bloque oculto se mantiene completo, en primer lugar.
     4) UN SOLO botón con enlace en toda la entrada:
        POSTULA AQUÍ (caja final). En "Pasos para postular" NO
        pongas <a>. Prohibido repetir textos como "Ver publicación
        oficial".
     5) En "Bases y anexos oficiales" los href deben ser DISTINTOS
        entre sí. Si solo hay UNA URL: deja UN SOLO <li>.
        Prohibido duplicar el mismo enlace.
     6) Ciudad y Ubicación = dato REAL de la publicación:
        JSON-LD jobLocation (addressLocality / addressRegion), meta
        "Departamento X" o el texto "Para trabajar en X". NUNCA
        adivines: no copies ciudades de la navegación del sitio
        (menú/desplegable "EMPLEOS EN ...") ni los ejemplos de
        estas instrucciones (Sicuani, Chachapoyas...).
        Si la publicación no lo dice: No especificado.
     ========================================================= -->

<div class="empleo-individual">

<div class="empleo-datos-ocultos">
  <p><strong>Fuente:</strong> @@FUENTE@@</p>
  <p><strong>Categoría:</strong> @@CATEGORIA@@</p>
  <p><strong>Empresa:</strong> @@EMPRESA@@</p>
  <p><strong>Ubicación:</strong> @@UBICACION@@</p>
  <p><strong>Ciudad:</strong> @@CIUDAD@@</p>
  <p><strong>Modalidad:</strong> @@MODALIDAD@@</p>
  <p><strong>Salario:</strong> @@SALARIO@@</p>
  <p><strong>Contrato:</strong> @@CONTRATO@@</p>
  <p><strong>Vacantes:</strong> @@VACANTES@@</p>
  <p><strong>Dirigido a:</strong> @@DIRIGIDO_A@@</p>
  <p><strong>Estudios:</strong> @@ESTUDIOS@@</p>
  <p><strong>Experiencia:</strong> @@EXPERIENCIA@@</p>
  <p><strong>Jornada:</strong> @@JORNADA@@</p>
  <p><strong>Fecha de publicación:</strong> @@FECHA_PUBLICACION@@</p>
  <p><strong>Fecha de cierre:</strong> @@FECHA_CIERRE@@</p>
  <p><strong>Tipo contratante:</strong> @@TIPO_CONTRATANTE@@</p>
  <p><strong>Tipo de contrato Estado:</strong> @@TIPO_CONTRATO_ESTADO@@</p>
  <p><strong>Tipo de entidad:</strong> @@TIPO_ENTIDAD@@</p>
</div>

<div class="empleo-cabecera">

  <div class="empleo-categoria">@@CATEGORIA@@</div>

  <h1>@@TITULO@@</h1>

  <div class="empleo-empresa">@@EMPRESA@@</div>

  <div class="empleo-salario-header">
    @@SALARIO_HEADER@@
  </div>

</div>

<p class="empleo-vigencia">@@VIGENCIA@@</p>

<div class="empleo-info">

  <!-- Los 4 recuadros son ESTRUCTURA: nunca los borres ni los reordenes.
       Si un dato no existe, escribe "No especificado" DENTRO del recuadro. -->

  <div class="empleo-info-card">
    <div class="empleo-info-label">Vacantes</div>
    <div class="empleo-info-value">@@VACANTES@@</div>
  </div>

  <div class="empleo-info-card">
    <div class="empleo-info-label">Contrato</div>
    <div class="empleo-info-value">@@TIPO_CONTRATO_ESTADO@@</div>
  </div>

  <div class="empleo-info-card">
    <div class="empleo-info-label">Dirigido a</div>
    <div class="empleo-info-value">@@DIRIGIDO_A@@</div>
  </div>

  <div class="empleo-info-card">
    <div class="empleo-info-label">Ubicación</div>
    <div class="empleo-info-value">@@UBICACION@@</div>
  </div>

</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Resumen de la convocatoria</h2>
  <!-- @@RESUMEN@@ = 1 o 2 frases ESCRITAS POR TI con los datos reales:
       quién convoca, para qué perfil, cuántas vacantes y hasta cuándo.
       Prohibido copiar frases de la publicación original.
       Si falta algún dato, no lo menciones: no rellenes con
       "No especificado" ni con texto de relleno. -->
  <p>
    @@RESUMEN@@
  </p>
</div>

<div class="empleo-seccion">
  <h2>Perfil y funciones del puesto</h2>
  <p>
    @@DESCRIPCION_P1@@
  </p>
  <!-- Si un dato vale "No especificado" o "No especificada": BORRA esa <p> de AQUÍ (solo en este bloque).
       NO toques los 4 recuadros de la ficha de arriba ni el bloque oculto: esos sí van completos. -->
  <div class="empleo-destacado">
    <p><strong>Vacantes:</strong> @@VACANTES@@</p>
    <p><strong>Dirigido a:</strong> @@DIRIGIDO_A@@</p>
    <p><strong>Estudios:</strong> @@ESTUDIOS@@</p>
    <p><strong>Experiencia:</strong> @@EXPERIENCIA@@</p>
    <p><strong>Jornada:</strong> @@JORNADA@@</p>
  </div>
  <p><strong>Funciones principales:</strong></p>
  <!-- 1 función REAL por <li>, redactada con tus palabras (sin copiar el anuncio).
       Si la publicación trae menos de 6, BORRA los <li> sobrantes.
       NUNCA dejes <li>No especificado</li>: no es una función. Si no hay ninguna, borra el <p> y el <ul>. -->
  <ul>
    <li>@@FUNCION1@@</li>
    <li>@@FUNCION2@@</li>
    <li>@@FUNCION3@@</li>
    <li>@@FUNCION4@@</li>
    <li>@@FUNCION5@@</li>
    <li>@@FUNCION6@@</li>
  </ul>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Lo que ofrece esta convocatoria</h2>
  <!-- Igual que arriba: borra las <p> cuyo dato no exista (nada de "No especificado" a la vista). -->
  <div class="empleo-destacado">
    <p><strong>Remuneración:</strong> @@SALARIO@@</p>
    <p><strong>Entidad:</strong> @@EMPRESA@@</p>
    <p><strong>Ubicación:</strong> @@UBICACION@@</p>
    <p><strong>Modalidad:</strong> @@MODALIDAD@@</p>
    <p><strong>Fecha de publicación:</strong> @@FECHA_PUBLICACION@@</p>
    <p><strong>Fecha de cierre:</strong> @@FECHA_CIERRE@@</p>
  </div>
</div>

<div class="empleo-seccion">
  <h2>Pasos para postular</h2>
  <!-- Si @@FECHA_CIERRE@@ es "No especificada": BORRA esta <p> con la Fecha límite. -->
  <div class="empleo-destacado">
    <p><strong>Fecha límite:</strong> @@FECHA_CIERRE@@</p>
  </div>
  <p>
    @@DESCRIPCION_P2@@
  </p>
  <!-- Los 5 pasos son TEXTO FIJO de esta plantilla: NO los reescribas,
       NO inventes pasos nuevos y NO agregues horarios ni requisitos.
       AQUÍ NO VA NINGÚN <a>. El único botón con enlace de la entrada
       está en la caja final. -->
  <ol>
    <li>Lee completas las bases: requisitos, cronograma, anexos y formularios.</li>
    <li>Reúne y digitaliza tus documentos antes de la fecha límite.</li>
    <li>Ingresa al medio oficial de postulación que indican las bases (el enlace directo está en el botón de la caja final).</li>
    <li>Completa el formulario y adjunta los archivos en el orden que piden las bases.</li>
    <li>Guarda la constancia de postulación y revisa la página de la entidad por cambios de cronograma.</li>
  </ol>
</div>

<div class="empleo-anuncio">
  Espacio publicitario
</div>

<div class="empleo-seccion">
  <h2>Bases y anexos oficiales</h2>
  <!-- @@URL_BASES@@ = enlace EXACTO de las bases / cronograma / anexos de la publicación.
       Si la publicación no trae ese enlace: pon @@URL_ORIGEN@@.
       REGLA DE LOS DOCUMENTOS: revisa TODA la publicación y lista TODOS los documentos
       que traigan su propio enlace: bases y cronograma, anexos, ficha de postulación,
       declaración jurada, formularios. UN <li> por documento (máximo 3), href SIEMPRE
       DISTINTOS entre sí y texto que diga CUÁL es cada documento. Ejemplo con 3:
         <li><a href="URL1" target="_blank" rel="noopener noreferrer">Bases y cronograma</a></li>
         <li><a href="URL2" target="_blank" rel="noopener noreferrer">Ficha de postulación</a></li>
         <li><a href="URL3" target="_blank" rel="noopener noreferrer">Declaración jurada</a></li>
       Nunca repitas la misma URL: si solo hay UNA url, deja UN SOLO <li>
       (prohibido duplicarlo y prohibido duplicar el mismo enlace). -->
  <ul>
    <li>
      <a
        href="@@URL_BASES@@"
        target="_blank"
        rel="noopener noreferrer"
      >
        Bases, cronograma y anexos en la convocatoria oficial
      </a>
    </li>
  </ul>
</div>

<div class="empleo-seccion">
  <h2>Consejos antes de postular</h2>
  <!-- Texto FIJO de la plantilla: no lo reescribas ni lo copies del anuncio. -->
  <ul>
    <li>Comprueba en las bases que cumples cada requisito antes de llenar el formulario: un solo requisito sin cubrir basta para quedar fuera.</li>
    <li>Digitaliza cada documento en un archivo claro y con el formato que piden las bases; así evitas rechazos por archivos ilegibles.</li>
    <li>Postula únicamente por el canal y dentro del plazo que fija el cronograma oficial: otra vía no es válida.</li>
    <li>Sigue la página de la entidad: ahí aparecen fe de erratas, cambios de cronograma o la suspensión de un proceso.</li>
  </ul>
</div>

<div class="empleo-seccion">
  <h2>Resultados y siguientes pasos</h2>
  <!-- Texto FIJO de la plantilla: no lo reescribas ni lo copies del anuncio. -->
  <p>Cada etapa se resuelve según el cronograma que publican las bases; la entidad indica allí las fechas y el medio de publicación de cada resultado.</p>
  <p>Si no quedas seleccionado, revisa los requisitos del puesto y vuelve a intentarlo: los procesos del Estado se abren de forma periódica.</p>
</div>

<div class="empleo-postular">
  <h2>¿Te interesa esta convocatoria?</h2>
  <!-- ÚNICO botón con enlace de toda la entrada. Texto fijo: POSTULA AQUÍ.
       @@URL_POSTULAR@@ = módulo/portal de postulación copiado LITERAL de la publicación
       (mismo protocolo, dominio, PUERTO, ruta, query y #fragmento).
       Si no lo copiaste carácter por carácter: pon @@URL_ORIGEN@@ (la URL que se te dio).
       Prohibido inventar dominios, acortar URLs ni buscar el portal oficial. -->
  <a
    class="empleo-boton"
    href="@@URL_POSTULAR@@"
    target="_blank"
    rel="noopener noreferrer"
  >
    POSTULA AQUÍ
  </a>
  <div class="empleo-aviso">
    Antes de postular revisa las bases y el cronograma oficiales.
  </div>
</div>

<div class="ofertas-relacionadas">
  <h2>Convocatorias relacionadas</h2>
  <div id="ofertasRelacionadas" class="relacionados-grid"></div>
</div>

</div>
```

---

## ORIGINALIDAD DEL TEXTO (parafraseo obligatorio)

La entrada **no debe parecer copiada** de la publicación original. Quien la lea no debe encontrar frases idénticas al anuncio, salvo los datos duros.

### Se parafrasea (reescribe con tus palabras)

- Descripción del puesto y **funciones del puesto** (en Estado: *Perfil y funciones del puesto*).
- **Requisitos** y estudios.
- Condiciones del contrato (jornada, beneficios, alcance).
- Recomendaciones, avisos y cualquier párrafo explicativo.
- **Secciones propias de la plantilla Estado** (*Resumen de la convocatoria*, *Pasos para postular*, *Consejos antes de postular*, *Resultados y siguientes pasos*): se redactan desde cero con datos de la publicación; si la plantilla ya trae el texto, déjalo tal cual — **nunca lo reemplaces** por un párrafo copiado del anuncio.
- **Los títulos de las secciones**: son fijos y propios; no copies los títulos que usan otros portales (`Requisitos`, `¿Cómo postular?`, `Condiciones del contrato`…).

### Se copia LITERAL (dato duro, no se reescribe)

- Nombre de la entidad/empresa y del portal oficial.
- N° de convocatoria o de plaza (`N° 025-2026`).
- Fechas en `DD/MM/AAAA` y montos (`S/ 1,130.00`).
- Número de vacantes, ciudades, siglas y nombres propios.
- **URLs** (siempre carácter por carácter).

### Reglas duras

1. **Prohibido copiar 2 frases seguidas** tal como vienen en la fuente (salvo listas de datos duros: fechas, montos, vacantes, N°, URLs).
2. Cambia la estructura: otra ordenación de frases, sinónimos, voz activa en vez de pasiva. **No** cambies el significado: no inventes requisitos ni borres obligaciones importantes.
3. Cada `<li>` de *Funciones principales* / *Requisitos* se redacta distinto al original, conservando el dato que aporta.
4. Si la fuente ya viene en texto "de bando" (formal), **rézalo**: entiéndelo y explícalo de nuevo.

### Checklist de originalidad (antes de devolver el HTML)

```
[ ] Ningún párrafo largo de la entrada coincide palabra por palabra con la fuente
[ ] Los datos duros (fechas, montos, vacantes, N°, URLs) siguen literales
[ ] El significado de requisitos y actividades NO cambió
[ ] Los títulos de sección y los textos fijos (Resumen, Pasos, Consejos, Resultados) no vienen copiados de la fuente
```

---

## Ejemplo de uso (mensaje que envías a ChatGPT)

```
<pega aquí TODO el PROMPT MAESTRO de arriba, INCLUIDAS las dos plantillas data-only>

Ahora rellena la plantilla data-only con estos datos de la publicación original:

<pega aquí el texto o la URL de la oferta original>

IMPORTANTE:
- Devuelve el resultado solo dentro de un bloque ```html ... ```
- SIN <style> NI <script>
- PRIMERO decide el sector: si es Privado usa la plantilla genérica; si es Estado usa la PLANTILLA CONVOCATORIA ESTADO y aplica sus reglas (bloque oculto primero, TITULO_BLOGGER=ENTIDAD: Puesto, etiqueta solo Empleo, vigencia con una de las 2 cadenas exactas)
- En @@TIPO_CONTRATANTE@@ escribe exactamente Estado o Privado (o No especificado)
- Si es Estado, escribe `Estado` en @@TIPO_CONTRATANTE@@ y rellena @@TIPO_CONTRATANTE_ESTADO@@ y @@TIPO_ENTIDAD@@ con valores exactos de las tablas
- Si es Privado, escribe No aplica en ambos
- ENLACES: copia literal de la publicación original (mismo puerto/ruta/query/#). NO busques ni "limpies" el sitio oficial. Si no tienes la URL exacta, usa la URL de la publicación original. Un solo botón POSTULA AQUÍ en la caja final; en Pasos para postular ningún <a>.
- ESTRUCTURA: los 4 recuadros de la ficha (Vacantes, Contrato, Dirigido a, Ubicación) y los campos del bloque oculto NUNCA se borran; el "No especificado" solo va ahí. En .empleo-destacado y en <ul> borra la línea/<li> que no exista.
- SECCIONES (Estado): conserva los 7 títulos y su orden exactos (Resumen de la convocatoria, Perfil y funciones del puesto, Lo que ofrece esta convocatoria, Pasos para postular, Bases y anexos oficiales, Consejos antes de postular, Resultados y siguientes pasos); escribe @@RESUMEN@@ con tus palabras y no toques los textos fijos.
- DATOS: fechas y ciudad salen del JSON-LD (datePosted, validThrough, jobLocation); el título conserva su N°.
- ORIGINALIDAD: parafrasea con tus palabras descripción, requisitos, actividades y condiciones (nada de copiar frases seguidas de la publicación). Literales solo: entidad, N° de convocatoria, fechas DD/MM/AAAA, montos, vacantes, ciudades y URLs.
- SIN línea de Fuente en la cabecera (no publiques "Fuente: CONVOCATORIASDETRABAJO.COM")
- ANTES del HTML emite el bloque CONTROL: URL_ORIGEN / URL_POSTULAR / URL_BASES / SECCIONES_ESTADO
- Al final incluye TITULO_BLOGGER=..., ETIQUETA_BLOGGER=Empleo, TIPO_CONTRATANTE=... (y los otros 2 si es Estado)
```

---

## RECURSO OPCIONAL - solo si una entrada salió con errores (no es el flujo normal)

El flujo normal **no** usa estas utilidades: la IA entrega el HTML listo y lo pegas directo en Blogger con `Ctrl+V`. Si una entrada sale con errores, tienes dos utilidades en esta misma carpeta:

- **`corregir-entrada.cmd`** — arregla la entrada **sola** y luego la valida.
- **`validar-entrada.cmd`** — solo valida (no toca el archivo).

### 1) Arreglar sola (solo si hace falta)

1. Guarda el HTML que te devolvió la IA en un archivo `.html` (ej: `entrada.html`).
2. **Arrastra ese archivo sobre `corregir-entrada.cmd`**.
3. Cuando pida la **URL de la publicación original**, pégala y pulsa Enter (Enter vacío = arregla solo la estructura).

Crea `entrada-corregido.html` junto al original y ejecuta el validador. **Si la validación sale `RESULTADO: OK`, el HTML final queda copiado al PORTAPAPELES**: en Blogger solo pega con `Ctrl+V` (el archivo sigue guardado por si quieres revisarlo). Arregla por su cuenta:

- mueve el bloque oculto al primer sitio y completa los campos que falten;
- quita la línea de Fuente de la cabecera y asegura la categoría;
- reconstruye la ficha con los **4 recuadros**;
- borra los "No especificado" que quedaron a la vista (fuera del bloque oculto y de la ficha);
- deja **un solo botón** `POSTULA AQUÍ` en la caja final y sin `<a>` en las secciones de texto (*Pasos para postular* / *¿Cómo postular?*);
- elimina `<style>` / `<script>` / `style=` y completa los metadatos `ETIQUETA_BLOGGER` / `TITULO_BLOGGER`;
- añade las secciones que falten (en Estado: las 7 con sus títulos exactos y en su orden), el banner de vigencia y `#ofertasRelacionadas`;
- **repara cada enlace**: toma URLs que sí están copiadas literalmente en la publicación original (si la IA inventó o "limpió" una URL, la sustituye por la real; si no hay candidato, cae en la URL de origen).

### 2) Validar sin tocar nada

1. **Arrastra el archivo sobre `validar-entrada.cmd`**.
2. Cuando pida la **URL de la publicación original**, pégala y pulsa Enter (Enter vacío = valida solo la estructura).

**Qué comprueba:**

- que no queden marcadores `@@...@@` ni `<style>` / `<script>` / estilos inline;
- que el bloque oculto sea el primer hijo y tenga sus 18 campos;
- que la ficha tenga los **4 recuadros** (Vacantes, Contrato, Dirigido a, Ubicación);
- que **no aparezca "No especificado"** fuera del bloque oculto y de los 4 recuadros;
- que haya **un solo botón** con el texto `POSTULA AQUÍ`, sin `<a>` en *Pasos para postular* / *¿Cómo postular?* ni textos repetidos como "Ver convocatoria oficial";
- que las **7 secciones de Estado** estén presentes con sus títulos exactos (y que *Resumen de la convocatoria* traiga un párrafo de verdad);
- que la cabecera **no tenga** la línea de Fuente;
- que **cada `href` exista copiado literalmente en la publicación original** (si la IA inventó o acortó un enlace, sale como ERROR);
- que el texto **no esté copiado de la publicación**: si un párrafo largo coincide palabra por palabra con la fuente (≥60%) sale `AVISO` con el porcentaje — repara ese párrafo parafraseándolo (es un aviso, no bloquea).

Si dice `RESULTADO: OK` → **ya está listo**: el HTML está en el portapapeles, pégalo en Blogger con `Ctrl+V`.
Si dice `ERROR` → **no lo pegues**: pásala primero por `corregir-entrada.cmd`, corrige a mano lo que siga marcando o vuelve a pedirla a la IA con este instructivo.
