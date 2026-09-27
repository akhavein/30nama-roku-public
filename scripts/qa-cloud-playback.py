#!/usr/bin/env python3
"""A saved-list mutation may complete without interrupting playback."""
import importlib.util,pathlib,json
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
q.launch('cloud:slowwrite')
q.expect('remaining account title after earlier removal',lambda s:s.get('visibleids')==[104,201])
q.mark();q.keys('Select');s=q.expect('playback transaction title ready',lambda s:s.get('page')=='title' and s.get('cloudknown'))
index=s['titleactions'].index('cloud-watch');q.keys(*(['Down']*index),'Select')
q.expect('save pending before Play',lambda s:s.get('cloudpending'))
q.keys(*(['Up']*index),'Select');q.expect('playback starts while save finishes',lambda s:s.get('page')=='player' and s.get('player')=='playing',20)
q.mark();q.expect('background account verification cannot interrupt player',lambda s:s.get('page')=='player' and s.get('player')=='playing' and not s.get('cloudpending'),20)
q.keys('Back','Back')
(q.ROOT/'build/qa-cloud-playback-results.json').write_text(json.dumps(q.results,indent=2))
print('ACCOUNT PLAYBACK PASS',len(q.results),flush=True)
