sub Main()
    m.checks = 0
    Assert(EasyLoginCode({success:true,result:{code:"Ab12_cd9",url:"https://30nama.com/auth/Ab12_cd9"}}) = "Ab12_cd9","valid provider code and exact official URL accepted")
    Assert(EasyLoginCode({success:true,result:{code:"Ab12_cd9",url:"https://evil.test/auth/Ab12_cd9"}}) = "","untrusted QR host rejected")
    Assert(EasyLoginCode({success:true,result:{code:"Ab12_cd9",url:"http://30nama.com/auth/Ab12_cd9"}}) = "","HTTP QR rejected")
    Assert(EasyLoginCode({success:true,result:{code:"../other",url:"https://30nama.com/auth/../other"}}) = "","path injection rejected")
    Assert(EasyLoginCode({success:true,result:{code:"Ab12_cd9",url:"https://30nama.com/auth/other"}}) = "","mismatched activation code rejected")
    Assert(EasyLoginCode({success:false,result:{code:"Ab12_cd9",url:"https://30nama.com/auth/Ab12_cd9"}}) = "","failed creation never displays a code")
    Assert(EasyLoginCode(invalid) = "","malformed response rejected")
    Assert(EasyLoginToken({success:false,result:{usertoken:"synthetic"}}) = "","failed response cannot authenticate")
    Assert(EasyLoginToken({success:true,result:{}}) = "","missing token cannot authenticate")
    Assert(ProviderRequestToken("easy-code","old-secret","new-secret") = "","code creation never uses the previous account token")
    Assert(ProviderRequestToken("easy-poll","old-secret","new-secret") = "","device polling is unauthenticated")
    Assert(ProviderRequestToken("easy-verify","old-secret","new-secret") = "new-secret","profile verification uses only newly issued token")
    Assert(ProviderRequestToken("profile","old-secret","new-secret") = "old-secret","ordinary requests retain active account")
    Reset()
    HandleEasyLogin("easy-code",{success:true,result:{code:"Ab12_cd9",url:"https://30nama.com/auth/Ab12_cd9"}},200)
    Assert(m.easyState.phase = "waiting" and m.qrCode = "Ab12_cd9","code creation enters waiting and starts local QR")
    Assert(m.api.token = "previous" and m.registry.writes = 0,"creation preserves existing account")
    m.easyClock.elapsed = 4999
    OnEasyLoginTick()
    Assert(m.calls.Count() = 0,"no polling before interval")
    m.easyClock.elapsed = 5000
    OnEasyLoginTick()
    Assert(m.calls.Count() = 1 and m.calls[0].tag = "easy-poll","poll at bounded interval")
    m.easyClock.elapsed = 10000
    OnEasyLoginTick()
    Assert(m.calls.Count() = 1,"never overlap an in-flight poll")
    m.tasks.Delete("easy-poll")
    HandleEasyLogin("easy-poll",{success:false},200)
    Assert(m.easyState.phase = "waiting" and m.registry.writes = 0,"unapproved code remains pending")
    HandleEasyLogin("easy-poll",{success:false},429)
    Assert(m.easyState.nextPollMs = 20000,"rate limiting backs off")
    for n = 1 to 10
        HandleEasyLogin("easy-poll",{success:false},503)
    end for
    Assert(m.easyState.nextPollMs = 40000,"retry backoff capped at thirty seconds")
    HandleEasyLogin("easy-poll",{success:true,result:{usertoken:"new-synthetic-token"}},200)
    Assert(m.easyState.phase = "verifying" and m.easyCandidate = "new-synthetic-token","approval awaits independent profile validation")
    Assert(m.api.token = "previous" and m.registry.writes = 0,"unverified token is not persisted")
    HandleEasyLogin("easy-verify",{success:true,result:{userid:42}},200)
    Assert(m.api.token = "new-synthetic-token" and m.registry.values.session_token = "new-synthetic-token","verified session persisted")
    Assert(m.registry.values.account_owner = "42" and m.cleared,"account replacement clears old local viewing data")
    Assert(m.page = "account" and m.easyState = invalid and m.easyCandidate = "","success closes linking and clears transient secrets")
    Assert(m.resumed and m.loaded,"success resumes requested content and loads account history")
    writes = m.registry.writes
    HandleEasyLogin("easy-verify",{success:true,result:{userid:42}},200)
    Assert(m.registry.writes = writes,"duplicate completion does not persist twice")
    Reset()
    m.easyState.phase = "waiting": m.easyState.code = "Ab12_cd9"
    m.easyClock.elapsed = 300000
    HandleEasyLogin("easy-poll",{success:true,result:{usertoken:"late-token"}},200)
    Assert(m.api.token = "previous" and m.registry.writes = 0 and m.easyState = invalid,"approval at expiry cannot replace account")
    Reset()
    m.easyState.phase = "waiting"
    HandleEasyLogin("easy-poll",{success:false},410)
    Assert(m.easyState = invalid and m.easyTimer.control = "stop","provider expiration stops polling")
    Reset()
    m.easyState.phase = "verifying": m.easyCandidate = "unverified"
    HandleEasyLogin("easy-verify",{success:true,result:{userid:0}},200)
    Assert(m.registry.writes = 0 and m.api.token = "previous","invalid profile cannot replace account")
    Reset()
    m.pendingStoreLink = {id:1}
    m.easyButtons.itemSelected = 1
    OnEasyLoginButton()
    HandleEasyLogin("easy-poll",{success:true,result:{usertoken:"cancelled-token"}},200)
    Assert(m.pendingStoreLink = invalid and m.api.token = "previous" and m.easyState = invalid,"cancel clears handoff and ignores late approval")
    Reset()
    m.easyClock.elapsed = 300001
    OnEasyLoginTick()
    Assert(m.easyTimer.control = "stop" and m.easyState = invalid,"deadline stops all login work without a response")
    print "REGRESSION PASS: ";m.checks;" Easy Login assertions"
end sub
sub Reset()
    m.page = "easy-login"
    m.easyState = {phase:"creating",code:"",nextPollMs:5000,failures:0}
    m.easyClock = {elapsed:0,TotalMilliseconds:function()
        return m.elapsed
    end function}
    m.api = {token:"previous"}
    m.calls = []: m.tasks = {}
    m.easyPanel = {visible:true}:m.easyCode = {}:m.easyCountdown = {}:m.status = {}
    m.easyTimer = {control:"start"}: m.easyQr = {uri:""}
    m.easyButtons = {itemSelected:0,setFocus:sub(value)
    end sub}
    m.registry = {values:{account_owner:"1"},writes:0,Read:function(key)
        return m.values.Lookup(key)
    end function,Write:sub(key,value)
        m.writes = m.writes + 1
        m.values[key] = value
    end sub,Flush:sub()
    end sub}
    m.cleared = false: m.resumed = false: m.loaded = false
end sub
sub Request(tag as String,action as String,payload as Object)
    m.calls.Push({tag:tag,action:action})
    m.tasks[tag] = true
end sub
sub CancelRequest(tag as String)
    m.tasks.Delete(tag)
end sub
sub StartEasyQr(code as String)
    m.qrCode = code
end sub
sub InvalidateSessionRequests()
end sub
sub ShowAccount()
    StopEasyLogin()
    m.page = "account"
end sub
sub ClearLocalViewingData()
    m.cleared = true
end sub
sub LoadRemoteHistory()
    m.loaded = true
end sub
sub ResumeStoreLink()
    m.resumed = true
end sub
sub ReportStoreAuthentication()
end sub
sub EnsureManagedSession()
end sub
sub QueueStoreRendered()
end sub
sub Assert(ok as Boolean,message as String)
    if not ok then print "FAIL: ";message: stop
    m.checks = m.checks + 1
end sub
