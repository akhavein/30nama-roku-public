#!/usr/bin/env python3
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('autoplay:201');q.expect('autoplay series seasons loaded',lambda s:s.get('page')=='seasons')
q.keys('Select','Select','Select');q.expect('autoplay first episode starts',lambda s:s.get('episode')==11 and s.get('player')=='playing',15)
q.expect('completion automatically starts next episode',lambda s:s.get('episode')==12 and s.get('player')=='playing',30)
q.expect('autoplay crosses season boundary',lambda s:s.get('episode')==21 and s.get('player')=='playing',30)
q.launch('stream:201');q.expect('manual-mode seasons loaded',lambda s:s.get('page')=='seasons')
q.keys('Select','Select','Select');q.expect('manual-mode first episode starts',lambda s:s.get('episode')==11 and s.get('player')=='playing',15)
q.expect('autoplay off returns to title with next resume target',lambda s:s.get('page')=='title' and any(x.get('episodeid')==12 for x in s.get('history',[])),25)
print('AUTOPLAY DEVICE PASS',flush=True)
