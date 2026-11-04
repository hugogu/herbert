#!/bin/sh
# Captures the App Store screenshots of the original-only edition and frames them with captions.
# Usage: scripts/capture_store_screenshots.sh [iphone-6.3] [iphone-6.9] [ipad] [mac]
# LANGUAGES (default "en zh-Hans ja") and IPHONE_63_SIMULATOR, IPHONE_69_SIMULATOR or IPAD_SIMULATOR
# override the defaults. App Store Connect requires iphone-6.3; iphone-6.9 is optional.
set -eu
cd "$(dirname "$0")/.."
devices="${*:-iphone-6.3 iphone-6.9 ipad mac}"
languages="${LANGUAGES:-en zh-Hans ja}"
version=$(python3 -c 'import sys; sys.path.insert(0, "scripts")
from check_store_metadata import ROOT, app_version
print(app_version(ROOT / "scripts/generate_project.py")["version"])')
build=$(python3 -c 'import sys; sys.path.insert(0, "scripts")
from check_store_metadata import ROOT, app_version
print(app_version(ROOT / "scripts/generate_project.py")["build"])')
product=$(python3 - <<'PYTHON'
import re
from pathlib import Path
settings = Path('scripts/generate_project.py').read_text().split('store_settings = {', 1)[1]
print(re.search(r"'PRODUCT_NAME': '([^']+)'", settings).group(1))
PYTHON
)
# Never compose a new release from an earlier release's cached captures.
mkdir -p .build
session=$(mktemp -d "$PWD/.build/store-capture-XXXXXXXX")
captures="$session/captures"
composed="$session/composed"
derived=".build/store-screenshots/$version-$build"

simulator() {
    xcrun simctl list devices available -j | python3 -c '
import json
import sys

for runtime, devices in json.load(sys.stdin)["devices"].items():
    for device in devices:
        if device["name"] == sys.argv[1] and "iOS" in runtime:
            print(device["udid"])
            raise SystemExit
raise SystemExit(f"No available iOS simulator named {sys.argv[1]}")' "$1"
}

for device in $devices; do
    case "$device" in
        iphone-6.3 | iphone-6.9 | ipad)
            case "$device" in
                iphone-6.3) name="${IPHONE_63_SIMULATOR:-iPhone 18 Pro}" ;;
                iphone-6.9) name="${IPHONE_69_SIMULATOR:-iPhone 18 Pro Max}" ;;
                *) name="${IPAD_SIMULATOR:-iPad Pro 13-inch (M5)}" ;;
            esac
            udid=$(simulator "$name")
            xcrun simctl boot "$udid" 2>/dev/null || true
            xcrun simctl bootstatus "$udid" -b >/dev/null
            # Apple's customary 9:41 status bar with full signal and battery.
            time=$(python3 -c 'from datetime import datetime, timezone
print(datetime(2026, 1, 9, 9, 41).astimezone().astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"))')
            xcrun simctl status_bar "$udid" override --time "$time" --dataNetwork wifi --wifiMode active \
                --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName '' \
                --batteryState discharging --batteryLevel 100
            destination="platform=iOS Simulator,id=$udid"
            info="$derived/Build/Products/Debug-iphonesimulator/$product.app/Info.plist"
            ;;
        mac)
            if ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
                echo "Unlock the Mac first: macOS cannot enable UI automation on a locked screen." >&2
                exit 1
            fi
            destination='platform=macOS,arch=arm64'
            info="$derived/Build/Products/Debug/$product.app/Contents/Info.plist"
            ;;
        *)
            echo "Usage: scripts/capture_store_screenshots.sh [iphone-6.3] [iphone-6.9] [ipad] [mac]" >&2
            exit 2
            ;;
    esac
    xcodebuild build-for-testing -project Herbert.xcodeproj -scheme HerbertAppStore -destination "$destination" \
        -derivedDataPath "$derived" CODE_SIGN_IDENTITY=- -quiet
    python3 - "$info" "$version" "$build" <<'PYTHON'
import plistlib
import sys
from pathlib import Path

info = plistlib.loads(Path(sys.argv[1]).read_bytes())
actual = (info['CFBundleShortVersionString'], str(info['CFBundleVersion']))
expected = tuple(sys.argv[2:])
if actual != expected:
    raise SystemExit(f'Built app version {actual} does not match expected {expected}')
PYTHON
    for language in $languages; do
        run="$session/run-$device-$language"
        echo "Capturing $version ($build), $device, $language; log: $run.log"
        TEST_RUNNER_HERBERT_CAPTURE_STORE_SCREENSHOTS=1 TEST_RUNNER_HERBERT_SCREENSHOT_LANGUAGE="$language" \
            xcodebuild test-without-building -project Herbert.xcodeproj -scheme HerbertAppStore \
            -destination "$destination" -derivedDataPath "$derived" -resultBundlePath "$run.xcresult" \
            -parallel-testing-enabled NO \
            -only-testing:HerbertAppStoreUITests/StoreScreenshotTests/testCaptureAppStoreScreenshots \
            >"$run.log" 2>&1 || { cat "$run.log" >&2; exit 1; }
        xcrun xcresulttool export attachments --path "$run.xcresult" --output-path "$run-attachments"
        python3 - "$run-attachments" "$captures/$device/$language" <<'PYTHON'
import json
from pathlib import Path
import shutil
import sys

source, output = Path(sys.argv[1]), Path(sys.argv[2])
scenes = json.loads(Path('store/screenshots/captions.json').read_text())['scenes']
images = {}
for test in json.loads((source / 'manifest.json').read_text()):
    for item in test['attachments']:
        name = item['suggestedHumanReadableName'].split('_0_')[0].removeprefix('store-')
        if name in scenes and not item['isAssociatedWithFailure']:
            images[name] = source / item['exportedFileName']
if missing := sorted(set(scenes) - set(images)):
    raise SystemExit(f'Missing captures: {missing}')
output.mkdir(parents=True, exist_ok=True)
for name, path in images.items():
    shutil.copyfile(path, output / f'{name}.png')
print(f'Captured {len(images)} scenes in {output}')
PYTHON
    done
done
swift scripts/compose_store_screenshots.swift "$captures" store/screenshots/captions.json "$composed"
python3 - "$composed" "$version" "$build" <<'PYTHON'
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

source = Path(sys.argv[1])
captions_hash = hashlib.sha256(Path('store/screenshots/captions.json').read_bytes()).hexdigest()
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
for folder in sorted(source.glob('*/*')):
    destination = Path('store/screenshots') / folder.relative_to(source)
    destination.mkdir(parents=True, exist_ok=True)
    images = sorted(folder.glob('*.png'))
    # Scene insertions change numbering: remove the previous set only after composition succeeds.
    for old in destination.glob('*.png'):
        old.unlink()
    for image in images:
        shutil.copyfile(image, destination / image.name)
    manifest = {
        'version': sys.argv[2], 'build': sys.argv[3], 'commit': commit,
        'captured_at': datetime.now(timezone.utc).isoformat(),
        'captions_sha256': captions_hash,
        'images': {image.name: hashlib.sha256(image.read_bytes()).hexdigest() for image in images},
    }
    (destination / 'capture.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Updated {destination}: {len(images)} screenshots')
PYTHON
python3 scripts/check_store_metadata.py
echo "Before submitting, run: python3 scripts/check_store_metadata.py --require-current-screenshots"
