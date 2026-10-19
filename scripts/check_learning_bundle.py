#!/usr/bin/env python3
"""Audit the local learning product independently from its marketing category."""
import argparse
from pathlib import Path
import plistlib
from check_app_store_bundle import check_bundle


def check_learning(app):
    check_bundle(app)
    plist = app / 'Contents/Info.plist' if (app / 'Contents').exists() else app / 'Info.plist'
    info = plistlib.loads(plist.read_bytes())
    if info.get('CFBundleIdentifier') != 'info.hugogu.HerbertLearning':
        raise ValueError('Expected a separate learning app identity.')
    if info.get('HerbertLeaderboardURL'):
        raise ValueError('Learning app must not configure a leaderboard endpoint.')
    executable = app / 'Contents/MacOS' / info['CFBundleExecutable'] if (app / 'Contents').exists() else app / info['CFBundleExecutable']
    data = executable.read_bytes()
    for marker in [b'HerbertCloud', b'HerbertBattlefield', b'ASAuthorizationAppleIDProvider', b'GKLocalPlayer']:
        if marker in data:
            raise ValueError(f'Online component in local learning executable: {marker.decode()}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    check_learning(args.app)
    print('Local learning audit passed: originals only; no cloud, Battlefield or Game Center code.')
