import json
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest

from check_app_store_bundle import check_bundle

ROOT = Path(__file__).resolve().parents[1]


class StoreBundleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / 'Herbot Bot.app'
        self.resources = self.app / 'Contents/Resources/Herbert_HerbertCore.bundle'
        self.resources.mkdir(parents=True)
        self.info = self.app / 'Contents/Info.plist'
        self.metadata = {'CFBundleIdentifier': 'info.hugogu.Herbert',
                         'CFBundleDisplayName': 'Herbot Bot', 'CFBundleName': 'Herbot Bot',
                         'CFBundleExecutable': 'Herbot Bot'}
        self.info.write_bytes(plistlib.dumps(self.metadata))
        self.executable = self.app / 'Contents/MacOS/Herbot Bot'
        self.executable.parent.mkdir()
        self.executable.touch()
        shutil.copyfile(ROOT / 'Sources/HerbertCore/Resources/original-problems.json',
                        self.resources / 'original-problems.json')

    def test_accepts_ios_layout(self):
        shutil.move(self.info, self.app / 'Info.plist')
        shutil.move(self.executable, self.app / 'Herbot Bot')
        shutil.move(self.resources, self.app / self.resources.name)
        shutil.rmtree(self.app / 'Contents')
        check_bundle(self.app)

    def test_rejects_old_product_filename(self):
        old_app = self.app.rename(self.app.with_name('HerbertAppStore.app'))
        with self.assertRaisesRegex(ValueError, 'product filename'):
            check_bundle(old_app)

    def test_rejects_old_names_changed_bundle_id_and_missing_identity_keys(self):
        for key in self.metadata:
            for value in ['HerbertAppStore', None]:
                with self.subTest(key=key, value=value):
                    metadata = dict(self.metadata)
                    if value is None:
                        del metadata[key]
                    else:
                        metadata[key] = value
                    self.info.write_bytes(plistlib.dumps(metadata))
                    with self.assertRaisesRegex(ValueError, key):
                        check_bundle(self.app)

    def test_rejects_missing_declared_executable(self):
        self.executable.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing.*executable'):
            check_bundle(self.app)

    def test_rejects_missing_info_plist(self):
        self.info.unlink()
        with self.assertRaises(OSError):
            check_bundle(self.app)

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
        for name in ['original-solutions.json', 'community-study-solutions.json']:
            with self.subTest(name=name):
                path = self.resources / name
                path.write_text('[]')
                with self.assertRaises(ValueError):
                    check_bundle(self.app)
                path.unlink()
