from pathlib import Path
import shutil
import struct
import tempfile
import unittest
import zlib

from check_store_metadata import check_store

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
