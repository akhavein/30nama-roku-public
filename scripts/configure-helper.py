#!/usr/bin/env python3
"""Pair this TV with a private HTTPS helper without putting its key in Git/releases."""
import argparse,pathlib,tempfile,shutil,zipfile,subprocess,time,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('url');p.add_argument('--token-file',required=True);a=p.parse_args()
if not re.fullmatch(r'https://[a-zA-Z0-9.-]+',a.url):raise SystemExit('Expected HTTPS origin without path')
raw=pathlib.Path(a.token_file).read_text().strip();token=raw.split('=',1)[1] if raw.startswith('HELPER_BEARER_TOKEN=') else raw
if not re.fullmatch(r'[A-Za-z0-9_-]{32,128}',token):raise SystemExit('Invalid helper credential format')
(ROOT/'.runtime').mkdir(exist_ok=True,mode=0o700)
with tempfile.TemporaryDirectory(prefix='pair-helper-',dir=ROOT/'.runtime') as tmp:
 folder=pathlib.Path(tmp)
 for name in ['components','source','images']:shutil.copytree(ROOT/name,folder/name)
 shutil.copy(ROOT/'manifest',folder/'manifest')
 app=folder/'components/App.brs';s=app.read_text();needle='    m.registry = CreateObject("roRegistrySection", "30nama")'
 assert needle in s
 s=s.replace(needle,needle+'\n    m.registry.Write("helper_url","'+a.url+'")\n    m.registry.Write("helper_token","'+token+'")\n    m.registry.Flush()',1);app.write_text(s)
 archive=folder/'pair.zip'
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for name in ['components','source','images']:
   for f in (folder/name).rglob('*'):
    if f.is_file():z.write(f,f.relative_to(folder))
  z.write(folder/'manifest','manifest')
 subprocess.run(['python3',str(ROOT/'scripts/device.py'),'install',str(archive)],check=True)
 subprocess.run(['python3',str(ROOT/'scripts/device.py'),'launch'],check=True)
 time.sleep(4)
 subprocess.run(['python3',str(ROOT/'scripts/device.py'),'install',str(ROOT/'build/30nama-roku.zip')],check=True)
 subprocess.run(['python3',str(ROOT/'scripts/device.py'),'launch'],check=True)
print('TV paired; credential-bearing temporary package removed; clean shipping package restored')
