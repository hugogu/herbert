import plistlib
import unittest

from check_learning_bundle import check_learning
import test_app_store_bundle


class LearningBundleTests(unittest.TestCase):
    def setUp(self):
        test_app_store_bundle.StoreBundleTests.setUp(self)
        self.app = self.app.rename(self.app.with_name('HerbertLearning.app'))
        (self.app / 'Contents/MacOS/Herbot Bot').unlink()
        self.info_path = self.app / 'Contents/Info.plist'
        self.info = {'CFBundleIdentifier': 'info.hugogu.HerbertLearning',
                     'CFBundleExecutable': 'HerbertLearning', 'CFBundleName': 'HerbertLearning',
                     'CFBundleDisplayName': 'Herbert Learning'}
        self.info_path.write_bytes(plistlib.dumps(self.info))
        self.executable = self.app / 'Contents/MacOS/HerbertLearning'
        self.executable.parent.mkdir(parents=True, exist_ok=True)
        self.executable.write_bytes(b'local-learning-only')

    def test_accepts_only_independent_offline_product(self):
        check_learning(self.app)
        for field, value in [('CFBundleIdentifier', 'info.hugogu.Herbert'),
                             ('CFBundleName', 'Herbot Bot'), ('CFBundleDisplayName', 'Herbot Bot'),
                             ('CFBundleExecutable', 'Herbot Bot'),
                             ('HerbertLeaderboardURL', 'https://api.example.com')]:
            with self.subTest(field=field):
                self.info_path.write_bytes(plistlib.dumps({**self.info, field: value}))
                with self.assertRaises(ValueError):
                    check_learning(self.app)
        self.info_path.write_bytes(plistlib.dumps(self.info))
        for component in [b'HerbertCloud', b'HerbertBattlefield', b'ASAuthorizationAppleIDProvider', b'GKLocalPlayer']:
            with self.subTest(component=component):
                self.executable.write_bytes(component)
                with self.assertRaises(ValueError):
                    check_learning(self.app)

    def test_accepts_ios_bundle_layout(self):
        import shutil
        shutil.move(self.app / 'Contents/Resources/Herbert_HerbertCore.bundle', self.app)
        shutil.move(self.executable, self.app)
        shutil.move(self.info_path, self.app)
        shutil.rmtree(self.app / 'Contents')
        check_learning(self.app)

    def test_rejects_store_product_filename_and_nonoriginal_resources(self):
        old_app = self.app
        self.app = self.app.rename(self.app.with_name('Herbot Bot.app'))
        with self.assertRaisesRegex(ValueError, 'HerbertLearning.app'):
            check_learning(self.app)
        self.app = self.app.rename(old_app)
        (self.app / 'original-solutions.json').write_text('[]')
        with self.assertRaisesRegex(ValueError, 'Non-store resource'):
            check_learning(self.app)
