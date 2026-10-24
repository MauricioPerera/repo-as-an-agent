"""Regression checks for the landing's publication boundary and navigation."""

import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("build_site", ROOT / "scripts/build-site.py")
site = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(site)
RELEASE = {"tag_name": "v9.4.2", "draft": False, "prerelease": False}


class ReleaseTests(unittest.TestCase):
    def source_html(self):
        return (ROOT / "site/index.html").read_text(encoding="utf-8")

    def test_latest_version_and_repository_link_are_rendered_together(self):
        release = dict(RELEASE, html_url="https://untrusted.example/wrong")
        html = site.render_release(self.source_html(), "otra-persona/mi-copia", release)
        self.assertIn('href="https://github.com/otra-persona/mi-copia/releases/tag/v9.4.2"', html)
        self.assertIn('class="pill-version">v9.4.2 ↗</span>', html)
        self.assertNotIn("untrusted.example", html)
        # The introduction version of the task feature is historical content.
        self.assertIn("NUEVO EN v1.1.0", html)
        self.assertIn("NUEVO EN v1.2.0", html)
        self.assertIn("NUEVO EN v1.3.0", html)
        self.assertIn("EVALÚA Y CONSERVA", html)

    def test_copy_without_releases_links_to_its_own_releases(self):
        html = site.render_release(self.source_html(), "otra-persona/mi-copia")
        self.assertIn('id="latest-release" href="https://github.com/otra-persona/mi-copia/releases"', html)
        self.assertIn('class="pill-version">Ver versiones ↗</span>', html)

    def test_release_text_is_escaped_and_tag_is_a_single_url_segment(self):
        html = site.render_release(self.source_html(), "owner/repo", dict(RELEASE, tag_name='v2/<b>&"'))
        self.assertIn('v2/&lt;b&gt;&amp;&quot; ↗', html)
        self.assertIn('/releases/tag/v2%2F%3Cb%3E%26%22"', html)

    def test_missing_or_duplicate_release_slot_is_rejected(self):
        html = self.source_html()
        for broken in (site.RELEASE_SLOT.sub("", html), html + site.RELEASE_SLOT.search(html).group()):
            with self.subTest(html=broken[-100:]), self.assertRaisesRegex(ValueError, "único espacio"):
                site.render_release(broken, "owner/repo", RELEASE)

    def test_invalid_repository_is_rejected_before_network_access(self):
        with patch.object(site, "urlopen") as request:
            for repository in ("owner/repo/extra", "owner/repo?token=secret", "https://github.com/owner/repo"):
                with self.subTest(repository=repository), self.assertRaisesRegex(ValueError, "formato"):
                    site.latest_release(repository)
            request.assert_not_called()

    def test_drafts_prereleases_and_invalid_tags_are_rejected(self):
        for release in (None, [], {}, dict(RELEASE, draft=True), dict(RELEASE, prerelease=True),
                        dict(RELEASE, tag_name=""), dict(RELEASE, tag_name=123), dict(RELEASE, tag_name="v1\nmal")):
            with self.subTest(release=release), self.assertRaises(ValueError):
                site.release_tag(release)

    def test_api_response_supplies_the_latest_stable_tag(self):
        response = io.BytesIO(json.dumps(RELEASE).encode())
        with patch.dict(site.os.environ, {"GITHUB_TOKEN": "test-only-token"}), \
                patch.object(site, "urlopen", return_value=response) as request:
            self.assertEqual(site.latest_release("owner/repo"), RELEASE)
        argument = request.call_args.args[0]
        self.assertEqual(argument.full_url, "https://api.github.com/repos/owner/repo/releases/latest")
        self.assertEqual(argument.get_header("Authorization"), "Bearer test-only-token")
        self.assertEqual(request.call_args.kwargs["timeout"], 20)

    def test_api_404_is_the_only_http_error_that_uses_the_empty_release_fallback(self):
        for code in (404, 403, 429, 500):
            with self.subTest(code=code), patch.object(site, "urlopen", side_effect=HTTPError("", code, "", {}, None)):
                if code == 404:
                    self.assertIsNone(site.latest_release("owner/repo"))
                else:
                    with self.assertRaisesRegex(ValueError, f"HTTP {code}"):
                        site.latest_release("owner/repo")

    def test_network_and_malformed_responses_stop_publication(self):
        for error in (URLError("offline"), TimeoutError()):
            with self.subTest(error=error), patch.object(site, "urlopen", side_effect=error), \
                    self.assertRaisesRegex(ValueError, "publicación detenida"):
                site.latest_release("owner/repo")
        for payload in (b"<html>error</html>", b"\xff", b"{}", b"null"):
            with self.subTest(payload=payload), patch.object(site, "urlopen", return_value=io.BytesIO(payload)), \
                    self.assertRaises(ValueError):
                site.latest_release("owner/repo")


class LandingTests(unittest.TestCase):
    def public_files(self):
        return {name: (ROOT / source).read_bytes() for name, source in site.PUBLIC_FILES.items()}

    def test_real_page_has_valid_local_links(self):
        self.assertGreater(site.validate(self.public_files()), 0)

    def test_missing_resource_is_rejected(self):
        files = self.public_files()
        files["index.html"] += b'<a href="missing.md">Missing</a>'
        with self.assertRaisesRegex(ValueError, "inexistente"):
            site.validate(files)

    def test_missing_anchor_is_rejected(self):
        files = self.public_files()
        files["index.html"] += b'<a href="#missing">Missing</a>'
        with self.assertRaisesRegex(ValueError, "Ancla inexistente"):
            site.validate(files)

    def test_missing_copy_or_panel_target_is_rejected(self):
        for attribute in ("data-copy-target", "aria-controls"):
            with self.subTest(attribute=attribute):
                files = self.public_files()
                files["index.html"] += f'<button {attribute}="missing">Control</button>'.encode()
                with self.assertRaisesRegex(ValueError, "Destino de control inexistente"):
                    site.validate(files)

    def test_empty_control_target_is_rejected(self):
        for attribute in ("data-copy-target", "aria-controls"):
            with self.subTest(attribute=attribute):
                files = self.public_files()
                files["index.html"] += f'<button {attribute}="">Control</button>'.encode()
                with self.assertRaisesRegex(ValueError, "Destino de control vacío"):
                    site.validate(files)

    def test_duplicate_id_is_rejected(self):
        files = self.public_files()
        files["index.html"] += b'<div id="inicio"></div>'
        with self.assertRaisesRegex(ValueError, "duplicado"):
            site.validate(files)

    def test_root_relative_asset_is_rejected(self):
        files = self.public_files()
        files["index.html"] += b'<script src="/app.js"></script>'
        with self.assertRaisesRegex(ValueError, "no portable"):
            site.validate(files)

    def test_private_files_stay_out_of_the_artifact(self):
        with tempfile.TemporaryDirectory(prefix="landing-test-") as folder:
            root = Path(folder)
            for target, source in site.PUBLIC_FILES.items():
                path = root / source
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / source).read_bytes())
            for private in ("workspace/private.txt", "knowledge/private.md", ".env", "site/private.txt",
                            "tests/browser/node_modules/example/index.js", "tests/browser/test-results/trace.zip"):
                path = root / private
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("NO PUBLICAR", encoding="utf-8")
            output = site.build(root, repository="owner/repo", release=RELEASE)
            self.assertEqual({path.name for path in output.iterdir()}, set(site.PUBLIC_FILES) | {".nojekyll"})
            self.assertEqual((output / "prompt.md").read_bytes(), (root / "prompt.md").read_bytes())
            self.assertIn('/releases/tag/v9.4.2"', (output / "index.html").read_text(encoding="utf-8"))

    def test_unexpected_output_is_preserved_and_blocks_build(self):
        with tempfile.TemporaryDirectory(prefix="landing-test-") as folder:
            root = Path(folder)
            for source in site.PUBLIC_FILES.values():
                path = root / source
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((ROOT / source).read_bytes())
            (root / "_site").mkdir()
            private = root / "_site/private.txt"
            private.write_text("NO BORRAR NI PUBLICAR", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "archivos ajenos"):
                site.build(root)
            self.assertEqual(private.read_text(encoding="utf-8"), "NO BORRAR NI PUBLICAR")


if __name__ == "__main__":
    unittest.main()
