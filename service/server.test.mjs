import test from 'node:test';import assert from 'node:assert/strict';
import {createGateway,profileIdentity} from './server.mjs';
const good='fixture-provider-session';
async function fixture(fn,opts={}){
 let time=100000, calls=[];
 const app=createGateway({apiKey:'fixture-key',upstreamKey:'fixture-helper-key',port:0,verify:async t=>t===good?'42':null,now:()=>time,forward:async(path,body)=>{calls.push({path,body});return {status:200,body:Buffer.from('{"success":true}'),type:'application/json'}},...opts});await app.start();
 const url='http://127.0.0.1:'+app.server.address().port;
 const call=(path,body,key='',method='POST')=>fetch(url+path,{method,headers:{'Content-Type':'application/json',Authorization:'Bearer '+key},body:body===undefined?undefined:JSON.stringify(body)});
 const enroll=async(device='test-device-id-00001')=>await(await call('/session',{token:good,deviceId:device})).json();
 try{await fn({call,enroll,calls,advance:n=>time+=n})}finally{app.server.shutdown()}
}
test('provider identity must be verified, not merely HTTP 200',()=>{assert.equal(profileIdentity({success:false,result:{userid:42}}),null);assert.equal(profileIdentity({success:true,result:{userid:42}}),'42');assert.equal(profileIdentity({success:true,result:{userid:-1}}),null);for(const userid of [true,[],{},'4e2',' 42','042',null,1.2])assert.equal(profileIdentity({success:true,result:{userid}}),null);assert.equal(profileIdentity({success:true,result:{userid:'42'}}),'42')});
test('invalid auth and malformed enrollment fail without forwarding',()=>fixture(async({call,calls})=>{assert.equal((await call('/preview',{})).status,401);assert.equal((await call('/session',{token:'invalid',deviceId:'test-device-id-00001'})).status,401);assert.equal((await call('/session',{token:good,deviceId:'x',extra:1})).status,400);assert.equal(calls.length,0)}));
test('issued credential is opaque, expires, and does not expose provider token',()=>fixture(async({call,enroll,advance})=>{const s=await enroll();assert.equal(s.success,true);assert.notEqual(s.token,good);assert.equal((await call('/preview',{url:'fixture'},s.token)).status,200);advance(900001);assert.equal((await call('/preview',{},s.token)).status,401)}));
test('sign-out revokes access immediately',()=>fixture(async({call,enroll})=>{const s=await enroll();assert.equal((await call('/session',undefined,s.token,'DELETE')).status,200);assert.equal((await call('/subtitle',{},s.token)).status,401)}));
test('renewal replaces only the same account/device session',()=>fixture(async({call,enroll})=>{const first=await enroll();const other=await enroll('test-device-id-00002');const last=await enroll();assert.equal((await call('/subtitle',{},first.token)).status,401);assert.equal((await call('/subtitle',{},other.token)).status,200);assert.equal((await call('/subtitle',{},last.token)).status,200)}));
test('progress is bound to verified owner and server API key',()=>fixture(async({call,enroll,calls})=>{const s=await enroll();assert.equal((await call('/progress',{token:good,progress:{uid:43}},s.token)).status,403);assert.equal((await call('/progress',{token:'other',progress:{uid:42}},s.token)).status,403);assert.equal((await call('/progress',{apiKey:'attacker',token:good,progress:{uid:42}},s.token)).status,200);assert.equal(calls[0].body.apiKey,'fixture-key')}));
test('session storage and enrollment are bounded',()=>fixture(async({call,enroll})=>{await enroll();assert.equal((await call('/session',{token:good,deviceId:'test-device-id-00002'})).status,503)},{maxSessions:1}));
test('upstream failures do not disclose private error text',()=>fixture(async({call,enroll})=>{const s=await enroll();const r=await call('/subtitle',{},s.token);assert.equal(r.status,503);assert.deepEqual(await r.json(),{success:false})},{forward:async()=>{throw Error('private-signed-url')}}));
test('upstream configuration cannot become arbitrary network proxy',()=>{assert.throws(()=>createGateway({apiKey:'x',upstreamKey:'y',helperOrigin:'https://example.com'}));assert.throws(()=>createGateway({apiKey:'x',upstreamKey:'y',helperOrigin:'http://127.0.0.1/?x=y'}))});
test('same-account devices share a rate budget',()=>fixture(async({call,enroll})=>{
 const a=await enroll(),b=await enroll('test-device-id-00002');
 for(let i=0;i<120;i++)assert.equal((await call('/preview',{},i%2?a.token:b.token)).status,200);
 assert.equal((await call('/preview',{},b.token)).status,429);
}));
test('parallel work is bounded per session',()=>fixture(async({call,enroll})=>{
 const s=await enroll();
 const pending=[call('/preview',{},s.token),call('/preview',{},s.token)];
 await new Promise(resolve=>setTimeout(resolve,30));
 assert.equal((await call('/preview',{},s.token)).status,429);
 for(const response of await Promise.all(pending))assert.equal(response.status,200);
},{forward:async()=>{await new Promise(resolve=>setTimeout(resolve,150));return {status:200,body:Buffer.from('{}'),type:'application/json'}}}));
test('revocation affects one device without revoking its sibling',()=>fixture(async({call,enroll})=>{
 const a=await enroll();const b=await enroll('test-device-id-00002');
 await call('/session',undefined,a.token,'DELETE');
 assert.equal((await call('/preview',{},a.token)).status,401);
 assert.equal((await call('/preview',{},b.token)).status,200);
}));
