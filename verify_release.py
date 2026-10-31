"""Checks a built release zip before it ships. Exits 1 and lists every problem it finds.

    python verify_release.py dist/Spellwork-<version>.zip <version> [forbidden word ...]

Reads the zip's raw central directory, not zipfile's view of it: on Windows zipfile turns
backslashes into slashes when it reads, so it would hide the one defect it most needs to catch.
"""
import json
import struct
import sys
import zipfile

zip_path, version = sys.argv[1:3]
forbidden = [w.lower().encode() for w in sys.argv[3:] if w]
problems = []

raw = open(zip_path, 'rb').read()
raw_names = []
pos = 0
while True:
    pos = raw.find(b'PK\x01\x02', pos)
    if pos < 0:
        break
    name_len = struct.unpack('<H', raw[pos + 28:pos + 30])[0]
    raw_names.append(raw[pos + 46:pos + 46 + name_len])
    pos += 46

# The zip spec requires '/' separators. Tools that follow it unpack a '\' name as one flat file.
for n in raw_names:
    if b'\\' in n:
        problems.append(f'backslash in entry name: {n!r}')

z = zipfile.ZipFile(zip_path)
names = [n for n in z.namelist() if not n.endswith('/')]
if len(z.namelist()) != len(raw_names):
    problems.append(f'zipfile sees {len(z.namelist())} entries, the central directory has {len(raw_names)}')

external = 'SKSE/Plugins/SkyrimNet/external/'
layer_id = 'whyregister.spellwork'
layer = external + layer_id + '/'
expected = [
    'Spellwork.esp',
    'Scripts/SW_Main.pex',
    'Scripts/SW_PlayerAlias.pex',
    'Scripts/SW_SoulStudyEffect.pex',
    'Scripts/SW_UI.pex',
    'Scripts/SW_Ward.pex',
    'Scripts/SW_PracticeWardEffect.pex',
    'Scripts/SW_WardDummy.pex',
    'Magelight/Spellwork/manifest.json',
    'Magelight/Spellwork/views/study/index.html',
    layer + 'manifest.json',
    layer + 'triggers/sw_studied.yaml',
    layer + 'triggers/sw_ward_conjured.yaml',
    layer + 'triggers/sw_ward_expired.yaml',
    layer + 'triggers/sw_ward_dismissed.yaml',
]
for e in expected:
    if e not in names:
        problems.append(f'missing: {e}')

# Magelight installs its own Magelight.pex; a copy here would overwrite it (with whatever version
# imports/ was taken from).
for n in names:
    if n.lower() in ('scripts/magelight.pex', 'source/scripts/magelight.psc'):
        problems.append(f'ships a Magelight file it must not: {n}')

# Magelight refuses a manifest whose modId is not its folder's name, so only ours, matching.
ml = 'Magelight/'
ml_dirs = sorted({n[len(ml):].split('/')[0] for n in names if n.startswith(ml)})
if ml_dirs != ['Spellwork']:
    problems.append(f'folders under Magelight/: {ml_dirs}, expected only [\'Spellwork\']')
if ml + 'Spellwork/manifest.json' in names:
    try:
        mlm = json.loads(z.read(ml + 'Spellwork/manifest.json').decode('utf-8'))
        if mlm.get('modId', 'Spellwork') != 'Spellwork':
            problems.append(f"Magelight manifest modId {mlm.get('modId')!r} != folder name 'Spellwork'")
        if mlm.get('version') != version:
            problems.append(f"Magelight manifest version {mlm.get('version')!r} != release version {version!r}")
        for view, v in mlm.get('views', {}).items():
            if ml + 'Spellwork/' + v.get('path', '') not in names:
                problems.append(f"Magelight view {view!r} names a page the zip lacks: {v.get('path')!r}")
    except ValueError as err:
        problems.append(f'Magelight manifest.json is not valid JSON: {err}')

# SkyrimNet rejects any folder under external/ that has no manifest.json, and a store folder must be
# named for its manifest id. So: exactly one layer folder, ours, with a manifest whose id matches.
layer_dirs = sorted({n[len(external):].split('/')[0] for n in names if n.startswith(external)})
if layer_dirs != [layer_id]:
    problems.append(f'layer folders under external/: {layer_dirs}, expected only [{layer_id!r}]')
if layer + 'manifest.json' in names:
    try:
        manifest = json.loads(z.read(layer + 'manifest.json').decode('utf-8'))
        if manifest.get('id') != layer_id:
            problems.append(f"layer manifest id {manifest.get('id')!r} != folder name {layer_id!r}")
        if manifest.get('version') != version:
            problems.append(f"layer manifest version {manifest.get('version')!r} != release version {version!r}")
    except ValueError as err:
        problems.append(f'layer manifest.json is not valid JSON: {err}')
# A trigger's name is its identity and must match its file name, or SkyrimNet skips it.
for n in names:
    if n.startswith(layer + 'triggers/') and n.endswith('.yaml'):
        stem = n.split('/')[-1].split('.')[0]
        lines = [l for l in z.read(n).decode('utf-8').splitlines() if l.startswith('name:')]
        if not lines or lines[0].split(':', 1)[1].strip().strip('"') .lower() != stem.lower():
            problems.append(f'trigger {n}: name does not match the file name {stem!r}')

# Only Spellwork's own files: nothing of another mod's, and in SKSE/ only our layer.
for n in names:
    top = n.split('/')[0]
    if top not in ('Spellwork.esp', 'Spellwork-LICENSE.txt', 'Scripts', 'Source', 'Magelight', 'SKSE'):
        problems.append(f'unexpected file: {n}')
    if top == 'SKSE' and not n.startswith(layer):
        problems.append(f'unexpected file under SKSE/: {n}')
    if n.startswith(('Scripts/', 'Source/Scripts/')) and not n.split('/')[-1].startswith('SW_'):
        problems.append(f'script that is not Spellwork\'s: {n}')

# Mod-manager bookkeeping that slipped into the stage would ship as junk.
for n in names:
    if '__folder_managed_by_vortex' in n or n.lower().endswith(('.tmp', '.bak')):
        problems.append(f'junk file: {n}')

for n in names:
    data = z.read(n).lower()
    for w in forbidden:
        if w in data or w in n.lower().encode():
            problems.append(f'{n} contains {w.decode()!r}')

if problems:
    print(f'release check FAILED for {zip_path}:')
    for p in problems:
        print('  - ' + p)
    sys.exit(1)
print(f'release check: {len(names)} files, Spellwork {version}, 0 problems')
