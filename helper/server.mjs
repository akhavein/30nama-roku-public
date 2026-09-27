import http from 'node:http';
import {timingSafeEqual} from 'node:crypto';

export function allowedSubtitle(value) {
  if (typeof value !== 'string' || value.length > 4096) return false;
  try {
    const u = new URL(value);
    return u.protocol === 'https:' && u.hostname === 'subtitle.30nama.com' && !u.username && !u.password && (!u.port || u.port === '443') && !u.hash;
  } catch { return false; }
}

class Browser {
  constructor(port,origin='about:blank') { this.origin=origin;this.port=port;this.id=0;this.pending=new Map();this.connecting=null; }
  async connect() {
    if (this.ws?.readyState === WebSocket.OPEN) return;
    if (this.connecting) return this.connecting;
    this.connecting=this.open().finally(()=>this.connecting=null);
    return this.connecting;
  }
  async open() {
    const base=`http://127.0.0.1:${this.port}`;
    const targets=await(await fetch(base+'/json/list',{signal:AbortSignal.timeout(4000)})).json();
    // Observer requests must be same-origin. A blank page triggers a CORS
    // preflight the provider rejects, even though renderer health passes.
    const origin=this.origin;
    const target=origin==='about:blank'?origin:origin+'/';
    let page=targets.find(t=>t.type==='page' && (origin==='about:blank'?t.url===target:t.url.startsWith(target)));
    if (!page) page=await(await fetch(base+'/json/new?'+encodeURIComponent(target),{method:'PUT',signal:AbortSignal.timeout(4000)})).json();
    this.ws=new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(new Error('browser-timeout')),4000);this.ws.onopen=()=>{clearTimeout(t);resolve()};this.ws.onerror=()=>{clearTimeout(t);reject(new Error('browser-unavailable'))}});
    this.ws.onmessage=e=>{const d=JSON.parse(e.data);const call=this.pending.get(d.id);if(call){clearTimeout(call.timer);this.pending.delete(d.id);d.error?call.reject(new Error('browser-command')):call.resolve(d.result)}};
    this.ws.onclose=()=>{for(const call of this.pending.values()){clearTimeout(call.timer);call.reject(new Error('browser-closed'))}this.pending.clear();this.ws=null};
    for(let attempt=0;attempt<20;attempt++){
      const result=await this.send('Runtime.evaluate',{expression:'location.origin',returnByValue:true},4000);
      if(result.result?.value===(origin==='about:blank'?'null':origin))return;
      await new Promise(resolve=>setTimeout(resolve,200));
    }
    this.ws.close();
    throw new Error('browser-origin-unavailable');
  }
  async call(method,params,timeout=22000) {
    await this.connect();
    return this.send(method,params,timeout);
  }
  send(method,params,timeout=22000) {
    return new Promise((resolve,reject)=>{const id=++this.id;const timer=setTimeout(()=>{this.pending.delete(id);reject(new Error('browser-timeout'))},timeout);this.pending.set(id,{resolve,reject,timer});this.ws.send(JSON.stringify({id,method,params}))});
  }
  async progress(value) {
    const options={method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','c-api-key':(value.apiKey||value.apikey),'c-token':value.token,'c-platform':'Website','c-app-version':'2.0.0','c-useragent':'30nama Roku TV','c-output-requests':'true'},body:new URLSearchParams(value.progress).toString(),redirect:'error'};
    const result=await this.call('Runtime.evaluate',{expression:`fetch('https://interface.30nama.com/observer/observer',{...${JSON.stringify(options)},signal:AbortSignal.timeout(18000)}).then(r=>({status:r.status}))`,awaitPromise:true,returnByValue:true});
    if(result.exceptionDetails || !result.result?.value)throw new Error('progress-fetch');
    return result.result.value;
  }
  async subtitle(url) {
    const result=await this.call('Runtime.evaluate',{
      expression:`fetch(${JSON.stringify(url)},{cache:'no-store',redirect:'error',signal:AbortSignal.timeout(18000)}).then(async r=>{const body=await r.text();return {status:r.status,body:body.length<=4000000?body:''}})`,
      awaitPromise:true,returnByValue:true
    });
    if (result.exceptionDetails || !result.result?.value) throw new Error('subtitle-fetch');
    return result.result.value;
  }
}

export function createServer({bind='127.0.0.1',port=8788,browserPort=9226,allowedClients=['127.0.0.1'],fetchSubtitle,sendProgress,bearerToken='',previewPort=0}={}) {
  const browser=new Browser(browserPort);const progressBrowser=new Browser(browserPort,'https://interface.30nama.com');const cache=new Map();const inflight=new Map();
  const retrieve=fetchSubtitle || (url=>browser.subtitle(url));
  const respond=(res,status,body,type='text/plain; charset=utf-8')=>{res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store'});res.end(body)};
  const server=http.createServer(async(req,res)=>{
    if(bearerToken){
      const actual=Buffer.from(req.headers.authorization||'');const expected=Buffer.from('Bearer '+bearerToken);
      if(actual.length!==expected.length || !timingSafeEqual(actual,expected))return respond(res,401,'Unauthorized');
    }else if(!allowedClients.includes(req.socket.remoteAddress))return respond(res,403,'Forbidden');
    if(req.method==='GET' && req.url==='/health'){
      try{if(!fetchSubtitle)await Promise.all([browser.call('Runtime.evaluate',{expression:'1',returnByValue:true},4000),progressBrowser.call('Runtime.evaluate',{expression:'1',returnByValue:true},4000)]);return respond(res,200,JSON.stringify({ok:true,service:'30nama-subtitles'}),'application/json')}
      catch{return respond(res,503,'Browser unavailable')}
    }
    if(req.method!=='POST' || !['/subtitle','/progress','/preview'].includes(req.url))return respond(res,404,'Not found');
    let raw='';try{for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>8192){respond(res,413,'Too large');req.destroy();return}}}catch{return}
    if(req.url==='/preview'){
      if(!bearerToken || !Number.isInteger(previewPort) || previewPort<1 || previewPort>65535)return respond(res,404,'Not enabled');
      if(Buffer.byteLength(raw)>6144)return respond(res,413,'Too large');
      let value;try{value=JSON.parse(raw)}catch{return respond(res,400,'Invalid request')}
      if(!value || Object.keys(value).sort().join(',')!=='seconds,url' || typeof value.url!=='string' || value.url.length>4096 || !Number.isInteger(value.seconds) || value.seconds<0 || value.seconds>21600)return respond(res,400,'Invalid request');
      try{
        const response=await fetch(`http://127.0.0.1:${previewPort}/preview`,{method:'POST',headers:{Authorization:'Bearer '+bearerToken,'Content-Type':'application/json'},body:raw,redirect:'error',signal:AbortSignal.timeout(12000)});
        const reader=response.body.getReader();let size=0;const parts=[];
        for(;;){const part=await reader.read();if(part.done)break;size+=part.value.length;if(size>140000){await reader.cancel();return respond(res,502,'Invalid preview')}parts.push(Buffer.from(part.value))}
        return respond(res,[200,401,422,429].includes(response.status)?response.status:503,Buffer.concat(parts),'application/json');
      }catch{return respond(res,503,'Preview unavailable')}
    }
    if(req.url==='/progress'){
      let value;try{value=JSON.parse(raw)}catch{return respond(res,400,'Invalid request')}
      if(!allowedProgress(value))return respond(res,400,'Invalid progress');
      try{const result=await(sendProgress|| (v=>progressBrowser.progress(v)))(value);return respond(res,result.status===200?200:502,JSON.stringify({success:result.status===200}),'application/json')}
      catch{return respond(res,503,'Progress browser unavailable')}
    }
    let url;try{url=JSON.parse(raw).url}catch{return respond(res,400,'Invalid request')}
    if(!allowedSubtitle(url))return respond(res,400,'Unsupported subtitle host');
    const hit=cache.get(url);if(hit && hit.until>Date.now())return respond(res,200,hit.body);
    try {
      if(inflight.size>=4 && !inflight.has(url))return respond(res,429,'Busy; retry shortly');
      let work=inflight.get(url);if(!work){work=retrieve(url).finally(()=>inflight.delete(url));inflight.set(url,work)}
      const result=await work;
      if(result.status!==200)return respond(res,[403,404,410].includes(result.status)?result.status:502,'Subtitle unavailable');
      if(typeof result.body!=='string' || result.body.length>4000000 || !result.body.includes('-->'))return respond(res,502,'Invalid subtitle');
      cache.set(url,{body:result.body,until:Date.now()+300000});while(cache.size>16)cache.delete(cache.keys().next().value);
      // No signed URLs, subtitle content, cookies or account credentials in logs.
      console.log(JSON.stringify({event:'subtitle',status:200,bytes:Buffer.byteLength(result.body)}));
      respond(res,200,result.body);
    } catch { respond(res,503,'Subtitle browser unavailable'); }
  });
  server.requestTimeout=25000;server.headersTimeout=10000;
  server.shutdown=()=>{browser.ws?.close();progressBrowser.ws?.close();server.close()};
  return {server,start:()=>new Promise(resolve=>server.listen(port,bind,resolve))};
}

if(import.meta.url===`file://${process.argv[1]}`){
  const app=createServer({bind:process.env.CAPTION_BIND||'127.0.0.1',port:Number(process.env.CAPTION_PORT||8788),browserPort:Number(process.env.CAPTION_BROWSER_PORT||9226),bearerToken:process.env.HELPER_BEARER_TOKEN||'',previewPort:Number(process.env.PREVIEW_PORT||0)});
  await app.start();console.log('30nama subtitle helper ready');
  for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>{app.server.shutdown();setTimeout(()=>process.exit(0),2000).unref()});
}

export function allowedProgress(value){
  if(value && value.apikey && !value.apiKey)value.apiKey=value.apikey;
  if(!value || typeof value.token!=='string' || !value.token || value.token.length>2048 || typeof value.apiKey!=='string' || !value.apiKey || value.apiKey.length>256)return false;
  const p=value.progress;if(!p || Object.keys(p).sort().join(',')!=='d,fid,k,pid,t,uid')return false;
  for(const key of ['fid','pid','uid','t','d'])if(!/^\d+$/.test(String(p[key])) || !Number.isSafeInteger(Number(p[key])))return false;
  return Number(p.fid)>0 && Number(p.pid)>0 && Number(p.uid)>0 && Number(p.t)>0 && Number(p.t)%30===0 && Number(p.d)>=Number(p.t) && typeof p.k==='string' && p.k.length>0 && p.k.length<=2048;
}
