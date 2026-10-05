# INSTRUCCIONES — OFERTAS DEL SECTOR PRIVADO (6 secciones, sin copiar la fuente)

> **Nota para quien pega este archivo:** úsalo cuando el empleador sea una **empresa particular** (no hay CAS, 728, 276, Prácticas, Servicio Civil, Municipalidad, Ministerio ni Gobierno). Si es del Estado, usa `INSTRUCCIONES-ESTADO.md`. Pega este archivo completo **y debajo** la URL (o el texto) de la publicación original, en un chat **nuevo**, y pide **una** entrada por mensaje. El HTML que te devuelvan va **listo para pegar**: cópialo directo en Blogger con `Ctrl+V`. `corregir-entrada.cmd` **no** es parte del flujo: úsalo solo si algo salió mal.

> **Flujo automático (sin IA):** para las convocatorias del Estado existe `generar-entrada.cmd` (pegas la URL y te devuelve el HTML listo en el portapapeles). Por ahora **solo cubre entradas de Estado**, así que en las empresas particulares sigue el flujo de este archivo; eso sí, pásale la URL del texto (no solo el enlace) para que la IA no tenga que leerla, y revisa el resultado con `comparar-entrada.cmd` antes de publicar (detecta datos inventados). El flujo en lote (`obtener-urls.cmd`, `generar-lote.cmd`, `publicar-blogger.cmd`, `flujocompleto.cmd`) también es **solo Estado**: en particulares sigue este archivo.

---

## 1. Tu tarea (una sola cosa)

Rellenar la **PLANTILLA DE OFERTA (SECTOR PRIVADO)** que está en el punto 9: solo sustituyes los textos `@@...@@`. Todo lo demás (CSS, clases, orden, títulos) queda **idéntico, byte por byte**.

**NO** reconstruyas la plantilla de memoria. **NO** la resumas. **NO** le cambies los títulos de sección.

---

## 2. Cómo debe ser tu respuesta

**SOLO** estas dos cosas, en este orden:

**A) ANTES del HTML — bloque de CONTROL** (fuera de cualquier bloque de código):

```
URL_ORIGEN = <URL exacta de la publicación que se me dio>
URL_POSTULAR = <URL copiada literal, o URL_ORIGEN>
TIPO_CONTRATANTE = Privado
TITULO_BLOGGER = <igual que el título del <h1> de la entrada>
ETIQUETA_BLOGGER = Empleo
SECCIONES_PRIVADO = 6/6 <los 6 títulos de la regla 3, en orden>
```

**B) DESPUÉS — el HTML completo**, dentro de un bloque ` ```html `.

**Nada más.** Sin explicaciones ni resúmenes. Nunca empieces por el HTML: sin bloque de CONTROL, la respuesta se descarta.

---

## 3. REGLA 1: los 6 títulos de sección (obligatorios, en este orden)

El HTML debe contener **exactamente** estos 6 `<h2>`, sin cambiar una letra, sin reordenarlos, sin añadir ni quitar ninguno:

1. `<h2>Descripción del puesto</h2>` → `@@DESCRIPCION_P1@@` (qué hace el puesto) y `@@DESCRIPCION_P2@@` (cómo es la empresa / el equipo), **escritos por ti**.
2. `<h2>Funciones</h2>` → `@@FUNCION1@@` … `@@FUNCION6@@`, 1 por `<li>`, con tus palabras.
3. `<h2>Requisitos</h2>` → `@@REQUISITO1@@` … `@@REQUISITO5@@`, 1 por `<li>`, con tus palabras.
4. `<h2>Información de la oferta</h2>` → recuadro con vacantes, jornada, contrato, modalidad, experiencia, estudios, salario, fechas y los 3 campos de tipo.
5. `<h2>Beneficios</h2>` → `@@BENEFICIO1@@` … `@@BENEFICIO4@@`.
6. `<h2>Información de la empresa</h2>` → empresa, sector, tamaño, ubicación y descripción.

Después van, sin contar como secciones: `<h2>¿Te interesa esta oferta?</h2>` (caja con el botón) y `<h2>Ofertas recomendadas para ti</h2>`.

**PROHIBIDO** en entradas privadas usar los títulos de las convocatorias del Estado (si aparece cualquiera, la respuesta se rechaza):

`Resumen de la convocatoria` · `Perfil y funciones del puesto` · `Lo que ofrece esta convocatoria` · `Pasos para postular` · `Bases y anexos oficiales` · `Consejos antes de postular` · `Resultados y siguientes pasos`

Si tu borrador no trae esos 6 títulos en ese orden, **corrígelo antes de entregar**: no se entrega nada "a medias".

---

## 4. REGLA 2: NO copies y pegues la publicación (la que más se incumple)

La entrada no debe parecer un calco del anuncio. **Prohibido copiar dos frases seguidas** tal como vienen en la fuente (salvo datos duros, ver abajo).

**MALO (prohibido):**

> "Se requiere título profesional en Contabilidad emitido por universidad reconocida por SUNEDU, con conocimientos en normativa tributaria y experiencia mínima de dos años."

**BUENO (así sí):**

> "Buscan contadores con título de una universidad reconocida por SUNEDU; valoran el dominio de la normativa tributaria y al menos dos años de experiencia en el área."

Reglas duras:

- **Lee, entiende y reescribe**: cambia el orden de las frases, usa sinónimos, voz activa en vez de pasiva. **No** cambies el significado, **no** inventes requisitos ni **no** borres obligaciones importantes.
- Cada `<li>` de *Funciones*, *Requisitos* y *Beneficios* se redacta distinto al original, conservando el dato que aporta.
- **Prohibidas** las frases-publicidad de la fuente, p. ej. `Descarga las bases para revisar los requisitos completos`.
- **Se copia LITERAL solo esto:** nombre de la empresa y del portal, N° de oferta, fechas en `DD/MM/AAAA`, montos (`S/ 2,500`), número de vacantes, ciudades, siglas, nombres propios y **URLs**.
- Los títulos de las secciones son los 6 de la regla 3: **nunca** salen de la publicación.

---

## 5. REGLA 3: datos, fechas y `No especificado`

| Dato | Regla |
|---|---|
| `@@FECHA_CIERRE@@` | **Siempre `DD/MM/AAAA`**, solo la fecha (sin hora). `5 de noviembre de 2026` → `05/11/2026`. Si no hay fecha: `No especificada` **y borra esa `<p>` del recuadro** |
| `@@FECHA_PUBLICACION@@` | `DD/MM/AAAA` (campo `datePosted` del JSON-LD si existe) |
| `@@VACANTES@@` | Solo el número (`3`), nunca `3 vacantes`. Sin número: `No especificado` |
| `@@TIPO_CONTRATANTE@@` | Exactamente `Privado` (prohibido `Empresa`, `Particular`, `Público`, vacío…) |
| `@@TIPO_CONTRATO_ESTADO@@` | Exactamente `No aplica` (no existe en el sector privado) |
| `@@TIPO_ENTIDAD@@` | Exactamente `No aplica` |
| Dato inexistente | **Recuadros de la ficha**: `No especificado`. En `.empleo-destacado` y en `<ul>`: **borra la `<p>`/`<li>`**. Nunca dejes `<li>No especificado</li>` a la vista. **No** dejes `@@...@@` sin rellenar |

---

## 6. REGLA 4: no toques la estructura

- Nada de `<style>`, `<script>`, CSS inline ni clases nuevas (el CSS y el JS viven en el tema de Blogger).
- **Sin bloque oculto**: esta plantilla no lleva `<div class="empleo-datos-ocultos">`; no lo agregues.
- **Sin banner de vigencia**: no agregues `<p class="empleo-vigencia">` (es exclusivo de las convocatorias del Estado).
- La cabecera **sí** lleva su línea `Fuente: @@FUENTE@@` (`.empleo-fuente`): no la borres.
- Los 4 recuadros de la ficha (**Ubicación, Modalidad, Contrato, Salario**) **nunca** se borran ni se reordenan.
- **Un solo botón** con enlace en toda la entrada: `POSTULAR EN <PORTAL>` en la caja final.
- Enlaces = **copia carácter por carácter** de la publicación (mismo `http/https`, mismo dominio, mismo **puerto**, misma ruta, misma query y mismo `#`). Si no lo copiaste exacto → `@@URL_ORIGEN@@`. **Prohibido** inventar, limpiar o acortar URLs.
- `@@TITULO@@` = el puesto completo. `TITULO_BLOGGER` = **igual** al del `<h1>` (sin prefijo de entidad: eso es solo del Estado).
- Etiqueta = **solo** `Empleo` (una sola; nunca agregues `Estado` ni `Privado`).
- `@@CATEGORIA@@` = una sola de: `Ingeniería`, `Salud`, `Ventas y Servicios`, `Administración y Finanzas`, `Derecho`, `Educación`, `Otros`.
- `@@PORTAL@@` = nombre del portal en MAYÚSCULAS (`BUMERAN`, `COMPUTRABAJO`, `APTITUS`).

---

## 7. AUTOCHEQUEO — recórrerlo sobre TU HTML antes de responder

Abre el HTML que acabas de escribir y verifica cada punto **leyendo tu propio código**, no de memoria. Si alguno queda con `[ ]`, **no entregues**: corrige el HTML y vuelve a empezar el recorrido. Solo respondes con **todos** los puntos en `[x]`.

```
[ ] Los 6 <h2> son exactamente los de la regla 3 y van en ese orden
[ ] Ningún título de la lista PROHIBIDA (los del Estado) aparece en el HTML
[ ] Ningún párrafo viene 2 frases seguidas copiado de la publicación (solo datos duros literales)
[ ] No quedó ningún @@...@@ sin reemplazar
[ ] FECHA_CIERRE y FECHA_PUBLICACION en DD/MM/AAAA
[ ] TIPO_CONTRATANTE=Privado, TIPO_CONTRATO_ESTADO=No aplica, TIPO_ENTIDAD=No aplica
[ ] Un solo botón "POSTULAR EN <PORTAL>"; ningún otro <a> de más
[ ] Cada href es copia literal de una URL de la publicación (si no, = URL_ORIGEN)
[ ] La cabecera conserva la línea de Fuente y NO agregué bloque oculto ni vigencia
[ ] Los 4 recuadros (Ubicación, Modalidad, Contrato, Salario) están completos
[ ] Ningún "No especificado" visible fuera de los 4 recuadros
[ ] Sin <style>, <script> ni style= en el HTML (el CSS vive en el tema de Blogger)
[ ] Ningún artefacto de cita (:contentReference, oaicite, [citation]) quedó en el HTML
[ ] Sin textos de botón prohibidos ("Ver publicación oficial", "Ver convocatoria oficial", "Ir a la convocatoria oficial")
[ ] Existe #ofertasRelacionadas y salen las líneas finales TITULO_BLOGGER / ETIQUETA_BLOGGER / TIPO_CONTRATANTE
```

---

## 8. MARCADORES (solo estos existen en esta plantilla)

| Marcador | Qué poner |
|---|---|
| `@@FUENTE@@` | Portal de origen (`BUMERAN`, `COMPUTRABAJO`…) |
| `@@CATEGORIA@@` | Una de las 7 de la regla 6 |
| `@@TITULO@@` | Puesto completo |
| `@@EMPRESA@@` / `@@EMPRESA2@@` | Igual en ambos: nombre de la empresa |
| `@@SALARIO_HEADER@@` / `@@SALARIO@@` / `@@SALARIO2@@` | Igual en los tres: `S/ 2,500` o `S/. 2,500` |
| `@@UBICACION@@` | Ciudad + departamento + país **reales de la publicación** (ej: `Lima, Lima, Perú` — ejemplo, no lo copies; si no aparece: `No especificado`) |
| `@@MODALIDAD@@` / `@@MODALIDAD2@@` | Igual en ambos: `Presencial` / `Remoto` / `Híbrido` |
| `@@CONTRATO@@` / `@@CONTRATO2@@` | Igual en ambos: `Full-time`, `Part-time`… |
| `@@DESCRIPCION_P1@@` | Qué hace el puesto (tus palabras) |
| `@@DESCRIPCION_P2@@` | Cómo es la empresa / el equipo (tus palabras) |
| `@@FUNCION1@@` … `@@FUNCION6@@` | 1 función por `<li>`; si hay menos, **borra** los sobrantes; si hay más, agrega `@@FUNCION7@@`… |
| `@@REQUISITO1@@` … `@@REQUISITO5@@` | Ídem para requisitos |
| `@@BENEFICIO1@@` … `@@BENEFICIO4@@` | Ídem para beneficios |
| `@@VACANTES@@` | Solo número o `No especificado` |
| `@@JORNADA@@` / `@@EXPERIENCIA@@` / `@@ESTUDIOS@@` | Datos de la publicación; si no existen, **borra** esa `<p>` |
| `@@FECHA_PUBLICACION@@` / `@@FECHA_CIERRE@@` | `DD/MM/AAAA` |
| `@@TIPO_CONTRATANTE@@` | `Privado` |
| `@@TIPO_CONTRATO_ESTADO@@` / `@@TIPO_ENTIDAD@@` | `No aplica` |
| `@@SECTOR@@` / `@@TAMANO@@` / `@@UBICACION_EMPRESA@@` / `@@DESCRIPCION_EMPRESA@@` | Datos de la empresa; si no existen, `No especificado` |
| `@@URL_POSTULAR@@` | Copia literal de la publicación, o `@@URL_ORIGEN@@` |
| `@@PORTAL@@` | Nombre del portal en MAYÚSCULAS |

---

## 9. PLANTILLA — COPIA Y RELLENA (la única válida)

```html
<!-- =========================================================
     PLANTILLA DE OFERTA INDIVIDUAL - VERSION DATA-ONLY
     EL CSS Y EL JS VIVEN EN EL TEMA DE BLOGGER
     (Blogger > Tema > Editar HTML: Bloque-Tema-Blogger)
     Solamente reemplaza los textos marcados con @@...@@
     ========================================================= -->

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
