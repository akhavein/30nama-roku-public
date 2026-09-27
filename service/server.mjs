// Public-facing session gateway. Keep it separate from the household helper.
import http from 'node:http';
import {randomBytes, createHash} from 'node:crypto';
const PROFILE='https://interface.30nama.com/api/v1/action/user';
const hash=x=>createHash('sha256').update(x).digest('hex');
const string=(v,n)=>typeof v==='string' && v.length>0 && v.length<=n;
export async function bounded(response,limit=160000){
  const reader=response.body?.getReader(); if(!reader)throw Error('body');
  let size=0;const parts=[];
  try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit)throw Error('size');parts.push(Buffer.from(value))}}
  catch(e){await reader.cancel();throw e}
  return Buffer.concat(parts);
}
export function profileIdentity(body){
  const id=body?.result?.userid;
  if(body?.success!==true || !['string','number'].includes(typeof id) || !/^[1-9][0-9]*$/.test(String(id)) || !Number.isSafeInteger(Number(id)))return null;
  return String(id);
}
export function createGateway({apiKey,upstreamKey,helperOrigin='http://127.0.0.1:8789',bind='127.0.0.1',port=8791,verify,forward,now=Date.now,sessionMs=15*60*1000,maxSessions=1000}={}){
  if(!string(apiKey,256)||!string(upstreamKey,256))throw Error('configuration missing');
  const helper=new URL(helperOrigin);
  if(helper.protocol!=='http:'||helper.hostname!=='127.0.0.1'||helper.pathname!=='/'||helper.search||helper.hash||helper.username||helper.password)throw Error('loopback helper required');
  const sessions=new Map(), limits=new Map();let active=0;
  function allow(key,max,window=60000){
    const time=now();let item=limits.get(key);
    if(!item||item.until<=time){item={count:0,until:time+window};limits.set(key,item)}
    // Bound unauthenticated address bookkeeping, ignoring spoofable forwarding headers.
    while(limits.size>4000)limits.delete(limits.keys().next().value);
    return ++item.count<=max;
  }
  function cleanup(){for(const [key,s] of sessions)if(s.expires<=now())sessions.delete(key)}
  const validate=verify||(async token=>{
    const response=await fetch(PROFILE,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','c-api-key':apiKey,'c-token':token,'c-platform':'Website','c-app-version':'2.0.0','c-useragent':'30nama Roku TV'},body:'',redirect:'error',signal:AbortSignal.timeout(6000)});
    if(response.status===401||response.status===403)return null;
    if(response.status!==200)throw Error('provider unavailable');
    return profileIdentity(JSON.parse((await bounded(response,131072)).toString()));
  });
  const relay=forward||(async(path,body)=>{
    const response=await fetch(helperOrigin+path,{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+upstreamKey},body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(21000)});
    return {status:response.status,body:await bounded(response,path==='/subtitle'?4000000:160000),type:response.headers.get('content-type')||'application/json'};
  });
  function answer(res,status,value,type='application/json'){
    res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});
    res.end(Buffer.isBuffer(value)?value:JSON.stringify(value));
  }
  const server=http.createServer(async(req,res)=>{
    cleanup();
    if(!['/session','/subtitle','/progress','/preview','/health'].includes(req.url))return answer(res,404,{success:false});
    if(req.method==='GET'&&req.url==='/health')return answer(res,200,{success:true,ok:true,service:'session-gateway'});
    const credential=(req.headers.authorization||'').replace(/^Bearer /,'');
    const session=sessions.get(hash(credential));
    if(req.method==='DELETE'&&req.url==='/session'){
      if(!session)return answer(res,401,{success:false});
      sessions.delete(hash(credential));return answer(res,200,{success:true});
    }
    if(req.method!=='POST')return answer(res,405,{success:false});
    if(req.url!=='/session'&&!session)return answer(res,401,{success:false});
    const limitKey=session?'u:'+session.uid:'ip:'+req.socket.remoteAddress;
    if(!allow(limitKey,session?120:30))return answer(res,429,{success:false});
    if(active>=8 || (session?.active||0)>=2)return answer(res,429,{success:false});
    active++;if(session)session.active++;
    try{
      let size=0;const parts=[];
      for await(const chunk of req){size+=chunk.length;if(size>8192){answer(res,413,{success:false});req.destroy();return}parts.push(chunk)}
      let body;try{body=JSON.parse(Buffer.concat(parts).toString())}catch{return answer(res,400,{success:false})}
      if(!body||typeof body!=='object'||Array.isArray(body))return answer(res,400,{success:false});
      if(req.url==='/session'){
        if(Object.keys(body).sort().join(',')!=='deviceId,token'||!string(body.token,2048)||!string(body.deviceId,80)||!/^[A-Za-z0-9-]{16,80}$/.test(body.deviceId))return answer(res,400,{success:false});
        if(sessions.size>=maxSessions)return answer(res,503,{success:false});
        const uid=await validate(body.token);
        if(!uid)return answer(res,401,{success:false});
        if(!allow('enroll:'+uid,12))return answer(res,429,{success:false});
        const device=hash(body.deviceId);
        const owned=[...sessions.entries()].filter(([,s])=>s.uid===uid);
        for(const [id,s] of owned)if(s.device===device)sessions.delete(id);
        const remaining=[...sessions.values()].filter(s=>s.uid===uid);
        if(remaining.length>=8||sessions.size>=maxSessions)return answer(res,429,{success:false});
        const key=randomBytes(32).toString('base64url');
        sessions.set(hash(key),{uid,device,token:body.token,expires:now()+sessionMs,active:0});
        return answer(res,200,{success:true,token:key,expiresIn:Math.floor(sessionMs/1000)});
      }
      // A revoked/expired session cannot begin new work after a slow body upload.
      if(sessions.get(hash(credential))!==session||session.expires<=now())return answer(res,401,{success:false});
      if(req.url==='/progress'){
        if(!body.progress||String(body.progress.uid)!==session.uid||body.token!==session.token)return answer(res,403,{success:false});
        body={progress:body.progress,token:session.token,apiKey};
      }
      const result=await relay(req.url,body);
      const status=[200,400,403,404,410,413,422,429].includes(result.status)?result.status:503;
      return answer(res,status,result.body,result.type);
    }catch{return answer(res,503,{success:false})}
    finally{active--;if(session)session.active--}
  });
  server.requestTimeout=25000;server.headersTimeout=10000;server.maxConnections=64;
  server.shutdown=()=>{sessions.clear();limits.clear();server.closeAllConnections();server.close()};
  return {server,start:()=>new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,bind,resolve)})};
}
if(import.meta.url===`file://${process.argv[1]}`){
  const app=createGateway({apiKey:process.env.PROVIDER_API_KEY,upstreamKey:process.env.HELPER_BEARER_TOKEN,helperOrigin:process.env.HELPER_ORIGIN||'http://127.0.0.1:8789',port:Number(process.env.GATEWAY_PORT||8791)});
  await app.start();console.log('Session gateway ready');
  for(const s of ['SIGTERM','SIGINT'])process.on(s,()=>app.server.shutdown());
}
