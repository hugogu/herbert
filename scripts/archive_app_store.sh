#!/bin/sh
# Archives the original-only App Store edition, audits its bundle and exports or uploads it.
# Usage: scripts/archive_app_store.sh ios|macos [--check|--upload]
#   --check   unsigned archive and audit only, for verifying a release candidate locally or in CI
#   --upload  send the signed build to App Store Connect instead of exporting an .ipa/.pkg
# Signing uses Xcode automatic signing with DEVELOPMENT_TEAM from the ignored Config/Local.xcconfig.
set -eu
cd "$(dirname "$0")/.."
platform="${1:-}"
mode="${2:-export}"
case "$platform" in
    ios) destination='generic/platform=iOS'; plist='Info.plist' ;;
    macos) destination='generic/platform=macOS'; plist='Contents/Info.plist' ;;
    *) echo "Usage: scripts/archive_app_store.sh ios|macos [--check|--upload]" >&2; exit 2 ;;
esac
case "$mode" in
    export | --check | --upload) ;;
    *) echo "Usage: scripts/archive_app_store.sh ios|macos [--check|--upload]" >&2; exit 2 ;;
esac
setting() { python3 -c "import re, sys; print(re.search(r\"'$1': '([^']+)'\", sys.stdin.read()).group(1))" \
    < scripts/generate_project.py; }
version="$(setting MARKETING_VERSION)"
build="$(setting CURRENT_PROJECT_VERSION)"
output="outputs/app-store/$platform-$version-$build"
if [ "$mode" != --check ]; then
    if ! grep -Eq '^DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' Config/Local.xcconfig 2>/dev/null; then
        echo "Set DEVELOPMENT_TEAM = <your team ID> in Config/Local.xcconfig first." >&2
        exit 1
    fi
    signing='-allowProvisioningUpdates'
else
    output="$output-check"
    signing='CODE_SIGNING_ALLOWED=NO'
fi
if [ -e "$output" ]; then
    echo "$output already exists. Increase CURRENT_PROJECT_VERSION for a new upload, or remove it." >&2
    exit 1
fi

archive="$output/HerbertAppStore.xcarchive"
xcodebuild archive -project Herbert.xcodeproj -scheme HerbertAppStore -configuration Release \
    -destination "$destination" -archivePath "$archive" $signing
app="$archive/Products/Applications/HerbertAppStore.app"
python3 scripts/check_app_store_bundle.py "$app"
for key in CFBundleDisplayName CFBundleShortVersionString CFBundleVersion ITSAppUsesNonExemptEncryption; do
    printf '%s: ' "$key"
    /usr/libexec/PlistBuddy -c "Print :$key" "$app/$plist"
done
if [ "$platform" = macos ]; then
    printf 'LSApplicationCategoryType: '
    /usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$app/$plist"
fi
if [ "$mode" = --check ]; then
    echo "Unsigned $platform archive audited at $archive"
    exit 0
fi

if [ "$platform" = macos ]; then
    # The Mac App Store requires the sandbox; the release build must not be debuggable.
    entitlements="$(codesign -d --entitlements - --xml "$app" 2>/dev/null)"
    case "$entitlements" in *com.apple.security.app-sandbox*) ;; *) echo "Missing App Sandbox" >&2; exit 1 ;; esac
    case "$entitlements" in *get-task-allow*) echo "Debug entitlement in release build" >&2; exit 1 ;; esac
fi
cat > "$output/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>$([ "$mode" = --upload ] && echo upload || echo export)</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$output/export" \
    -exportOptionsPlist "$output/ExportOptions.plist" -allowProvisioningUpdates
echo "Finished $platform $version ($build): $output"
