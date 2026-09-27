#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
npm run check
npm test
python3 - <<'PY'
from pathlib import Path
import re
import xml.etree.ElementTree as ET
root = ET.parse('components/App.xml').getroot()
ids = [e.attrib['id'] for e in root.iter() if 'id' in e.attrib]
assert len(ids) == len(set(ids)), 'Duplicate SceneGraph ids'
source = Path('components/App.brs').read_text()
assert set(re.findall(r'findNode\("([^"]+)"\)', source)) <= set(ids)
lookup = re.search(r'for each id in \[(.*?)\]', source, re.S)
assert lookup, 'Missing scene lookup map'
assert set(re.findall(r'"([^"]+)"', lookup.group(1))) <= set(ids), 'Scene lookup references missing node'
assert not Path('components/Qa.brs').exists(), 'QA hooks must never ship'
assert '30nama-test' not in source, 'QA registry must never ship'
assert 'm.registry.Write("helper_token"' not in source, 'Pairing credential hook must never ship'
for filename in Path('components').glob('*.brs'):
    text = filename.read_text()
    assert 'suppressCaptions' not in text, 'Experimental caption suppression must never ship'
    assert 'qaRun' not in text and 'qaScenario' not in text, 'QA launch hook must never ship'

for filename in Path('components').glob('*.xml'):
    doc = ET.parse(filename)
    for script in doc.iter('script'):
        assert Path(script.attrib['uri'].removeprefix('pkg:/')).is_file()
manifest = dict(line.split('=',1) for line in Path('manifest').read_text().splitlines() if '=' in line and not line.startswith('#'))
for name in ['mm_icon_focus_fhd','mm_icon_focus_hd','splash_screen_hd','splash_screen_sd']:
    path=Path(manifest[name].removeprefix('pkg:/'))
    assert path.is_file(), 'Manifest artwork missing'
    assert path.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', 'Artwork is not PNG'
print('SceneGraph XML, node references and manifest artwork checks passed')
PY
