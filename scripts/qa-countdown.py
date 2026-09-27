#!/usr/bin/env python3
import importlib.util,pathlib,time
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
def start():
 q.launch('autoplay:201');q.expect('countdown series ready',lambda s:s.get('page')=='seasons');q.keys('Select','Select','Select');q.expect('countdown episode playing',lambda s:s.get('player')=='playing',15)
start();q.expect('countdown appears at natural completion',lambda s:s.get('nextpending') and s.get('nextremaining',0)>0,22)
q.command('scripts/device.py','screenshot','build/feature-countdown.jpg');q.keys('Back');q.expect('Back cancels next episode',lambda s:s.get('page')=='title' and not s.get('nextpending'))
time.sleep(11);q.expect('cancelled timer cannot start playback later',lambda s:s.get('page')=='title')
start();q.expect('countdown available for play-now',lambda s:s.get('nextpending'),22);q.keys('Select');q.expect('OK starts next episode immediately',lambda s:s.get('episode')==12 and s.get('player')=='playing',15)
q.expect('countdown expires into next season',lambda s:s.get('episode')==21 and s.get('player')=='playing',35)
(q.ROOT/'build/qa-countdown-results.json').write_text((q.ROOT/'build/qa-results.json').read_text())
