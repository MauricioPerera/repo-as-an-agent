---
name: onboarding
description: >-
  Guides a non-technical user through a brief, friendly initial setup to personalize
  this Git-based workspace. Use this skill when boot-check.sh reports
  ONBOARDING_STATUS=template or when the user asks to configure or reset their
  workspace profile.
---

# Onboarding del Espacio de Trabajo

Este procedimiento personaliza la plantilla inicial para adaptarla al proyecto real de la persona sin abrumarla con preguntas técnicas.

## Pasos

1. **Verificar estado inicial:**
   Ejecuta [boot-check.sh](../../scripts/boot-check.sh):
   ```sh
   sh .agents/scripts/boot-check.sh
   ```
   Si `GIT_INITIALIZED=false`, ejecuta primero `sh .agents/scripts/bootstrap.sh`.

2. **Conversación breve (máximo 3 preguntas sencillas):**
   Saluda con calidez y pregunta en lenguaje cotidiano:
   - ¿Para qué proyecto o actividad vas a usar principalmente esta carpeta? *(ej. escribir un libro, llevar propuestas de clientes, organizar apuntes, administrar documentos de negocio)*
   - ¿Qué tono o estilo prefieres cuando redacte o edite tus documentos?
   - ¿Cómo te gustaría que te llame o qué nombre quieres registrar como autor de tus documentos?

3. **Configurar identidad de autor en Git (opcional si dio su nombre):**
   Si el usuario indicó su nombre, actualiza la configuración local del repositorio:
   ```sh
   git config user.name "<Nombre del Usuario>"
   ```

4. **Actualizar memoria OKF:**
   - Edita [context.md](../../../knowledge/profile/context.md):
     - Cambia `status: 'template'` por `status: 'configured'`.
     - Actualiza `timestamp` con la fecha/hora actual ISO 8601.
     - Rellena el propósito principal y las preferencias de estilo acordadas.
   - Registra una línea breve con la fecha de hoy en [log.md](../../../knowledge/log.md).

5. **Validar y crear el primer punto de guardado personalizado:**
   - Verifica la memoria con [okf-lint.sh](../../scripts/okf-lint.sh):
     ```sh
     sh .agents/scripts/okf-lint.sh
     ```
   - Guarda el hito con [git-ops.sh](../../scripts/git-ops.sh):
     ```sh
     sh .agents/scripts/git-ops.sh checkpoint "Configuración inicial del espacio personalizada"
     ```
   - Confirma al usuario en dos o tres líneas que su espacio ya está listo y recuérdale que puede dejar archivos en `workspace/bandeja/` o `workspace/documentos/`.
