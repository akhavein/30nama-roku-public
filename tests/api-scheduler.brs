sub Main()
    m.checks = 0
    ResetQueue()
    first = Add("catalog",1)
    second = Add("detail",2)
    Assert(first.control = "run" and second.control = "stop","first request starts immediately; next waits for spacing")
    m.apiClock.elapsed = 99
    PumpApiRequests()
    Assert(second.control = "stop","nothing starts before 100ms spacing")
    m.apiClock.elapsed = 100
    PumpApiRequests()
    Assert(second.control = "run" and m.apiActive.Count() = 2,"second request uses the second slot")
    background = Add("next-prefetch",3)
    search = Add("search",4)
    auth = Add("easy-verify",5)
    m.apiClock.elapsed = 200
    PumpApiRequests()
    Assert(auth.control = "stop" and m.apiActive.Count() = 2,"queued work cannot exceed two in flight")
    ReleaseApiRequest("catalog","old-id")
    Assert(m.apiActive.Count() = 2,"stale completion cannot release a current slot")
    ReleaseApiRequest("catalog","1")
    PumpApiRequests()
    Assert(auth.control = "run" and search.control = "stop" and background.control = "stop","verification takes priority over queued search and prefetch")
    CancelRequest("detail")
    m.apiClock.elapsed = 300
    PumpApiRequests()
    Assert(search.control = "run" and m.apiActive.Count() = 2,"cancelling an active request frees one slot")
    CancelRequest("next-prefetch")
    Assert(not m.apiPending.DoesExist("next-prefetch") and not m.tasks.DoesExist("next-prefetch"),"navigation cancels pending work before transmission")
    Assert(m.apiTimer.control = "stop","empty queue stops timer even while tasks run")
    ResetQueue()
    a = Add("stream",1)
    m.apiClock.elapsed = 100
    b = Add("detail",2)
    for i = 1 to 16
        pending = Add("queued-" + Text(i),i+2)
    end for
    rejected = Add("overflow",99)
    Assert(m.apiPending.Count() = 16 and m.apiActive.Count() = 2,"queue remains bounded under saturation")
    Assert(rejected.result.error = "queue_full" and rejected.control = "stop","overflow fails locally without transmission")
    m.apiClock.elapsed = 30100
    PumpApiRequests()
    Assert(m.apiPending.Count() = 0 and pending.result.error = "queue_timeout","queued requests expire within thirty seconds")
    Assert(pending.control = "stop" and m.apiActive.Count() = 2,"queue expiry never starts or cancels unrelated active work")
    ResetQueue()
    first = Add("stream",1)
    older = Add("cloud-list",2)
    newer = Add("profile",3)
    m.apiClock.elapsed = 100
    PumpApiRequests()
    Assert(older.control = "run" and newer.control = "stop","same-priority requests preserve FIFO order")
    CancelRequest("profile")
    m.apiClock.elapsed = 400
    ReleaseApiRequest("stream","1")
    PumpApiRequests()
    Assert(newer.control = "stop","cancelled account request cannot start later")
    print "REGRESSION PASS: ";m.checks;" API scheduler assertions"
end sub
sub ResetQueue()
    m.apiPending = {}: m.apiActive = {}: m.apiNextStartMs = 0
    m.apiClock = {elapsed:0,TotalMilliseconds:function()
        return m.elapsed
    end function}
    m.apiTimer = {control:"stop"}
    m.tasks = {}
    m.top = {removeChild:sub(task)
    end sub}
end sub
function Add(tag as String, id as Integer) as Object
    task = {tag:tag,requestId:Text(id),control:"stop",unobserveField:sub(field)
    end sub}
    m.tasks[tag] = task
    EnqueueApiRequest(task)
    return task
end function
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks + 1
end sub
