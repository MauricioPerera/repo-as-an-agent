"""Regression checks for the landing's publication boundary and navigation."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("build_site", ROOT / "scripts/build-site.py")
site = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(site)


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
            for private in ("workspace/private.txt", "knowledge/private.md", ".env", "site/private.txt"):
                path = root / private
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("NO PUBLICAR", encoding="utf-8")
            output = site.build(root)
            self.assertEqual({path.name for path in output.iterdir()}, set(site.PUBLIC_FILES) | {".nojekyll"})
            self.assertEqual((output / "prompt.md").read_bytes(), (root / "prompt.md").read_bytes())

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
