#!/usr/bin/env python3
"""Sample real Roku playback and count natural episode transitions without media URLs."""
import argparse,json,pathlib,subprocess,sys,time,urllib.request,xml.etree.ElementTree as ET,re,datetime,hashlib,os,signal
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--minutes',type=int,default=45);p.add_argument('--transitions',type=int,default=2);p.add_argument('--artifact',type=pathlib.Path);a=p.parse_args()
cfg=json.loads(pathlib.Path(os.environ.get('ROKU_DEV_CONFIG', str(ROOT.parent/'secrets/roku-dev.json'))).read_text());base='http://'+cfg['host']+':8060';out=ROOT/'build/soak-results.json';log=ROOT/'build/soak-console.log';samples=[];transitions=0;last=None;unhealthy=0;start=time.monotonic();failure=None
started_at=datetime.datetime.now(datetime.timezone.utc)
meta={'startedAt':started_at.isoformat(),'expectedEndAt':(started_at+datetime.timedelta(minutes=a.minutes)).isoformat(),'artifactSha256':hashlib.sha256(a.artifact.read_bytes()).hexdigest() if a.artifact else None}
def publish(result):
 result={**meta,'updatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),**result}
 temp=out.with_suffix('.json.tmp');temp.write_text(json.dumps(result,indent=2));os.replace(temp,out)
def terminate(signum,frame):raise KeyboardInterrupt()
signal.signal(signal.SIGTERM,terminate)
handle=log.open('w');listener=subprocess.Popen([sys.executable,str(ROOT/'scripts/device.py'),'console',str(a.minutes*60+90)],stdout=handle,stderr=subprocess.DEVNULL)
def seconds(node,name):
 try:return float(node.findtext(name,'0').split()[0])/1000
 except Exception:return 0
try:
 while time.monotonic()-start < a.minutes*60:
  elapsed=round(time.monotonic()-start)
  try:
   active=ET.fromstring(urllib.request.urlopen(base+'/query/active-app',timeout=6).read()).find('app')
   if active is None or active.get('id')!='dev':failure='App left foreground; stopped without reclaiming TV';break
   player=ET.fromstring(urllib.request.urlopen(base+'/query/media-player',timeout=6).read());state=player.get('state');position=seconds(player,'position');duration=seconds(player,'duration')
   sample={'elapsedSeconds':elapsed,'state':state,'positionSeconds':round(position,2),'durationSeconds':round(duration,2),'error':player.get('error')=='true'}
   if state=='play' and duration>60:
    if last and last['durationSeconds']-last['positionSeconds']<45 and position<45 and last['positionSeconds']>120:transitions+=1
    if last and abs(position-last['positionSeconds'])<.5:unhealthy+=1
    else:unhealthy=0
    last=sample
   else:unhealthy+=1
   if sample['error']:failure='Native player reported error';samples.append(sample);break
   if unhealthy>=7:failure='Playback failed to advance for at least 90 seconds';samples.append(sample);break
   samples.append(sample)
  except Exception as e:
   unhealthy+=1;samples.append({'elapsedSeconds':elapsed,'probeError':type(e).__name__})
   if unhealthy>=7:failure='Repeated device probe failure';break
  publish({'status':'running','elapsedSeconds':elapsed,'naturalTransitions':transitions,'samples':samples})
  time.sleep(15)
except KeyboardInterrupt:
 failure='Recorder interrupted; incomplete measurement'
finally:
 listener.terminate();listener.wait(timeout=10);handle.close()
text=log.read_text();plays=re.findall(r'\[30nama\]\[play\] title=\s*(\d+) episode=\s*(\d+) resume=\s*(\d+)',text)
result={'status':'passed' if not failure and transitions>=a.transitions else 'failed','elapsedSeconds':round(time.monotonic()-start),'naturalTransitions':transitions,'requiredTransitions':a.transitions,'failure':failure if failure else (None if transitions>=a.transitions else 'Required natural transitions not observed'),'playStarts':[{'titleId':int(t),'episodeId':int(e),'resumeSeconds':int(r)} for t,e,r in plays],'samples':samples}
publish(result);print(json.dumps({k:v for k,v in result.items() if k!='samples'}),flush=True)
raise SystemExit(0 if result['status']=='passed' else 1)
