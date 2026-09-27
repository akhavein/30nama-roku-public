#!/usr/bin/env python3
"""Scene scrubber: synthetic frames, isolated registry, native decode/remote."""
import importlib.util,pathlib,json,time
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
def check(name,fn,timeout=12):return q.expect(name,fn,timeout)
def start(mode):
 q.launch('preview:'+mode);check(mode+' native playback ready',lambda s:s.get('player')=='playing')
def open_scene():
 q.mark();q.keys('Up');s=check('scene toolbar action discoverable',lambda s:s.get('controls') and 'scenes' in s.get('controlactions',[]))
 target=s['controlactions'].index('scenes');steps=(target-s['control'])%len(s['controlactions'])
 if steps:q.keys(*(['Right']*steps))
 q.mark();q.keys('Select');return check('scene browser pauses player',lambda s:s.get('scenevisible') and s.get('player')=='paused')
start('normal');opened=open_scene();origin=opened['position']
check('actual JPEG renders on native Poster',lambda s:s.get('sceneimage') and s.get('sceneload')=='ready')
q.command('scripts/device.py','screenshot','build/v17-scene-fixture.jpg')
q.mark();q.keys('Right','Right','Fwd');s=check('rapid preview keys accumulate without moving playback',lambda s:s.get('scenetarget')==min(59,int(origin)+50) and abs(s.get('position',999)-origin)<2)
check('latest target image shown',lambda s:s.get('sceneimage') and s.get('scenestatus')=='Scene near 0:'+str(s['scenetarget']).zfill(2))
q.mark();q.keys('Back');check('cancel resumes original playing position',lambda s:not s.get('scenevisible') and s.get('player')=='playing' and abs(s.get('position',999)-origin)<4)
q.mark();q.keys('Play');check('pause before browsing',lambda s:s.get('player')=='paused')
opened=open_scene();q.mark();q.keys('Fwd','Select');check('OK seeks while preserving original pause',lambda s:not s.get('scenevisible') and s.get('player')=='paused' and s.get('seektarget',0)>=30 and not s.get('seeksettling'),20)
opened=open_scene();q.mark();q.keys('Rev','Back');check('cancel preserves original pause without seeking',lambda s:not s.get('scenevisible') and s.get('player')=='paused' and abs(s.get('position',999)-opened['position'])<2)
start('slow');open_scene();time.sleep(.6);q.mark();q.keys('Back');check('Back cancels pending frame immediately',lambda s:not s.get('scenevisible') and s.get('player')=='playing')
time.sleep(3.5);check('late preview cannot reopen overlay',lambda s:not s.get('scenevisible') and not s.get('sceneimage') and s.get('player')=='playing')
start('slow');opened=open_scene();time.sleep(.6);q.mark();q.keys('Right');check('new target wins over cancelled in-flight response',lambda s:s.get('sceneimage') and s.get('scenetarget')==int(opened['position'])+10 and s.get('scenestatus')=='Scene near 0:'+str(s['scenetarget']).zfill(2),12)
start('stale');open_scene();check('wrong timestamp response is rejected',lambda s:'unavailable' in s.get('scenestatus','') and not s.get('sceneimage'))
for mode in ['failure','unpaired','badimage','badflag']:
 start(mode);open_scene();check(mode+' leaves usable time-only scrubber',lambda s:'unavailable' in s.get('scenestatus','') and not s.get('sceneimage'))
 q.mark();q.keys('Right','Select');check(mode+' can still commit time seek',lambda s:not s.get('scenevisible') and s.get('player')=='playing' and s.get('position',0)>=8,20)
start('sleep');open_scene();check('sleep expiry cancels preview and stops safely',lambda s:s.get('page')=='title' and not s.get('scenevisible') and s.get('player')=='stopped',16)
(q.ROOT/'build/qa-previews-results.json').write_text(json.dumps(q.results,indent=2))
print('PREVIEW NATIVE PASS',len(q.results),flush=True)
