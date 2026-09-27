sub Main()
    m.checks = 0
    m.tasks = {}
    m.top = {removeChild:sub(node)
    end sub}
    m.generation = 7
    m.page = "player"
    m.title = {id:100}
    m.episode = invalid
    m.captionCode = "fa"
    m.captionCache = {}
    m.captionNotice = {text:""}
    m.customCaptionEnabled = true
    m.captionRefreshed = false
    m.requests = 0
    m.updates = 0
    task = {requestId:"new",generation:7,result:{success:true,cues:[{start:0.0,finish:2.0,text:"fixture"}]}}
    event = {node:task,GetRoSGNode:function()
        return m.node
    end function}
    m.tasks.captions = {requestId:"other"}
    OnCaptionResult(event)
    Assert(m.tasks.captions.requestId = "other", "stale subtitle callback retains new task")
    m.tasks.captions = task
    task.generation = 6
    OnCaptionResult(event)
    Assert(not m.captionCache.DoesExist("fa"), "old title subtitle cannot populate current cache")
    task.generation = 7
    m.tasks.captions = task
    m.customCaptionEnabled = false
    OnCaptionResult(event)
    Assert(m.updates = 0, "subtitle callback after Off cannot redraw captions")
    m.customCaptionEnabled = true
    m.tasks.captions = task
    OnCaptionResult(event)
    Assert(m.captionCues.Count() = 1 and m.captionCache.fa.Count() = 1, "successful cues cached by language")
    Assert(m.updates = 1 and m.captionNotice.text = "", "successful cues render and clear loading notice")
    task.result = {success:false,status:410}
    m.tasks.captions = task
    OnCaptionResult(event)
    Assert(m.requests = 1 and m.captionRefreshed, "expired subtitle requests one fresh stream record")
    m.tasks.captions = task
    OnCaptionResult(event)
    Assert(m.requests = 1 and Instr(1,m.captionNotice.text,"couldn't") > 0, "repeated expiry stops after one retry")
    m.captionRefreshed = false
    task.result.status = 404
    m.tasks.captions = task
    OnCaptionResult(event)
    Assert(m.requests = 1, "missing subtitle does not refetch stream unnecessarily")
    task.result.status = 503
    m.tasks.captions = task
    OnCaptionResult(event)
    Assert(m.requests = 1, "offline helper exposes retry without disrupting player")
    m.loadedCode = ""
    RefreshCaptionMetadata({success:true,result:{subtitle:{en:"https://subtitle.30nama.com/en.srt",fa:"https://subtitle.30nama.com/fa.srt"}}})
    Assert(m.loadedCode = "fa" and m.loadedRefreshed, "movie refresh retries selected language")
    Assert(SidecarUrl("fa") = "https://subtitle.30nama.com/fa.srt", "movie refresh replaces signed subtitle URL")
    m.episode = {id:12}
    RefreshCaptionMetadata({success:true,result:{list:{"1":[{data:{id:11,season:1,number:1},subtitle:{fa:"https://subtitle.30nama.com/wrong.srt"}},{data:{id:12,season:1,number:2},subtitle:{fa:"https://subtitle.30nama.com/right.srt"}}]}}})
    Assert(SidecarUrl("fa") = "https://subtitle.30nama.com/right.srt", "series refresh selects exact current episode")
    RefreshCaptionMetadata({success:false})
    Assert(Instr(1,m.captionNotice.text,"refresh") > 0, "failed refresh gives recoverable message")
    m.customCaptionEnabled = false
    m.loadedCode = "unchanged"
    RefreshCaptionMetadata({success:true,result:{subtitle:{}}})
    Assert(m.loadedCode = "unchanged", "refresh after Off cannot restart subtitle task")
    print "REGRESSION PASS: ";m.checks;" subtitle controller assertions"
end sub
sub Request(tag,action,payload)
    m.requests = m.requests + 1
end sub
sub UpdateCustomCaption()
    m.updates = m.updates + 1
end sub
sub LoadSidecarCaptions(code,refreshed)
    m.loadedCode = code
    m.loadedRefreshed = refreshed
end sub
sub Assert(condition as Boolean,label as String)
    if not condition then print "FAIL: ";label: stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
