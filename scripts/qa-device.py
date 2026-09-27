#!/usr/bin/env python3
"""Isolated, synthetic device QA; production account/history remain untouched.
Build creates a separate ZIP. Server accepts only Roku and loopback clients.
"""
import os,argparse,json,pathlib,shutil,zipfile,urllib.request,urllib.parse,time,subprocess
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
ROOT=pathlib.Path(__file__).resolve().parent.parent
HOST=os.environ.get('ROKU_QA_HOST','127.0.0.1');PORT=8765;ROKU=os.environ.get('ROKU_QA_DEVICE','127.0.0.1')
MEDIA=f'http://{HOST}:{PORT}/fixture.m3u8'
def build():
    dest=ROOT/'build/qa-app'
    if dest.exists():shutil.rmtree(dest)
    dest.mkdir(parents=True,exist_ok=True)
    for name in ['components','source']:shutil.copytree(ROOT/name,dest/name,dirs_exist_ok=True)
    shutil.copy(ROOT/'manifest',dest/'manifest')
    p=dest/'components/Api.brs';s=p.read_text();import re
    s=re.sub(r'base: "[^"]+"',f'base: "http://{HOST}:{PORT}/api"',s);s=re.sub(r'apiKey: "[^"]+"','apiKey: "fixture"',s);p.write_text(s)
    p=dest/'components/App.brs';s=p.read_text().replace('"30nama")','"30nama-test")',1);s=s.replace('    m.api.token = m.registry.Read("session_token")','    m.api.token = "fixture"\n    m.top.observeField("qaScenario","OnQaScenario")');p.write_text(s)
    p=dest/'components/App.xml';s=p.read_text().replace('<children>','<interface><field id="qaRun" type="string" /><field id="qaScenario" type="string" alwaysNotify="true" /></interface>\n<script type="text/brightscript" uri="pkg:/components/Qa.brs" />\n<children>',1);p.write_text(s)
    p=dest/'components/Previews.brs';s=p.read_text().replace('Left(m.helperUrl,8) <> "https://"','Left(m.helperUrl,7) <> "http://"');p.write_text(s)
    (dest/'components/Qa.brs').write_text((ROOT/'tests/device/Qa.brs').read_text().replace('QA_HOST_PLACEHOLDER',HOST))
    p=dest/'source/main.brs';s=p.read_text().replace('sub Main()','sub Main(args as Dynamic)').replace('    screen.Show()','    screen.Show()\n    if args <> invalid and args.scenario <> invalid then scene.qaRun = args.qaRun: scene.qaScenario = args.scenario');p.write_text(s)
    with zipfile.ZipFile(ROOT/'build/qa-roku.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in dest.rglob('*'):
            if p.is_file():z.write(p,p.relative_to(dest))
    print('Isolated QA package built')
def media():
    folder=ROOT/'build/qa-media';folder.mkdir(parents=True,exist_ok=True)
    for name,seconds in [('fixture',12),('long',60)]:
        subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-f','lavfi','-i','color=c=0x24374a:s=640x360:r=24','-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t',str(seconds),'-c:v','libx264','-preset','ultrafast','-g','48','-pix_fmt','yuv420p','-c:a','aac','-hls_time','2','-hls_list_size','0','-hls_playlist_type','vod',str(folder/(name+'.m3u8'))],check=True)
    for extension,flags in [('mp4',['-movflags','+faststart']),('mpd',['-f','dash','-seg_duration','2'])]:
        subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(folder/('fixture.m3u8' if extension=='mp4' else 'compat.mp4')),'-c','copy',*flags,str(folder/('compat.'+extension))],check=True)
    for lang,text in [('en','Subtitle test: English'),('fa','آزمایش زیرنویس فارسی (2026)')]:
        (folder/(lang+'.vtt')).write_text('WEBVTT\n\n00:00:00.000 --> 00:01:00.000\n'+text+'\n')
    print('Synthetic HLS, MP4, DASH and subtitle fixtures generated')
def audio_media():
    folder=ROOT/'build/qa-media'
    for name,flags in [('video-only',['-an','-c:v','copy']),('audio-only',['-vn','-c:a','copy'])]:
        subprocess.run(['ffmpeg','-y','-hide_banner','-loglevel','error','-i',str(folder/'long.m3u8'),*flags,'-hls_time','2','-hls_list_size','0','-hls_playlist_type','vod',str(folder/(name+'.m3u8'))],check=True)
    (folder/'multiaudio.m3u8').write_text('#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="audio-only.m3u8?lang=en"\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Persian",LANGUAGE="fa",DEFAULT=NO,AUTOSELECT=YES,URI="audio-only.m3u8?lang=fa"\n#EXT-X-STREAM-INF:BANDWIDTH=250000,RESOLUTION=640x360,AUDIO="audio"\nvideo-only.m3u8\n')
    print('Silent bilingual audio fixture generated')
class Handler(SimpleHTTPRequestHandler):
    cloud_stores = {}
    cloud_reads = {}
    cloud_writes = {}
    stream_counts = {}
    health_count = 0
    search_counts = {}
    subtitle_counts = {}
    def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT/'build/qa-media'),**kw)
    def log_message(self,*args):pass
    def allowed(self):return self.client_address[0] in [ROKU,HOST,'127.0.0.1']
    def do_GET(self):
        if not self.allowed():self.send_error(403);return
        if self.path.endswith('/health'):
            if self.path=='/unauthorized/health':self.send_error(401);return
            if self.path=='/recover/health':
                self.health_count=type(self).health_count+1;type(self).health_count=self.health_count
                if self.health_count==1:self.send_error(503);return
            body=b'{"ok":true}';self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
        if self.path=='/stall.m3u8':time.sleep(20);self.path='/long.m3u8'
        if self.path=='/expired.vtt':self.send_error(410);return
        if self.path=='/slow-fa.vtt':time.sleep(10);self.path='/fa.vtt'
        if self.path.endswith('.vtt'):print(json.dumps({'captionFetched':self.path}),flush=True)
        if self.path=='/transient-fa.vtt':
            self.subtitle_counts['transient']=self.subtitle_counts.get('transient',0)+1
            if self.subtitle_counts['transient']==1:self.send_error(503);return
            self.path='/fa.vtt'
        super().do_GET()
    def do_POST(self):
        if not self.allowed():self.send_error(403);return
        if self.path.endswith('/preview'):
            import base64
            body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
            if '/slow/' in self.path:time.sleep(3)
            if '/failure/' in self.path:self.send_error(503);return
            if '/stale/' in self.path:body['seconds']+=5
            result={'success':True,'seconds':body['seconds'],'jpeg':base64.b64encode((ROOT/'build/qa-media/scene.jpg').read_bytes()).decode()}
            if '/badimage/' in self.path:result['jpeg']='/9j/2Q=='
            if '/badflag/' in self.path:result['success']={}
            payload=json.dumps(result).encode()
            self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers()
            try:self.wfile.write(payload)
            except (BrokenPipeError,ConnectionResetError):pass
            return
        form=urllib.parse.parse_qs(self.rfile.read(int(self.headers.get('Content-Length','0'))).decode());action=self.path.removeprefix('/api/');status=200;raw=None;result={}
        mode='default'
        if action.startswith('case/'):
            _,mode,action=action.split('/',2)
        if mode not in self.cloud_stores:self.cloud_stores[mode]=set() if mode=='empty' else {101,201,104}
        if action=='user_mylist':
            self.cloud_reads[mode]=self.cloud_reads.get(mode,0)+1
            if mode=='preflight' and self.cloud_reads[mode]==2:status=503
            if mode=='authfail':status=401
            result={'watchlist':{'post':[str(x) for x in sorted(self.cloud_stores[mode])]}}
        elif action.startswith('add_to_mylist/'):
            ident=int(action.split('/')[2]);self.cloud_writes[mode]=self.cloud_writes.get(mode,0)+1
            if mode!='unconfirmed':
                if ident in self.cloud_stores[mode]:self.cloud_stores[mode].remove(ident)
                else:self.cloud_stores[mode].add(ident)
            if mode=='lostack':status=503
            if mode=='slowwrite':time.sleep(4)
            if mode=='logoutwrite':time.sleep(8)
            result={'saved':True}
        elif action.startswith('mylist/group/watchlist/page/'):
            page=int(action.split('/')[-1]);ids=sorted(self.cloud_stores[mode]);selected=ids[(page-1)*2:page*2]
            result={'page':page,'pages':max(1,(len(ids)+1)//2),'posts':[{'id':x,'title':{101:'Zulu movie',104:'Beta movie',201:'Alpha series'}.get(x,'Fixture'),'is_series':x==201} for x in selected]}
            if mode=='malformed':result={'posts':'bad'}
            if mode=='offline' or (mode=='pagefail' and page==2):status=503
            if mode=='slow':time.sleep(4)
            if mode=='shrink' and page==2:result={'page':2,'pages':1,'posts':[]}
        elif action=='mainV2':result={'hero_section':[{'id':101,'title':'QA Movie'},{'id':200,'title':'QA Series','is_series':1},None,{'id':'bad'}]}
        elif action.startswith('search/'):
            q=form.get('query',[''])[0]
            self.search_counts[q]=self.search_counts.get(q,0)+1
            if q=='flaky' and self.search_counts[q]==1:status=503
            if q=='timeout':time.sleep(17)
            if q=='cancel':time.sleep(4)
            if q=='500':status=500
            if q=='401':status=401
            if q=='429':status=429
            if q=='malformed':raw=b'{not json'
            page=int(action.split('/')[2])
            if q=='mixed' and page==2:status=500
            result={'pages':3,'posts':[] if q in ['empty',"Schindler's List"] else [{'id':100+page,'title':'Page '+str(page),'poster':''},None,{'id':0}]}
            if q=='views':result['posts']=[{'id':301,'title':'Zebra Movie','imdb_score':'8.2'},{'id':302,'title':'Alpha Series','is_series':True,'imdb_score':'9.1'},{'id':303,'title':'Beta Movie','imdb_score':'7.3'}]
            if q=='focus':result['posts']=[{'id':100+page*10+i,'title':f'Result {i}'} for i in range(4)]
            if q=='all-invalid':result['posts']=[None,{'id':0}]
            if q=='wrong-type':result['posts']={}
            if q=='shrink':result['pages']=1
            if q=='last':result['pages']=2
            if q=='unicode':result['posts']=[{'id':150,'title':'آزمایش فارسی 2026'}]
        elif action.startswith('single/'):result={'id':int(action.split('/')[-1]),'title':'QA title','english_plot':'A synthetic fixture for device acceptance.'}
        elif action.startswith('stream/'):
            id=int(action.split('/')[-1])
            self.stream_counts[id]=self.stream_counts.get(id,0)+1
            if id==401:status=401
            elif id==500:status=500
            elif id==200:result={'list':{}}
            elif id in [119,120,121,122]:
                markers={119:{'intro_start':'00:00:05','intro_end':'00:00:25'},120:{'intro_start':'00:00:25','intro_end':'00:00:05'},121:{'intro_start':'00:00:00','intro_end':'00:02:00'},122:{'intro_start':'00:00:00','intro_end':'00:00:20'}}
                result={'file':{'source':[{'auto':f'http://{HOST}:{PORT}/long.m3u8','2ch':f'http://{HOST}:{PORT}/long.m3u8?stereo=1','label':'Intro fixture'}]},'subtitle':{'fa':f'http://{HOST}:{PORT}/fa.vtt'},'options':markers[id]}
            elif id==202:result={'list':{'1':[{'data':{'id':21+n,'season':1,'number':n+1,'title':f'Intro episode {n+1}'},'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{},'options':{'intro_start':'00:00:00','intro_end':'00:00:20'} if n==0 else {}} for n in range(2)]}}
            elif id==201:result={'list':{str(s):[{'data':{'id':s*10+n,'season':s,'number':n,'title':f'Episode {n}'},'file':{'url':MEDIA},'subtitle':{}} for n in range(1,3)] for s in [12,2,1,10]}}
            elif id in [112,113]:result={'file':{'url':f'http://{HOST}:{PORT}/compat.'+('mp4' if id==112 else 'mpd')},'subtitle':{}}
            elif id==118:
                time.sleep(4);result={'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{}}
            elif id==117:result={'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{'fa':f'http://{HOST}:{PORT}/transient-fa.vtt'}}
            elif id==116:result={'file':{'url':f'http://{HOST}:{PORT}/multiaudio.m3u8'},'subtitle':{}}
            elif id in [110,111]:result={'file':{'source':[{'auto':f'http://{HOST}:{PORT}/'+('missing.m3u8' if id==110 else 'long.m3u8'),'2ch':f'http://{HOST}:{PORT}/long.m3u8?stereo=1','label':'Fixture'}]},'subtitle':{}}
            elif id==101:result={'file':{'url':MEDIA},'subtitle':{}}
            elif id==104:result={'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{c:f'http://{HOST}:{PORT}/{c}.vtt' for c in ['en','fa']}}
            elif id==109:result={'file':{'url':f'http://{HOST}:{PORT}/'+('stall.m3u8' if self.stream_counts[id]==1 else 'long.m3u8')},'subtitle':{}}
            elif id in [106,108]:result={'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{'fa':f'http://{HOST}:{PORT}/'+('expired.vtt' if id==108 or self.stream_counts[id]==1 else 'fa.vtt')}}
            elif id in [105,107]:result={'file':{'url':f'http://{HOST}:{PORT}/long.m3u8'},'subtitle':{'fa':f'http://{HOST}:{PORT}/'+('missing.vtt' if id==105 else 'slow-fa.vtt')}}
            elif id==102:result={'file':{'url':f'http://{HOST}:{PORT}/missing.m3u8'},'subtitle':{}}
            else:result={'file':{},'subtitle':{}}
        elif action=='send_otp':result={'sent':True}
        elif action=='verify_otp':
            if form.get('code')==['123456']:result={'user_session':'fixture-only'}
            elif form.get('code')==['401401']:status=401
            else:status=400
        body=raw or json.dumps({'success':status==200,'result':result}).encode()
        self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers()
        try:self.wfile.write(body)
        except (BrokenPipeError,ConnectionResetError):pass
        print(json.dumps({'action':action,'status':status,'mode':mode}),flush=True)
def launch(scenario,run_id=None):
    for path in ['/keypress/Home','/launch/dev?'+urllib.parse.urlencode({'scenario':scenario,'qaRun':run_id or str(time.time_ns())})]:
        urllib.request.urlopen(urllib.request.Request('http://'+ROKU+':8060'+path,data=b''),timeout=15).read();time.sleep(1)
    print('QA launched:',scenario)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['build','serve','launch','media']);p.add_argument('scenario',nargs='?');p.add_argument('--run-id');a=p.parse_args()
    if a.action=='build':build()
    elif a.action=='media':media();audio_media()
    elif a.action=='serve':ThreadingHTTPServer((HOST,PORT),Handler).serve_forever()
    else:launch(a.scenario,a.run_id)
