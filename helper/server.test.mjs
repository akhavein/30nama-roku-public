import test from 'node:test';import assert from 'node:assert/strict';
import {allowedSubtitle,createServer} from './server.mjs';
test('only the service subtitle origin is accepted',()=>{
 assert(allowedSubtitle('https://subtitle.30nama.com/signed/file.srt'));
 for(const url of ['http://subtitle.30nama.com/x','https://subtitle.30nama.com.evil.test/x','https://user:pass@subtitle.30nama.com/x','https://127.0.0.1/x','file:///etc/passwd','https://subtitle.30nama.com:8080/x','https://subtitle.30nama.com/x#fragment','not a URL'])assert.equal(allowedSubtitle(url),false);
});
test('fetch, cache, failure mapping and validation',async()=>{
 let calls=0;
 const app=createServer({bind:'127.0.0.1',port:0,fetchSubtitle:async url=>{calls++;return url.endsWith('expired')?{status:410,body:''}:url.endsWith('html')?{status:200,body:'<html>verification</html>'}:{status:200,body:'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest'}}});
 await app.start();const base=`http://127.0.0.1:${app.server.address().port}`;
 const post=url=>fetch(base+'/subtitle',{method:'POST',body:JSON.stringify({url})});
 try{
  assert.equal((await fetch(base+'/health')).status,200);
  assert.equal((await post('https://127.0.0.1/private')).status,400);
  const url='https://subtitle.30nama.com/test';assert.equal((await post(url)).status,200);assert.equal((await post(url)).status,200);assert.equal(calls,1);
  assert.equal((await post('https://subtitle.30nama.com/expired')).status,410);
  assert.equal((await post('https://subtitle.30nama.com/html')).status,502);
  assert.equal((await fetch(base+'/other')).status,404);
 }finally{app.server.shutdown()}
});
test('other LAN clients are denied',async()=>{
 const app=createServer({bind:'127.0.0.1',port:0,allowedClients:[],fetchSubtitle:async()=>{throw Error('should not run')}});await app.start();
 try{assert.equal((await fetch(`http://127.0.0.1:${app.server.address().port}/health`)).status,403)}finally{app.server.shutdown()}
});

test('progress bridge validates payload and never permits arbitrary destinations',async()=>{
 const app=createServer({bind:'127.0.0.1',port:0,sendProgress:async value=>({status:200})});await app.start();
 const base=`http://127.0.0.1:${app.server.address().port}`;
 const value={token:'fixture-token',apiKey:'fixture-key',progress:{fid:'1',pid:'2',uid:'3',t:'30',d:'600',k:'fixture-signature'}};
 const post=v=>fetch(base+'/progress',{method:'POST',body:JSON.stringify(v)});
 try{
  assert.equal((await post(value)).status,200);
  assert.equal((await post({...value,token:''})).status,400);
  assert.equal((await post({...value,progress:{...value.progress,t:'31'}})).status,400);
  assert.equal((await post({...value,progress:{...value.progress,url:'https://evil.test'}})).status,400);
  assert.equal((await post({...value,progress:{...value.progress,d:'0'}})).status,400);
 }finally{app.server.shutdown()}
});
test('remote helper requires exact bearer authentication even for health',async()=>{
 const app=createServer({bind:'127.0.0.1',port:0,bearerToken:'fixture-auth',fetchSubtitle:async()=>({status:200,body:'WEBVTT\n00:00:00.000 --> 00:00:01.000\nTest'})});await app.start();const base=`http://127.0.0.1:${app.server.address().port}`;
 try{assert.equal((await fetch(base+'/health')).status,401);assert.equal((await fetch(base+'/health',{headers:{Authorization:'Bearer wrong'}})).status,401);assert.equal((await fetch(base+'/health',{headers:{Authorization:'Bearer fixture-auth'}})).status,200)}finally{app.server.shutdown()}
});

test('preview is optional, authenticated, bounded, and isolated from subtitles',async()=>{
 const http=await import('node:http');let calls=0;let auth='';let mode='ok';
 const worker=http.createServer(async(req,res)=>{calls++;auth=req.headers.authorization;for await(const chunk of req){};if(mode==='large'){res.end('x'.repeat(140001));return}res.writeHead(mode==='busy'?429:200,{'Content-Type':'application/json'});res.end(JSON.stringify({success:true,seconds:5,jpeg:'fixture'}))});
 await new Promise(resolve=>worker.listen(0,'127.0.0.1',resolve));
 const app=createServer({bind:'127.0.0.1',port:0,bearerToken:'fixture-auth',previewPort:worker.address().port,fetchSubtitle:async()=>({status:200,body:'WEBVTT\n00:00:00.000 --> 00:00:01.000\nTest'})});await app.start();
 const base=`http://127.0.0.1:${app.server.address().port}`;
 const post=(body,token='fixture-auth')=>fetch(base+'/preview',{method:'POST',headers:{Authorization:'Bearer '+token},body:JSON.stringify(body)});
 try{
  const value={url:'https://media.example.test/master',seconds:5};
  assert.equal((await post(value,'wrong')).status,401);assert.equal(calls,0);
  assert.equal((await post({...value,token:'do-not-forward'})).status,400);assert.equal(calls,0);
  assert.equal((await post(value)).status,200);assert.equal(auth,'Bearer fixture-auth');
  mode='busy';assert.equal((await post(value)).status,429);
  mode='large';assert.equal((await post(value)).status,502);
  assert.equal((await fetch(base+'/subtitle',{method:'POST',headers:{Authorization:'Bearer fixture-auth'},body:JSON.stringify({url:'https://subtitle.30nama.com/test'})})).status,200);
  assert.equal((await post({...value,url:'x'.repeat(6200)})).status,413);
 }finally{app.server.shutdown();worker.close()}
 const off=createServer({bind:'127.0.0.1',port:0,bearerToken:'fixture-auth'});await off.start();
 try{assert.equal((await fetch(`http://127.0.0.1:${off.server.address().port}/preview`,{method:'POST',headers:{Authorization:'Bearer fixture-auth'},body:'{}'})).status,404)}finally{off.server.shutdown()}
});
