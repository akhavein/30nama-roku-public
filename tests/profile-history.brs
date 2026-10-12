sub Main()
    m.checks = 0
    m.requests = []
    m.cancelled = []
    m.api = {token:"fixture"}
    m.managedOrigin = ""
    m.storeMode = false
    m.registry = {values:{account_owner:"1"},Read:function(key)
        return m.values.Lookup(key)
    end function,Write:sub(key,value)
        m.values[key] = value
    end sub,Delete:sub(key)
        m.values.Delete(key)
    end sub,GetKeyList:function()
        return m.values.Keys()
    end function,Flush:sub()
    end sub}
    m.history = [{id:101}]
    LoadRemoteHistory()
    Assert(m.requests.Count() = 1 and m.requests[0].tag = "profile","history waits for profile ownership verification")
    Assert(m.cancelled[0] = "remote-history","refresh cancels an older history snapshot before verifying")
    for each status in [0,403,429,503]
        HandleProfile({success:true,result:{userid:2}},status)
    end for
    HandleProfile({success:true,result:{userid:0}},200)
    HandleProfile(invalid,200)
    Assert(m.requests.Count() = 1 and m.history.Count() = 1,"failed or malformed verification cannot fetch or clear history")
    Assert(m.registry.Read("account_owner") = "1","failed verification preserves the prior owner")
    HandleProfile({success:true,result:{userid:2,usertoken:"fixture"}},200)
    Assert(m.requests.Count() = 2 and m.requests[1].tag = "remote-history","verified profile starts exactly one history read")
    Assert(m.requests[1].historyCount = 0 and m.requests[1].owner = "2","old history is cleared and new ownership persisted before fetching")
    Assert(m.userId = 2 and m.syncToken = "fixture","verified profile establishes progress identity")
    m.history = [{id:202,syncDirty:true}]
    HandleProfile({success:true,result:{userid:2}},200)
    Assert(m.history.Count() = 1 and m.history[0].syncDirty,"same-owner refresh preserves unsent local progress")
    m.api.token = ""
    before = m.requests.Count()
    LoadRemoteHistory()
    Assert(m.requests.Count() = before,"signed-out state cannot start account reads")
    print "REGRESSION PASS: ";m.checks;" profile/history assertions"
end sub
sub Request(tag as String,action as String,payload as Object)
    m.requests.Push({tag:tag,historyCount:m.history.Count(),owner:m.registry.Read("account_owner")})
end sub
sub CancelRequest(tag as String)
    m.cancelled.Push(tag)
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
