# Formato Markdown del gestor: validación compartida por CLI y control de guardado.
function error(message) {
    print "TASK_FORMAT_ERROR: " display ": " message
    failed = 1
}
function text(value) { return value ~ /[^[:space:]]/ && value != "-" }
BEGIN { section = "header" }
{
    sub(/\r$/, "")
    if ($0 ~ /[\001-\010\013\014\016-\037\177]/) error("carácter de control no admitido")
    if (NR == 1) {
        if ($0 !~ /^# .+/) error("falta el título Markdown")
        title = substr($0, 3)
        next
    }
    if ($0 ~ /^## /) {
        section = $0
        headings[section]++
        next
    }
    if (section == "header") {
        if ($0 ~ /^ID: /) { id = substr($0, 5); id_count++ }
        else if ($0 ~ /^Estado: /) { state = substr($0, 9); state_count++ }
        else if (text($0)) error("cabecera inesperada")
        next
    }
    if (section == "## Objetivo" && text($0)) objective++
    if (section == "## Resultado" && text($0)) result++
    if (section == "## Motivo del estado" && text($0)) reason++
    if (section == "## Criterios de aceptación") {
        if ($0 ~ /^- \[[ x]\] / && text(substr($0, 7))) {
            criteria++
            checked[criteria] = (substr($0, 4, 1) == "x")
        } else if ($0 ~ /^  Evidencia: / && criteria > 0 && text(substr($0, 14))) {
            evidence[criteria]++
            if (!checked[criteria]) error("un criterio pendiente no puede tener evidencia verificada")
        } else if (text($0)) error("criterio o evidencia con formato inválido")
    }
}
END {
    if (!text(title)) error("el título está vacío")
    if (id_count != 1 || id != expected_id) error("el ID debe coincidir con el nombre del archivo")
    if (state_count != 1 || (state != "pendiente" && state != "en curso" && state != "bloqueada" && state != "terminada")) error("estado desconocido o repetido")
    if (headings["## Objetivo"] != 1 || !objective) error("falta un objetivo no vacío")
    if (headings["## Criterios de aceptación"] != 1 || !criteria) error("se requiere al menos un criterio")
    if (headings["## Resultado"] != 1 || headings["## Motivo del estado"] != 1) error("faltan secciones de resultado o motivo, o están repetidas")
    for (i = 1; i <= criteria; i++) {
        if (evidence[i] > 1 || (checked[i] && evidence[i] != 1)) error("cada criterio verificado requiere una evidencia")
        if (state == "terminada" && !checked[i]) error("hay criterios pendientes: no se puede terminar")
    }
    if (state == "terminada" && !result) error("una tarea terminada requiere resultado")
    if (state == "bloqueada" && !reason) error("una tarea bloqueada requiere motivo")
    if (failed) exit 1
    if (field == "state") print state
    else if (field == "title") print title
    else if (field == "criteria") print criteria
}
