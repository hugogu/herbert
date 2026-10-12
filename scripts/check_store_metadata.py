#!/usr/bin/env python3
"""Validate App Store listing metadata and screenshots against App Store Connect limits."""
import argparse
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
LOCALIZED = ['name', 'subtitle', 'description', 'keywords', 'promotional_text',
             'support_url', 'marketing_url', 'privacy_url']
CATEGORIES = {
    'BOOKS', 'BUSINESS', 'DEVELOPER_TOOLS', 'EDUCATION', 'ENTERTAINMENT', 'FINANCE', 'FOOD_AND_DRINK',
    'GAMES', 'GRAPHICS_AND_DESIGN', 'HEALTH_AND_FITNESS', 'LIFESTYLE', 'MAGAZINES_AND_NEWSPAPERS', 'MEDICAL',
    'MUSIC', 'NAVIGATION', 'NEWS', 'PHOTO_AND_VIDEO', 'PRODUCTIVITY', 'REFERENCE', 'SHOPPING',
    'SOCIAL_NETWORKING', 'SPORTS', 'STICKERS', 'TRAVEL', 'UTILITIES', 'WEATHER',
}
GAME_SUBCATEGORIES = {
    'GAMES_' + name for name in [
        'ACTION', 'ADVENTURE', 'BOARD', 'CARD', 'CASINO', 'CASUAL', 'DICE', 'EDUCATIONAL', 'FAMILY',
        'MUSIC', 'PUZZLE', 'RACING', 'ROLE_PLAYING', 'SIMULATION', 'SPORTS', 'STRATEGY', 'TRIVIA', 'WORD']
}
MAC_CATEGORIES = {'EDUCATION': 'public.app-category.education', 'GAMES': 'public.app-category.games'}
# Accepted portrait sizes; landscape is the same pair swapped. Mac screenshots are landscape only.
SCREENSHOT_SIZES = {
    'iphone': {(1320, 2868), (1290, 2796), (1260, 2736), (1284, 2778), (1242, 2688)},
    'ipad': {(2064, 2752), (2048, 2732)},
    'mac': {(1280, 800), (1440, 900), (2560, 1600), (2880, 1800)},
}


def read(path):
    return path.read_text(encoding='utf-8').strip()


def store_display_name(project):
    """The Home Screen name must resemble the store name (App Review Guideline 2.3.8)."""
    store = project.read_text().split('store_settings = {', 1)[1]
    return re.search(r"'INFOPLIST_KEY_CFBundleDisplayName': '([^']+)'", store).group(1)


def store_mac_category(project):
    store = project.read_text().split('store_settings = {', 1)[1]
    match = re.search(r"'INFOPLIST_KEY_LSApplicationCategoryType': '([^']+)'", store)
    return match.group(1) if match else None


def png_info(path):
    """Return width, height and whether the PNG can carry transparency."""
    with path.open('rb') as file:
        header = file.read(33)
        if header[:8] != b'\x89PNG\r\n\x1a\n' or header[12:16] != b'IHDR':
            raise ValueError(f'{path}: not a PNG file')
        width, height = struct.unpack('>II', header[16:24])
        color_type = header[25]
        chunks = file.read()
    return width, height, color_type in (4, 6) or b'tRNS' in chunks


def check_keywords(locale, keywords, name_words):
    errors = []
    size = len(keywords.encode('utf-8'))
    if size > 100:
        errors.append(f'{locale}: keywords use {size} of 100 bytes')
    terms = keywords.split(',')
    for term in terms:
        if term != term.strip() or not term:
            errors.append(f'{locale}: keyword "{term}" has surrounding spaces or is empty')
        elif len(term) <= 2:
            errors.append(f'{locale}: keyword "{term}" must be longer than two characters')
        elif term.casefold() in name_words:
            errors.append(f'{locale}: keyword "{term}" repeats the app name')
    if len({term.casefold() for term in terms}) != len(terms):
        errors.append(f'{locale}: keywords contain duplicates')
    return errors


def check_metadata(metadata, project):
    errors = []
    display = store_display_name(project)
    locales = sorted(path.name for path in metadata.iterdir() if path.is_dir() and path.name != 'review_information')
    if 'en-US' not in locales:
        errors.append('en-US metadata is required as the primary language')
    for locale in locales:
        fields = {}
        for field in LOCALIZED:
            path = metadata / locale / f'{field}.txt'
            if not path.is_file() or not read(path):
                errors.append(f'{locale}: missing {field}.txt')
                continue
            fields[field] = read(path)
        name = fields.get('name', '')
        if name and not 2 <= len(name) <= 30:
            errors.append(f'{locale}: name has {len(name)} characters; App Store Connect allows 2-30')
        if name and not name.startswith(display):
            errors.append(f'{locale}: name must start with the device display name "{display}"')
        for field, limit in [('subtitle', 30), ('promotional_text', 170), ('description', 4000)]:
            if len(fields.get(field, '')) > limit:
                errors.append(f'{locale}: {field} has {len(fields[field])} of {limit} characters')
        for field in ['support_url', 'marketing_url', 'privacy_url']:
            if field in fields and not re.fullmatch(r'https://\S+', fields[field]):
                errors.append(f'{locale}: {field} must be one HTTPS URL')
        if 'keywords' in fields:
            name_words = {word.casefold() for word in re.split(r'[\s:：]+', name) if word}
            errors += check_keywords(locale, fields['keywords'], name_words)

    if not read(metadata / 'copyright.txt'):
        errors.append('copyright.txt is empty')
    primary = read(metadata / 'primary_category.txt')
    secondary_path = metadata / 'secondary_category.txt'
    secondary = read(secondary_path) if secondary_path.exists() else ''
    for category in filter(None, [primary, secondary]):
        if category not in CATEGORIES:
            errors.append(f'Unknown App Store category {category}')
    for kind, category in [('primary', primary), ('secondary', secondary)]:
        for position in ['first', 'second']:
            path = metadata / f'{kind}_{position}_sub_category.txt'
            if path.exists() and (category != 'GAMES' or read(path) not in GAME_SUBCATEGORIES):
                errors.append(f'{path.name} needs GAMES as the {kind} category and a GAMES_* value')
    if MAC_CATEGORIES.get(primary) != store_mac_category(project):
        errors.append('The Mac LSApplicationCategoryType must match the primary App Store category')

    review = metadata / 'review_information'
    notes = read(review / 'notes.txt')
    if len(notes.encode('utf-8')) > 4000:
        errors.append(f'Review notes use {len(notes.encode("utf-8"))} of 4000 bytes')
    if not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', read(review / 'email_address.txt')):
        errors.append('Review contact email is invalid')
    return errors, locales


def check_screenshots(screenshots, locales):
    errors = []
    for device, sizes in SCREENSHOT_SIZES.items():
        folder = screenshots / device
        if not folder.exists():
            continue
        names = None
        for locale in sorted(path.name for path in folder.iterdir() if path.is_dir()):
            if locale not in locales:
                errors.append(f'{device}/{locale}: screenshots have no matching metadata locale')
            images = sorted(folder.joinpath(locale).glob('*.png'))
            if not 1 <= len(images) <= 10:
                errors.append(f'{device}/{locale}: {len(images)} screenshots; App Store Connect accepts 1-10')
            if names is None:
                names = [image.name for image in images]
            elif names != [image.name for image in images]:
                errors.append(f'{device}/{locale}: screenshots differ from other locales')
            for image in images:
                width, height, alpha = png_info(image)
                accepted = sizes | ({(h, w) for w, h in sizes} if device != 'mac' else set())
                if (width, height) not in accepted:
                    errors.append(f'{device}/{locale}/{image.name}: {width} × {height} is not an accepted size')
                if alpha:
                    errors.append(f'{device}/{locale}/{image.name}: screenshots cannot contain alpha')
    return errors


def check_store(store, project=ROOT / 'scripts/generate_project.py'):
    errors, locales = check_metadata(store / 'metadata', project)
    return errors + check_screenshots(store / 'screenshots', locales)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('store', type=Path, nargs='?', default=ROOT / 'store')
    args = parser.parse_args()
    errors = check_store(args.store)
    if errors:
        parser.exit(1, 'App Store metadata check failed:\n' + '\n'.join(f'- {error}' for error in errors) + '\n')
    print('App Store metadata check passed.')


if __name__ == '__main__':
    main()
