#!/usr/bin/env python3
"""Native account Watchlist transactions; fixture identity only."""
import importlib.util,pathlib,json,time
spec=importlib.util.spec_from_file_location('acceptance',pathlib.Path(__file__).with_name('qa-acceptance.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
def check(name,fn,timeout=15):return q.expect(name,fn,timeout)
def ready(mode):
 q.launch('cloud:'+mode);return check(mode+' account page loads',lambda s:s.get('page')=='cloud-watchlist' and s.get('visibleids')==[101,104])
def title():
 q.mark();q.keys('Select');return check('account title membership loaded',lambda s:s.get('page')=='title' and s.get('cloudknown'))
def mutate():
 s=q.states()[-1];index=s['titleactions'].index('cloud-watch');current=s['actionfocus'];q.mark()
 if current!=index:q.keys(*(['Down']*(index-current)))
 check('account mutation action focused',lambda s:s.get('titleactions',[None])[s.get('actionfocus',0)]=='cloud-watch')
 q.mark();q.keys('Select','Select')
ready('normal');check('TV-only sentinel remains separate',lambda s:s.get('watchcount')==1 and s.get('cloudpages')==2)
q.mark();q.keys('Right');check('second account title focused',lambda s:s.get('railfocus')==[0,1])
title();q.mark();q.keys('Back');check('account Back restores selected title',lambda s:s.get('page')=='cloud-watchlist' and s.get('railfocus')==[0,1])
q.mark();q.keys('Fwd');check('account FF loads provider next page',lambda s:s.get('cloudpage')==2 and s.get('visibleids')==[201])
q.mark();q.keys('Rev');check('account Rewind loads previous page',lambda s:s.get('cloudpage')==1 and s.get('visibleids')==[101,104])
title()
mutate();check('account removal readback confirmed',lambda s:not s.get('cloudpending') and 'saved and verified' in s.get('status',''))
check('account mutation cannot change TV-only list',lambda s:s.get('watchcount')==1 and len(s.get('cloudids',[]))==2)
q.mark();q.keys('Back');check('removed account title leaves list after refresh',lambda s:s.get('page')=='cloud-watchlist' and len(s.get('visibleids',[]))==2 and s.get('cloudpages')==1)
q.launch('cloud:empty');check('genuine empty account list explained',lambda s:s.get('page')=='cloud-watchlist' and s.get('visibleids')==[] and 'No matching' in s.get('empty',''))
q.launch('cloud:malformed');check('malformed response is recoverable, not a claimed empty account',lambda s:'unavailable' in s.get('status',''))
q.mark();q.keys('Info');check('error opens refresh menu',lambda s:s.get('page')=='cloud-watch-options' and s.get('cloudactions',[None])[0]=='refresh')
q.launch('cloud:signedout');check('signed-out account list requires sign-in',lambda s:'Sign in' in s.get('empty','') and not s.get('signedin'))
ready('pagefail');q.mark();q.keys('Fwd');check('failed page preserves prior account results',lambda s:s.get('cloudpage')==1 and s.get('visibleids')==[101,104] and 'unavailable' in s.get('status',''))
ready('shrink');q.mark();q.keys('Fwd');check('shrunk account pagination recovers to valid page',lambda s:s.get('cloudpage')==1 and s.get('visibleids')==[101,104])
ready('lostack');title();mutate();check('committed toggle with lost ACK is verified without replay',lambda s:not s.get('cloudpending') and 'saved and verified' in s.get('status','') and len(s.get('cloudids',[]))==2)
ready('unconfirmed');title();mutate();check('successful ACK without matching membership is not called saved',lambda s:not s.get('cloudpending') and not s.get('cloudknown') and 'not confirmed' in s.get('status',''),25)
q.mark();q.keys('Select');check('retry after uncertainty is read-only membership refresh',lambda s:s.get('cloudknown') and not s.get('cloudpending') and len(s.get('cloudids',[]))==3)
ready('preflight');title();mutate();check('failed preflight sends no write',lambda s:not s.get('cloudpending') and 'No change sent' in s.get('status',''))
q.launch('cloud:slow');q.mark();q.keys('Back');check('Back exits slow account load',lambda s:s.get('page')=='watchlist')
time.sleep(5);q.mark();check('late account list cannot navigate after Back',lambda s:s.get('page')=='watchlist')
ready('slowwrite');title();mutate();q.keys('Back');check('navigation remains usable during account write',lambda s:s.get('page')=='cloud-watchlist')
check('background mutation completes on account list',lambda s:not s.get('cloudpending') and s.get('cloudpages')==1 and len(s.get('visibleids',[]))==2,20)
ready('authfail');q.mark();q.keys('Select');check('membership 401 clears account state without local loss',lambda s:not s.get('signedin') and not s.get('cloudknown') and not s.get('cloudpending') and s.get('watchcount')==1)
# Server traces verify side-effect counts independently of client state.
rows=[]
for line in (q.ROOT/'build/cloud-server.log').read_text().splitlines():
 try:rows.append(json.loads(line))
 except ValueError:pass
for mode,count in [('lostack',1),('unconfirmed',1),('preflight',0)]:
 actual=sum(x.get('mode')==mode and x.get('action','').startswith('add_to_mylist/') for x in rows)
 assert actual==count,(mode,actual,count)
 q.results.append({'test':mode+' exact server write count '+str(count),'passed':True})
(q.ROOT/'build/qa-cloud-watchlist-results.json').write_text(json.dumps(q.results,indent=2))
print('ACCOUNT WATCHLIST NATIVE PASS',len(q.results),flush=True)
