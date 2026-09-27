#!/usr/bin/env python3
"""Native fault/flow acceptance driver for the isolated QA package."""
import json,pathlib,time,subprocess,sys,uuid
ROOT=pathlib.Path(__file__).resolve().parent.parent;LOG=ROOT/'build/acceptance.log';results=json.loads((ROOT/'build/qa-results.json').read_text()) if '--resume' in sys.argv else [];offset=0
run_id=None

def command(*args):subprocess.run([sys.executable,*args],cwd=ROOT,check=True,stdout=subprocess.DEVNULL)
def keys(*args):command('scripts/device.py','key',*args)
def launch(s):
    global offset,run_id
    run_id=uuid.uuid4().hex
    offset=LOG.stat().st_size
    command('scripts/qa-device.py','launch',s,'--run-id',run_id)
def states():
    with LOG.open() as f:f.seek(offset);lines=f.read().splitlines()
    out=[]
    for line in lines:
        if '[QA] ' in line:
            try:
                state=json.loads(line.split('[QA] ',1)[1])
                if run_id is None or state.get('run')==run_id:out.append(state)
            except ValueError:pass
    return out

def expect(name,predicate,timeout=8):
    until=time.monotonic()+timeout;last={}
    while time.monotonic()<until:
        ss=states()
        if ss:last=ss[-1]
        if predicate(last):
            results.append({'test':name,'passed':True,'state':last});print('PASS',name,flush=True);save();return last
        time.sleep(.2)
    results.append({'test':name,'passed':False,'state':last});print('FAIL',name,json.dumps(last),flush=True);save();raise RuntimeError(name)
def save():(ROOT/'build/qa-results.json').write_text(json.dumps(results,indent=2))
def mark():
    global offset
    offset=LOG.stat().st_size
def main():
    for scenario,part in [('search:empty','Page 1'),('search:malformed',"couldn't"),('search:500',"couldn't"),('search:401',"couldn't"),('search:429','Too many requests'),('search:timeout',"couldn't")]:
        if '--resume' in sys.argv and any(r['test']==scenario and r['passed'] for r in results):continue
        launch(scenario);state=expect(scenario,lambda s:part in s.get('status',''),20)
        if scenario=='search:401':assert state['signedin']==False
        if scenario=='search:429':assert state['signedin']==True
    launch('search:cancel');keys('Back','Back');time.sleep(5)
    expect('cancelled search does not navigate late',lambda s:s.get('page')=='home')
    launch('search:pages');expect('paginated search loads valid titles only',lambda s:s.get('results')==1 and s.get('searchpages')==3)
    mark();keys('Info','Select');expect('search next page',lambda s:s.get('searchpage')==2 and 'Page 2' in s.get('status',''))
    mark();keys('Info','Down','Select');expect('search previous page',lambda s:s.get('searchpage')==1 and 'Page 1' in s.get('status',''))
    mark();keys('Select');expect('search result opens detail',lambda s:s.get('page')=='title')
    mark();keys('Back');expect('detail Back restores search',lambda s:s.get('page')=='search' and s.get('results')==1)
    launch('empty-continue');expect('empty Continue has helpful message',lambda s:s.get('page')=='continue' and 'Nothing to resume' in s.get('empty',''))
    for scenario,part in [('stream:200','No playable'),('stream:103','No compatible'),('stream:401','expired'),('stream:500','unavailable'),('stream:102','Playback failed')]:
        launch(scenario);expect(scenario,lambda s:part in s.get('status',''),20)
    for scenario,part in [('login-empty','enter a value'),('login-invalid','valid email'),('login-send','one-time code'),('login-otp-invalid','failed')]:
        launch(scenario);expect(scenario,lambda s:any(part in x for x in s.get('message',[])))
    mark();keys('Back');expect('login Cancel returns to account',lambda s:s.get('page')=='account' and 'message' not in s)
    launch('login-success');expect('synthetic OTP success persists session',lambda s:s.get('signedin') and 'successfully' in s.get('status',''))
    launch('stream:101');expect('fixture movie reaches native playback',lambda s:s.get('player')=='playing',12)
    expect('movie completion leaves Continue',lambda s:s.get('page')=='title' and any(x.get('completed') for x in s.get('history',[])),20)
    launch('stream:201');expect('seasons sort numerically',lambda s:s.get('page')=='seasons' and s.get('items',[])[:4]==['Season 1   ·   2 episodes','Season 2   ·   2 episodes','Season 10   ·   2 episodes','Season 12   ·   2 episodes'])
    mark();keys('Select');expect('season opens episodes',lambda s:s.get('page')=='episodes')
    mark();keys('Select');expect('episode opens details',lambda s:s.get('page')=='title')
    mark();keys('Select');expect('episode native playback',lambda s:s.get('player')=='playing',12)
    expect('episode finish advances continue target',lambda s:s.get('page')=='title' and any(x.get('episodeId',x.get('episodeid'))==12 and not x.get('completed') for x in s.get('history',[])),20)
    print('DEVICE ACCEPTANCE PASS',len(results),flush=True)

if __name__ == "__main__":main()
