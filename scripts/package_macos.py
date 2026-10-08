#!/usr/bin/env python3
"""Create or verify a universal, sandboxed Mac preview DMG using macOS tools."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
INSTALL_NOTES = """Herbert for Mac — open-source preview

Requires macOS 14 or later. Supports Apple Silicon and Intel Macs.
Drag Herbert.app to Applications, then open Herbert from Applications.
No Xcode, account, or network connection is required to play.
Optional AI Battlefield uses your own provider API keys and an Internet connection.
Provider API charges may apply. Keys stay in Keychain; match history stays on this Mac.

This preview is ad-hoc signed, not Developer ID signed or Apple notarized.
If macOS blocks the first launch, follow Apple's instructions for this app:
System Settings > Privacy & Security > Open Anyway, after trying to open it.
https://support.apple.com/en-us/102445

中文：将 Herbert.app 拖入 Applications（应用程序），然后打开。
如首次启动被系统阻止，可按 Apple 指引在“系统设置 > 隐私与安全”中确认打开。
日本語：Herbert.app を Applications にドラッグしてから開いてください。
初回起動がブロックされた場合は、Apple の案内に従い、
「システム設定 > プライバシーとセキュリティ」で許可してください。

Includes 50 original lessons and 1,769 archived community problems.
Code and original lessons: MIT. Community content: separate rights;
see the included LICENSE and NOTICE.md for attribution and scope.
Source, updates, and issues: https://github.com/hugogu/herbert
"""


def run(*args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, timeout=180).stdout


def read_metadata(app):
    if app.name != 'Herbert.app' or not app.is_dir():
        raise ValueError('Expected a built Herbert.app directory.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if (info.get('CFBundleIdentifier') != 'info.hugogu.Herbert'
            or info.get('CFBundlePackageType') != 'APPL'
            or 'MacOSX' not in info.get('CFBundleSupportedPlatforms', [])
            or info.get('CFBundleExecutable') != 'Herbert'):
        raise ValueError('Expected the native Mac open-source edition of Herbert.')
    if info.get('LSMinimumSystemVersion') != '14.0':
        raise ValueError('Expected the macOS 14 deployment target.')
    if not info.get('CFBundleShortVersionString') or not info.get('CFBundleVersion'):
        raise ValueError('App version and build number are required.')
    return info


def check_resources(app):
    resources = app / 'Contents/Resources'
    for name, canonical in [
        ('original-problems.json', ROOT / 'Sources/HerbertCore/Resources/original-problems.json'),
        ('problems.json', ROOT / 'Sources/HerbertCommunity/Resources/problems.json'),
    ]:
        matches = list(resources.rglob(name))
        if len(matches) != 1 or json.loads(matches[0].read_text()) != json.loads(canonical.read_text()):
            raise ValueError(f'Missing, duplicated, or modified puzzle catalog: {name}')
    if any(app.rglob('*-solutions.json')):
        raise ValueError('Test reference solutions must not be distributed.')


def check_app(app):
    info = read_metadata(app)
    architectures = run('lipo', '-archs', str(app / 'Contents/MacOS/Herbert')).decode().split()
    if set(architectures) != {'arm64', 'x86_64'}:
        raise ValueError('The distributed app must contain both arm64 and x86_64.')
    run('codesign', '--verify', '--deep', '--strict', '--all-architectures', str(app))
    entitlements = plistlib.loads(run('codesign', '-d', '--entitlements', '-', '--xml', str(app)))
    if not entitlements.get('com.apple.security.app-sandbox'):
        raise ValueError('The distributed app must retain its sandbox.')
    if not entitlements.get('com.apple.security.network.client'):
        raise ValueError('AI Battlefield requires the outgoing network client entitlement.')
    if entitlements.get('com.apple.security.get-task-allow'):
        raise ValueError('The distributed app must not permit debugger attachment.')
    check_resources(app)
    return info


def verify_dmg(dmg):
    run('hdiutil', 'verify', str(dmg))
    with tempfile.TemporaryDirectory(prefix='herbert-mount-') as directory:
        mount = Path(directory) / 'volume'
        mount.mkdir()
        run('hdiutil', 'attach', str(dmg), '-readonly', '-nobrowse', '-mountpoint', str(mount))
        try:
            if not (mount / 'Applications').is_symlink() or os.readlink(mount / 'Applications') != '/Applications':
                raise ValueError('DMG must include the Applications shortcut.')
            for name in ['LICENSE', 'NOTICE.md']:
                if (mount / name).read_bytes() != (ROOT / name).read_bytes():
                    raise ValueError(f'DMG must include the complete {name}.')
            if (mount / 'Read Me.txt').read_text() != INSTALL_NOTES:
                raise ValueError('DMG must include the installation and signing notes.')
            return check_app(mount / 'Herbert.app')
        finally:
            run('hdiutil', 'detach', str(mount))


def build_dmg(app, output):
    check_app(app)
    if output.suffix != '.dmg' or output.exists() or output.with_suffix('.dmg.sha256').exists():
        raise ValueError('Choose a new .dmg output path; existing artifacts are preserved.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='herbert-dmg-') as directory:
        work = Path(directory)
        stage = work / 'stage'
        stage.mkdir()
        run('ditto', str(app), str(stage / 'Herbert.app'))
        (stage / 'Applications').symlink_to('/Applications', target_is_directory=True)
        for name in ['LICENSE', 'NOTICE.md']:
            shutil.copyfile(ROOT / name, stage / name)
        (stage / 'Read Me.txt').write_text(INSTALL_NOTES)
        image = work / 'Herbert.dmg'
        run('hdiutil', 'create', '-volname', 'Herbert', '-srcfolder', str(stage),
            '-fs', 'HFS+', '-format', 'UDZO', str(image))
        info = verify_dmg(image)
        shutil.move(str(image), output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.dmg.sha256').write_text(f'{digest}  {output.name}\n')
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('build', help='Package a built Release app and write its SHA-256.')
    build.add_argument('--app', type=Path, required=True)
    build.add_argument('--output', type=Path, required=True)
    verify = commands.add_parser('verify', help='Mount read-only and audit an existing DMG.')
    verify.add_argument('dmg', type=Path)
    args = parser.parse_args()
    try:
        info = build_dmg(args.app, args.output) if args.command == 'build' else verify_dmg(args.dmg)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Mac packaging failed: {error}\n')
    print(f'Verified Herbert {info["CFBundleShortVersionString"]} ({info["CFBundleVersion"]}): '
          'arm64 + x86_64, macOS 14+, sandboxed, 50 originals + 1,769 community problems.')


if __name__ == '__main__':
    main()
