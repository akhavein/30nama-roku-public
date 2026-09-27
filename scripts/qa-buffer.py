#!/usr/bin/env python3
"""Native buffering timeout/recovery; QA shortens only the timer duration."""
import importlib.util,pathlib
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'));q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('stream:109');q.expect('stalled native stream refreshes automatically once',lambda s:s.get('player')=='playing' and s.get('refreshattempts')==1,18)
q.expect('startup recovery does not invent or erase progress',lambda s:s.get('history')==[])
q.expect('recovered stream keeps advancing',lambda s:s.get('player')=='playing' and s.get('position',0)>3,12)
print('BUFFER RECOVERY PASS',flush=True)
