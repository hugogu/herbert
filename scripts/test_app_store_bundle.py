import json
from pathlib import Path
import shutil
import tempfile
import unittest

from check_app_store_bundle import check_bundle

ROOT = Path(__file__).resolve().parents[1]


class StoreBundleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / 'Herbert.app'
        self.resources = self.app / 'Contents/Resources/Herbert_HerbertCore.bundle'
        self.resources.mkdir(parents=True)
        shutil.copyfile(ROOT / 'Sources/HerbertCore/Resources/original-problems.json',
                        self.resources / 'original-problems.json')

    def test_accepts_originals_only_and_rejects_missing_or_modified_catalog(self):
        check_bundle(self.app)
        catalog = self.resources / 'original-problems.json'
        data = json.loads(catalog.read_text())
        data.pop()
        catalog.write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            check_bundle(self.app)
        catalog.unlink()
        with self.assertRaises(ValueError):
            check_bundle(self.app)

    def test_rejects_community_resources_even_with_an_innocent_filename(self):
        archive = self.resources / 'extra.json'
        archive.write_text('[{"id":1,"rows":["u.o"]}]')
        with self.assertRaises(ValueError):
            check_bundle(self.app)
        archive.unlink()
        (self.app / 'Herbert_HerbertCommunity.bundle').mkdir()
        with self.assertRaises(ValueError):
            check_bundle(self.app)

    def test_rejects_test_only_solution_leak(self):
        (self.resources / 'original-solutions.json').write_text('[]')
        with self.assertRaises(ValueError):
            check_bundle(self.app)
