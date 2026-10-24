#!/bin/sh
# Regresiones del recibo de fase 2. Recibe la evidencia recién generada en CI.
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
[ "$#" -eq 2 ] || exit 2
EVIDENCE=$1 SEAL=$2
PARENT=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
CHECK=$(mktemp -d "$PARENT/agty-engine-receipt.XXXXXX")
cleanup() {
    CODE=$?
    trap - EXIT
    RESOLVED=$(CDPATH= cd -- "$CHECK" && pwd -P)
    case "$RESOLVED" in "$PARENT"/agty-engine-receipt.*) rm -rf -- "$RESOLVED" ;; esac
    exit "$CODE"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
verify() { sh "$SOURCE/.agents/tests/run-adversarial-engine-tests.sh" verify "$@"; }
verify "$EVIDENCE" "$SEAL" > "$CHECK/result"
grep -Fxq ENGINE_EVIDENCE_STATUS=PASS "$CHECK/result"
if grep -Fxq ENGINE_STATUS=PASS "$CHECK/result"; then exit 1; fi
if env TMPDIR="$EVIDENCE" sh "$SOURCE/.agents/tests/run-adversarial-engine-tests.sh" verify "$EVIDENCE" "$SEAL" > "$CHECK/result" 2>&1; then exit 1; else CODE=$?; fi
[ "$CODE" -eq 2 ]
grep -Fxq REASON=TEMP_DIRECTORY_OVERLAP "$CHECK/result"
BAD_DESTINATION=$CHECK/'nombre
ambiguo'
if sh "$SOURCE/.agents/tests/run-adversarial-engine-tests.sh" run "$BAD_DESTINATION" > "$CHECK/result" 2>&1; then exit 1; else CODE=$?; fi
[ "$CODE" -eq 2 ] && [ ! -e "$BAD_DESTINATION" ]
grep -Fxq REASON=DESTINATION_EXISTS_OR_INVALID "$CHECK/result"
cp -R "$EVIDENCE" "$CHECK/copia"
printf '\nPASS inventado\n' >> "$CHECK/copia/informe.md"
reject() {
    if verify "$CHECK/copia" "$SEAL" > "$CHECK/result" 2>&1; then exit 1; else CODE=$?; fi
    [ "$CODE" -eq 2 ]
    grep -Fxq REASON=EVIDENCE_INTEGRITY_ERROR "$CHECK/result"
}
reject
HASH=$(git hash-object --no-filters -- "$CHECK/copia/informe.md")
awk -F '\t' -v hash="$HASH" 'BEGIN {OFS="\t"} $2 == "./informe.md" {$1=hash} {print}' "$CHECK/copia/huellas.tsv" > "$CHECK/nuevas-huellas"
mv "$CHECK/nuevas-huellas" "$CHECK/copia/huellas.tsv"
# Un paquete autoconsistente nuevo tampoco satisface el recibo externo anterior.
reject
printf 'ENGINE_RECEIPT_TESTS=PASS\nCHECKS=5\n'
