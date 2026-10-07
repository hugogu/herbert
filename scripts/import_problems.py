#!/usr/bin/env python3
"""Archive public Herbert boards, preserving provenance. No login or submissions."""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import http.client
from html import unescape
import json
from pathlib import Path
import re
import time
import urllib.request

BASE = 'http://herbert.tealang.info/'
ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.build' / 'original-cache'


def fetch(path, action=None):
    key = hashlib.sha256((path + str(action)).encode()).hexdigest()
    cached = CACHE / key
    if cached.exists():
        return cached.read_text()
    for attempt in range(4):
        try:
            request = urllib.request.Request(
                BASE + path, data=b'action=problem' if action else None,
                headers={'User-Agent': 'HerbertOfflinePort/1.0 (public puzzle archival)', 'Connection': 'close'})
            with urllib.request.urlopen(request, timeout=12) as response:
                data = response.read().decode('utf-8')
            if action:
                parse_board(data)
            elif '</html>' not in data.lower():
                raise ValueError('Incomplete HTML')
            cached.write_text(data)
            return data
        except (OSError, ValueError, http.client.HTTPException) as error:
            if attempt == 3:
                raise RuntimeError(f'{path}: {error}') from error
            time.sleep(0.5 * (attempt + 1))


def parse_listing(source):
    result = []
    for row in re.findall(r'<tr[^>]*class=[^>]*problem[^>]*>(.*?)</tr>', source, re.S):
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.S)
        if len(cells) < 6:
            raise ValueError('Malformed listing row')
        clean = lambda s: unescape(re.sub('<[^>]*>', '', s)).strip()
        identifier = int(clean(cells[0]))
        if identifier == 0:  # Original "Null" placeholder is not a playable problem.
            continue
        result.append({'id': identifier, 'title': clean(cells[1]), 'author': clean(cells[2]),
                       'byteLimit': int(clean(cells[3])),
                       'originalBest': int(clean(cells[4])) if clean(cells[4]).isdigit() else None,
                       'sourceURL': BASE + f'problem.php?id={identifier}'})
    return result


def parse_board(source):
    parts = source.strip().splitlines()
    if len(parts) != 2 or len(parts[0]) != 625 or not parts[1].isdigit():
        raise ValueError('Expected 625 cells and byte limit')
    board, limit = parts[0], int(parts[1])
    if board.count('u') != 1 or not set(board) <= set('.*oxu0123456789abcdef'):
        raise ValueError(f'Invalid board symbols/start: {set(board)}')
    if 'o' not in board:
        raise ValueError('No targets')
    return [board[i:i + 25] for i in range(0, 625, 25)], limit


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--max-id', type=int)
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    first = fetch('problems.php')
    pages = max([1] + [int(x) for x in re.findall(r'problems.php\?page=(\d+)', first)])
    listings, failed = [], []
    def listing(page):
        return parse_listing(first if page == 1 else fetch(f'problems.php?page={page}'))
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = {pool.submit(listing, page): page for page in range(1, pages + 1)}
        for job in concurrent.futures.as_completed(jobs):
            try:
                listings.extend(job.result())
            except Exception as error:
                failed.append(str(error))
    listings.sort(key=lambda item: item['id'])
    if args.max_id is not None:
        listings = [item for item in listings if item['id'] <= args.max_id]
    print(f'Found {len(listings)} playable listings across {pages} pages.', flush=True)
    imported = []
    def board(problem):
        raw = fetch(f"problem.php?id={problem['id']}", action=True)
        rows, limit = parse_board(raw)
        if limit != problem['byteLimit']:
            raise ValueError(f"#{problem['id']}: listing/data byte limits disagree")
        return {**problem, 'rows': rows, 'sourceSHA256': hashlib.sha256(raw.encode()).hexdigest()}
    out = ROOT / 'Sources/HerbertCore/Resources/problems.json'
    def save():
        out.write_text(json.dumps(sorted(imported, key=lambda item: item['id']), ensure_ascii=False, separators=(',', ':')) + '\n')
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = {pool.submit(board, item): item['id'] for item in listings}
        for job in concurrent.futures.as_completed(jobs):
            try:
                imported.append(job.result())
            except Exception as error:
                failed.append(str(error))
                print(f'FAILED: {error}', flush=True)
            if len(imported) % 25 == 0:
                save()
                print(f'Imported {len(imported)}/{len(listings)}', flush=True)
    save()
    ids = {item['id'] for item in imported}
    manifest = {'source': BASE + 'problems.php', 'fetchedAt': datetime.now(timezone.utc).isoformat(),
                'listingCount': len(listings), 'importedCount': len(imported), 'pages': pages,
                'excludedPlaceholderIDs': [0], 'missingIDs': [item['id'] for item in listings if item['id'] not in ids],
                'errors': failed, 'symbols': sorted(set(''.join(''.join(item['rows']) for item in imported))),
                'license': 'Original website does not specify a redistribution license. Original authors retain their rights.'}
    (ROOT / 'docs/problem-import-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(manifest, ensure_ascii=False), flush=True)
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
