# Sistema de publicación - Empleos Perú Hoy

## Estructura

```
├── PÁGINAS (7)          → se pegan en Blogger > Páginas
├── INSTRUCCIONES (4)    → se pegan en ChatGPT antes de cada publicación
├── plantilla-oferta     → se pega con INSTRUCCIONES-EMPLEOS (la rellena ChatGPT)
├── Bloque-Tema          → se pega una sola vez en Blogger > Tema
├── RESPALDO/            → registro de cambios (no se usa en el flujo)
└── _DESCARTAR/          → basura / versiones viejas
```

### Páginas (pegar en Blogger > Páginas)

| Archivo | Página | Slug |
|---|---|---|
| `INICIO-PAGE.html` | Inicio | `/` |
| `EMPLEOS-PAGE.html` | Empleos | `empleos` |
| `BECAS-PAGE.html` | Becas | `becas` |
| `CURSOS-PAGE.html` | Cursos | `cursos` |
| `ARTICULOS-PAGE.html` | Artículos | `articulos` |
| `POLITICA-PAGE.html` | Política de privacidad | `politica-de-privacidad` |
| `TERMINOS-PAGE.html` | Términos y condiciones | `terminos-y-condiciones` |

Las páginas por categoría/rubro y la página de Estado (`empleos-estado`) se descartaron (en `_DESCARTAR/`). Las categorías y el sector se filtran en Empleos.

### Instrucciones para ChatGPT (pegar como mensaje inicial)

| Archivo | Para publicar |
|---|---|
| `INSTRUCCIONES-EMPLEOS.md` | Ofertas de empleo (+ `plantilla-oferta-data.html`) |
| `INSTRUCCIONES-BECAS.md` | Becas (el template va dentro del archivo) |
| `INSTRUCCIONES-CURSOS.md` | Cursos (el template va dentro del archivo) |
| `INSTRUCCIONES-ARTICULOS.md` | Artículos (el template va dentro del archivo) |

### Tema

| Archivo | Función |
|---|---|
| `Bloque-Tema-Blogger.txt` | CSS + JS del sitio. Pegar en Blogger > Tema > Editar HTML y republicar. |
| `Bloque-Tema-Blogger.txt.backup` | Copia de seguridad del tema |

---

## Flujo: publicar una oferta de empleo

1. Copia la publicación original (texto o URL).
2. En ChatGPT: pega `INSTRUCCIONES-EMPLEOS.md` + `plantilla-oferta-data.html` + la oferta.
3. ChatGPT devuelve HTML rellenado + `TITULO_BLOGGER` + `ETIQUETA_BLOGGER=Empleo` + `TIPO_CONTRATANTE` (+ `TIPO_CONTRATO_ESTADO` / `TIPO_ENTIDAD` si es Estado).
4. En Blogger: entrada nueva → Modo HTML → pegas → etiqueta `Empleo` → Publicar.

### Sector Privado / Estado

La página de empleos usa un interruptor de solo dos opciones: **Privado | Estado** (sin “Todos”).

- **Privado** (por defecto): Modalidad, Departamento, Experiencia, Salario + carrusel de categorías.
- **Estado**: Departamento, **Contrato** (CAS, 728, 276…) y **Dónde** (Municipalidad, Ministerio…). Se ocultan Modalidad y Experiencia.
- Al cambiar de sector se limpian los filtros del modo que se oculta.
- Posts de Estado deben traer `Tipo contratante: Estado` (+ `Tipo de contrato Estado` y `Tipo de entidad`). Si el campo falta, el JS lo infiere o el post se muestra en ambos modos.
- En las tarjetas del listado **no** se muestra chip Privado/Estado (ya estás filtrando). En la entrada individual se inyecta el chip **Privado** o **Estado** a partir de `Tipo contratante`.

### SEO (sitio completo)

- **JobPosting completo**: fecha real de publicación, `validThrough` (cierre), `employmentType` (FULL_TIME…), `baseSalary` PEN, `url`, experiencia/estudios, BreadcrumbList.
- **Schema por tipo de página**: WebSite + WebPage + BreadcrumbList en listing/estáticas; Course / EducationalOccupationalProgram / Article / JobPosting según el post; ItemList en grids (se refresca a los 2.5s y 6s cuando cargan los feeds).
- **Migas de navegación** en posts, home, listings y páginas `/p/*`.
- **Anuncios al scroll**: slot cada 4 tarjetas en el grid de empleos (altura fija = sin CLS). En posts ya hay 5 slots `.empleo-anuncio`.
- **Footer interno** en Inicio, Empleos, Becas, Cursos y Artículos (enlaces cruzados).
- **Home**: hub con Empleos / Becas / Cursos / Artículos + contadores por etiqueta.

Orden recomendado: llenar bien Empleos con posts reales de ambos sectores. Más adelante, si hace falta, se retoman páginas por rubro o departamento.

Para becas, cursos y artículos: mismo flujo, pero **sin plantilla aparte** (el template está dentro de cada `INSTRUCCIONES-*.md`).

## Regla de oro

Solo se rellenan valores `@@...@@` (empleos) o `{CAMPOS}` (el resto). Si ChatGPT reescribe CSS/JS/clases, **no corrijas campo por campo**: vuelve a generar pidiendo respetar la plantilla.
