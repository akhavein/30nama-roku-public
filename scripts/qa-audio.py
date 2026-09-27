#!/usr/bin/env python3
"""Verify actual native audio selection, persistence and restoration, using silence."""
import importlib.util,pathlib,json
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
def active(state):
    return next((o for o in state.get('audiooptions',[]) if o.get('track')==state.get('currentaudio')), {})
def select(index):
    q.mark();q.keys('Play','Right','Right','Right','Right','Select')
    q.expect('audio menu accessible with remote',lambda s:s.get('trackkind')=='audio' and s.get('tracks'))
    q.keys(*(['Down']*index+['Select','Play']))
q.launch('stream:116')
state=q.expect('bilingual HLS exposes native audio tracks',lambda s:s.get('player')=='playing' and len(s.get('audiooptions',[]))==2,18)
original=active(state).get('language')
assert original in ['en','fa']
target='fa' if original=='en' else 'en'
index=next(i for i,o in enumerate(state['audiooptions']) if o.get('language')==target)
select(index)
q.expect('selected audio is actually playing and preference saved',lambda s:active(s).get('language')==target and s.get('savedaudiolanguage')==target and s.get('player')=='playing',18)
q.launch('stream:116')
state=q.expect('audio language restores after relaunch',lambda s:active(s).get('language')==target and s.get('player')=='playing',18)
index=next(i for i,o in enumerate(state['audiooptions']) if o.get('language')==original)
select(index)
q.expect('original audio language restored after QA',lambda s:active(s).get('language')==original and s.get('player')=='playing',18)
(q.ROOT/'build/qa-audio-results.json').write_text(json.dumps(q.results,indent=2))
print('AUDIO ACCEPTANCE PASS',len(q.results),flush=True)
