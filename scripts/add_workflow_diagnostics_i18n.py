#!/usr/bin/env python3
"""Merge reviewed local workflow and diagnostic translations."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
FIXUPS = json.loads(Path(__file__).with_name('rheq_workflow_diagnostics_translations.json').read_text())
LANGUAGES = {'en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'pt-BR', 'es', 'ko', 'de'}
path = ROOT / 'Reqeast/Localizable.xcstrings'
catalog = json.loads(path.read_text())
for key, translations in FIXUPS.items():
    values = {'en': key, **translations}
    assert set(values) == LANGUAGES
    entry = catalog['strings'].setdefault(key, {}).setdefault('localizations', {})
    entry.update({locale: {'stringUnit': {'state': 'translated', 'value': text}} for locale, text in values.items()})
path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, separators=(',', ' : ')) + '\n')
