#!/usr/bin/env python3
"""Merge reviewed IDEA integration translations without replacing other catalog entries."""
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
catalog = root / 'Reqeast/Localizable.xcstrings'
data = json.loads(catalog.read_text())
rows = json.loads((root / 'scripts/idea_bridge_translations.json').read_text())
langs = ['zh-Hans', 'zh-Hant', 'ja', 'fr', 'pt-BR', 'es', 'ko', 'de']
for key, values in rows.items():
    assert len(values) == len(langs), key
    entry = data['strings'].setdefault(key, {})
    entry['extractionState'] = 'manual'
    localizations = entry.setdefault('localizations', {})
    for lang, value in [('en', key)] + list(zip(langs, values)):
        localizations[lang] = {'stringUnit': {'state': 'translated', 'value': value}}
catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
print(f'{len(rows)} IDEA integration strings merged in 9 languages')
