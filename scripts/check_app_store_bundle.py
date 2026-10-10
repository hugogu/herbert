#!/usr/bin/env python3
"""Fail closed unless a built app contains only the 30 original puzzle resources."""
import argparse
import json
from pathlib import Path


def check_bundle(app):
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Pass a built .app directory, not the source tree.')
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
    retained_ids = [10001, 10006, 10012, 10074, 10075, 10076, 10051, 10052, 10027] + list(range(10077, 10098))
    if [item.get('id') for item in catalog] != retained_ids:
        raise ValueError('Expected the 30 retained curriculum IDs only.')
    if [item['lesson']['order'] for item in catalog] != list(range(1, 31)):
        raise ValueError('Expected continuous L01–L30 display numbers.')
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
        parser.exit(1, f'App Store resource check failed: {error}\n')
    print('App Store resource check passed: 30 originals, no community archive or reference solutions.')


if __name__ == '__main__':
    main()
