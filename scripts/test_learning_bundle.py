import plistlib
import unittest

from check_learning_bundle import check_learning
import test_app_store_bundle


class LearningBundleTests(unittest.TestCase):
    def setUp(self):
        test_app_store_bundle.StoreBundleTests.setUp(self)
        self.info_path = self.app / 'Contents/Info.plist'
        self.info = {'CFBundleIdentifier': 'info.hugogu.HerbertLearning',
                     'CFBundleExecutable': 'HerbertLearning'}
        self.info_path.write_bytes(plistlib.dumps(self.info))
        self.executable = self.app / 'Contents/MacOS/HerbertLearning'
        self.executable.parent.mkdir(parents=True)
        self.executable.write_bytes(b'local-learning-only')

    def test_accepts_only_independent_offline_product(self):
        check_learning(self.app)
        for field, value in [('CFBundleIdentifier', 'info.hugogu.Herbert'),
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
