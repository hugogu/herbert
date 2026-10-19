#!/bin/sh
# Opt-in real-Keychain check: fixed sandbox identity and throwaway per-run values only; no UI automation.
set -eu
cd "$(dirname "$0")/.."
probe_root=$(mktemp -d "${TMPDIR:-/tmp}/herbert-keychain.XXXXXX")
trap 'rm -rf "$probe_root"' EXIT HUP INT TERM
probe_app="$probe_root/HerbertKeychainProbe.app"
mkdir -p "$probe_app/Contents/MacOS"
python3 - "$probe_app/Contents/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], 'wb') as target:
    plistlib.dump({'CFBundleIdentifier': 'info.hugogu.Herbert.KeychainProbe',
                  'CFBundleExecutable': 'HerbertKeychainProbe', 'CFBundlePackageType': 'APPL'}, target)
PY
xcrun swiftc -O -framework Security Sources/HerbertCore/DeviceKeychain.swift \
    Tools/HerbertKeychainProbe/main.swift -o "$probe_app/Contents/MacOS/HerbertKeychainProbe"
probe_entitlements=Config/MacPreview.entitlements
if [ "$#" -eq 1 ]; then
    probe_entitlements="$probe_root/entitlements.plist"
    codesign -d --entitlements - --xml "$1" > "$probe_entitlements"
elif [ "$#" -ne 0 ]; then
    echo "Usage: $0 [ad-hoc-built-app]" >&2
    exit 2
fi
codesign --force --sign - --entitlements "$probe_entitlements" "$probe_app"
codesign --verify --strict "$probe_app"
"$probe_app/Contents/MacOS/HerbertKeychainProbe"
