#!/usr/bin/env python3
"""Run actual PSI in an isolated, headless IDEA process. Never drive input devices."""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IDE = Path('/Applications/IntelliJ IDEA.app')
contents = IDE / 'Contents'
launch = json.loads((contents / 'Resources/product-info.json').read_text())['launch'][0]
subprocess.run(['python3', str(ROOT / 'build.py'), '--test'], check=True)
root = Path(tempfile.mkdtemp(prefix='rheq-idea-test-'))
fixture = root / 'project'
(fixture / 'src/demo').mkdir(parents=True)
(fixture / '.idea').mkdir()
shutil.copyfile(ROOT / 'tests/DemoController.java.fixture', fixture / 'src/demo/DemoController.java')
(fixture / '.idea/modules.xml').write_text('<project version="4"><component name="ProjectModuleManager"><modules><module fileurl="file://$PROJECT_DIR$/fixture.iml" filepath="$PROJECT_DIR$/fixture.iml"/></modules></component></project>')
(fixture / 'fixture.iml').write_text('<module type="JAVA_MODULE" version="4"><component name="NewModuleRootManager"><content url="file://$MODULE_DIR$"><sourceFolder url="file://$MODULE_DIR$/src" isTestSource="false"/></content><orderEntry type="sourceFolder" forTests="false"/></component></module>')
annotations = {
    'org.springframework.web.bind.annotation.RestController': '',
    'org.springframework.web.bind.annotation.RequestMapping': 'String[] value() default {}; String[] path() default {}; RequestMethod[] method() default {}; String[] params() default {}; String[] headers() default {};',
    'org.springframework.web.bind.annotation.GetMapping': 'String[] value() default {}; String[] path() default {}; String[] params() default {}; String[] headers() default {};',
    'org.springframework.web.bind.annotation.PostMapping': 'String[] value() default {}; String[] path() default {}; String[] params() default {}; String[] headers() default {};',
    'org.springframework.web.bind.annotation.RequestParam': 'String value() default ""; String name() default ""; String defaultValue() default ""; boolean required() default true;',
    'org.springframework.web.bind.annotation.PathVariable': 'String value() default ""; String name() default ""; boolean required() default true;',
    'org.springframework.web.bind.annotation.RequestBody': 'boolean required() default true;',
    'io.swagger.v3.oas.annotations.Operation': 'String summary() default "";',
    'jakarta.validation.constraints.NotBlank': '',
    'jakarta.validation.constraints.Min': 'long value();',
}
for qualified, body in annotations.items():
    package, name = qualified.rsplit('.', 1)
    file = fixture / 'src' / (qualified.replace('.', '/') + '.java')
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text('package ' + package + '; public @interface ' + name + ' {' + body + '}')
(fixture / 'src/org/springframework/web/bind/annotation/RequestMethod.java').write_text('package org.springframework.web.bind.annotation; public enum RequestMethod { GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS }')
plugins = root / 'plugins'  
plugins.mkdir()
shutil.copytree(ROOT / 'build/test/rheq-controller-bridge', plugins / 'rheq-controller-bridge')
jvm = [arg.replace('$APP_PACKAGE', str(IDE)) for arg in launch['additionalJvmArguments']
       if not arg.startswith('-Didea.paths.selector=') and not arg.startswith('-Dsplash=')]
args = [str(contents / 'jbr/Contents/Home/bin/java'), '-Xmx1536m'] + jvm + [
    '-Djava.awt.headless=true', '-Didea.home.path=' + str(contents), '-Didea.config.path=' + str(root / 'config'),
    '-Didea.system.path=' + str(root / 'system'), '-Didea.plugins.path=' + str(plugins), '-Didea.log.path=' + str(root / 'log'),
    '-Didea.platform.prefix=Idea', '-Didea.is.internal=true', '-Didea.trust.all.projects=true',
    '-Didea.initially.ask.config=false', '-Didea.auto.reload.plugins=false', '-cp',
    ':'.join(str(contents / 'lib' / name) for name in launch['bootClassPathJarNames']),
    'com.intellij.idea.Main', 'rheq-bridge-test', str(fixture / 'src/demo/DemoController.java'), str(root / 'export.rheqapi'), str(fixture)]
print('Isolated test directory:', root, flush=True)
with (root / 'stdout.log').open('w') as output:
    result = subprocess.run(args, stdout=output, stderr=subprocess.STDOUT, timeout=120)
print((root / 'stdout.log').read_text()[-7000:])
if result.returncode:
    raise SystemExit(result.returncode)
export = json.loads((root / 'export.rheqapi').read_text())
assert set(export['paths']) == {'/orders', '/orders/{id}'}
get = export['paths']['/orders/{id}']['get']
assert get['summary'] == 'Get order'
assert any(p['name'] == 'id' and p['in'] == 'path' and p['required'] for p in get['parameters'])
assert any(p['name'] == 'limit' and p['in'] == 'query' and p['schema']['example'] == 10 for p in get['parameters'])
body = export['paths']['/orders']['post']['requestBody']['content']['application/json']['schema']
assert body['properties']['quantity']['type'] == 'integer'
assert body['properties']['tags']['type'] == 'array'
assert 'name' in body['required']
assert body['example']['quantity'] == 1
assert body['example']['tags'] == ['example']
shutil.copyfile(root / 'export.rheqapi', '/tmp/rheq-idea-psi-export.rheqapi')
print('PSI integration passed: controller/method scopes, paths, parameters, DTO and validation.')
