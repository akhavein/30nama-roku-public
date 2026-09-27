#!/usr/bin/env python3
"""Create a private configured ZIP without changing tracked public source."""
import argparse
import os
from pathlib import Path
import re
import zipfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--key-file', required=True, type=Path)
p.add_argument('--service-origin', default='')
a = p.parse_args()
if a.service_origin:
    u = urlsplit(a.service_origin)
    if u.scheme != 'https' or not u.hostname or u.username or u.password or u.port not in (None,443) or u.path or u.query or u.fragment or not re.fullmatch(r'https://[A-Za-z0-9.-]+', a.service_origin):
        raise SystemExit('Service origin must be a plain HTTPS origin')
key = a.key_file.read_text().strip()
if not re.fullmatch(r'[A-Za-z0-9_+=/.-]{8,256}', key):
    raise SystemExit('Invalid key format; expected one plain-text provider key')
source = ROOT / 'build/30nama-roku.zip'
target = ROOT / 'build/30nama-roku-configured.zip'
with zipfile.ZipFile(source) as original:
    contents = {i.filename: (i, original.read(i)) for i in original.infolist()}
name = 'components/Api.brs'
marker = b'CONFIGURE_PROVIDER_API_KEY'
if contents[name][1].count(marker) != 1:
    raise SystemExit('Expected an unconfigured public build; run npm run package first')
info, data = contents[name]
contents[name] = (info, data.replace(marker, key.encode()))
if a.service_origin:
    name = 'components/Service.brs'
    info, data = contents[name]
    marker = b'return ""'
    if data.count(marker) != 1:
        raise SystemExit('Unexpected service configuration template')
    contents[name] = (info, data.replace(marker, ('return "'+a.service_origin+'"').encode()))
fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
os.fchmod(fd, 0o600)
with os.fdopen(fd, 'wb') as output, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
    for info, data in contents.values():
        archive.writestr(info, data)
print('Created private build/30nama-roku-configured.zip; do not publish it')
