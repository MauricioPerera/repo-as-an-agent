# Perfil YAML OKF sin dependencias: mapa plano de escalares de una línea y
# listas de escalares en línea. Se rechazan construcciones fuera del perfil.
# No evalúa etiquetas, alias ni expresiones del documento.

function fail(message) {
    print "YAML inválido (línea " NR "): " message
    failed = 1
    exit 1
}

function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
}

function spaces() {
    while (substr(value, pos, 1) ~ /[ \t]/ && pos <= length(value)) pos++
}

function scalar(in_list,    start, quote, ch, esc, digits, hex, i, point, digit) {
    spaces()
    text = ""
    kind = "string"
    ch = substr(value, pos, 1)
    if (ch == "\047" || ch == "\042") {
        quote = ch
        pos++
        while (pos <= length(value)) {
            ch = substr(value, pos++, 1)
            if (ch == quote) {
                if (quote == "\047" && substr(value, pos, 1) == quote) {
                    text = text quote
                    pos++
                } else return
            } else if (quote == "\042" && ch == "\\") {
                esc = substr(value, pos++, 1)
                if (esc == "") fail("escape sin terminar")
                if (esc == "x" || esc == "u" || esc == "U") {
                    digits = esc == "x" ? 2 : (esc == "u" ? 4 : 8)
                    hex = substr(value, pos, digits)
                    if (length(hex) != digits || hex ~ /[^0-9a-fA-F]/) fail("escape hexadecimal incompleto")
                    point = 0
                    for (i = 1; i <= digits; i++) {
                        digit = index("0123456789abcdef", tolower(substr(hex, i, 1))) - 1
                        point = point * 16 + digit
                    }
                    if (point > 1114111 || (point >= 55296 && point <= 57343)) fail("escape Unicode inválido")
                    text = text (point == 32 || point == 9 || point == 10 || point == 13 ? " " : "x")
                    pos += digits
                } else {
                    if (index("0abtnvfre \042/\\N_LP", esc) == 0) fail("escape no permitido")
                    text = text (esc == "t" || esc == "n" || esc == "r" || esc == " " ? " " : esc)
                }
            } else text = text ch
        }
        fail("comillas sin cerrar")
    }

    start = pos
    if (in_list && ch ~ /[?:]/) fail("las listas solo admiten escalares; usa comillas para este valor")
    if (ch ~ /[\[\]{},#&*!|>\047\042%@`]/ || (ch ~ /[-?:]/ && (pos == length(value) || substr(value, pos + 1, 1) ~ /[ \t]/))) {
        fail("se esperaba un escalar; usa comillas para caracteres especiales")
    }
    while (pos <= length(value)) {
        ch = substr(value, pos, 1)
        if (in_list && (ch == "," || ch == "]")) break
        if (ch == "#" && (pos == start || substr(value, pos - 1, 1) ~ /[ \t]/)) break
        if (ch ~ /[\[\]{}]/) fail("colección fuera del perfil plano OKF")
        if (ch == ":" && (pos == length(value) || substr(value, pos + 1, 1) ~ /[ \t]/ || (in_list && substr(value, pos + 1, 1) ~ /[,\]]/))) {
            fail("dos puntos sin comillas dentro de un valor")
        }
        pos++
    }
    text = trim(substr(value, start, pos - start))
    if (text == "" || text == "~" || tolower(text) == "null") kind = "null"
}

function field_value(    ch) {
    pos = 1
    spaces()
    if (substr(value, pos, 1) == "[") {
        pos++
        spaces()
        while (substr(value, pos, 1) != "]") {
            if (pos > length(value) || substr(value, pos, 1) == "," || substr(value, pos, 1) == "#") fail("lista sin cerrar o elemento vacío")
            scalar(1)
            spaces()
            ch = substr(value, pos, 1)
            if (ch == "]") break
            if (ch != ",") fail("se esperaba una coma o el cierre de la lista")
            pos++
            spaces()
        }
        pos++
        kind = "list"
    } else if (pos > length(value) || substr(value, pos, 1) == "#") {
        kind = "null"
        text = ""
    } else scalar(0)

    # Después de una comilla o lista solo se permite espacio y un comentario.
    ch = substr(value, pos, 1)
    if (ch == "#" && pos > 1 && substr(value, pos - 1, 1) !~ /[ \t]/) fail("el comentario debe estar separado por un espacio")
    spaces()
    if (pos <= length(value) && substr(value, pos, 1) != "#") fail("contenido inesperado después del valor")
}

NR == 1 {
    if ($0 ~ /^---[[:space:]]*$/) {
        in_frontmatter = 1
        next
    }
    if (structural) {
        no_frontmatter = 1
        exit
    }
    print "debe iniciar en la línea 1 con YAML frontmatter ('---')."
    failed = 1
    exit 1
}

in_frontmatter {
    if ($0 ~ /[\001-\010\013\014\016-\037\177]/) fail("carácter de control no permitido")
    if ($0 ~ /^---[[:space:]]*$/) {
        in_frontmatter = 0
        closed = 1
        next
    }
    if ($0 ~ /^[[:space:]]*(#.*)?$/) next
    if ($0 !~ /^[A-Za-z_][A-Za-z0-9_-]*:([ \t]|$)/) fail("usa campos planos nombre: valor de una sola línea")
    key = $0
    sub(/:.*/, "", key)
    if (key in seen) fail("campo duplicado: " key)
    seen[key] = 1
    value = substr($0, length(key) + 2)
    field_value()
    nonempty[key] = kind == "string" && length(trim(text)) > 0
    next
}

closed && /[^[:space:]]/ { body_lines++ }

END {
    if (failed) exit 1
    if (no_frontmatter || (structural && NR == 0)) exit 0
    if (NR == 0) {
        print "está vacío."
        exit 1
    }
    if (!closed) {
        print "no cierra su bloque YAML frontmatter con '---'."
        exit 1
    }
    if (structural) {
        if ("type" in seen) {
            print "es un archivo estructural reservado en OKF y NO debe definir 'type:' de concepto."
            exit 1
        }
        exit 0
    }
    if (!nonempty["type"]) {
        print "no incluye el campo obligatorio OKF 'type:' con valor."
        failed = 1
    }
    if (!nonempty["title"]) {
        print "no incluye el campo 'title:' con valor."
        failed = 1
    }
    if (!nonempty["description"]) {
        print "no incluye el campo 'description:' con valor."
        failed = 1
    }
    if (!body_lines) {
        print "no tiene contenido Markdown después del frontmatter."
        failed = 1
    }
    exit failed ? 1 : 0
}
