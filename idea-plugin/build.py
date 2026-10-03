#!/usr/bin/env python3
"""Compile against an installed IDEA SDK without bundling its libraries."""
import argparse
import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--ide", type=Path, default=Path("/Applications/IntelliJ IDEA.app"))
parser.add_argument("--test", action="store_true")
args = parser.parse_args()
contents = args.ide / "Contents"
info = json.loads((contents / "Resources/product-info.json").read_text())
if not info["buildNumber"].startswith("262."):
    raise SystemExit("This package requires IDEA build 262.x")
out = ROOT / "build" / ("test" if args.test else "release")
shutil.rmtree(out, ignore_errors=True)
classes = out / "classes"
classes.mkdir(parents=True)
sources = sorted((ROOT / "src/main/java").rglob("*.java"))
if args.test:
    sources += sorted((ROOT / "tests").glob("*.java"))
classpath = ":".join(str(p) for directory in [contents / "lib", contents / "plugins/java/lib"] for p in sorted(directory.rglob("*.jar")))
subprocess.run([str(contents / "jbr/Contents/Home/bin/javac"), "--release", "25", "-encoding", "UTF-8", "-cp", classpath,
                "-d", str(classes)] + [str(p) for p in sources], check=True)
plugin = out / "rheq-controller-bridge"
jar = plugin / "lib/rheq-controller-bridge.jar"
jar.parent.mkdir(parents=True)
with zipfile.ZipFile(jar, "w", zipfile.ZIP_DEFLATED) as archive:
    for folder in [classes, ROOT / "src/main/resources"]:
        for path in sorted(folder.rglob("*")):
            if not path.is_file(): continue
            name = path.relative_to(folder).as_posix()
            data = path.read_bytes()
            if args.test and name == "META-INF/plugin.xml":
                data = data.replace(b"</idea-plugin>", b'<extensions defaultExtensionNs="com.intellij"><appStarter id="rheq-bridge-test" implementation="com.rheq.idea.BridgeTestStarter"/></extensions></idea-plugin>')
            archive.writestr(name, data)
if args.test:
    print(plugin)
else:
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    package = dist / "rheq-controller-bridge-0.1.1.zip"
    with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(jar, jar.relative_to(out))
    digest = hashlib.sha256(package.read_bytes()).hexdigest()
    package.with_suffix(".zip.sha256").write_text(digest + "  " + package.name + "\n")
    print(package)
    print("SHA-256:", digest)
