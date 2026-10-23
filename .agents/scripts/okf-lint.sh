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

TMP_FILES="${TMPDIR:-/tmp}/okf_files_$$.txt"
TMP_LINKS="${TMPDIR:-/tmp}/okf_links_$$.txt"
trap 'rm -f "$TMP_FILES" "$TMP_LINKS"' EXIT INT TERM

find "$KNOWLEDGE_DIR" -type f -name "*.md" | sort > "$TMP_FILES"

while IFS= read -r FILE || [ -n "$FILE" ]; do
    [ -z "$FILE" ] && continue
    REL_FILE="${FILE#"$KNOWLEDGE_DIR"/}"
    BASENAME=$(basename -- "$FILE")

    # Validar que no contenga retornos de carro CRLF que rompan parsers estrictos
    if awk '/\r$/ { found=1; exit } END { exit !found }' "$FILE"; then
        report_error "$REL_FILE contiene saltos de línea CRLF (\\r); debe usar LF."
    fi

    if [ "$BASENAME" = "index.md" ] || [ "$BASENAME" = "log.md" ]; then
        # Regla OKF: index.md y log.md están reservados para estructura, no para conceptos core
        HAS_CONCEPT_TYPE=$(awk '
            NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
            in_fm && /^---[[:space:]]*$/ { exit }
            in_fm && /^type:[[:space:]]*[^[:space:]]+/ { print "yes"; exit }
        ' "$FILE")
        if [ "$HAS_CONCEPT_TYPE" = "yes" ]; then
            report_error "$REL_FILE es un archivo estructural reservado en OKF y NO debe definir 'type:' de concepto."
        fi
    else
        CONCEPTS_CHECKED=$((CONCEPTS_CHECKED + 1))

        # Auditar Frontmatter YAML y cuerpo del Concept Document
        FM_CHECK=$(awk '
            BEGIN {
                in_fm = 0
                closed_fm = 0
                has_type = 0
                has_title = 0
                has_desc = 0
                body_lines = 0
            }
            NR == 1 {
                if ($0 ~ /^---[[:space:]]*$/) {
                    in_fm = 1
                    next
                } else {
                    print "MISSING_OPEN_DELIM"
                    exit
                }
            }
            in_fm == 1 {
                if ($0 ~ /^---[[:space:]]*$/) {
                    in_fm = 0
                    closed_fm = 1
                    next
                }
                if ($0 ~ /^type:[[:space:]]*/) {
                    val = $0
                    sub(/^type:[[:space:]]*/, "", val)
                    gsub(/["'\''[:space:]]/, "", val)
                    if (length(val) > 0) has_type = 1
                }
                if ($0 ~ /^title:[[:space:]]*/) {
                    val = $0
                    sub(/^title:[[:space:]]*/, "", val)
                    gsub(/["'\''[:space:]]/, "", val)
                    if (length(val) > 0) has_title = 1
                }
                if ($0 ~ /^description:[[:space:]]*/) {
                    val = $0
                    sub(/^description:[[:space:]]*/, "", val)
                    gsub(/["'\''[:space:]]/, "", val)
                    if (length(val) > 0) has_desc = 1
                }
                next
            }
            closed_fm == 1 {
                if ($0 ~ /[^[:space:]]/) body_lines++
            }
            END {
                if (NR == 0) {
                    print "EMPTY_FILE"
                } else if (!closed_fm) {
                    print "UNCLOSED_FRONTMATTER"
                } else {
                    if (!has_type) print "MISSING_TYPE"
                    if (!has_title) print "MISSING_TITLE"
                    if (!has_desc) print "MISSING_DESCRIPTION"
                    if (body_lines == 0) print "EMPTY_BODY"
                }
            }
        ' "$FILE")

        for ISSUE in $FM_CHECK; do
            case "$ISSUE" in
                EMPTY_FILE)
                    report_error "$REL_FILE está vacío."
                    ;;
                MISSING_OPEN_DELIM)
                    report_error "$REL_FILE debe iniciar en la línea 1 con YAML frontmatter ('---')."
                    ;;
                UNCLOSED_FRONTMATTER)
                    report_error "$REL_FILE no cierra su bloque YAML frontmatter con '---'."
                    ;;
                MISSING_TYPE)
                    report_error "$REL_FILE no incluye el campo obligatorio OKF 'type:' con valor."
                    ;;
                MISSING_TITLE)
                    report_error "$REL_FILE no incluye el campo 'title:' con valor."
                    ;;
                MISSING_DESCRIPTION)
                    report_error "$REL_FILE no incluye el campo 'description:' con valor."
                    ;;
                EMPTY_BODY)
                    report_error "$REL_FILE no tiene contenido Markdown después del frontmatter."
                    ;;
            esac
        done
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

        if [ ! -e "$RESOLVED" ]; then
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
