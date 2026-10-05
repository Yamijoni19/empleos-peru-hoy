<!-- =========================================================
     CORRECCIÓN DE LAS 10 BECAS EXISTENTES — ORDEN NUEVO
     ---------------------------------------------------------
     En Blogger > Entradas > cada beca > modo HTML:

     ESTRUCTURA NUEVA (respetar este orden):
       1. Bloque oculto <div style="display:none;"> con campos
          (TEXTO PLANO: "Campo: valor" — SIN <strong>/<b>)
       2. BANNER azul (título + institución)  ← PRIMERO
       3. <img> de portada (DESPUÉS del banner)
          style="...border-radius:16px;margin:14px auto;"
          (4 esquinas redondeadas, NO 16px 16px 0 0)
       4. Badges (Rama / Nivel / Cobertura)
       5. Contenido blanco (fechas, descripción, etc.)

     VALIDACIÓN DE IMAGEN (obligatoria antes de publicar):
       - Cada URL de Imagen:/<img> debe dar HTTP 200 + image/*
       - Misma URL en Imagen: y en <img src>
       - NO inventar paths; si da 404 → rehostear o pedir otra
       - Script: node .../check-becas-imagenes.js (lee este archivo)

     PASOS por cada entrada:
     1. Abrir la entrada en modo HTML
     2. Si el <img> está ANTES del banner azul:
        - CORTAR el <img> (cortar, no borrar)
        - PEGAR el <img> DESPUÉS del cierre del banner azul
        - Asegurar style:
          display:block;width:100%;height:auto;
          border-radius:16px;margin:14px auto;
     3. Si el banner azul no es el primer elemento visible
        después del bloque oculto, moverlo arriba
     4. Actualizar bloque oculto con el de abajo (si falta
        Dirigido a / Zona / Imagen / fechas)
     5. Guardar / actualizar
     6. Al terminar las 10: republicar TEMA
     ========================================================= -->

<!-- ========== 1. becas-unir-territorio-peru ========== -->
<div style="display:none;">
<div>Tipo: movilidad</div>
<div>Rama: ciencias-sociales</div>
<div>Nivel: posgrado</div>
<div>Zona: peru</div>
<div>País: Perú</div>
<div>Cobertura: nacional</div>
<div>Dirigido a: Profesionales de 5 regiones del Perú</div>
<div>Duración: Según la maestría</div>
<div>Apoyo: Hasta 60%</div>
<div>Institución: Universidad Internacional de La Rioja (UNIR)</div>
<div>Fecha de inicio: 22/06/2026</div>
<div>Fecha de cierre: 01/11/2026</div>
<div>Imagen: https://files.catbox.moe/2lw428.png</div>
</div>
<img src="https://files.catbox.moe/2lw428.png" alt="Becas Territorio en UNIR" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 2. becas-impacto-social-y-cultural-unir ========== -->
<div style="display:none;">
<div>Tipo: universitaria</div>
<div>Rama: ciencias-sociales</div>
<div>Nivel: posgrado</div>
<div>Zona: peru</div>
<div>País: Perú</div>
<div>Cobertura: nacional</div>
<div>Dirigido a: Estudiantes de maestrías en UNIR Perú</div>
<div>Duración: Según el programa</div>
<div>Institución: Universidad Internacional de La Rioja (UNIR)</div>
<div>Fecha de inicio: 07/05/2026</div>
<div>Fecha de cierre: 15/10/2026</div>
<div>Imagen: https://files.catbox.moe/ea6lu7.png</div>
</div>
<img src="https://files.catbox.moe/ea6lu7.png" alt="Becas Universitarias UNIR Perú" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 3. becas-unir-joven-peru ========== -->
<div style="display:none;">
<div>Tipo: universitaria</div>
<div>Rama: educacion</div>
<div>Nivel: posgrado</div>
<div>Zona: peru</div>
<div>País: Perú</div>
<div>Cobertura: nacional</div>
<div>Dirigido a: Jóvenes profesionales de 25 a 35 años</div>
<div>Duración: Según la maestría</div>
<div>Apoyo: Hasta 60%</div>
<div>Institución: Universidad Internacional de La Rioja (UNIR)</div>
<div>Fecha de inicio: 01/05/2026</div>
<div>Fecha de cierre: 15/10/2026</div>
<div>Imagen: https://files.catbox.moe/fzo07r.png</div>
</div>
<img src="https://files.catbox.moe/fzo07r.png" alt="Becas Joven UNIR" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 4. becas-servidor-publico-del-peru-unir ========== -->
<div style="display:none;">
<div>Tipo: excelencia</div>
<div>Rama: economia</div>
<div>Nivel: posgrado</div>
<div>Zona: peru</div>
<div>País: Perú</div>
<div>Cobertura: nacional</div>
<div>Dirigido a: Empleados públicos del Perú</div>
<div>Duración: Según la maestría</div>
<div>Apoyo: Hasta 65%</div>
<div>Institución: Universidad Internacional de La Rioja (UNIR)</div>
<div>Fecha de inicio: 02/07/2026</div>
<div>Fecha de cierre: 15/10/2026</div>
<div>Imagen: https://files.catbox.moe/gqf0u2.png</div>
</div>
<img src="https://files.catbox.moe/gqf0u2.png" alt="Becas Servidores Públicos UNIR" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 5. becas-poder-judicial-del-peru-unir ========== -->
<div style="display:none;">
<div>Tipo: universitaria</div>
<div>Rama: derecho</div>
<div>Nivel: posgrado</div>
<div>Zona: peru</div>
<div>País: Perú</div>
<div>Cobertura: nacional</div>
<div>Dirigido a: Profesionales peruanos para maestría online</div>
<div>Duración: 1 año</div>
<div>Apoyo: Hasta 65%</div>
<div>Institución: Universidad Internacional de La Rioja (UNIR)</div>
<div>Fecha de inicio: 15/06/2026</div>
<div>Fecha de cierre: 15/10/2026</div>
<div>Imagen: https://files.catbox.moe/0r1meh.png</div>
</div>
<img src="https://files.catbox.moe/0r1meh.png" alt="Becas Poder Judicial UNIR" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 6. premios-fernando-albi ========== -->
<div style="display:none;">
<div>Tipo: investigacion</div>
<div>Rama: derecho</div>
<div>Nivel: universitario</div>
<div>Zona: exterior</div>
<div>País: España</div>
<div>Cobertura: internacional</div>
<div>Dirigido a: Municipios y entidades de Alicante</div>
<div>Duración: Sujeto a la convocatoria</div>
<div>Institución: Diputación Provincial de Alicante</div>
<div>Fecha de inicio: 13/03/2026</div>
<div>Fecha de cierre: 30/11/2026</div>
<div>Imagen: https://files.catbox.moe/70ht51.png</div>
</div>
<img src="https://files.catbox.moe/70ht51.png" alt="Convocatoria Premio Fernando Albi" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 7. becas-funiber-de-excelencia-academica ========== -->
<div style="display:none;">
<div>Tipo: excelencia</div>
<div>Rama: ciencias</div>
<div>Nivel: universitario</div>
<div>Zona: exterior</div>
<div>País: España</div>
<div>Cobertura: extranjero</div>
<div>Dirigido a: Alumnos de nuevo ingreso de América Latina</div>
<div>Duración: Según el programa</div>
<div>Institución: FUNIBER - Universidad Europea del Atlántico</div>
<div>Fecha de inicio: 07/01/2026</div>
<div>Fecha de cierre: 15/10/2026</div>
<div>Imagen: https://www.uneatlantico.es/themes/uneatlantico/logo.png</div>
</div>
<img src="https://www.uneatlantico.es/themes/uneatlantico/logo.png" alt="Becas FUNIBER Excelencia LATAM" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 8. becas-pronabec-inclusion-carreras (AUIP) ========== -->
<div style="display:none;">
<div>Tipo: movilidad</div>
<div>Rama: ciencias</div>
<div>Nivel: posgrado</div>
<div>Zona: exterior</div>
<div>País: España</div>
<div>Cobertura: extranjero</div>
<div>Dirigido a: Estudiantes de posgrado de doble titulación</div>
<div>Duración: Según el máster</div>
<div>Institución: AUIP</div>
<div>Fecha de inicio: 30/09/2025</div>
<div>Fecha de cierre: 31/10/2026</div>
<div>Imagen: https://files.catbox.moe/o6mhif.jpg</div>
</div>
<img src="https://files.catbox.moe/o6mhif.jpg" alt="Becas AUIP doble titulación" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 9. becas-pronabec-master-ucm ========== -->
<div style="display:none;">
<div>Tipo: movilidad</div>
<div>Rama: ingenieria</div>
<div>Nivel: posgrado</div>
<div>Zona: exterior</div>
<div>País: España</div>
<div>Cobertura: extranjero</div>
<div>Dirigido a: Profesionales peruanos para maestría en España</div>
<div>Duración: Según el máster</div>
<div>Apoyo: Integral</div>
<div>Institución: PRONABEC y Universidad Complutense de Madrid</div>
<div>Fecha de inicio: 01/03/2026</div>
<div>Fecha de cierre: 20/10/2026</div>
<div>Imagen: https://www.pronabec.gob.pe/wp-content/uploads/2026/01/Banner-Beca-Posgrado-Espana_desktop2.png</div>
</div>
<img src="https://www.pronabec.gob.pe/wp-content/uploads/2026/01/Banner-Beca-Posgrado-Espana_desktop2.png" alt="Beca PRONABEC máster UCM" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />

<!-- ========== 10. beca-generacion-bicentenario ========== -->
<div style="display:none;">
<div>Tipo: movilidad</div>
<div>Rama: ciencias</div>
<div>Nivel: posgrado</div>
<div>Zona: exterior</div>
<div>País: España</div>
<div>Cobertura: extranjero</div>
<div>Dirigido a: Profesionales peruanos con título universitario</div>
<div>Duración: Según la maestría o doctorado</div>
<div>Apoyo: Integral</div>
<div>Institución: PRONABEC</div>
<div>Fecha de inicio: 30/10/2026</div>
<div>Fecha de cierre: 13/11/2026</div>
<div>Imagen: https://www.pronabec.gob.pe/wp-content/uploads/2026/09/becaria_bgb_banner.png</div>
</div>
<img src="https://www.pronabec.gob.pe/wp-content/uploads/2026/09/becaria_bgb_banner.png" alt="Beca Generación Bicentenario" width="800" height="450" loading="lazy" style="display:block;width:100%;height:auto;border-radius:16px;margin:14px auto;" />
