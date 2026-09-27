sub Main()
    m.checks = 0
    m.title = NormalizeTitle({id:10,title:"Movie"})
    m.history = [HistoryEntry(m.title,invalid,120,1000,false)]
    m.syncMedia = {fid:"10",pid:"10",k:"fixture"}
    m.api = {token:"fixture"}
    m.userId = 1
    m.lastSyncPosition = -1
    m.tasks = {}
    m.progressQueue = []
    m.syncRetryTimer = {}
    m.requests = []
    SendProgress(120,1000)
    Assert(m.requests.Count() = 1 and m.tasks.progress.payload.t = "120","first checkpoint is sent")
    SendProgress(150,1000)
    SendProgress(180,1000)
    Assert(m.progressQueue.Count() = 1 and m.progressQueue[0].t = "180","in-flight progress coalesces to newest checkpoint")
    task = m.tasks.progress
    m.tasks.Delete("progress")
    m.history[0].position = 60
    HandleProgress(task,true)
    Assert(m.history[0].syncDirty,"late forward acknowledgement cannot mark intentional rewind synced")
    Assert(m.tasks.progress.payload.t = "180","completion flushes the queued checkpoint")
    m.tasks = {}
    m.progressQueue = []
    m.history[0].position = 125
    HandleProgress(task,true)
    Assert(not m.history[0].syncDirty,"acknowledgement covers matching thirty-second checkpoint")
    m.history[0].syncDirty = true
    m.history[0].position = 180
    HandleProgress(task,true)
    Assert(m.history[0].syncDirty,"late acknowledgement cannot mark newer checkpoint synced")
    m.progressQueue = [{fid:"10",pid:"10",t:"60"}]
    HandleProgress(task,false)
    Assert(m.progressQueue.Count() = 1 and m.progressQueue[0].t = "60","failed old checkpoint cannot replace queued rewind")
    Assert(m.syncRetryTimer.control = "start","failure schedules a bounded retry")
    m.progressQueue = []
    m.api.token = ""
    HandleProgress(task,false)
    FlushProgressQueue()
    Assert(not m.tasks.DoesExist("progress"),"logged-out session cannot send a queued checkpoint")
    m.progressQueue = [{fid:"10",t:"180"},{fid:"20",t:"90"}]
    m.tasks.progress = {requestId:"old-in-flight",payload:{fid:"10",t:"120"}}
    CancelOlderMediaProgress()
    Assert(m.progressQueue.Count()=1 and m.progressQueue[0].fid="20","seek discards stale queued checkpoints only for the current media")
    Assert(m.tasks.DoesExist("progress") and m.obsoleteProgressId="old-in-flight" and m.lastSyncPosition=-1,"seek serializes server writes while invalidating the stale acknowledgement")
    m.api.token="fixture"
    task=m.tasks.progress
    m.history[0].syncDirty=true
    SendProgress(60,1000)
    Assert(m.tasks.progress.requestId="old-in-flight" and m.progressQueue.Count()=2,"new rewind queues behind the in-flight server write")
    m.tasks.Delete("progress")
    HandleProgress(task,true)
    Assert(m.history[0].syncDirty and m.lastSyncPosition=-1 and m.tasks.DoesExist("progress"),"obsolete ACK cannot clean rewind and drains newer queued work")
    m.tasks={}
    m.progressQueue=[]
    m.obsoleteProgressId=task.requestId
    HandleProgress(task,false)
    Assert(m.progressQueue.Count()=0,"obsolete failed write is never retried")
    print "REGRESSION PASS: ";m.checks;" sync controller assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks+1
    print "PASS: ";label
end sub
sub Request(tag,action,payload)
    m.tasks[tag] = {payload:payload,requestId:Text(m.requests.Count()+1)}
    m.requests.Push(payload)
end sub
sub PersistHistory()
end sub

sub CancelRequest(tag)
    m.tasks.Delete(tag)
end sub
