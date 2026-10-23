---
type: 'System Playbook'
title: 'Arquitectura del Agente Basado en Git'
description: 'Documenta la separación entre Zona Humana, Memoria OKF y Motor Determinista POSIX sh.'
resource: '../../AGENTS.md'
tags: ['architecture', 'git', 'okf', 'safety']
timestamp: '2026-10-22T22:45:00-06:00'
---

# Arquitectura del Agente Basado en Git

Este espacio implementa el patrón **Repo-as-an-Agent**: cualquier motor de IA compatible (`Antigravity`, `Codex`, `Claude Code`, `OpenCode`, `Cursor`) obtiene contexto inmediato leyendo [AGENTS.md](../../AGENTS.md).

## Separación de Responsabilidades

1. **Zona Humana (`workspace/`):** Espacio exclusivo de archivos del usuario (`bandeja/`, `documentos/`, `datos/`, `entregables/`).
2. **Memoria Estructurada (`knowledge/`):** Grafo de conceptos en formato OKF validado automáticamente por `.agents/scripts/okf-lint.sh` y protegido en cada guardado por `.agents/hooks/pre-commit`. Consulta el [Perfil del Espacio](../profile/context.md) para conocer las preferencias del usuario.
3. **Motor Determinista (`.agents/scripts/`):**
   - `bootstrap.sh`: Inicializa Git, configura `core.hooksPath = .agents/hooks` e identidad local por defecto.
   - `boot-check.sh`: Verifica salud al inicio de cada conversación.
   - `git-ops.sh`: Encapsula puntos de guardado (`checkpoint`), borradores paralelos (`draft-create`, `draft-switch`, `merge-draft`) y reversiones con red de rescate inmutable (`undo-safe` con etiquetas `rescate/*`).
