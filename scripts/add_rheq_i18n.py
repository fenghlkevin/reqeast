#!/usr/bin/env python3
"""Merge RHEQ branding and appearance translations without changing technical identifiers."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'pt-BR', 'es', 'ko', 'de']
FIXUPS = {
    'Appearance': ['Appearance', '外观', '外觀', '外観', 'Apparence', 'Aparência', 'Apariencia', '모양', 'Darstellung'],
    'Theme': ['Theme', '主题', '主題', 'テーマ', 'Thème', 'Tema', 'Tema', '테마', 'Design'],
    'Follow System': ['Follow System', '跟随系统', '跟隨系統', 'システムに合わせる', 'Suivre le système', 'Seguir o sistema', 'Seguir el sistema', '시스템 설정 따르기', 'Systemeinstellung'],
    'Light': ['Light', '浅色', '淺色', 'ライト', 'Clair', 'Claro', 'Claro', '라이트', 'Hell'],
    'Dark': ['Dark', '深色', '深色', 'ダーク', 'Sombre', 'Escuro', 'Oscuro', '다크', 'Dunkel'],
    'A workspace for your APIs': ['A workspace for your APIs', '你的 API 工作空间', '你的 API 工作空間', 'API のためのワークスペース', 'Un espace pour vos API', 'Um espaço para suas APIs', 'Un espacio para tus API', 'API 작업 공간', 'Ein Arbeitsbereich für Ihre APIs'],
    'Project License': ['Project License', '项目许可证', '專案授權條款', 'プロジェクトのライセンス', 'Licence du projet', 'Licença do projeto', 'Licencia del proyecto', '프로젝트 라이선스', 'Projektlizenz'],
    'Based on Reqeast by Felipe Lima. Licensed under Apache License 2.0.': [
        'Based on Reqeast by Felipe Lima. Licensed under Apache License 2.0.',
        '基于 Felipe Lima 开发的 Reqeast，采用 Apache License 2.0。',
        '以 Felipe Lima 開發的 Reqeast 為基礎，採用 Apache License 2.0。',
        'Felipe Lima による Reqeast を基にしています。Apache License 2.0 に基づきます。',
        'Basé sur Reqeast de Felipe Lima, sous Apache License 2.0.',
        'Baseado no Reqeast de Felipe Lima, sob Apache License 2.0.',
        'Basado en Reqeast de Felipe Lima, bajo Apache License 2.0.',
        'Felipe Lima의 Reqeast를 기반으로 하며 Apache License 2.0을 따릅니다.',
        'Basiert auf Reqeast von Felipe Lima, unter Apache License 2.0.'],
}


def main():
    path = ROOT / 'Reqeast/Localizable.xcstrings'
    catalog = json.loads(path.read_text())
    for key, entry in list(catalog['strings'].items()):
        if 'Reqeast' not in key or key.startswith('Based on Reqeast'): continue
        copy = json.loads(json.dumps(entry))
        for localization in copy.get('localizations', {}).values():
            if 'stringUnit' in localization:
                localization['stringUnit']['value'] = localization['stringUnit']['value'].replace('Reqeast', 'RHEQ')
        copy.setdefault('localizations', {}).setdefault('en', {'stringUnit': {'state': 'translated', 'value': key.replace('Reqeast', 'RHEQ')}})
        catalog['strings'][key.replace('Reqeast', 'RHEQ')] = copy
    for key, values in FIXUPS.items():
        assert len(values) == len(LANGUAGES)
        entry = catalog['strings'].setdefault(key, {})
        entry['localizations'] = {language: {'stringUnit': {'state': 'translated', 'value': value}}
                                  for language, value in zip(LANGUAGES, values)}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, separators=(',', ' : ')) + '\n')
    for name in ['workflow_manual_translations.json', 'app_manual_content.json']:
        p = ROOT / 'scripts' / name
        p.write_text(p.read_text().replace('Reqeast', 'RHEQ'))


if __name__ == '__main__':
    main()
