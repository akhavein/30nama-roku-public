#!/usr/bin/env python3
"""Idempotent private Mac mini helper install; no credentials required."""
import os,pathlib,plistlib,subprocess,sys,time
root=pathlib.Path(__file__).resolve().parents[1]
runtime=root/'.runtime';runtime.mkdir(exist_ok=True,mode=0o700)
(runtime/'browser').mkdir(exist_ok=True,mode=0o700)
agentdir=pathlib.Path.home()/'Library/LaunchAgents';agentdir.mkdir(exist_ok=True)
node=subprocess.check_output(['which','node'],text=True).strip()
chrome='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
services={
 'local.roku.30nama-caption-browser':[chrome,'--user-data-dir='+str(runtime/'browser'),'--remote-debugging-address=127.0.0.1','--remote-debugging-port=9226','--no-first-run','--no-default-browser-check','--no-startup-window'],
 'local.roku.30nama-captions':[node,str(root/'helper/server.mjs')]
}
for label,args in services.items():
 path=agentdir/(label+'.plist')
 config={'Label':label,'ProgramArguments':args,'WorkingDirectory':str(root),'RunAtLoad':True,'KeepAlive':True,'ThrottleInterval':10,'StandardOutPath':str(runtime/(label+'.log')),'StandardErrorPath':str(runtime/(label+'.error.log'))}
 subprocess.run(['launchctl','bootout',f'gui/{os.getuid()}/{label}'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 if '--remove' in sys.argv:
  if path.exists():path.rename(runtime/(label+'.disabled.plist'))
 else:
  path.write_bytes(plistlib.dumps(config));path.chmod(0o600)
  for attempt in range(6):
   result=subprocess.run(['launchctl','bootstrap',f'gui/{os.getuid()}',str(path)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   if result.returncode==0:break
   time.sleep(1)
  else:raise RuntimeError('LaunchAgent bootstrap failed: '+label)

 print(label, 'removed' if '--remove' in sys.argv else 'installed')
