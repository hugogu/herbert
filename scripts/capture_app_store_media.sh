#!/bin/sh
# Capture the actual macOS store build; run locales sequentially because they share focus.
set -eu
cd "$(dirname "$0")/.."
language="${1:-en}"
kind="${2:-screenshots}"
case "$language" in
    en) locale="en-US" ;;
    zh-Hans) locale="zh-Hans" ;;
    *) echo 'Usage: scripts/capture_app_store_media.sh [en|zh-Hans] [screenshots|video]' >&2; exit 2 ;;
esac
case "$kind" in
    screenshots) method="testCaptureAppStoreMedia" ;;
    video) method="testCaptureAppStoreVideo" ;;
    *) echo 'Expected screenshots or video.' >&2; exit 2 ;;
esac
run=".build/store-media-$(date +%Y%m%d-%H%M%S)"
output="outputs/app-store-macos/0.4.0/$locale"
mkdir -p "$run" "$output/raw-video"
export TEST_RUNNER_HERBERT_CAPTURE_SCREENSHOTS=1
export TEST_RUNNER_HERBERT_SCREENSHOT_LANGUAGE="$language"
xcodebuild -project Herbert.xcodeproj -scheme HerbertAppStore -destination 'platform=macOS' \
    -derivedDataPath .build/store-media-040 -resultBundlePath "$run/results.xcresult" \
    CODE_SIGN_IDENTITY=- -only-testing:"HerbertAppStoreUITests/HerbertUITests/$method" test
python3 scripts/check_app_store_bundle.py .build/store-media-040/Build/Products/Debug/HerbertAppStore.app
xcrun xcresulttool export attachments --path "$run/results.xcresult" --output-path "$run/attachments"
if [ "$kind" = screenshots ]; then
    python3 - "$run/attachments" "$output" <<'PY'
import json
import struct
import subprocess
import sys
from pathlib import Path

attachments, output = map(Path, sys.argv[1:])
captured = set()
for test in json.loads((attachments / 'manifest.json').read_text()):
    for item in test.get('attachments', []):
        name = item.get('suggestedHumanReadableName', '')
        if 'readme-store-' not in name:
            continue
        stem = name[name.index('readme-store-') + len('readme-store-'):].split('_')[0].removesuffix('.png')
        destination = output / f'{stem}.png'
        # PNG RGB output removes the screenshot alpha channel without altering UI content.
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(attachments / item['exportedFileName']),
                        '-vf', 'format=rgb24', '-frames:v', '1', str(destination)], check=True)
        width, height = struct.unpack('>II', destination.read_bytes()[16:24])
        if (width, height) not in {(1440, 900), (2880, 1800)}:
            raise SystemExit(f'Unexpected screenshot size: {destination}: {width} x {height}')
        captured.add(stem)
if len(captured) != 6:
    raise SystemExit(f'Expected six screenshots; exported {len(captured)}.')
print(f'Saved six screenshots to {output}')
PY
else
    python3 - "$run/attachments" "$output/raw-video" <<'PY'
import json
import sys
import zipfile
from pathlib import Path

attachments, output = map(Path, sys.argv[1:])
captured = set()
for test in json.loads((attachments / 'manifest.json').read_text()):
    for item in test.get('attachments', []):
        name = item.get('suggestedHumanReadableName', '')
        if 'store-video-' not in name:
            continue
        stem = name[name.index('store-video-') + len('store-video-'):].split('_')[0].removesuffix('.zip')
        with zipfile.ZipFile(attachments / item['exportedFileName']) as archive:
            archive.extractall(output / stem)
        captured.add(stem)
if captured != {'01-library', '02-run', '03-step'}:
    raise SystemExit(f'Incomplete video sources: {captured}')
print(f'Saved three native video sequences to {output}')
PY
fi
