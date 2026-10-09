import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from package_macos import ROOT, build_dmg, check_app, check_resources, create_dmg, read_metadata, run


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
            'LSMinimumSystemVersion': '14.0', 'CFBundleShortVersionString': '0.3.1',
            'CFBundleVersion': '4',
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
        for entitlements in [{}, {'com.apple.security.app-sandbox': True},
                                {'com.apple.security.app-sandbox': True,
                                 'com.apple.security.network.client': True,
                                 'com.apple.security.get-task-allow': True}]:
            run.side_effect = [b'arm64 x86_64', b'', plistlib.dumps(entitlements)]
            with self.assertRaises(ValueError):
                check_app(self.app)

    @patch('package_macos.check_resources')
    @patch('package_macos.run')
    def test_accepts_sandboxed_network_client_without_debugger_access(self, run, resources):
        run.side_effect = [b'arm64 x86_64', b'', plistlib.dumps({
            'com.apple.security.app-sandbox': True, 'com.apple.security.network.client': True})]
        self.assertEqual(check_app(self.app)['CFBundleShortVersionString'], '0.3.1')
        resources.assert_called_once_with(self.app)

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

    @patch('package_macos.time.sleep')
    @patch('package_macos.run')
    def test_rebuilds_a_fresh_image_after_create_convert_or_verify_failure(self, command, sleep):
        for failed_verb in ['create', 'convert', 'verify']:
            with self.subTest(verb=failed_verb):
                work = Path(self.directory.name) / failed_verb
                work.mkdir()
                stage = work / 'stage'
                stage.mkdir()
                calls = []
                failed = False

                def execute(*args):
                    nonlocal failed
                    calls.append(args)
                    if args[1] == 'create':
                        self.assertEqual(args[args.index('-format') + 1], 'UDRW')
                        Path(args[-1]).write_bytes(b'writable image')
                    elif args[1] == 'convert':
                        self.assertEqual(args[args.index('-tasks') + 1], '1')
                        self.assertEqual(args[args.index('-format') + 1], 'UDZO')
                        Path(args[-1]).write_bytes(b'compressed image')
                    if args[1] == failed_verb and not failed:
                        failed = True
                        raise subprocess.CalledProcessError(1, args, output=b'corrupt image')
                    return b''

                command.side_effect = execute
                sleep.reset_mock()
                image = create_dmg(stage, work)
                self.assertEqual(image.parent.name, 'attempt-2')
                self.assertEqual(image.read_bytes(), b'compressed image')
                self.assertEqual([args[1] for args in calls[-3:]], ['create', 'convert', 'verify'])
                first, second = [Path(args[-1]) for args in calls if args[1] == 'create']
                self.assertNotEqual(first, second)
                sleep.assert_called_once_with(2)

    @patch('package_macos.check_app')
    @patch('package_macos.audit_dmg')
    @patch('package_macos.time.sleep')
    @patch('package_macos.run')
    def test_persistent_command_failures_never_publish_an_image_or_checksum(self, command, sleep, audit, check):
        for failure in [subprocess.CalledProcessError(1, ['hdiutil', 'create']),
                        subprocess.TimeoutExpired(['hdiutil', 'create'], 180)]:
            with self.subTest(error=type(failure).__name__):
                command.reset_mock()
                sleep.reset_mock()

                def execute(*args):
                    if args[0] == 'hdiutil':
                        raise failure
                    return b''

                command.side_effect = execute
                output = Path(self.directory.name) / 'failed.dmg'
                with self.assertRaises(type(failure)):
                    build_dmg(self.app, output)
                self.assertFalse(output.exists())
                self.assertFalse(output.with_suffix('.dmg.sha256').exists())
                self.assertEqual(sum(call.args[0] == 'hdiutil' for call in command.call_args_list), 3)
                self.assertEqual([call.args[0] for call in sleep.call_args_list], [2, 4])
                audit.assert_not_called()

    @patch('package_macos.check_app')
    @patch('package_macos.audit_dmg', side_effect=ValueError('Modified puzzle catalog'))
    @patch('package_macos.create_dmg')
    @patch('package_macos.run', return_value=b'')
    def test_bundle_audit_failures_are_not_retried_or_published(self, command, create, audit, check):
        output = Path(self.directory.name) / 'invalid.dmg'
        with self.assertRaisesRegex(ValueError, 'Modified puzzle catalog'):
            build_dmg(self.app, output)
        create.assert_called_once()
        audit.assert_called_once_with(create.return_value)
        self.assertFalse(output.exists())
        self.assertFalse(output.with_suffix('.dmg.sha256').exists())

    @patch('package_macos.check_app')
    @patch('package_macos.audit_dmg')
    @patch('package_macos.run')
    def test_publishes_only_the_verified_image_and_matching_checksum(self, command, audit, check):
        output = Path(self.directory.name) / 'verified.dmg'
        audit.return_value = self.metadata

        def execute(*args):
            if args[:2] == ('hdiutil', 'convert'):
                Path(args[-1]).write_bytes(b'verified compressed image')
            if args[:2] == ('hdiutil', 'verify'):
                self.assertFalse(output.exists())
            return b''

        def mounted_audit(image):
            self.assertEqual(image.read_bytes(), b'verified compressed image')
            self.assertFalse(output.exists())
            return self.metadata

        command.side_effect = execute
        audit.side_effect = mounted_audit
        self.assertEqual(build_dmg(self.app, output), self.metadata)
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        self.assertEqual(output.with_suffix('.dmg.sha256').read_text(), f'{digest}  {output.name}\n')
        self.assertTrue(self.app.exists())


@unittest.skipUnless(sys.platform == 'darwin' and shutil.which('hdiutil'), 'Requires macOS disk images')
class MacDiskImageIntegrationTests(unittest.TestCase):
    def test_real_image_round_trip_retains_files_and_applications_shortcut(self):
        with tempfile.TemporaryDirectory(prefix='herbert-image-test-') as directory:
            work = Path(directory)
            stage = work / 'stage'
            stage.mkdir()
            payload = bytes(range(256)) * 1024
            (stage / 'fixture.bin').write_bytes(payload)
            (stage / 'Applications').symlink_to('/Applications', target_is_directory=True)
            image = create_dmg(stage, work)
            self.assertEqual(run('hdiutil', 'imageinfo', str(image), '-format').strip(), b'UDZO')
            mount = work / 'mount'
            mount.mkdir()
            run('hdiutil', 'attach', str(image), '-readonly', '-nobrowse', '-mountpoint', str(mount))
            try:
                self.assertEqual((mount / 'fixture.bin').read_bytes(), payload)
                self.assertTrue((mount / 'Applications').is_symlink())
                self.assertEqual((mount / 'Applications').readlink(), Path('/Applications'))
            finally:
                run('hdiutil', 'detach', str(mount))
