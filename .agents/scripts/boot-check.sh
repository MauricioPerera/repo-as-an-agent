#!/bin/sh
# boot-check.sh — Diagnóstico silencioso de arranque y auto-activación de protecciones.
# Compatible con POSIX sh (Git for Windows, macOS, Linux) y Git Worktrees.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

cd "$REPO_ROOT"

if ! command -v git >/dev/null 2>&1; then
    echo "BOOT_STATUS=ERROR"
    echo "GIT_AVAILABLE=false"
    echo "ERROR=Git no está disponible en el sistema."
    exit 1
fi

if [ ! -e "$REPO_ROOT/.git" ]; then
    echo "BOOT_STATUS=NEEDS_BOOTSTRAP"
    echo "GIT_INITIALIZED=false"
    echo "RECOMMENDED_ACTION=sh .agents/scripts/bootstrap.sh"
    exit 0
fi

# Auto-reparar configuración local esencial (por ej. tras un git clone fresco)
CURRENT_HOOKS=$(git config --get core.hooksPath || true)
if [ "$CURRENT_HOOKS" != ".agents/hooks" ]; then
    git config core.hooksPath .agents/hooks
fi
git config core.quotepath false

if [ -z "$(git config --get user.name || true)" ]; then
    git config user.name "Usuario del Espacio"
fi
if [ -z "$(git config --get user.email || true)" ]; then
    git config user.email "usuario@espacio-local.git"
fi

chmod +x "$REPO_ROOT/.agents/scripts/"*.sh 2>/dev/null || true
chmod +x "$REPO_ROOT/.agents/hooks/"* 2>/dev/null || true

# Rama / borrador actual
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")

# Conteo de cambios sin guardar
UNSAVED_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Estado de conflicto compatible con repositorios normales y git worktrees
CONFLICT_STATE="false"
MERGE_HEAD_PATH=$(git rev-parse --git-path MERGE_HEAD 2>/dev/null || echo ".git/MERGE_HEAD")
if [ -f "$MERGE_HEAD_PATH" ]; then
    CONFLICT_STATE="true"
elif [ -n "$(git ls-files -u 2>/dev/null)" ]; then
    CONFLICT_STATE="true"
fi

# Estado de onboarding leyendo knowledge/profile/context.md
ONBOARDING_STATUS="missing"
PROFILE_FILE="$REPO_ROOT/knowledge/profile/context.md"
if [ -f "$PROFILE_FILE" ]; then
    STATUS_VAL=$(awk '
        NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
        in_fm && /^---[[:space:]]*$/ { exit }
        in_fm && /^status:[[:space:]]*/ {
            sub(/^status:[[:space:]]*/, "", $0)
            gsub(/["'\''[:space:]]/, "", $0)
            print $0
            exit
        }
    ' "$PROFILE_FILE")
    if [ -n "$STATUS_VAL" ]; then
        ONBOARDING_STATUS="$STATUS_VAL"
    else
        ONBOARDING_STATUS="configured"
    fi
fi

# Verificar si ya existen commits
HAS_COMMITS="false"
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    HAS_COMMITS="true"
fi

echo "BOOT_STATUS=READY"
echo "GIT_INITIALIZED=true"
echo "HOOKS_ACTIVE=true"
echo "HAS_COMMITS=$HAS_COMMITS"
echo "CURRENT_DRAFT=$CURRENT_BRANCH"
echo "UNSAVED_CHANGES=$UNSAVED_COUNT"
echo "CONFLICT_STATE=$CONFLICT_STATE"
echo "ONBOARDING_STATUS=$ONBOARDING_STATUS"

if [ "$HAS_COMMITS" = "true" ]; then
    echo "--- RECENT_CHECKPOINTS ---"
    git log -n 3 --date=format:'%Y-%m-%d %H:%M' --pretty=format:'%h | %ad | %s'
    echo ""
fi
