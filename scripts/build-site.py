"""Build the public landing from an explicit allowlist; no third-party packages."""

from html.parser import HTMLParser
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_FILES = {
    "index.html": "site/index.html",
    "styles.css": "site/styles.css",
    "app.js": "site/app.js",
    "favicon.svg": "site/favicon.svg",
    "prompt.md": "prompt.md",
}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.references = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "base":
            raise ValueError("No uses <base>: los recursos deben funcionar en una ruta de proyecto.")
        if "id" in attrs:
            if not attrs["id"] or attrs["id"] in self.ids:
                raise ValueError(f"Identificador HTML vacío o duplicado: {attrs['id']!r}")
            self.ids.add(attrs["id"])
        for attribute in ("href", "src"):
            if attribute in attrs:
                self.references.append(attrs[attribute])


def check_reference(reference, files, ids):
    if not reference:
        raise ValueError("Enlace o recurso vacío.")
    url = urlsplit(reference)
    if url.scheme in ("https", "http", "mailto"):
        return
    if url.scheme or url.netloc or reference.startswith("/"):
        raise ValueError(f"Ruta no portable o protocolo no permitido: {reference}")
    path = unquote(url.path)
    if path and path not in files:
        raise ValueError(f"Recurso local fuera de la publicación o inexistente: {reference}")
    if (not path or path == "index.html") and url.fragment:
        if unquote(url.fragment) not in ids:
            raise ValueError(f"Ancla inexistente: {reference}")


def validate(files):
    page = Page()
    page.feed(files["index.html"].decode("utf-8"))
    page.close()
    for reference in page.references:
        check_reference(reference, files, page.ids)
    css = files["styles.css"].decode("utf-8")
    for match in re.finditer(r"url\(\s*['\"]?([^\s)'\"]+)", css):
        check_reference(match.group(1), files, page.ids)
    if not files["prompt.md"].decode("utf-8").startswith("# Publica la landing"):
        raise ValueError("El prompt de despliegue está vacío o no es el archivo esperado.")
    return len(page.references)


def build(root=ROOT):
    root = Path(root).resolve()
    output = root / "_site"
    files = {}
    for target, source in PUBLIC_FILES.items():
        source_path = root / source
        if source_path.is_symlink() or not source_path.resolve().is_relative_to(root):
            raise ValueError(f"La fuente pública no puede ser un enlace a otra ubicación: {source}")
        files[target] = source_path.read_bytes()
    references = validate(files)
    files[".nojekyll"] = b""
    if output.is_symlink():
        raise ValueError("_site no puede ser un enlace simbólico.")
    if output.exists():
        unexpected = {entry.name for entry in output.iterdir()} - files.keys()
        if unexpected:
            raise ValueError(f"_site contiene archivos ajenos; muévelos antes de construir: {sorted(unexpected)}")
        for name in files:
            target = output / name
            if target.is_symlink() or (target.exists() and not target.is_file()):
                raise ValueError(f"Destino público no válido: {target}")
    output.mkdir(exist_ok=True)
    for name, content in files.items():
        (output / name).write_bytes(content)
    print(f"Landing validada: {references} enlaces y recursos locales/externos declarados.")
    print(f"Publicación: {output} ({len(files)} archivos públicos; sin workspace/ ni knowledge/).")
    return output


if __name__ == "__main__":
    try:
        build()
    except (OSError, ValueError) as error:
        print(f"ERROR DE CONSTRUCCIÓN: {error}", file=sys.stderr)
        sys.exit(1)
