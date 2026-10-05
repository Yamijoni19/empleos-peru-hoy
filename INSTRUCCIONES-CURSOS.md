# INSTRUCCIONES PARA PUBLICAR CURSOS EN BLOGGER

**IMPORTANTE:** Genera SOLO el contenido HTML del post. Copia las plantillas EXACTAMENTE como están. NO cambies estilos, colores, estructura ni clases. Solo rellena los {CAMPOS} con la información del curso.

---

## REGLAS ABSOLUTAS (NO LAS CAMBIES POR NADA)

1. **COPIA las plantillas HTML EXACTAMENTE** — NO cambies colores, fondos, bordes, tamaños ni estructura.
2. **SOLO rellena los {CAMPOS}** con la información del curso. NO agregues campos extra.
3. **NO uses** clases CSS propias, `<table>`, `<img>`, `<br>` excesivos.
4. **Mínimo 700 palabras** de contenido descriptivo por curso.
5. **Los campos ocultos son OBLIGATORIOS** y DEBEN tener `<strong>` en cada etiqueta.
6. **El título debe ser el NOMBRE COMPLETO del curso**.
7. **NO DUPLIQUES información** — La info rápida va UNA sola vez.
8. **NO hagas bloques gigantes de texto** — Máximo 3-4 párrafos por sección.
9. **TODOS los `<li>` DEBEN tener `<span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span>`** — NUNCA el icono como texto plano.
10. **Cada sección DEBE estar envuelta en `<div class="empleo-seccion">`**.

---

## ⚠️ CAMPOS OCULTOS — FORMATO EXACTO (NO LO CAMBIES)

Los campos ocultos alimentan la tarjeta del curso. Si cambias el formato, la tarjeta no aparece.

**Formato EXACTO — copia tal cual:**
```html
<div style="display:none;">
<p><strong>Tipo:</strong> {Tipo}</p>
<p><strong>Nivel:</strong> {Nivel}</p>
<p><strong>Duración:</strong> {Duración}</p>
<p><strong>Modalidad:</strong> {Modalidad}</p>
<p><strong>Institución:</strong> {Institución}</p>
<p><strong>Precio:</strong> {Precio}</p>
<p><strong>Certificado:</strong> {Sí o No}</p>
</div>
```

**❌ ESTO ESTÁ MAL (sin <strong>):**
```html
<div style="display:none;">
<p>Tipo: Otros</p>
<p>Nivel: Básico</p>
</div>
```

**✅ ESTO ESTÁ BIEN (con <strong>):**
```html
<div style="display:none;">
<p><strong>Tipo:</strong> Otros</p>
<p><strong>Nivel:</strong> Básico</p>
</div>
```

---

## PLANTILLA COMPLETA — COPIA Y RELLENA

Copia TODO el siguiente HTML. Solo cambia los {CAMPOS} con la info del curso.

```html
<h2><strong>{NOMBRE COMPLETO DEL CURSO}</strong></h2>

<div class="empleo-seccion">
<h2>📋 Información del curso</h2>
<div style="background:linear-gradient(135deg,#eef2ff,#e0e7ff);padding:20px 24px;border-radius:12px;border-left:5px solid #4f46e5;">
<p style="margin:0 0 10px;font-size:16px;color:#3730a3;font-weight:700;">📋 Información rápida del curso</p>
<p style="margin:0;font-size:14px;color:#374151;line-height:1.8;">
<strong>🏛️ Institución:</strong> {INSTITUCIÓN}<br>
<strong>📚 Tipo:</strong> {TIPO}<br>
<strong>📊 Nivel:</strong> {NIVEL}<br>
<strong>⏱️ Duración:</strong> {DURACIÓN}<br>
<strong>💻 Modalidad:</strong> {MODALIDAD}<br>
<strong>💰 Precio:</strong> {PRECIO}<br>
<strong>🎓 Certificado:</strong> {SÍ o NO}<br>
<strong>🌐 Idioma:</strong> {IDIOMA}
</p>
</div>
</div>

<div class="empleo-seccion">
<h2>🎯 ¿De qué trata este curso?</h2>
<p>{PÁRRAFO 1 - Qué es el curso y para quién (3-4 líneas)}</p>
<p>{PÁRRAFO 2 - Qué habilidades desarrollarás (3-4 líneas)}</p>
<p>{PÁRRAFO 3 - Por qué es útil para tu perfil (3-4 líneas)}</p>
</div>

<div class="empleo-seccion">
<h2>✅ ¿Qué aprenderás?</h2>
<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:20px 24px;">
<ul style="margin:0;padding-left:0;list-style:none;">
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 1}</strong> — {explicación corta}.</li>
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 2}</strong> — {explicación corta}.</li>
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 3}</strong> — {explicación corta}.</li>
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 4}</strong> — {explicación corta}.</li>
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 5}</strong> — {explicación corta}.</li>
<li style="margin-bottom:12px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span> <strong>{HABILIDAD 6}</strong> — {explicación corta}.</li>
</ul>
</div>
</div>

<div class="empleo-seccion">
<h2>📚 Contenido del programa</h2>
<div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;padding:20px 24px;">
<div style="margin-bottom:14px;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #0f4c81;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 1:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
<div style="margin-bottom:14px;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #1976d2;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 2:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
<div style="margin-bottom:14px;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #0d9488;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 3:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
<div style="margin-bottom:14px;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #b45309;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 4:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
<div style="margin-bottom:14px;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #6d28d9;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 5:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
<div style="margin:0;padding:12px 16px;background:#fff;border-radius:10px;border-left:4px solid #16a34a;">
<p style="margin:0;font-size:15px;color:#1e293b;"><strong>Módulo 6:</strong> {NOMBRE MÓDULO} — {descripción de 1 línea}</p>
</div>
</div>
</div>

<div class="empleo-seccion">
<h2>📌 Requisitos previos</h2>
<div style="background:#fffbeb;border:1px solid #fde68a;border-radius:12px;padding:18px 22px;">
<ul style="margin:0;padding-left:0;list-style:none;">
<li style="margin-bottom:8px;padding-left:22px;position:relative;font-size:15px;color:#374151;line-height:1.6;"><span style="position:absolute;left:0;top:2px;">📌</span> {REQUISITO 1}</li>
<li style="margin-bottom:8px;padding-left:22px;position:relative;font-size:15px;color:#374151;line-height:1.6;"><span style="position:absolute;left:0;top:2px;">📌</span> {REQUISITO 2}</li>
<li style="margin-bottom:0;padding-left:22px;position:relative;font-size:15px;color:#374151;line-height:1.6;"><span style="position:absolute;left:0;top:2px;">📌</span> {REQUISITO 3}</li>
</ul>
</div>
</div>

<div class="empleo-seccion">
<h2>🏆 Beneficios del certificado</h2>
<div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:12px;padding:20px 24px;">
<ul style="margin:0;padding-left:0;list-style:none;">
<li style="margin-bottom:10px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#2563eb;font-weight:700;">★</span> {BENEFICIO 1}</li>
<li style="margin-bottom:10px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#2563eb;font-weight:700;">★</span> {BENEFICIO 2}</li>
<li style="margin-bottom:10px;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#2563eb;font-weight:700;">★</span> {BENEFICIO 3}</li>
<li style="margin-bottom:0;padding-left:28px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:0;color:#2563eb;font-weight:700;">★</span> {BENEFICIO 4}</li>
</ul>
</div>
</div>

<div class="empleo-seccion">
<h2>🚀 Cómo inscribirse</h2>
<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:20px 24px;">
<ol style="margin:0;padding-left:0;list-style:none;counter-reset:none;">
<li style="margin-bottom:12px;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">1</span> {PASO 1}</li>
<li style="margin-bottom:12px;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">2</span> {PASO 2}</li>
<li style="margin-bottom:12px;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">3</span> {PASO 3}</li>
<li style="margin-bottom:12px;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">4</span> {PASO 4}</li>
<li style="margin-bottom:12px;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">5</span> {PASO 5}</li>
<li style="margin-bottom:0;padding-left:36px;position:relative;font-size:15px;color:#374151;line-height:1.7;"><span style="position:absolute;left:0;top:1px;width:24px;height:24px;background:linear-gradient(135deg,#16a34a,#22c55e);color:#fff;border-radius:50%;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;">6</span> {PASO 6}</li>
</ol>
</div>
</div>

<div class="empleo-seccion">
<h2>🔗 Enlace oficial</h2>
<div style="background:linear-gradient(135deg,#ede9fe,#f5f3ff);border:1px solid #c4b5fd;border-radius:12px;padding:18px 22px;text-align:center;">
<p style="margin:0;font-size:15px;"><strong>{NOMBRE PLATAFORMA}:</strong> <a href="{URL}" target="_blank" rel="noopener" style="color:#2563eb;text-decoration:underline;font-weight:600;">{URL}</a></p>
</div>
</div>

<div class="empleo-seccion">
<h2>💡 ¿Por qué tomar este curso?</h2>
<div style="background:linear-gradient(135deg,#fef3c7,#fef9c3);border:1px solid #fde68a;border-radius:12px;padding:20px 24px;">
<p style="margin:0 0 12px;font-size:15px;color:#92400e;line-height:1.8;">{PÁRRAFO 1 - Ventajas del curso (3-4 líneas)}</p>
<p style="margin:0 0 12px;font-size:15px;color:#92400e;line-height:1.8;">{PÁRRAFO 2 - Oportunidades laborales (3-4 líneas)}</p>
<p style="margin:0;font-size:15px;color:#92400e;line-height:1.8;">{PÁRRAFO 3 - Inversión de tiempo (3-4 líneas)}</p>
</div>
</div>

<div class="empleo-seccion">
<h2>❓ Preguntas frecuentes</h2>

<div style="margin-bottom:16px;padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿El curso es realmente gratuito?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>

<div style="margin-bottom:16px;padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿Cuánto tiempo tengo para completarlo?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>

<div style="margin-bottom:16px;padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿El certificado tiene validez en Perú?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>

<div style="margin-bottom:16px;padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿Necesito conocimientos previos?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>

<div style="margin-bottom:16px;padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿Puedo poner el certificado en mi currículum?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>

<div style="padding:16px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;">
<p style="margin:0 0 6px;font-size:16px;color:#0f4c81;font-weight:700;">¿Hay fecha límite para inscribirse?</p>
<p style="margin:0;font-size:15px;color:#374151;line-height:1.7;">{Respuesta de 2-3 líneas.}</p>
</div>
</div>

<div style="display:none;">
<p><strong>Tipo:</strong> {TIPO}</p>
<p><strong>Nivel:</strong> {NIVEL}</p>
<p><strong>Duración:</strong> {DURACIÓN}</p>
<p><strong>Modalidad:</strong> {MODALIDAD}</p>
<p><strong>Institución:</strong> {INSTITUCIÓN}</p>
<p><strong>Precio:</strong> {PRECIO}</p>
<p><strong>Certificado:</strong> {SÍ o NO}</p>
</div>
```

---

## VALORES VÁLIDOS

- **Tipo:** Tecnología, Negocios, Desarrollo, Diseño, Idiomas, Otros
- **Nivel:** Básico, Intermedio, o Avanzado
- **Modalidad:** Virtual, Presencial, o Semipresencial
- **Certificado:** Sí o No

---

## CHECKLIST FINAL (VERIFICA ANTES DE ENTREGAR)

- [ ] El título es el NOMBRE COMPLETO del curso
- [ ] Cada sección tiene `<div class="empleo-seccion">`
- [ ] Info rápida con el estilo EXACTO (gradiente morado, border-left #4f46e5)
- [ ] Checkmarks con `<span style="position:absolute;left:0;top:0;color:#16a34a;font-weight:700;">✓</span>`
- [ ] Módulos en tarjetas con borde de color (no solo <h3>)
- [ ] Pasos con círculos verdes (no emojis 1️⃣ 2️⃣)
- [ ] FAQ con `<p>` (no `<h3>`) para las preguntas
- [ ] **Campos ocultos con `<strong>` en cada etiqueta**
- [ ] **NO hay campos extra** como "Ruta formativa"
- [ ] **NO hay clases CSS propias**
