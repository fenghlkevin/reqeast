#!/usr/bin/env python3
"""Validate the release archive before any local IDE deployment."""
import hashlib
import io
import stat
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent
package = root / 'dist/rheq-controller-bridge-0.1.1.zip'
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    for item in archive.infolist():
        path = Path(item.filename)
        assert not path.is_absolute() and '..' not in path.parts
        assert not stat.S_ISLNK(item.external_attr >> 16)
    assert archive.namelist() == ['rheq-controller-bridge/lib/rheq-controller-bridge.jar']
    jar_bytes = archive.read(archive.namelist()[0])
with zipfile.ZipFile(io.BytesIO(jar_bytes)) as jar:
    assert jar.testzip() is None
    plugin = ET.fromstring(jar.read('META-INF/plugin.xml'))
    assert plugin.findtext('id') == 'com.rheq.idea.controller'
    assert plugin.findtext('version') == '0.1.1'
    assert plugin.find('idea-version').attrib == {'since-build': '262', 'until-build': '262.*'}
    assert {'com.intellij.modules.platform', 'com.intellij.java'} <= {d.text for d in plugin.findall('depends')}
    assert len(plugin.findall('.//action')) == 3
    assert plugin.find('.//codeInsight.lineMarkerProvider').attrib == {'language': 'JAVA', 'implementationClass': 'com.rheq.idea.ControllerImportLineMarkerProvider'}
    for name in ['rheqImport.svg', 'rheqImport_dark.svg']:
        svg = ET.fromstring(jar.read('icons/' + name))
        assert svg.attrib['width'] == svg.attrib['height'] == '16'
    assert not any(name.startswith('com/intellij/') or 'BridgeTestStarter' in name for name in jar.namelist())
    for icon in ['pluginIcon.svg', 'pluginIcon_dark.svg']:
        svg = ET.fromstring(jar.read('META-INF/' + icon))
        assert svg.attrib['width'] == svg.attrib['height'] == '40'
        assert b'fill="#fff"' in jar.read('META-INF/' + icon)
    english = jar.read('messages/BridgeBundle.properties').decode()
    keys = {line.split('=', 1)[0] for line in english.splitlines() if '=' in line}
    for locale in ['zh_CN', 'zh_TW', 'ja', 'fr', 'pt_BR', 'es', 'ko', 'de']:
        values = jar.read(f'messages/BridgeBundle_{locale}.properties').decode()
        assert {line.split('=', 1)[0] for line in values.splitlines() if '=' in line} == keys
print('Validated ID, version, IDEA compatibility, action declarations, icons, locales and archive paths.')
print('SHA-256:', hashlib.sha256(package.read_bytes()).hexdigest())
