"""Build the public landing from an explicit allowlist; no third-party packages."""

import argparse
from html import escape
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_FILES = {
    "index.html": "site/index.html",
    "styles.css": "site/styles.css",
    "app.js": "site/app.js",
    "favicon.svg": "site/favicon.svg",
    "prompt.md": "prompt.md",
}
DEFAULT_REPOSITORY = "MauricioPerera/repo-as-an-agent"
RELEASE_SLOT = re.compile(r"<!-- release:start -->.*?<!-- release:end -->", re.DOTALL)


def validate_repository(repository):
    if not re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("El repositorio debe tener el formato PROPIETARIO/REPOSITORIO.")
    return repository


def release_tag(release):
    if not isinstance(release, dict) or release.get("draft") is not False or release.get("prerelease") is not False:
        raise ValueError("GitHub no devolvió una versión estable publicada válida.")
    tag = release.get("tag_name")
    if not isinstance(tag, str) or not tag.strip() or any(ord(char) < 32 for char in tag):
        raise ValueError("La versión publicada no tiene una etiqueta válida.")
    return tag


def latest_release(repository):
    """Only publication opts into network access; offline builds stay deterministic."""
    validate_repository(repository)
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2026-03-10"}
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GITHUB_TOKEN"]
    request = Request(f"https://api.github.com/repos/{repository}/releases/latest", headers=headers)
    try:
        with urlopen(request, timeout=20) as response:
            release = json.load(response)
    except HTTPError as error:
        error.close()
        if error.code == 404:
            return None  # A fresh template copy need not have a release yet.
        raise ValueError(f"No se pudo consultar la última versión: GitHub respondió HTTP {error.code}.") from error
    except (URLError, TimeoutError, OSError) as error:
        raise ValueError("No se pudo consultar la última versión de GitHub; publicación detenida.") from error
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("GitHub devolvió datos de versión ilegibles; publicación detenida.") from error
    release_tag(release)
    return release


def render_release(html, repository, release=None):
    validate_repository(repository)
    label = "Ver versiones"
    url = f"https://github.com/{repository}/releases"
    if release is not None:
        label = release_tag(release)
        # Construct the URL ourselves: API data cannot redirect the badge elsewhere.
        url += "/tag/" + quote(label, safe="")
    slot = (
        '<!-- release:start --><a class="version-pill" id="latest-release" '
        f'href="{escape(url, quote=True)}"><span class="status-dot" aria-hidden="true"></span> '
        f'EVALÚA Y CONSERVA <span class="pill-version">{escape(label)} ↗</span></a><!-- release:end -->'
    )
    if len(RELEASE_SLOT.findall(html)) != 1:
        raise ValueError("La cabecera debe contener un único espacio para la versión automática.")
    return RELEASE_SLOT.sub(lambda match: slot, html)


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.references = []
        self.controls = []

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
        for attribute in ("data-copy-target", "aria-controls"):
            if attribute in attrs:
                targets = attrs[attribute].split() if attribute == "aria-controls" else [attrs[attribute]]
                if not targets or not all(targets):
                    raise ValueError(f"Destino de control vacío: {attribute}")
                self.controls.extend(targets)


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
    for target in page.controls:
        if target not in page.ids:
            raise ValueError(f"Destino de control inexistente: {target}")
    for reference in page.references:
        check_reference(reference, files, page.ids)
    css = files["styles.css"].decode("utf-8")
    for match in re.finditer(r"url\(\s*['\"]?([^\s)'\"]+)", css):
        check_reference(match.group(1), files, page.ids)
    if not files["prompt.md"].decode("utf-8").startswith("# Publica la landing"):
        raise ValueError("El prompt de despliegue está vacío o no es el archivo esperado.")
    return len(page.references)


def build(root=ROOT, repository=DEFAULT_REPOSITORY, release=None):
    root = Path(root).resolve()
    output = root / "_site"
    files = {}
    for target, source in PUBLIC_FILES.items():
        source_path = root / source
        if source_path.is_symlink() or not source_path.resolve().is_relative_to(root):
            raise ValueError(f"La fuente pública no puede ser un enlace a otra ubicación: {source}")
        files[target] = source_path.read_bytes()
    files["index.html"] = render_release(files["index.html"].decode("utf-8"), repository, release).encode("utf-8")
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPOSITORY),
                        help="PROPIETARIO/REPOSITORIO para el enlace de versiones.")
    parser.add_argument("--fetch-release", action="store_true",
                        help="Consultar la última versión estable en GitHub durante la publicación.")
    args = parser.parse_args()
    try:
        build(repository=args.repository, release=latest_release(args.repository) if args.fetch_release else None)
    except (OSError, ValueError) as error:
        print(f"ERROR DE CONSTRUCCIÓN: {error}", file=sys.stderr)
        sys.exit(1)
