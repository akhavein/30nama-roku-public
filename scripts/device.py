#!/usr/bin/env python3
"""Local Roku development helper. Never emits credentials or signed media URLs."""
import os,argparse,json,pathlib,socket,urllib.request,urllib.parse,uuid,re,time
ROOT=pathlib.Path(__file__).resolve().parent.parent
SECRET=pathlib.Path(os.environ.get('ROKU_DEV_CONFIG', str(ROOT/'.runtime/roku-dev.json')))
def client():
    cfg=json.loads(SECRET.read_text());base='http://'+cfg['host']
    mgr=urllib.request.HTTPPasswordMgrWithDefaultRealm();mgr.add_password(None,base,cfg['username'],cfg['password'])
    return cfg,base,urllib.request.build_opener(urllib.request.HTTPDigestAuthHandler(mgr))
def multipart(fields,files=None):
    boundary='roku'+uuid.uuid4().hex; parts=[]
    for name,value in fields.items():parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    for name,path in (files or {}).items():
        path=pathlib.Path(path);parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{path.name}"\r\nContent-Type: application/octet-stream\r\n\r\n'.encode()+path.read_bytes()+b'\r\n')
    return b''.join(parts)+f'--{boundary}--\r\n'.encode(), 'multipart/form-data; boundary='+boundary
def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['install','screenshot','key','launch','status','console','fetch']);p.add_argument('values',nargs='*');args=p.parse_args()
    cfg,base,opener=client();ecp=base+':8060'
    if args.action=='install':
        urllib.request.urlopen(urllib.request.Request(ecp+'/keypress/Home',data=b''),timeout=10).read()
        time.sleep(.8)
        body,ct=multipart({'mysubmit':'Install'},{'archive':pathlib.Path(args.values[0]) if args.values else ROOT/'build/30nama-roku.zip'})
        request=urllib.request.Request(base+'/plugin_install',data=body,headers={'Content-Type':ct})
        # Authenticate before uploading a larger font-bearing package. Some Roku
        # installers close an unauthenticated POST before its body is sent.
        try:urllib.request.urlopen(base,timeout=10).read()
        except urllib.error.HTTPError as e:
            if e.code!=401:raise
            challenge=e.headers.get('WWW-Authenticate','').removeprefix('Digest ')
            params=urllib.request.parse_keqv_list(urllib.request.parse_http_list(challenge))
            digest=next(h for h in opener.handlers if isinstance(h,urllib.request.HTTPDigestAuthHandler))
            request.add_header('Authorization','Digest '+digest.get_authorization(request,params))
        r=opener.open(request,timeout=90)
        text=r.read().decode(errors='replace');(ROOT/'build/install-response.html').write_text(text)
        print('Install HTTP',r.status,'response saved locally')
        print('Result:',re.findall(r'(Install Success\.|Install Failure[^<\n]{0,120}|Application Received: [0-9]+ bytes stored\.|Identical to previous version -- not replacing\.)',text,re.I)[:3])
    elif args.action=='screenshot':
        body,ct=multipart({'mysubmit':'Screenshot'})
        r=opener.open(urllib.request.Request(base+'/plugin_inspect',data=body,headers={'Content-Type':ct}),timeout=15);r.read()
        data=opener.open(base+'/pkgs/dev.jpg',timeout=15).read()
        out=pathlib.Path(args.values[0] if args.values else ROOT/'build/screenshot.jpg');out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(data);print(str(out))
    elif args.action=='key':
        keys=[]
        for value in args.values:
            keys.extend(['Lit_'+char for char in value[4:]] if value.startswith('Lit_') else [value])
        for key in keys:
            urllib.request.urlopen(urllib.request.Request(ecp+'/keypress/'+urllib.parse.quote(key,safe=''),data=b''),timeout=5).read();time.sleep(.22)
        print('Keys sent:',len(args.values))
    elif args.action=='launch':
        urllib.request.urlopen(urllib.request.Request(ecp+'/launch/dev',data=b''),timeout=5).read();print('Launch requested')
    elif args.action=='status':
        for route in ['active-app','media-player']:
            try:
                text=urllib.request.urlopen(ecp+'/query/'+route,timeout=5).read().decode();text=re.sub(r'https?[^\s<>"\x27]+','[URL]',text);print(text[:2000])
            except Exception as e: print(route,type(e).__name__)
    elif args.action=='fetch':
        path=args.values[0];out=pathlib.Path(args.values[1]);out.write_bytes(opener.open(base+path,timeout=15).read());print('Saved',out)
    elif args.action=='console':
        sock=socket.create_connection((cfg['host'],8085),timeout=5);sock.settimeout(1)
        until=time.monotonic()+float(args.values[0] if args.values else 10)
        while time.monotonic()<until:
            try:
                data=sock.recv(65536)
                if not data:break
                text=data.decode(errors='replace');text=re.sub(r'https?[^\s<>"\x27]+','[URL]',text);print(text,end='',flush=True)
            except socket.timeout:pass
if __name__=='__main__':main()
