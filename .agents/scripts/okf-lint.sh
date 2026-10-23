#!/bin/sh
# okf-lint.sh — Validador determinista de Open Knowledge Format (OKF).
# Reglas basadas en la especificación OKF:
#   1. knowledge/index.md y knowledge/log.md deben existir y son estructurales (no deben declarar 'type:' de concepto).
#   2. Todo otro archivo .md dentro de knowledge/ es un Concept Document y DEBE:
#      - Iniciar en la línea 1 con bloque YAML frontmatter delimitado por '---'.
#      - Incluir el campo obligatorio 'type:' con valor no vacío.
#      - Incluir 'title:' y 'description:' recomendados con valor no vacío.
#      - Contener cuerpo Markdown no vacío tras el frontmatter.
#   3. Todo enlace relativo Markdown [texto](ruta) o [texto](<ruta con espacios>) debe apuntar a un destino existente.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
STAGED_ROOT=""
STAGED_TREE=""
TMP_BASE=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd)
TMP_FILES="$TMP_BASE/okf_files_$$.txt"
TMP_LINKS="$TMP_BASE/okf_links_$$.txt"
cleanup_okf() {
    rm -f "$TMP_FILES" "$TMP_LINKS"
    if [ -n "$STAGED_ROOT" ]; then
        case "$STAGED_ROOT" in
            "$TMP_BASE"/okf-index.*) rm -rf "$STAGED_ROOT" ;;
        esac
    fi
}
trap cleanup_okf EXIT INT TERM

# Leer los blobs exactos del índice, sin conversiones de finales de línea ni
# filtros de checkout. Los destinos de enlaces se consultan en el mismo árbol.
if [ "${1:-}" = "--staged" ]; then
    STAGED_TREE=$(git -C "$REPO_ROOT" write-tree)
    STAGED_ROOT=$(mktemp -d "$TMP_BASE/okf-index.XXXXXX")
    mkdir -p "$STAGED_ROOT/knowledge"
    git -C "$REPO_ROOT" -c core.quotepath=false ls-tree -r --name-only "$STAGED_TREE" -- knowledge > "$TMP_FILES"
    while IFS= read -r STAGED_FILE || [ -n "$STAGED_FILE" ]; do
        case "$STAGED_FILE" in
            knowledge/*.md)
                mkdir -p "$STAGED_ROOT/$(dirname -- "$STAGED_FILE")"
                git -C "$REPO_ROOT" cat-file blob "$STAGED_TREE:$STAGED_FILE" > "$STAGED_ROOT/$STAGED_FILE"
                ;;
            knowledge/*) ;;
            *)
                echo "OKF_LINT_STATUS=FAIL"
                echo "ERROR=Nombre de archivo no admitido en knowledge/: $STAGED_FILE"
                exit 1
                ;;
        esac
    done < "$TMP_FILES"
    set -- "$STAGED_ROOT/knowledge"
fi
RAW_KNOWLEDGE_DIR="${1:-$REPO_ROOT/knowledge}"

if [ ! -d "$RAW_KNOWLEDGE_DIR" ]; then
    echo "OKF_LINT_STATUS=FAIL"
    echo "ERROR=No existe el directorio de conocimiento: $RAW_KNOWLEDGE_DIR"
    exit 1
fi

# Normalizar ruta eliminando barra final eventual para compatibilidad GNU/BSD find
KNOWLEDGE_DIR=$(CDPATH= cd -- "$RAW_KNOWLEDGE_DIR" && pwd)

ERRORS=0
CONCEPTS_CHECKED=0
LINKS_CHECKED=0

report_error() {
    echo "FAIL: $1"
    ERRORS=$((ERRORS + 1))
}

# 1. Validar presencia de archivos estructurales raíz
if [ ! -f "$KNOWLEDGE_DIR/index.md" ]; then
    report_error "Falta archivo estructural obligatorio: knowledge/index.md"
fi

if [ ! -f "$KNOWLEDGE_DIR/log.md" ]; then
    report_error "Falta archivo estructural obligatorio: knowledge/log.md"
fi

find "$KNOWLEDGE_DIR" -type f -name "*.md" | sort > "$TMP_FILES"

while IFS= read -r FILE || [ -n "$FILE" ]; do
    [ -z "$FILE" ] && continue
    REL_FILE="${FILE#"$KNOWLEDGE_DIR"/}"
    BASENAME=$(basename -- "$FILE")

    # Validar que no contenga retornos de carro CRLF que rompan parsers estrictos
    if awk '/\r$/ { found=1; exit } END { exit !found }' "$FILE"; then
        report_error "$REL_FILE contiene saltos de línea CRLF (\\r); debe usar LF."
    fi

    STRUCTURAL=0
    if [ "$BASENAME" = "index.md" ] || [ "$BASENAME" = "log.md" ]; then
        STRUCTURAL=1
    else
        CONCEPTS_CHECKED=$((CONCEPTS_CHECKED + 1))
    fi
    # La sintaxis YAML usa delimitadores ASCII. Recorrer bytes evita diferencias
    # de índices multibyte entre GNU awk y el awk de macOS sin alterar el UTF-8.
    if ! FM_OUT=$(LC_ALL=C awk -v structural="$STRUCTURAL" -f "$SCRIPT_DIR/okf-frontmatter.awk" "$FILE"); then
        report_error "$REL_FILE: $FM_OUT"
    fi

    # 3. Extraer enlaces Markdown soportando bloques cercados indentados, <ruta con espacios> y paréntesis balanceados (ej. "Archivo (1).md")
    awk '
        /^[[:space:]]*```/ { in_code = !in_code; next }
        in_code { next }
        {
            line = $0
            gsub(/`[^`]*`/, "", line)
            n = length(line)
            i = 1
            while (i <= n) {
                if (substr(line, i, 2) == "](") {
                    j = i + 2
                    while (j <= n && substr(line, j, 1) ~ /[[:space:]]/) j++
                    if (j <= n && substr(line, j, 1) == "<") {
                        j++
                        start = j
                        while (j <= n && substr(line, j, 1) != ">") j++
                        if (j <= n) {
                            target = substr(line, start, j - start)
                            while (j <= n && substr(line, j, 1) != ")") j++
                            print NR "|" target
                        }
                        i = j + 1
                        continue
                    } else {
                        start = j
                        depth = 0
                        end_target = 0
                        while (j <= n) {
                            ch = substr(line, j, 1)
                            if (ch == "(") {
                                depth++
                            } else if (ch == ")") {
                                if (depth == 0) {
                                    if (end_target == 0) end_target = j
                                    break
                                }
                                depth--
                            } else if (ch ~ /[[:space:]]/ && depth == 0) {
                                if (end_target == 0) end_target = j
                            }
                            j++
                        }
                        if (j <= n && substr(line, j, 1) == ")" && end_target > start) {
                            target = substr(line, start, end_target - start)
                            print NR "|" target
                        }
                        i = j + 1
                        continue
                    }
                }
                i++
            }
        }
    ' "$FILE" > "$TMP_LINKS"

    FILE_DIR=$(dirname -- "$FILE")
    while IFS='|' read -r LINE_NO TARGET || [ -n "$LINE_NO" ]; do
        [ -z "$LINE_NO" ] && continue
        [ -z "$TARGET" ] && continue

        # Ignorar URLs externas, esquemas URI y anclas puras en el mismo documento
        case "$TARGET" in
            http://*|https://*|mailto:*|tel:*|file://*|conversation://*|'#'*)
                continue
                ;;
        esac

        # Quitar fragmento #seccion y decodificar %20 para rutas con espacios
        CLEAN_PATH="${TARGET%%'#'*}"
        CLEAN_PATH=$(printf '%s' "$CLEAN_PATH" | sed 's/%20/ /g')
        [ -z "$CLEAN_PATH" ] && continue

        LINKS_CHECKED=$((LINKS_CHECKED + 1))

        case "$CLEAN_PATH" in
            /*)
                RESOLVED="$REPO_ROOT$CLEAN_PATH"
                ;;
            *)
                RESOLVED="$FILE_DIR/$CLEAN_PATH"
                ;;
        esac

        LINK_EXISTS=false
        if [ -n "$STAGED_ROOT" ]; then
            case "$CLEAN_PATH" in
                /*) INDEX_PATH="${CLEAN_PATH#/}" ;;
                *) INDEX_PATH="$(dirname -- "${FILE#"$STAGED_ROOT"/}")/$CLEAN_PATH" ;;
            esac
            # Resolver ../ y ./ sin consultar archivos locales ajenos al guardado.
            if INDEX_PATH=$(printf '%s\n' "$INDEX_PATH" | awk -F/ '
                {
                    depth = 0
                    for (i = 1; i <= NF; i++) {
                        if ($i == "" || $i == ".") continue
                        if ($i == "..") {
                            if (depth == 0) exit 1
                            depth--
                        } else parts[++depth] = $i
                    }
                    for (i = 1; i <= depth; i++) printf "%s%s", (i > 1 ? "/" : ""), parts[i]
                }
            ') && git -C "$REPO_ROOT" cat-file -e "$STAGED_TREE:$INDEX_PATH" 2>/dev/null; then
                LINK_EXISTS=true
            fi
        elif [ -e "$RESOLVED" ]; then
            LINK_EXISTS=true
        fi
        if [ "$LINK_EXISTS" = "false" ]; then
            report_error "$REL_FILE (línea $LINE_NO) tiene un enlace roto hacia '$TARGET'."
        fi
    done < "$TMP_LINKS"

done < "$TMP_FILES"

if [ "$ERRORS" -gt 0 ]; then
    echo "OKF_LINT_STATUS=FAIL"
    echo "CONCEPTS_CHECKED=$CONCEPTS_CHECKED"
    echo "LINKS_CHECKED=$LINKS_CHECKED"
    echo "ERRORS=$ERRORS"
    exit 1
fi

echo "OKF_LINT_STATUS=PASS"
echo "CONCEPTS_CHECKED=$CONCEPTS_CHECKED"
echo "LINKS_CHECKED=$LINKS_CHECKED"
echo "ERRORS=0"
exit 0
