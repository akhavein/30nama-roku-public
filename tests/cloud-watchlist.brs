sub Main()
    m.checks = 0
    ids = CloudWatchIds({success:true,result:{watchlist:{post:["12",13,"0012"]}}})
    Assert(ids.Count() = 2 and ids.DoesExist("12"),"account IDs normalized and deduplicated")
    Assert(CloudWatchIds({success:true,result:{watchlist:{post:[]}}}).Count() = 0,"real empty account list is valid")
    Assert(CloudWatchIds({success:true,result:{watchlist:{post:["9999999999"]}}}) = invalid,"overflow cannot turn an ID into another title")
    for each bad in [invalid,{}, {success:false},{success:true,result:[]},{success:true,result:{watchlist:{post:"12"}}},{success:true,result:{watchlist:{post:["12x"]}}},{success:true,result:{watchlist:{post:[0]}}},{success:true,result:{watchlist:{post:[{}]}}}]
        Assert(CloudWatchIds(bad) = invalid,"invalid membership never looks like empty")
    end for
    page = CloudWatchPage({success:true,result:{page:1,pages:3,posts:[{id:12,title:"One"},invalid]}})
    Assert(page.pages = 3 and page.items.Count() = 1,"account pagination normalizes valid titles")
    Assert(CloudWatchPage({success:true,result:{page:1,pages:0,posts:[]}}).pages = 1,"empty library page count normalized")
    Assert(CloudWatchPage({success:true,result:{page:1,pages:2,posts:[invalid]}}) = invalid,"corrupt page is not an empty library")
    Assert(CloudWatchPage({success:true,result:{page:1,pages:2,posts:{}}}) = invalid,"wrong page shape rejected")
    Assert(CloudWatchPage({success:true,result:{page:"1-2",pages:2,posts:[]}}) = invalid,"malformed numeric page cannot be truncated")
    Assert(CloudGlobalTag("cloud-write") and not CloudGlobalTag("cloud-list"),"only mutation transaction survives navigation")
    m.api = {token:"fixture"}:m.title = {id:12}:m.page = "title"
    m.cloudIds = {}:m.status = {text:""}:m.cloudVerifyTimer = {control:"stop"}
    m.requests = []
    TestClick()
    Assert(m.requests.Count() = 1 and m.requests[0].tag = "cloud-check" and m.cloudMutation.wanted,"click reads before toggle")
    BeginCloudMutation()
    Assert(m.requests.Count() = 1,"double click cannot duplicate mutation")
    yes = {success:true,result:{watchlist:{post:["12"]}}}
    no = {success:true,result:{watchlist:{post:[]}}}
    HandleCloudResult("cloud-check",yes,200)
    Assert(m.requests.Count() = 1 and m.cloudMutation = invalid,"already-satisfied add never toggles it off")
    BeginCloudMutation()
    Assert(m.requests.Count() = 1,"rapid repeat after fast confirmation cannot undo the action")
    Assert(CloudWatchLabel(12) = "Remove from account Watchlist","confirmed membership drives correct label")
    TestClick()
    HandleCloudResult("cloud-check",yes,200)
    Assert(m.requests[2].tag = "cloud-write" and m.requests[2].action = "add_to_mylist/id/12/group/watchlist","remove uses verified service contract once")
    HandleCloudResult("cloud-write",invalid,0)
    Assert(m.requests[3].tag = "cloud-verify","lost ACK triggers readback, never another write")
    HandleCloudResult("cloud-verify",no,200)
    Assert(m.cloudMutation = invalid and IsMap(m.cloudIds) and not m.cloudIds.DoesExist("12"),"lost ACK with matching readback is confirmed")
    TestClick()
    HandleCloudResult("cloud-check",invalid,503)
    Assert(m.cloudMutation = invalid and m.cloudIds = invalid,"failed preflight sends no toggle and invalidates stale view")
    before = m.requests.Count():TestClick()
    Assert(m.requests.Count() = before+1 and m.requests[before].tag = "cloud-membership","unknown state requires read-only check, not a new toggle")
    HandleCloudResult("cloud-membership",no,200)
    TestClick():HandleCloudResult("cloud-check",no,200):HandleCloudResult("cloud-write",{success:true},200)
    before = m.requests.Count()
    HandleCloudResult("cloud-verify",no,200)
    Assert(m.cloudVerifyTimer.control = "start" and m.cloudMutation.verifies = 1,"mismatched readback schedules read-only retry")
    OnCloudVerifyTimer()
    Assert(m.requests[m.requests.Count()-1].tag = "cloud-verify","timer cannot replay toggle")
    HandleCloudResult("cloud-verify",invalid,503):HandleCloudResult("cloud-verify",no,200)
    Assert(m.cloudMutation = invalid and m.cloudIds = invalid,"three unconfirmed reads stop without claiming success")
    Assert(Instr(1,m.status.text,"not confirmed") > 0,"unconfirmed update is disclosed")
    m.cloudIds = {}:TestClick()
    m.page = "player":m.status.text = "watching"
    HandleCloudResult("cloud-check",no,200):HandleCloudResult("cloud-write",{success:true},200):HandleCloudResult("cloud-verify",yes,200)
    Assert(m.status.text = "watching" and m.page = "player","background completion cannot navigate or disturb playback")
    m.page = "title":m.cloudMutation = {id:12,wanted:false,verifies:0}
    HandleCloudResult("cloud-membership",no,200)
    Assert(m.cloudIds.DoesExist("12"),"older membership read cannot overwrite active transaction")
    m.api.token = "":before=m.requests.Count()
    HandleCloudResult("cloud-check",yes,200):OnCloudVerifyTimer()
    Assert(m.cloudIds = invalid and m.cloudMutation = invalid and m.requests.Count() = before,"logout blocks late writes and clears account state")
    print "REGRESSION PASS: ";m.checks;" account Watchlist assertions"
end sub
sub Request(tag as String,action as String,payload as Object)
    m.requests.Push({tag:tag,action:action})
end sub
sub RenderTitle()
end sub
sub ShowAccount()
end sub
sub Assert(ok as Boolean,label as String)
    m.checks = m.checks + 1
    if not ok then print "FAIL: ";label:stop
end sub

sub TestClick()
    m.cloudClickClock = invalid
    BeginCloudMutation()
end sub
