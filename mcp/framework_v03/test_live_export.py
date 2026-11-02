import base64
import hashlib
import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from live_export import ExportDenied, export_published_site

class LiveExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/"index.html").write_text("<!doctype html><title>IA-TB Architecture</title>")
        (self.root/"static").mkdir()
        (self.root/"static"/"app.css").write_text("body{background:#000}")

    def test_zip_roundtrip(self):
        result = export_published_site(self.root)
        raw = base64.b64decode(result["archive_b64"], validate=True)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), result["sha256"])
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            self.assertEqual(sorted(z.namelist()), ["index.html","static/app.css"])
            self.assertIn(b"Architecture", z.read("index.html"))
        self.assertEqual(result["source"], "published-vps-site")

    def test_forbid_symlink_files(self):
        (self.root/"link").symlink_to("/etc/passwd")
        with self.assertRaises(ExportDenied):
            export_published_site(self.root)

    def test_forbid_symlink_root(self):
        with self.assertRaises(ExportDenied):
            export_published_site(self.root/"link")

    def test_missing_index(self):
        (self.root/"index.html").unlink()
        with self.assertRaises(ExportDenied):
            export_published_site(self.root)

    def test_large_file(self):
        (self.root/"huge.txt").write_bytes(b"A" * 1000001)
        with self.assertRaises(ExportDenied):
            export_published_site(self.root)

if __name__ == "__main__":
    unittest.main()
