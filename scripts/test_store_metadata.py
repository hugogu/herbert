from pathlib import Path
import hashlib
import json
import shutil
import struct
import tempfile
import unittest
import zlib

from check_store_metadata import app_version, check_store

ROOT = Path(__file__).resolve().parents[1]


def png(path, width, height, alpha=False):
    """Write the PNG chunks the checker reads; the pixel data is deliberately empty."""
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))

    header = struct.pack('>IIBBBBB', width, height, 8, 6 if alpha else 2, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IEND', b''))


class StoreMetadataTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.store = Path(self.directory.name) / 'store'
        shutil.copytree(ROOT / 'store/metadata', self.store / 'metadata')
        (self.store / 'screenshots').mkdir()

    def write(self, relative, text):
        (self.store / 'metadata' / relative).write_text(text + '\n', encoding='utf-8')

    def errors(self):
        return '\n'.join(check_store(self.store))

    def test_repository_listing_passes(self):
        self.assertEqual(check_store(ROOT / 'store'), [])

    def test_rejects_long_names_and_names_unlike_the_home_screen_name(self):
        self.write('en-US/name.txt', 'Herbot Bot: Code Puzzles for Everyone')
        self.assertIn('name has 37 characters', self.errors())
        self.write('en-US/name.txt', 'Code Puzzles')
        self.assertIn('must start with the device display name "Herbot Bot"', self.errors())

    def test_counts_keyword_bytes_not_characters(self):
        # 34 three-byte characters fit in 100 characters but exceed 100 bytes.
        self.write('zh-Hans/keywords.txt', ','.join(['编程游戏'] * 8 + ['学编程']))
        self.assertIn('keywords use', self.errors())

    def test_rejects_short_duplicate_and_name_keywords(self):
        self.write('en-US/keywords.txt', 'ai,logic,Logic,herbot')
        errors = self.errors()
        self.assertIn('keyword "ai" must be longer than two characters', errors)
        self.assertIn('keywords contain duplicates', errors)
        self.assertIn('keyword "herbot" repeats the app name', errors)

    def test_rejects_field_limits_and_insecure_urls(self):
        self.write('ja/promotional_text.txt', 'あ' * 171)
        self.write('en-US/support_url.txt', 'http://example.com/support')
        errors = self.errors()
        self.assertIn('ja: promotional_text has 171 of 170 characters', errors)
        self.assertIn('en-US: support_url must be one HTTPS URL', errors)

    def test_game_subcategories_need_a_games_category(self):
        self.write('secondary_category.txt', 'REFERENCE')
        self.assertIn('needs GAMES as the secondary category', self.errors())

    def test_review_notes_are_limited_in_bytes(self):
        self.write('review_information/notes.txt', '审' * 1400)
        self.assertIn('Review notes use 4200 of 4000 bytes', self.errors())

    def test_release_notes_are_required_and_limited_in_characters(self):
        self.write('ja/release_notes.txt', '新' * 4000)
        self.assertEqual(self.errors(), '')
        self.write('ja/release_notes.txt', '新' * 4001)
        self.assertIn('ja: release_notes has 4001 of 4000 characters', self.errors())
        (self.store / 'metadata/ja/release_notes.txt').unlink()
        self.assertIn('ja: missing release_notes.txt', self.errors())

    def make_current_captures(self):
        captions_path = self.store / 'screenshots/captions.json'
        captions_path.write_text(json.dumps({'scenes': ['play', 'three-d']}))
        version = app_version(ROOT / 'scripts/generate_project.py')
        for device, size in [('iphone-6.3', (1206, 2622)), ('ipad', (2752, 2064)), ('mac', (2880, 1800))]:
            for locale in ['en-US', 'zh-Hans', 'ja']:
                folder = self.store / 'screenshots' / device / locale
                for name in ['01-play.png', '02-three-d.png']:
                    png(folder / name, *size)
                manifest = {
                    **version, 'captions_sha256': hashlib.sha256(captions_path.read_bytes()).hexdigest(),
                    'images': {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in folder.glob('*.png')},
                }
                (folder / 'capture.json').write_text(json.dumps(manifest))

    def release_errors(self):
        return '\n'.join(check_store(self.store, require_current_screenshots=True))

    def test_submission_requires_all_devices_and_locales_to_be_recaptured(self):
        self.make_current_captures()
        self.assertEqual(self.release_errors(), '')
        shutil.rmtree(self.store / 'screenshots/mac/ja')
        self.assertIn('mac/ja: missing capture.json', self.release_errors())

    def test_submission_rejects_old_versions_builds_and_unreadable_manifests(self):
        self.make_current_captures()
        path = self.store / 'screenshots/iphone-6.3/en-US/capture.json'
        current = json.loads(path.read_text())
        for manifest in [{**current, 'version': '1.0.0'}, {**current, 'build': '0'}]:
            path.write_text(json.dumps(manifest))
            self.assertIn('captures must be from version', self.release_errors())
        for text in ['{', '[]']:
            path.write_text(text)
            self.assertIn('unreadable capture.json', self.release_errors())

    def test_submission_rejects_changed_captions_images_and_stale_scene_files(self):
        self.make_current_captures()
        captions = self.store / 'screenshots/captions.json'
        captions.write_text(json.dumps({'scenes': ['play', 'three-d'], 'title': 'New title'}))
        png(self.store / 'screenshots/mac/en-US/01-play.png', 1440, 900)
        png(self.store / 'screenshots/mac/en-US/02-course.png', 2880, 1800)
        errors = self.release_errors()
        self.assertIn('captions changed', errors)
        self.assertIn('image differs from its capture manifest', errors)
        self.assertIn('screenshots must match the current caption scene order', errors)

    def test_screenshots_need_accepted_sizes_without_alpha_and_matching_locales(self):
        png(self.store / 'screenshots/iphone-6.3/en-US/01-play.png', 1206, 2622)
        png(self.store / 'screenshots/iphone-6.3/ja/01-play.png', 1206, 2622)
        self.assertEqual(check_store(self.store), [])
        png(self.store / 'screenshots/iphone-6.3/ja/01-play.png', 1206, 2622, alpha=True)
        png(self.store / 'screenshots/iphone-6.9/en-US/01-play.png', 1206, 2622)
        png(self.store / 'screenshots/ipad/en-US/01-play.png', 2752, 2064)
        png(self.store / 'screenshots/mac/en-US/01-play.png', 1800, 2880)
        png(self.store / 'screenshots/mac/fr-FR/01-play.png', 2880, 1800)
        errors = self.errors()
        self.assertIn('iphone-6.3/ja/01-play.png: screenshots cannot contain alpha', errors)
        self.assertIn('iphone-6.9/en-US/01-play.png: 1206 × 2622 is not an accepted size', errors)
        self.assertNotIn('ipad/en-US/01-play.png', errors)
        self.assertIn('mac/en-US/01-play.png: 1800 × 2880 is not an accepted size', errors)
        self.assertIn('mac/fr-FR: screenshots have no matching metadata locale', errors)

    def test_requires_the_medium_iphone_set(self):
        # App Store Connect rejects a listing whose only iPhone screenshots are 6.9-inch.
        png(self.store / 'screenshots/iphone-6.9/en-US/01-play.png', 1320, 2868)
        self.assertIn('requires the 6.3-inch medium iPhone screenshots', self.errors())
        png(self.store / 'screenshots/iphone-6.3/en-US/01-play.png', 1206, 2622)
        self.assertEqual(check_store(self.store), [])


if __name__ == '__main__':
    unittest.main()
