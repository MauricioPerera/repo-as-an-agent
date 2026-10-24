# Edición acotada de intentos; todos los textos entran por ENVIRON, sin escapes awk.
function record() {
    print "### Intento " ENVIRON["AT_ID"]
    print "Agente: " ENVIRON["AT_AGENT"] "\nAcción: " ENVIRON["AT_ACTION"]
    print "Herramienta: " ENVIRON["AT_TOOL"] "\nInicio: " ENVIRON["AT_TIME"]
    print "Base: " ENVIRON["AT_BASE"] "\nFin: -\nDesenlace: abierto\nArchivo: -\nPunto: -\nObservación: -\n"
}
/^## / {
    if (section && action == "start") { record(); inserted=1 }
    section=($0 == "## Intentos de ejecución"); selected=0
}
section && /^### Intento / {selected=($3 == ENVIRON["AT_ID"])}
section && selected && action == "finish" {
    if (/^Fin: /) {print "Fin: " ENVIRON["AT_TIME"]; next}
    if (/^Desenlace: /) {print "Desenlace: " ENVIRON["AT_OUTCOME"]; next}
    if (/^Archivo: /) {print "Archivo: " ENVIRON["AT_PATH"]; next}
    if (/^Punto: /) {print "Punto: " ENVIRON["AT_POINT"]; next}
    if (/^Observación: /) {print "Observación: " ENVIRON["AT_NOTE"]; next}
}
{print}
END {
    if (action == "start" && !inserted) {
        if (!section) print "\n## Intentos de ejecución\n"
        record()
    }
}
