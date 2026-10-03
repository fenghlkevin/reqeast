#!/usr/bin/env python3
"""Merge locally authored manual translations; never send content to a service."""
import json
from pathlib import Path

FIXUPS = json.loads(Path(__file__).with_name('workflow_manual_translations.json').read_text())
LANGUAGES = {'en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'pt-BR', 'es', 'ko', 'de'}


def main():
    path = Path(__file__).resolve().parents[1] / 'Reqeast/Localizable.xcstrings'
    catalog = json.loads(path.read_text())
    for key, translations in FIXUPS.items():
        values = {'en': key, **translations}
        assert set(values) == LANGUAGES, key
        entry = catalog['strings'].setdefault(key, {})
        localized = entry.setdefault('localizations', {})
        for language, value in values.items():
            localized[language] = {'stringUnit': {'state': 'translated', 'value': value}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, separators=(',', ' : ')) + '\n')


if __name__ == '__main__':
    main()
