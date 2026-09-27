#!/usr/bin/env python3
"""An intro dismissed at a pre-end keyframe survives source replacement."""
import importlib.util,pathlib,json
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
def check(name,fn,timeout=15):return q.expect(name,fn,timeout)
def action(name):
 s=q.states()[-1];q.mark();n=(s['controlactions'].index(name)-s['control'])%len(s['controlactions'])
 if n:q.keys(*(['Right']*n))
 check('recovery toolbar focuses '+name,lambda s:s.get('controlactions',[None])[s.get('control',0)]==name)
 q.mark();q.keys('Select')
q.launch('stream:119');check('source recovery intro available',lambda s:s.get('introprompt'))
q.mark();q.keys('Play');check('source recovery fixture paused',lambda s:s.get('player')=='paused')
action('intro');check('skip reaches earlier native keyframe paused',lambda s:s.get('player')=='paused' and s.get('position')==24 and not s.get('seeksettling'),20)
action('source');check('source menu opens',lambda s:s.get('tracks') and s.get('trackkind')=='source')
q.mark();q.keys('Down','Select');check('source replacement preserves pause and consumed intro',lambda s:s.get('sourceindex')==1 and s.get('player')=='paused' and s.get('position')==24 and s.get('introtarget')==-1,25)
q.mark();q.keys('InstantReplay');check('explicit rewind on replacement permits intro again',lambda s:s.get('player')=='paused' and s.get('introtarget')==25 and not s.get('seeksettling'),20)
q.command('scripts/device.py','screenshot','build/v15-intro-paused-controls.jpg')
q.mark();q.keys('Back');check('prompt separated from caption area',lambda s:s.get('introprompt'))
q.command('scripts/device.py','screenshot','build/v15-intro-prompt.jpg')
q.keys('Back')
(q.ROOT/'build/qa-intro-recovery-results.json').write_text(json.dumps(q.results,indent=2))
print('INTRO RECOVERY PASS',len(q.results),flush=True)
