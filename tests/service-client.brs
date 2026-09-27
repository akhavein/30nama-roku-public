sub Main()
    m.checks = 0
    m.managedOrigin = ""
    m.helperToken = "manual-pairing-fixture"
    RevokeManagedSession()
    Assert(m.helperToken = "manual-pairing-fixture","unmanaged pairing unchanged by session gateway")
    m.managedOrigin = "https://service.example.test"
    m.managedEpoch = 2
    m.managedTask = {epoch:3}
    event = {node:{epoch:1,result:{success:true,token:"late"}},GetRoSGNode:function()
        return m.node
    end function}
    OnManagedSession(event)
    Assert(m.helperToken = "manual-pairing-fixture","late prior-account session cannot replace active credential")
    m.registry = {values:{history_v2:"private",watchlist:"private",caption_offset_1_2:"5",remote_step:"15",session_token:"fixture",service_device_id:"random-id"},Delete:sub(key)
        m.values.Delete(key)
    end sub,Write:sub(key,value)
        m.values[key]=value
    end sub,GetKeyList:function()
        return m.values.Keys()
    end function,Flush:sub()
    end sub}
    ClearLocalViewingData()
    Assert(m.history.Count()=0 and m.watchlist.Count()=0 and m.recentSearches.Count()=0,"clear resets local account-associated viewing collections")
    Assert(not m.registry.values.DoesExist("caption_offset_1_2"),"clear removes per-media caption offsets")
    Assert(m.registry.values.session_token="fixture" and m.registry.values.remote_step="15","clear is not logout and preserves non-viewing settings")
    Assert(m.registry.values.service_device_id="random-id","clear preserves app installation identity")
    print "REGRESSION PASS: ";m.checks;" service client assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks=m.checks+1
    print "PASS: ";label
end sub
