#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict -r Herbert Sources Tests HerbertUITests scripts/generate_icon.swift \
    scripts/compose_store_screenshots.swift Package.swift
python3 -m unittest discover -s scripts -p 'test_*.py'
swift test
