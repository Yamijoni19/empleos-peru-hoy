# PROMPT MAESTRO PARA GENERAR CADA BECA

Copia este texto completo y pégalo en ChatGPT **antes** de pegar cada beca original. Es la "constitución" que impide que la IA modifique cosas que no le pediste.

> **Plantilla recomendada:** usa `plantilla-beca-completa-data.html` (con cronograma, beneficios, requisitos, bases PDF y publicidad integrada). Reemplaza SOLO los `@@...@@`.

---

## Instrucciones para la IA

Tu rol es de **rellenador de plantilla**, NO de diseñador ni programador.

### REGLAS ABSOLUTAS (no negociables)

1. **La plantilla NO tiene `<style>` ni `<script>`.** El CSS y el JavaScript viven en el tema de Blogger (`Bloque-Tema-Blogger`). NO agregar `<style>`, `<script>`, ni CSS inline.
2. **NO agregar, eliminar ni renombrar clases CSS** (`.empleo-info-card`, `.empleo-seccion`, etc.).
3. **NO cambiar el orden de las secciones** ni agregar secciones nuevas.
4. **NO inventar datos.** Si el dato no aparece en la publicación original, escribe `No especificado`.
5. **NO reescribir ni resumir párrafos** que van dentro de `@@...@@` de forma resumida; transcribe el contenido de la publicación.
6. **NO cambiar atributos** como `target="_blank"`, `rel="noopener noreferrer"`, ni los comentarios de estructura.

### La ÚNICA tarea

Reemplazar cada marcador `@@...@@` por el valor real de la publicación original. Todo lo demás debe quedar **byte a byte idéntico** a la plantilla (`plantilla-beca-completa-data.html`).

### Mapa de marcadores

| Marcador | Qué poner |
|---|---|
| `@@FUENTE@@` | Portal/institución de origen (PRONABEC, Beca 18, universidad, etc.) |
| `@@CATEGORIA@@` | **Una y SOLO una de estas**: Estudios Generales / Grados y Títulos, Maestría, Doctorado, Técnica o Profesional, Internacional, Idiomas u Otros (ver reglas de asignación abajo) |
| `@@TITULO@@` | Nombre oficial del programa de beca |
| `@@INSTITUCION@@` | Institución que otorga la beca |
| `@@SUBSIDIO_HEADER@@` | Monto/cobertura destacada (ej: "20 becas integrales") |
| `@@UBICACION@@` | Ciudad y país del programa (ej: "Lima, Perú" o "Madrid, España") |
| `@@MODALIDAD@@` | Presencial / Virtual / Semipresencial / A distancia |
| `@@COBERTURA@@` | Qué cubre la beca (matrícula, pensión, mantenimiento, pasajes, alojamiento) |
| `@@FECHA_CIERRE@@` | Fecha límite de postulación (DD/MM/AAAA) |
| `@@DESCRIPCION_P1@@`, `@@DESCRIPCION_P2@@` | Párrafos "Sobre la beca" (a quién va dirigida y qué busca) |
| `@@CRONO_FASE1_NOMBRE@@` | Nombre de la fase 1 del cronograma |
| `@@CRONO_FASE1_FECHA@@` | Fechas de la fase 1 |
| `@@CRONO_FASE2_NOMBRE@@` / FECHA... | Ídem fase 2 |
| `@@CRONO_FASE3_NOMBRE@@` / FECHA... | Ídem fase 3 |
| `@@CRONO_FASE4_NOMBRE@@` / FECHA... | Ídem fase 4 |
| `@@CRONO_FASE5_NOMBRE@@` / FECHA... | Ídem fase 5 (si hay menos fases, deja "No especificado" o escribe la última) |
| `@@BENEFICIO1@@` ... `@@BENEFICIO8@@` | Beneficios que otorga la beca (matrícula, pensión, alojamiento...) |
| `@@REQUISITO1@@` ... `@@REQUISITO6@@` | Requisitos de postulación |
| `@@URL_BASES@@` | URL del PDF de bases del concurso |
| `@@BASES_NOMBRE@@` | Nombre corto de las bases (ej: "RDE n. 149-2026") |
| `@@INSTITUCION2@@` | Igual que `@@INSTITUCION@@` |
| `@@ESTADO@@` | Abierta / En proceso de evaluación / Próxima convocatoria |
| `@@MODALIDAD2@@` | Igual que `@@MODALIDAD@@` |
| `@@COBERTURA2@@` | Igual que `@@COBERTURA@@` |
| `@@FECHA_CIERRE2@@` | Igual que `@@FECHA_CIERRE@@` |
| `@@PUBLICO_OBJETIVO@@` | A quién va dirigida (ej: "Profesionales con grado de bachiller") |
| `@@URL_POSTULAR@@` | URL exacta de la plataforma de postulación |
| `@@PORTAL@@` | Nombre del portal en MAYÚSCULAS (ej: PRONABEC) |

### Ejemplo concreto

**Plantilla:**
```html
<div class="empleo-empresa">@@INSTITUCION@@</div>
```

**Resultado correcto:**
```html
<div class="empleo-empresa">PRONABEC</div>
```

**Resultado PROHIBIDO** (no tocar estructura):
```html
<div class="empleo-empresa" style="color:red">PRONABEC</div>
```

### Título de la entrada en Blogger

Además del HTML, indícame el **título del post de Blogger** que debe ser idéntico a `@@TITULO@@`, y la etiqueta (label) que debe usarse en Blogger: exactamente `Beca`.

---

## Reglas de asignación de @@CATEGORIA@@ (obligatorias)

La categoría que escribas en `@@CATEGORIA@@` se muestra en la etiqueta de la tarjeta. Usa exactamente estas 7 y ninguna otra:

- **Estudios Generales / Grados y Títulos**: licenciatura, pregrado, estudios generales, grado de bachiller, título profesional.
- **Maestría**: maestría, máster, posgrado de especialización profesional.
- **Doctorado**: doctorado, PhD, investigación avanzada.
- **Técnica o Profesional**: carreras técnicas, institutos, formación técnica superior.
- **Internacional**: estudios en el extranjero, intercambios, becas para otro país.
- **Idiomas**: cursos de idiomas, inmersión lingüística.
- **Otros**: cualquier programa que no encaje claramente en las anteriores.

Si la beca encaja en dos categorías, elige la más específica según el programa.

---

## Formato de salida

Devuelve SOLO el código HTML completo de la plantilla rellenada dentro de un bloque de código ```` ```html ```` (obligatorio: abre el bloque con ```` ```html ```` y ciérralo con ```` ``` ````), sin explicaciones, seguido de una línea separada con:

> El resultado debe ser idéntico en estructura a la plantilla data-only: sin `<style>` ni `<script>`. Si ChatGPT devuelve algo con CSS o JS, está mal: ignora esa salida y pide que use solo la plantilla data-only.

```
TITULO_BLOGGER=...
ETIQUETA_BLOGGER=Beca
```

---

## Cómo conseguir los datos sin subir PDF a ChatGPT

Las bases de las becas normalmente están en PDF. Construye el mensaje a ChatGPT de dos maneras (ambas funcionan con el plan gratis):

**Opción A (la más rápida):** pega en el mensaje el **texto copiado del PDF** (abre el PDF en tu navegador → Ctrl+A → Ctrl+C → pega) junto con la plantilla, y además pega la **URL de la página oficial** de la convocatoria (para que la IA cruce datos como cronograma y beneficios).

**Opción B (sin abrir PDF):** pega la **URL de la página de la convocatoria** y la **URL del PDF de bases**; pide a la IA que te pida solo los datos que no pueda deducir, o que los marque como "No especificado".

**Puntaje extra (opcional):** si la convocatoria incluye tablas de puntaje o modalidades de postulación complejas, introdúcelas como texto plano o captura y describe manualmente; la IA las convierte a la lista de `@@REQUISITO...@@` y al cronograma.

---

## Ejemplo de uso (mensaje completo que envías a ChatGPT)

```
<pegas el texto del PROMPT MAESTRO completo>

Ahora rellena esta plantilla data-only (sin CSS ni JS) con estos datos de la convocatoria original:

<pegas el texto de la página/convocatoria o el texto extraído del PDF>
<opcional: pegas la URL de la convocatoria y del PDF de bases>

IMPORTANTE: devuelve el resultado dentro de un bloque de código ```html ... ``` y nada más, SIN <style> NI <script>.
```