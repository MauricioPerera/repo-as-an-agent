---
name: okf-librarian
description: >-
  Creates, updates, links, and validates structured memory nodes inside knowledge/
  following the Open Knowledge Format (OKF) specification. Use this skill whenever
  storing durable project knowledge, business rules, glossaries, client notes, or
  decisions, or when okf-lint.sh reports validation errors.
---

# Curaduría de Memoria en Open Knowledge Format (`okf-librarian`)

La carpeta `knowledge/` es la memoria duradera, legible por humanos y versionada en Git de este espacio. Todo cambio en `knowledge/` es auditado automáticamente por [okf-lint.sh](../../scripts/okf-lint.sh) en cada punto de guardado.

## Reglas Estrictas del Estándar OKF

1. **Carga Progresiva:** Siempre lee primero [index.md](../../../knowledge/index.md) antes de recorrer subcarpetas completas.
2. **Archivos Estructurales Reservados:**
   - `knowledge/index.md` y `knowledge/log.md` (y cualquier `index.md`/`log.md` en subdirectorios) son archivos estructurales.
   - **Prohibido** asignarles `type:` de concepto en un YAML frontmatter.
3. **Documentos de Concepto (`knowledge/<dominio>/<concepto>.md`):**
   - Usa nombres en minúsculas con guiones (`acuerdos-precios.md`, `glosario-legal.md`).
   - Todo concepto **DEBE** iniciar en la línea 1 con YAML frontmatter válido:
     ```yaml
     ---
     type: '<Tipo de Concepto>'          # OBLIGATORIO: ej. 'Glossary', 'Decision Record', 'Client Profile', 'Playbook'
     title: '<Título legible>'           # OBLIGATORIO en esta plantilla
     description: '<Resumen en 1 línea>' # OBLIGATORIO en esta plantilla
     tags: ['<tag1>', '<tag2>']          # Recomendado
     timestamp: '<ISO-8601>'             # Recomendado
     ---
     ```
   - Debe contener al menos un bloque de contenido Markdown claro después del cierre `---`.
4. **Grafo de Enlaces Relativos:**
   - Conecta conceptos relacionados usando enlaces Markdown relativos reales (ej. `[Perfil del Espacio](../profile/context.md)`).
   - **Nunca dejes enlaces rotos:** `okf-lint.sh` verifica físicamente cada ruta enlazada.

## Flujo de Trabajo Paso a Paso

1. Revisa [index.md](../../../knowledge/index.md) para comprobar si ya existe un nodo sobre ese tema (actualízalo en lugar de duplicarlo).
2. Crea o edita el nodo `<concepto>.md` dentro de una subcarpeta temática adecuada (ej. `knowledge/dominio/`, `knowledge/clientes/`, `knowledge/decisiones/`).
3. Si creaste un concepto nuevo, enlázalo en [index.md](../../../knowledge/index.md).
4. Registra una entrada breve con fecha en [log.md](../../../knowledge/log.md) describiendo qué aprendió o actualizó el espacio.
5. **Validación determinista obligatoria:**
   Ejecuta siempre:
   ```sh
   sh .agents/scripts/okf-lint.sh
   ```
   Asegúrate de obtener `OKF_LINT_STATUS=PASS` antes de crear un punto de guardado.
