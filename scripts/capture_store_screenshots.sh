#!/bin/sh
# Captures the App Store screenshots of the original-only edition and frames them with captions.
# Usage: scripts/capture_store_screenshots.sh [iphone] [ipad] [mac]
# LANGUAGES (default "en zh-Hans ja"), IPHONE_SIMULATOR and IPAD_SIMULATOR override the defaults.
set -eu
cd "$(dirname "$0")/.."
devices="${*:-iphone ipad mac}"
languages="${LANGUAGES:-en zh-Hans ja}"
captures=.build/store-captures
derived=.build/store-screenshots

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
        iphone | ipad)
            if [ "$device" = iphone ]; then
                name="${IPHONE_SIMULATOR:-iPhone 18 Pro Max}"
            else
                name="${IPAD_SIMULATOR:-iPad Pro 13-inch (M5)}"
            fi
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
            ;;
        mac)
            if ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
                echo "Unlock the Mac first: macOS cannot enable UI automation on a locked screen." >&2
                exit 1
            fi
            destination='platform=macOS,arch=arm64'
            ;;
        *)
            echo "Usage: scripts/capture_store_screenshots.sh [iphone] [ipad] [mac]" >&2
            exit 2
            ;;
    esac
    xcodebuild build-for-testing -project Herbert.xcodeproj -scheme HerbertAppStore -destination "$destination" \
        -derivedDataPath "$derived" CODE_SIGN_IDENTITY=- -quiet
    for language in $languages; do
        run=".build/store-run-$device-$language"
        rm -rf "$run.xcresult" "$run-attachments"
        TEST_RUNNER_HERBERT_CAPTURE_STORE_SCREENSHOTS=1 TEST_RUNNER_HERBERT_SCREENSHOT_LANGUAGE="$language" \
            xcodebuild test-without-building -project Herbert.xcodeproj -scheme HerbertAppStore \
            -destination "$destination" -derivedDataPath "$derived" -resultBundlePath "$run.xcresult" \
            -only-testing:HerbertAppStoreUITests/StoreScreenshotTests/testCaptureAppStoreScreenshots
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
swift scripts/compose_store_screenshots.swift "$captures" store/screenshots/captions.json store/screenshots
