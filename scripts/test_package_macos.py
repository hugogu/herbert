from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch

from package_macos import ROOT, build_dmg, check_app, check_resources, read_metadata


class MacPackageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = Path(self.directory.name) / 'Herbert.app'
        (self.app / 'Contents/Resources').mkdir(parents=True)
        self.info = self.app / 'Contents/Info.plist'
        self.metadata = {
            'CFBundleIdentifier': 'info.hugogu.Herbert', 'CFBundlePackageType': 'APPL',
            'CFBundleSupportedPlatforms': ['MacOSX'], 'CFBundleExecutable': 'Herbert',
            'LSMinimumSystemVersion': '14.0', 'CFBundleShortVersionString': '0.2.0',
            'CFBundleVersion': '2',
        }
        self.info.write_bytes(plistlib.dumps(self.metadata))

    def test_rejects_wrong_app_platform_edition_or_version(self):
        self.assertEqual(read_metadata(self.app), self.metadata)
        for key, value in [('CFBundleIdentifier', 'other.app'),
                           ('CFBundleExecutable', 'HerbertAppStore'),
                           ('CFBundleSupportedPlatforms', ['iPhoneOS']),
                           ('LSMinimumSystemVersion', '26.0'), ('CFBundleVersion', '')]:
            with self.subTest(key=key):
                self.info.write_bytes(plistlib.dumps({**self.metadata, key: value}))
                with self.assertRaises(ValueError):
                    read_metadata(self.app)

    def test_rejects_missing_modified_duplicate_catalogs_and_reference_solutions(self):
        with self.assertRaises(ValueError):
            check_resources(self.app)
        resources = self.app / 'Contents/Resources'
        for name, source in [('original-problems.json', 'HerbertCore'), ('problems.json', 'HerbertCommunity')]:
            shutil.copyfile(ROOT / f'Sources/{source}/Resources/{name}', resources / name)
        check_resources(self.app)
        catalog = resources / 'problems.json'
        original = catalog.read_bytes()
        catalog.write_text('[]')
        with self.assertRaises(ValueError):
            check_resources(self.app)
        catalog.write_bytes(original)
        duplicate = resources / 'nested'
        duplicate.mkdir()
        shutil.copyfile(catalog, duplicate / catalog.name)
        with self.assertRaises(ValueError):
            check_resources(self.app)
        shutil.rmtree(duplicate)
        (resources / 'original-solutions.json').write_text('[]')
        with self.assertRaises(ValueError):
            check_resources(self.app)

    @patch('package_macos.run')
    def test_rejects_unsandboxed_or_debuggable_release(self, run):
        for entitlements in [{}, {'com.apple.security.app-sandbox': True,
                                 'com.apple.security.get-task-allow': True}]:
            run.side_effect = [b'arm64 x86_64', b'', plistlib.dumps(entitlements)]
            with self.assertRaises(ValueError):
                check_app(self.app)

    @patch('package_macos.run', return_value=b'arm64')
    def test_rejects_single_architecture_build(self, run):
        with self.assertRaisesRegex(ValueError, 'both arm64 and x86_64'):
            check_app(self.app)

    @patch('package_macos.check_app')
    def test_does_not_overwrite_an_existing_artifact(self, check):
        output = Path(self.directory.name) / 'existing.dmg'
        output.write_bytes(b'keep existing image')
        with self.assertRaises(ValueError):
            build_dmg(self.app, output)
        self.assertEqual(output.read_bytes(), b'keep existing image')
