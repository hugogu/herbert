import json
import plistlib
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform == 'darwin', 'Xcode project validation requires macOS plutil')
class CloudEnvironmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(['plutil', '-convert', 'json', '-o', '-',
                                 str(ROOT / 'Herbert.xcodeproj/project.pbxproj')],
                                check=True, capture_output=True, text=True)
        cls.objects = json.loads(result.stdout)['objects']

    def configurations(self, name):
        target = next(obj for obj in self.objects.values()
                      if obj['isa'] == 'PBXNativeTarget' and obj['name'] == name)
        config_list = self.objects[target['buildConfigurationList']]
        return {self.objects[key]['name']: self.objects[key]['buildSettings']
                for key in config_list['buildConfigurations']}

    def test_store_debug_is_staging_and_archive_is_production(self):
        configs = self.configurations('HerbertAppStore')
        for kind, environment, bundle_id in [
            ('Debug', 'STAGING', 'info.hugogu.Herbert.Staging'),
            ('Release', 'PRODUCTION', 'info.hugogu.Herbert'),
        ]:
            with self.subTest(configuration=kind):
                self.assertEqual(configs[kind]['HERBERT_CLOUD_URL'],
                                 f'$(HERBERT_CLOUD_{environment}_URL)')
                self.assertEqual(configs[kind]['PRODUCT_BUNDLE_IDENTIFIER'], bundle_id)
                self.assertEqual(configs[kind]['INFOPLIST_FILE'], 'Config/Cloud/Info.plist')
                template = plistlib.loads((ROOT / configs[kind]['INFOPLIST_FILE']).read_bytes())
                self.assertEqual(template['HerbertLeaderboardURL'], '$(HERBERT_CLOUD_URL)')

    def test_local_editions_have_no_cloud_endpoint(self):
        for target in ['Herbert', 'HerbertLearning']:
            for config in self.configurations(target).values():
                self.assertNotIn('INFOPLIST_KEY_HerbertLeaderboardURL', config)
                self.assertNotIn('INFOPLIST_FILE', config)
                self.assertNotIn('HERBERT_CLOUD_URL', config)
