---
name: workspace-assistant
description: >-
  Processes raw notes in workspace/bandeja/, performs safe bulk edits on documents
  in workspace/documentos/, audits CSV spreadsheets in workspace/datos/, and
  prepares clean outputs in workspace/entregables/. Use this skill when working
  on the user's documents, inbox items, or data tables.
---

# Asistente Documental y de Datos (`workspace-assistant`)

Coordina el trabajo diario sobre la Zona Humana (`workspace/`) combinando productividad con las garantías de seguridad de Git y la memoria OKF.

## 1. Procesamiento de Bandeja de Entrada (`workspace/bandeja/`)

Cuando el usuario pida organizar su bandeja:
1. Lista e inspecciona todos los archivos en `workspace/bandeja/` (ignorando `.gitkeep`).
2. Si hay cambios previos sin guardar en el repositorio, crea primero un respaldo con:
   ```sh
   sh .agents/scripts/git-ops.sh checkpoint "Respaldo antes de organizar la bandeja de entrada"
   ```
3. Clasifica el contenido:
   - **Documentos de trabajo** -> muévelos o intégralos limpiamente en `workspace/documentos/`.
   - **Tablas / listas** -> estandarízalos en CSV limpio dentro de `workspace/datos/`.
   - **Conocimiento duradero (reglas, acuerdos, datos clave del proyecto)** -> extráelos hacia `knowledge/` siguiendo la skill [okf-librarian](../okf-librarian/SKILL.md).
4. Presenta al usuario un resumen claro de qué se movió a dónde y crea un punto de guardado final.

## 2. Edición Masiva Segura en `workspace/documentos/`

Cuando la tarea modifique **3 o más archivos** o reescriba más del **30%** de un documento:
1. **Punto de guardado previo obligatorio:**
   ```sh
   sh .agents/scripts/git-ops.sh checkpoint "Estado previo antes de ajuste masivo en documentos"
   ```
   *(Si el cambio es experimental o arriesgado, crea además un borrador paralelo con `draft-create`).*
2. Aplica las modificaciones cuidando el tono definido en [context.md](../../../knowledge/profile/context.md).
3. Resume al usuario qué cambió por archivo (ej. secciones ajustadas, términos reemplazados) y pregúntale si desea dejarlo guardado como versión oficial o probar ajustes adicionales.

## 3. Limpieza y Auditoría de Tablas CSV (`workspace/datos/`)

1. Antes de limpiar duplicados, normalizar columnas o cruzar tablas en `workspace/datos/`, asegúrate de tener un `checkpoint` limpio.
2. Verifica determinísticamente tras editar cualquier CSV:
   - Número de filas antes vs. después (reporta exactamente cuántas filas se añadieron, fusionaron o eliminaron y por qué).
   - Que todas las filas conserven el mismo número de columnas que el encabezado.
3. Nunca inventes ni redondees cifras silenciosamente; si detectas datos ambiguos o incompletos, señálalos explícitamente al usuario.

## 4. Generación de Entregables (`workspace/entregables/`)

- Mantén los documentos fuente editables en `workspace/documentos/` (Markdown) y `workspace/datos/` (CSV).
- Coloca las versiones cerradas listas para enviar a terceros en `workspace/entregables/` con nombres claros (ej. `Propuesta-Comercial-2026-10.md` o exportaciones generadas con herramientas disponibles en el sistema como `pandoc`, si estuvieran instaladas).
