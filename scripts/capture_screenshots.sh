#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
capture_dir=".build/screenshots-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$capture_dir"
TEST_RUNNER_HERBERT_CAPTURE_SCREENSHOTS=1 xcodebuild \
    -project Herbert.xcodeproj -scheme Herbert \
    -destination 'platform=macOS' -derivedDataPath .build/xcode \
    -resultBundlePath "$capture_dir/results.xcresult" CODE_SIGN_IDENTITY=- \
    -only-testing:HerbertUITests/HerbertUITests/testCaptureReadmeScreenshots test
xcrun xcresulttool export attachments \
    --path "$capture_dir/results.xcresult" --output-path "$capture_dir/attachments"
python3 - "$capture_dir/attachments" <<'PYTHON'
import json
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1])
output = Path('docs/screenshots')
expected = {'library', 'flower', 'flower-board', 'shuriken', 'shuriken-board',
            'butterfly', 'butterfly-board', 'flower-classic', 'flower-classic-board'}
images = {}
for test in json.loads((source / 'manifest.json').read_text()):
    for item in test['attachments']:
        name = item['suggestedHumanReadableName'].split('_0_')[0].removeprefix('readme-')
        if name in expected and not item['isAssociatedWithFailure']:
            images[name] = source / item['exportedFileName']
if set(images) != expected:
    raise SystemExit(f'Missing screenshots: {sorted(expected - set(images))}')
output.mkdir(parents=True, exist_ok=True)
for name, path in images.items():
    shutil.copyfile(path, output / f'{name}.png')
print(f'Exported {len(images)} native screenshots to {output}. Review them before committing.')
PYTHON
