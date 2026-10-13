# INSTRUCCIONES — CONVOCATORIA DEL ESTADO (7 secciones, sin copiar la fuente)

> **Nota para quien pega este archivo:** úsalo para **toda** oferta del Estado (CAS, 728, 276, Prácticas, Servicio Civil, Locación, Consultoría). Pega este archivo completo **y debajo** la URL (o el texto) de la publicación original, en un chat **nuevo**, y pide **una** entrada por mensaje. El HTML que te devuelvan va **listo para pegar**: cópialo directo en Blogger con `Ctrl+V`. `corregir-entrada.cmd` **no** es parte del flujo: úsalo solo si algo salió mal.

> **Flujo automático (recomendado, sin IA):** doble clic en `generar-entrada.cmd`, pega la URL y espera unos segundos: baja la publicación, extrae los datos reales (vacantes, salario, ciudad, fechas, bases), rellena la plantilla, la valida y te deja el **HTML copiado al portapapeles** → `Ctrl+V` en Blogger. Si dice ERROR no se copia nada: lee el mensaje. Úsalo **antes** de recurrir a una IA; y si aun así generas la entrada con una IA, pásala por `comparar-entrada.cmd` antes de publicar (detecta datos inventados, p. ej. un número de vacantes equivocado). Guarda además el respaldo en `fuentes\` y `salida\`.

> **Flujo diario en lote (muchas convocatorias):** `obtener-urls.cmd` trae las convocatorias **nuevas** de convocatoriasdetrabajo.com a `urls.txt` sin entrar una por una (`obtener-urls.cmd full` rastrea todas las páginas para el primer carga; en modo diario solo mira lo nuevo). Luego `generar-lote.cmd` genera y valida todas en paralelo (reporte en `reporte\`, las OK quedan en `historial-urls.txt`). Con el setup de Google Cloud hecho una sola vez, `publicar-blogger.cmd` las publica directo con la etiqueta `Empleo` (usa `-Simular` para ver qué se publicaría, `-Draft` para borradores; log en `publicaciones.txt`). Todo junto en un comando: `flujocompleto.cmd`. Siembra inicial del historial con `importar-historial.ps1` (lee la URL de *Fuente* de los posts ya publicados).

---

## 1. Tu tarea (una sola cosa)

Rellenar la **PLANTILLA DE CONVOCATORIA DEL ESTADO** que está en el punto 9: solo sustituyes los textos `@@...@@`. Todo lo demás (CSS, clases, orden, títulos, textos fijos) queda **idéntico, byte por byte**.

**NO** reconstruyas la plantilla de memoria. **NO** la resumas. **NO** le cambies los títulos de sección.

---

## 2. Cómo debe ser tu respuesta

**SOLO** estas dos cosas, en este orden:

**A) ANTES del HTML — bloque de CONTROL** (fuera de cualquier bloque de código):

```
URL_ORIGEN = <URL exacta de la publicación que se me dio>
URL_POSTULAR = <URL copiada literal, o URL_ORIGEN>
URL_BASES = <URL copiada literal, o URL_ORIGEN>
TIPO_CONTRATANTE = Estado
TITULO_BLOGGER = ENTIDAD: Puesto
ETIQUETA_BLOGGER = Empleo
SECCIONES_ESTADO = 7/7 <los 7 títulos de la regla 3, en orden>
```

**B) DESPUÉS — el HTML completo**, dentro de un bloque ` ```html `.

**Nada más.** Sin explicaciones ni resúmenes. Nunca empieces por el HTML: sin bloque de CONTROL, la respuesta se descarta.

---

## 3. REGLA 1: los 7 títulos de sección (obligatorios, en este orden)

El HTML debe contener **exactamente** estos 7 `<h2>`, sin cambiar una letra, sin reordenarlos, sin añadir ni quitar ninguno:

1. `<h2>Resumen de la convocatoria</h2>` → `@@RESUMEN@@`: 1 o 2 frases **tuyas** con datos reales (quién convoca, para qué perfil, cuántas vacantes y hasta cuándo cierra). Sin copiar frases de la publicación.
2. `<h2>Perfil y funciones del puesto</h2>` → `@@DESCRIPCION_P1@@` + recuadro de perfil + lista `@@FUNCION1@@` … `@@FUNCION6@@`.
3. `<h2>Lo que ofrece esta convocatoria</h2>` → recuadro con remuneración, entidad, ubicación, modalidad y las 2 fechas.
4. `<h2>Pasos para postular</h2>` → línea `Fecha límite:` + `@@DESCRIPCION_P2@@` + los **5 pasos fijos** de la plantilla. **Ningún `<a>`** aquí.
5. `<h2>Bases y anexos oficiales</h2>` → **lista TODOS los documentos con enlace** que tenga la publicación (bases y cronograma, anexos, ficha de postulación, declaración jurada, formularios): **1 `<li>` por documento, máximo 3**, cada href **distinto** y con un texto que diga **cuál** es ese documento. **No te quedes con un solo enlace si la publicación trae varios.** Si solo hay un enlace: **un solo `<li>`**; nunca repitas el mismo enlace dos veces.
6. `<h2>Consejos antes de postular</h2>` → los **4 consejos fijos** de la plantilla, intactos.
7. `<h2>Resultados y siguientes pasos</h2>` → los **2 párrafos fijos** de la plantilla, intactos.

**PROHIBIDO** en estas entradas (si aparece cualquiera de estos títulos, la respuesta se rechaza y hay que rehacerla):

`Requisitos` · `Condiciones del contrato` · `¿Cómo postular?` · `Descargar bases` · `Recomendaciones para postular` · `Descripción del puesto` · `Beneficios` · `Principales responsabilidades`

Si tu borrador no trae esos 7 títulos en ese orden, **corrígelo antes de entregar**: no se entrega nada "a medias".

---

## 4. REGLA 2: NO copies y pegues la publicación (la que más se incumple)

La entrada no debe parecer un calco del anuncio. **Prohibido copiar dos frases seguidas** tal como vienen en la fuente (salvo datos duros, ver abajo).

**MALO (prohibido):**

> "Se requiere título profesional en Contabilidad emitido por universidad reconocida por SUNEDU, con conocimientos en normativa tributaria y experiencia mínima de dos años."

**BUENO (así sí):**

> "Buscan contadores con título de una universidad reconocida por SUNEDU; valoran el dominio de la normativa tributaria y al menos dos años de experiencia en el área."

Reglas duras:

- **Lee, entiende y reescribe**: cambia el orden de las frases, usa sinónimos, voz activa en vez de pasiva. **No** cambies el significado, **no** inventes requisitos ni **no** borres obligaciones importantes.
- Cada `<li>` de *Funciones principales* se redacta distinto al original, conservando el dato que aporta.
- **Prohibidas** las frases-publicidad de la fuente, p. ej. `Descarga las bases para revisar los requisitos completos`.
- **Se copia LITERAL solo esto:** nombre de la entidad y del portal, N° de convocatoria/plaza, fechas en `DD/MM/AAAA`, montos (`S/ 1,130.00`), número de vacantes, ciudades, siglas, nombres propios y **URLs**.
- Los textos **fijos de la plantilla** (los 5 pasos, los 4 consejos, los 2 párrafos de *Resultados*, la caja `¿Te interesa esta convocatoria?`) **no son de la fuente**: déjalos tal cual vienen; **nunca** los sustituyas por párrafos del anuncio.
- Los títulos de las secciones tampoco salen de la fuente: son los 7 de la regla 3.
- **Sin citas ni referencias de la IA**: nada de `:contentReference[oaicite:0]{index=0}`, `oaicite[...]`, `[citation]`, `【1】` ni notas al pie; el texto va limpio, solo tú y los datos.

---

## 5. REGLA 3: datos, fechas y `No especificado`

| Dato | Regla |
|---|---|
| `@@FECHA_CIERRE@@` | **Siempre `DD/MM/AAAA`**, solo la fecha (sin hora). `5 de noviembre de 2026` → `05/11/2026`. Si no hay fecha de cierre: `No especificada` **y borra la línea `Fecha límite:`** entera |
| `@@FECHA_PUBLICACION@@` | `DD/MM/AAAA` (campo `datePosted` del JSON-LD) |
| `@@VACANTES@@` | Solo el número (`10`), nunca `10 vacantes`. Sin número: `No especificado` |
| `@@TIPO_CONTRATANTE@@` | Exactamente `Estado` (prohibido `Público`, `Gobierno`, `Municipal`, vacío…) |
| `@@TIPO_CONTRATO_ESTADO@@` | Uno exacto de: `CAS`, `728`, `276`, `Prácticas`, `Servicio Civil`, `Locación de servicios`, `Consultoría`, `Otro` |
| `@@TIPO_ENTIDAD@@` | Uno exacto de: `Municipalidad`, `Ministerio`, `Gobierno Regional`, `Salud`, `Educación`, `Otra entidad` |
| `@@VIGENCIA@@` | Una de las 2 cadenas **exactas** que trae la plantilla (vigente o finalizada), con su clase `empleo-vigencia` correspondiente |
| Dato inexistente | **Bloque oculto** y **4 recuadros**: `No especificado`. En `.empleo-destacado` y en `<ul>`: **borra la `<p>`/`<li>`**. Nunca dejes `<li>No especificado</li>` a la vista |

Ubicación, ciudad, título y fechas: búscalos en el **JSON-LD** de la publicación (`jobLocation.address.addressLocality` + `addressRegion`); si el JSON-LD y el texto discrepan, manda el JSON-LD. **Nunca adivines la ciudad**: no la copies del menú o desplegable del sitio (`EMPLEOS EN ICA`, `EMPLEOS EN LIMA`…), del menú lateral ni de los ejemplos de estas instrucciones (`Sicuani`, `Chachapoyas`); si la publicación no la dice, va `No especificado`.

---

## 6. REGLA 4: no toques la estructura

- Nada de `<style>`, `<script>`, CSS inline ni clases nuevas (el CSS y el JS viven en el tema de Blogger).
- El bloque oculto `.empleo-datos-ocultos` es el **primer** elemento de la entrada y sus 18 campos van **siempre completos**.
- Los 4 recuadros de la ficha (Vacantes, Contrato, Dirigido a, Ubicación) **nunca** se borran.
- **Un solo botón** con enlace en toda la entrada: `POSTULA AQUÍ` en la caja final.
- Enlaces = **copia carácter por carácter** de la publicación (mismo `http/https`, mismo dominio, mismo **puerto**, misma ruta, misma query y mismo `#`). Si no lo copiaste exacto → `@@URL_ORIGEN@@`. **Prohibido** inventar, limpiar o acortar URLs.
- En *Bases y anexos oficiales* **nunca repitas un href**: cada `<li>` lleva una URL distinta y, si solo hay una, va **un solo `<li>`** (prohibido el enlace duplicado).
- En *Bases y anexos oficiales* **incluye TODOS los documentos con enlace** que aparezcan en la publicación (bases, anexos, cronograma, ficha de postulación, declaración jurada, formularios), **1 `<li>` por documento y máximo 3**, con el nombre de cada documento como texto del enlace. Un solo enlace cuando la publicación solo trae uno.
- **Cero artefactos de citas de la IA**: está prohibido dejar en el texto `:contentReference[oaicite:0]{index=0}`, `oaicite[...]`, `[citation]`, `【...】` o cualquier nota de referencia. Si los ves en tu borrador, **borrálos** antes de entregar (se detectan y la entrada se rechaza).
- Cabecera **sin** línea de `Fuente` (solo va en el bloque oculto).
- `@@TITULO@@` = solo el puesto con su N° (`N° 025-2026: Practicante para la Unidad Zonal III Amazonas`).
- `TITULO_BLOGGER` = `ENTIDAD: Puesto` (`PROVIAS NACIONAL: N° 025-2026: …`).
- Etiqueta = **solo** `Empleo` (una sola; nunca agregues `Estado`).
- `@@CATEGORIA@@` = una sola de: `Ingeniería`, `Salud`, `Ventas y Servicios`, `Administración y Finanzas`, `Derecho`, `Educación`, `Otros`.

---

## 7. AUTOCHEQUEO — recórrerlo sobre TU HTML antes de responder

Abre el HTML que acabas de escribir y verifica cada punto **leyendo tu propio código**, no de memoria. Si alguno queda con `[ ]`, **no entregues**: corrige el HTML y vuelve a empezar el recorrido. Solo respondes con **todos** los puntos en `[x]`.

```
[ ] Los 7 <h2> son exactamente los de la regla 3 y van en ese orden
[ ] Ningún título de la lista PROHIBIDA aparece en el HTML
[ ] Ningún párrafo viene 2 frases seguidas copiado de la publicación (solo datos duros literales)
[ ] Los textos fijos (5 pasos, 4 consejos, 2 párrafos, caja final) siguen intactos
[ ] No quedó ningún @@...@@ sin reemplazar
[ ] FECHA_CIERRE en DD/MM/AAAA, o la línea "Fecha límite" fue borrada
[ ] Un solo botón POSTULA AQUÍ; en "Pasos para postular" no hay ningún <a>
[ ] Cada href es copia literal de una URL de la publicación (si no, = URL_ORIGEN)
[ ] En "Bases y anexos oficiales" no repetí ningún href (un solo <li> si hay una sola URL)
[ ] En "Bases y anexos oficiales" listé TODOS los documentos con enlace de la publicación (máximo 3, cada uno con su nombre)
[ ] Bloque oculto primero, 4 recuadros presentes, sin línea de Fuente
[ ] Ningún "No especificado" visible fuera del bloque oculto y de los 4 recuadros
[ ] Ningún artefacto de cita (:contentReference, oaicite, [citation]) quedó en el HTML
[ ] Sin <style>, <script> ni style= en el HTML (el CSS vive en el tema de Blogger)
[ ] Bloque oculto con sus 18 campos completos (los inexistentes = "No especificado")
[ ] Banner de vigencia con una de las 2 cadenas exactas y la clase empleo-vigencia correcta
[ ] Sin textos de botón prohibidos ("Ver publicación oficial", "Ver convocatoria oficial", "Ir a la convocatoria oficial")
[ ] Existe #ofertasRelacionadas y salen las líneas finales TITULO_BLOGGER / ETIQUETA_BLOGGER / TIPO_CONTRATANTE
[ ] Ciudad y Ubicación = valor REAL de la publicación (sin adivinar, sin copiar el menú del sitio ni los ejemplos de estas instrucciones)
```

---

## 8. MARCADORES (solo estos existen en esta plantilla)

| Marcador | Qué poner |
|---|---|
| `@@FUENTE@@` | Portal de origen (p. ej. `CONVOCATORIASDETRABAJO.COM`); solo en el bloque oculto |
| `@@CATEGORIA@@` | Una de las 7 de la regla 6 |
| `@@TITULO@@` | Solo el puesto, con su N° |
| `@@EMPRESA@@` | Nombre de la entidad |
| `@@SALARIO_HEADER@@` / `@@SALARIO@@` | Igual en ambos: `S/ 1,130.00` o `Remuneración acorde al mercado` |
| `@@UBICACION@@` | Ciudad + región + Perú **tal como sale de la publicación** (ej: `Sicuani, Cusco, Perú`) |
| `@@CIUDAD@@` | Ciudad real de la publicación (ej: `Sicuani`); **ejemplo, no lo copies**. Si no aparece: `No especificado` |
| `@@MODALIDAD@@` | Valor **literal** de la publicación (`Profesional`, `Preprofesional`, `Presencial`…) |
| `@@CONTRATO@@` | Tipo de contrato (`Full-time`, …) |
| `@@VACANTES@@` | Solo número o `No especificado` |
| `@@DIRIGIDO_A@@` | A quién va dirigida, tal como lo dice la publicación |
| `@@ESTUDIOS@@` / `@@EXPERIENCIA@@` / `@@JORNADA@@` | Datos de la publicación; si no existen, **borra** esa `<p>` |
| `@@FECHA_PUBLICACION@@` / `@@FECHA_CIERRE@@` | `DD/MM/AAAA` |
| `@@TIPO_CONTRATANTE@@` | `Estado` |
| `@@TIPO_CONTRATO_ESTADO@@` / `@@TIPO_ENTIDAD@@` | Valores exactos de la regla 5 |
| `@@VIGENCIA@@` | Una de las 2 cadenas fijas de la plantilla |
| `@@RESUMEN@@` | 1 o 2 frases tuyas con datos reales |
| `@@DESCRIPCION_P1@@` | Quién postula y qué pide la convocatoria (tus palabras) |
| `@@DESCRIPCION_P2@@` | De dónde sale la postulación (tus palabras) |
| `@@FUNCION1@@` … `@@FUNCION6@@` | 1 función real por `<li>`, con tus palabras; si hay **menos**, borra los sobrantes; si hay **más**, agrega `@@FUNCION7@@`, `@@FUNCION8@@`… |
| `@@URL_ORIGEN@@` | URL exacta de la publicación que se me dio |
| `@@URL_POSTULAR@@` / `@@URL_BASES@@` | Copia literal de la publicación, o `@@URL_ORIGEN@@` |

---

## 9. PLANTILLA — COPIA Y RELLENA (la única válida)

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
