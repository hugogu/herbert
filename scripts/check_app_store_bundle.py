#!/usr/bin/env python3
"""Audit the App Store app's identity and its 50 original puzzle resources."""
import argparse
import json
from pathlib import Path
import plistlib


def check_bundle(app):
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Pass a built .app directory, not the source tree.')
    if app.name != 'Herbot Bot.app':
        raise ValueError('Expected the App Store product filename Herbot Bot.app.')
    mac = (app / 'Contents').is_dir()
    info = app / ('Contents/Info.plist' if mac else 'Info.plist')
    metadata = plistlib.loads(info.read_bytes())
    if not isinstance(metadata, dict):
        raise ValueError('Expected an Info.plist dictionary.')
    for key, value in {'CFBundleIdentifier': 'info.hugogu.Herbert',
                       'CFBundleDisplayName': 'Herbot Bot', 'CFBundleName': 'Herbot Bot',
                       'CFBundleExecutable': 'Herbot Bot'}.items():
        if metadata.get(key) != value:
            raise ValueError(f'Expected {key} = {value!r}, got {metadata.get(key)!r}.')
    executable = app / ('Contents/MacOS' if mac else '') / metadata['CFBundleExecutable']
    if not executable.is_file():
        raise ValueError('Missing the Herbot Bot executable declared by Info.plist.')
    originals = []
    for path in app.rglob('*'):
        if 'HerbertCommunity' in path.name or path.name == 'problems.json' or path.name.endswith('-solutions.json'):
            raise ValueError(f'Non-store resource in app: {path.relative_to(app)}')
        if path.suffix == '.json':
            data = json.loads(path.read_text())
            if path.name == 'original-problems.json':
                originals.append(data)
            elif isinstance(data, list) and any(isinstance(item, dict) and 'rows' in item for item in data):
                raise ValueError(f'Unexpected puzzle archive: {path.relative_to(app)}')
    if len(originals) != 1:
        raise ValueError('Expected exactly one original-problems.json in the app.')
    catalog = originals[0]
    retained_ids = [10001, 10006, 10012, 10074, 10075, 10076, 10051, 10052, 10027] + list(range(10077, 10118))
    if [item.get('id') for item in catalog] != retained_ids:
        raise ValueError('Expected the 50 retained curriculum IDs only.')
    if [item['lesson']['order'] for item in catalog] != list(range(1, 51)):
        raise ValueError('Expected continuous L01–L50 display numbers.')
    if any(not item.get('lesson') or item.get('sourceURL') for item in catalog):
        raise ValueError('Every puzzle must be an original curriculum lesson.')
    canonical = Path(__file__).resolve().parents[1] / 'Sources/HerbertCore/Resources/original-problems.json'
    if catalog != json.loads(canonical.read_text()):
        raise ValueError('Bundled originals differ from the verified curriculum.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    try:
        check_bundle(args.app)
    except (ValueError, OSError) as error:
        parser.exit(1, f'App Store bundle check failed: {error}\n')
    print('App Store bundle check passed: Herbot Bot identity, unchanged Bundle ID, '
          '50 originals, no community archive or reference solutions.')


if __name__ == '__main__':
    main()
