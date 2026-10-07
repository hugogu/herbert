"""Check shared localization coverage and printf argument safety without dependencies."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def translations(language):
    source = (ROOT / f'Sources/HerbertCore/Resources/{language}.lproj/Localizable.strings').read_text()
    return dict((json.loads(k), json.loads(v)) for k, v in
                re.findall(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");', source))


class LocalizationTests(unittest.TestCase):
    def test_all_languages_have_identical_keys_and_format_arguments(self):
        base = translations('en')
        self.assertGreater(len(base), 170)
        for language in ['zh-Hans', 'ja']:
            actual = translations(language)
            self.assertEqual(set(base), set(actual))
            for key, value in actual.items():
                self.assertEqual(re.findall(r'%(?:lld|ld|@)', key),
                                 re.findall(r'%(?:lld|ld|@)', value), (language, key))
                self.assertTrue(value.strip(), (language, key))

    def test_static_chinese_interface_and_diagnostic_strings_are_translated(self):
        keys = translations('en')
        files = list((ROOT / 'Herbert').rglob('*.swift')) + list((ROOT / 'Sources/HerbertCore').glob('*.swift'))
        for file in files:
            for raw in re.findall(r'"((?:[^"\\]|\\.)*)"', file.read_text()):
                if not re.search('[\u4e00-\u9fff]', raw) or r'\(' in raw:
                    continue
                self.assertTrue(json.loads('"' + raw + '"') in keys, (file.name, raw))
