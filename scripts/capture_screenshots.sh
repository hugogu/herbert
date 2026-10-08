#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
language="${1:-en}"
edition="${2:-community}"
case "$edition" in
    community) scheme="Herbert"; suite="HerbertUITests"; method="testCaptureReadmeScreenshots" ;;
    store) scheme="HerbertAppStore"; suite="HerbertAppStoreUITests"; method="testCaptureOriginalCourseScreenshots" ;;
    *) echo "Usage: scripts/capture_screenshots.sh [en|zh-Hans] [community|store]" >&2; exit 2 ;;
esac
case "$language" in
    en) output="docs/screenshots/en" ;;
    zh-Hans) output="docs/screenshots" ;;
    *) echo "Usage: scripts/capture_screenshots.sh [en|zh-Hans]" >&2; exit 2 ;;
esac
if [ "$edition" = store ]; then output="$output/course"; fi
capture_dir=".build/screenshots-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$capture_dir"
TEST_RUNNER_HERBERT_CAPTURE_SCREENSHOTS=1 TEST_RUNNER_HERBERT_SCREENSHOT_LANGUAGE="$language" xcodebuild \
    -project Herbert.xcodeproj -scheme "$scheme" \
    -destination 'platform=macOS' -derivedDataPath .build/screenshot-xcode \
    -resultBundlePath "$capture_dir/results.xcresult" CODE_SIGN_IDENTITY=- \
    -only-testing:"$suite/HerbertUITests/$method" test
xcrun xcresulttool export attachments \
    --path "$capture_dir/results.xcresult" --output-path "$capture_dir/attachments"
python3 - "$capture_dir/attachments" "$output" "$edition" <<'PYTHON'
import json
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1])
output = Path(sys.argv[2])
expected = {'library', 'flower', 'flower-board', 'shuriken', 'shuriken-board',
            'butterfly', 'butterfly-board', 'flower-classic', 'flower-classic-board'}
images = {}
if sys.argv[3] == 'store':
    expected = {'course-library'} | {f'course-{name}{suffix}' for name in ['spiral', 'windows', 'garden'] for suffix in ['', '-board']} | {'course-garden-classic', 'course-garden-classic-board'}
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
