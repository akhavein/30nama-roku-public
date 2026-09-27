#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
for id,name in [(112,'H.264/AAC MP4'),(113,'H.264/AAC DASH')]:
 q.launch('stream:'+str(id));q.expect(name+' native playback',lambda s:s.get('player')=='playing',20)
 q.expect(name+' natural completion',lambda s:s.get('page')=='title' and any(x.get('completed') for x in s.get('history',[])),25)
q.launch('caption-cycle');q.expect('native caption suppression/mode experiment survives 18 changes',lambda s:s.get('captioncycles',0)>=19 and s.get('player')=='playing',35)
q.expect('custom Persian captions recover after native mode cycling',lambda s:s.get('captiontext') and s.get('captionvisible'),15)
q.command('scripts/device.py','screenshot','build/caption-cycle-recovered.jpg')
(q.ROOT/'build/qa-compatibility-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
