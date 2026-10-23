#!/bin/sh
# bootstrap.sh — Inicializa o repara determinísticamente el repositorio del Agente Git.
# Compatible con POSIX sh (Git for Windows, macOS, Linux) y con Git Worktrees.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

cd "$REPO_ROOT"

if ! command -v git >/dev/null 2>&1; then
    echo "BOOTSTRAP_STATUS=FAIL"
    echo "ERROR=Git no está instalado o no se encuentra en el PATH."
    exit 1
fi

# 1. Inicializar Git si aún no existe repositorio/worktree aquí (.git directorio o archivo worktree)
GIT_CREATED="false"
if [ ! -e "$REPO_ROOT/.git" ]; then
    if git init -b main >/dev/null 2>&1; then
        :
    else
        git init >/dev/null 2>&1
        git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
    fi
    GIT_CREATED="true"
fi

# 2. Configurar hooks del repositorio y soporte UTF-8 para nombres de archivos con tildes/ñ/espacios
git config core.hooksPath .agents/hooks
git config core.quotepath false
git config core.autocrlf input

# 3. Asegurar identidad local de Git si el usuario no técnico nunca configuró Git en su equipo
USER_NAME=$(git config --get user.name || true)
USER_EMAIL=$(git config --get user.email || true)
IDENTITY_CONFIGURED="existing"

if [ -z "$USER_NAME" ]; then
    git config user.name "Usuario del Espacio"
    IDENTITY_CONFIGURED="local-default"
fi

if [ -z "$USER_EMAIL" ]; then
    git config user.email "usuario@espacio-local.git"
    IDENTITY_CONFIGURED="local-default"
fi

# 4. Asegurar estructura de directorios de la Zona Humana y Memoria OKF
mkdir -p \
    "$REPO_ROOT/workspace/bandeja" \
    "$REPO_ROOT/workspace/documentos" \
    "$REPO_ROOT/workspace/datos" \
    "$REPO_ROOT/workspace/entregables" \
    "$REPO_ROOT/knowledge/profile" \
    "$REPO_ROOT/knowledge/system"

# 5. Asegurar permisos de ejecución en scripts y hooks
chmod +x "$REPO_ROOT/.agents/scripts/"*.sh 2>/dev/null || true
chmod +x "$REPO_ROOT/.agents/hooks/"* 2>/dev/null || true
if [ -d "$REPO_ROOT/.agents/tests" ]; then
    chmod +x "$REPO_ROOT/.agents/tests/"*.sh 2>/dev/null || true
fi

echo "BOOTSTRAP_STATUS=PASS"
echo "REPO_ROOT=$REPO_ROOT"
echo "GIT_CREATED=$GIT_CREATED"
echo "HOOKS_PATH=$(git config --get core.hooksPath)"
echo "IDENTITY_MODE=$IDENTITY_CONFIGURED"
