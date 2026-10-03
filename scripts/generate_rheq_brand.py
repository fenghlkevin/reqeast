#!/usr/bin/env python3
"""Render original RHEQ geometry at native icon sizes. No upstream artwork is used."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTLINES = [
    [(8, 8), (58, 8), (58, 26), (26, 26), (26, 66), (8, 66)],
    [(58, 26), (80, 26), (94, 40), (94, 78), (76, 78), (76, 46), (58, 46)],
    [(40, 66), (56, 66), (90, 100), (64, 100), (40, 76)],
]


def mark(size=1024, foreground='#F0EFEB', background=(0, 0, 0, 0), inset=0.18):
    scale = 4
    image = Image.new('RGBA', (size * scale, size * scale), background)
    draw = ImageDraw.Draw(image)
    width = size * scale * (1 - 2 * inset)
    origin = size * scale * inset
    for outline in OUTLINES:
        draw.polygon([(origin + x / 100 * width, origin + y / 100 * width) for x, y in outline], fill=foreground)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def color_asset(name, light, dark):
    def entry(value, appearance=None):
        value = value.lstrip('#')
        result = {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {
            'red': f'{int(value[:2], 16) / 255:.6f}', 'green': f'{int(value[2:4], 16) / 255:.6f}',
            'blue': f'{int(value[4:], 16) / 255:.6f}', 'alpha': '1.000000'}}}
        if appearance: result['appearances'] = [{'appearance': 'luminosity', 'value': appearance}]
        return result
    path = ROOT / f'Reqeast/Assets.xcassets/{name}.colorset'
    path.mkdir(exist_ok=True)
    (path / 'Contents.json').write_text(json.dumps({'colors': [entry(light), entry(dark, 'dark')],
                                                 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')


def main():
    color_asset('AccentColor', '#315FF4', '#426BEA')
    color_asset('MethodBlue', '#3157B7', '#95ACFF')
    color_asset('MethodAmber', '#946020', '#DCA766')
    color_asset('MethodDanger', '#B33B46', '#E9979D')
    color_asset('MethodMuted', '#5E626B', '#A7ABB4')
    color_asset('WorkspaceBackground', '#F8F7F4', '#191A1D')
    color_asset('SidebarBackground', '#F0EFEB', '#202125')
    color_asset('PanelBackground', '#F5F4F0', '#222327')
    mark(foreground='#17181B', inset=0.02).save(ROOT / 'assets/logo.png')
    mark(foreground='#17181B', inset=0.02).save(ROOT / 'Reqeast/Assets.xcassets/AppLogo.imageset/logo.png')
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 108"><g fill="#17181B">'
    svg += ''.join('<polygon points="' + ' '.join(f'{x},{y}' for x, y in p) + '"/>' for p in OUTLINES)
    svg += '</g></svg>\n'
    (ROOT / 'assets/rheq-mark.svg').write_text(svg)
    icon_dir = ROOT / 'Reqeast/AppIcon.icon'
    for old in (icon_dir / 'Assets').glob('*.png'): old.unlink()
    mark(foreground='#17181B', inset=0.16).save(icon_dir / 'Assets/RHEQMark.png')
    config = json.loads((icon_dir / 'icon.json').read_text())
    config['fill-specializations'] = [{'value': {'solid': 'srgb:1.00000,1.00000,1.00000,1.00000'}}]
    group = config['groups'][0]
    group['shadow'] = {'kind': 'neutral', 'opacity': 0.0}
    group['translucency'] = {'enabled': False, 'value': 0.0}
    layer = group['layers'][0]
    layer.update({'image-name': 'RHEQMark.png', 'name': 'RHEQ Mark',
                  'position': {'scale': 1.0, 'translation-in-points': [0, 0]}})
    layer['blend-mode-specializations'] = [{'value': 'normal'}]
    layer['glass-specializations'] = [{'value': False}]
    layer['fill-specializations'] = [{'value': {'solid': 'srgb:0.09020,0.09412,0.10588,1.00000'}}]
    (icon_dir / 'icon.json').write_text(json.dumps(config, indent=2) + '\n')
    # Finder document icons use the same original geometry.
    docs = ROOT / 'Reqeast/Assets.xcassets/DocumentTypeIcon.appiconset'
    contents = json.loads((docs / 'Contents.json').read_text())
    for item in contents['images']:
        if 'filename' not in item: continue
        size = int(item['size'].split('x')[0]) * int(item.get('scale', '1x')[:-1])
        mark(size, foreground='#17181B', background='#FFFFFF').save(docs / item['filename'])
    mark(foreground='#17181B', background='#FFFFFF').save(ROOT / 'assets/rheq-icon.png')
    print('Generated original logo, modern icon, document icons, and adaptive surface colors.')


if __name__ == '__main__':
    main()
