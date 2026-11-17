#!/usr/bin/env python3
"""Build the current-version download package using Python's standard library."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
dest = root / 'outputs'
dest.mkdir(exist_ok=True)
archive = dest / 'bambu-p1s-silicone-wiper-v0.1.0.zip'
files = [root / n for n in ('README.md', 'NOTICE.md', 'LICENSE', 'LICENSE-MIT')]
files += sorted((root / 'latest').glob('*'))
files += sorted((root / 'docs').glob('*.md'))
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for file in files:
        bundle.write(file, file.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert len([n for n in bundle.namelist() if n.endswith('.gcode')]) == 4
checksums = []
for file in [archive] + sorted((root / 'latest').glob('*')):
    checksums.append(f'{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}')
(dest / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n', encoding='utf-8')
print(f'Created {archive.name}; four current templates, docs and licenses.')
