#!/usr/bin/env python3
"""Import verified manual screenshots exported by xcresulttool, without altering pixels."""
import json
import re
import shutil
import sys
import struct
from pathlib import Path

source = Path(sys.argv[1])
assets = Path(__file__).resolve().parents[1] / 'Reqeast/Assets.xcassets/UserManual'
locales = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'pt-BR', 'es', 'ko', 'de']
names = ['editor', 'rules', 'runner', 'data', 'results', 'inspect', 'preview', 'files', 'comparison']
expected = {f'manual-{locale}-{name}' for locale in locales for name in names}
found = {}
for test in json.loads((source / 'manifest.json').read_text()):
    for attachment in test['attachments']:
        match = re.match(r'(manual-.+?)_\d+_', attachment['suggestedHumanReadableName'])
        if match and match[1] in expected:
            found[match[1]] = source / attachment['exportedFileName']
if expected - found.keys():
    raise SystemExit(f'Missing screenshots: {sorted(expected - found.keys())}')
for name, path in found.items():
    data = path.read_bytes()
    width, height = struct.unpack('>II', data[16:24])
    if width < 1800 or height < 1200 or not 1.1 < width / height < 2:
        raise SystemExit(f'Invalid or clipped app window: {name} ({width}x{height})')
assets.mkdir(parents=True, exist_ok=True)
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
for name, image in found.items():
    destination = assets / f'{name}.imageset'
    destination.mkdir(exist_ok=True)
    shutil.copyfile(image, destination / 'screenshot.png')
    contents = {'images': [{'filename': 'screenshot.png', 'idiom': 'universal'}],
                'info': {'author': 'xcode', 'version': 1}}
    (destination / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n')
print(f'Imported {len(found)} original app screenshots.')
