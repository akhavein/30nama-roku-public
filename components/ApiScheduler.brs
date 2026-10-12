' A bounded scene-thread queue. Task retries retain their slot; mutations are
' never replayed by this scheduler. Other media Tasks have their own bounds.
sub InitApiScheduler()
    m.apiPending = {}
    m.apiActive = {}
    m.apiClock = CreateObject("roTimespan")
    m.apiClock.Mark()
    m.apiNextStartMs = 0
    m.apiTimer = m.top.findNode("apiTimer")
    m.apiTimer.observeField("fire","PumpApiRequests")
end sub

function ApiRequestPriority(tag as String) as Integer
    if Left(tag,5) = "easy-" or Left(tag,6) = "store-" or tag = "login" or tag = "stream" then return 0
    if tag = "profile" or tag = "progress" or Left(tag,6) = "cloud-" then return 1
    if tag = "search" or tag = "detail" then return 2
    if tag = "next-prefetch" then return 4
    return 3
end function

sub EnqueueApiRequest(task as Object)
    if m.apiPending.Count() >= 16 then
        task.httpStatus = 0
        task.result = {success:false,error:"queue_full"}
        return
    end if
    m.apiPending[task.tag] = {task:task,queuedAt:m.apiClock.TotalMilliseconds(),sequence:SafeInt(task.requestId)}
    m.apiTimer.control = "start"
    PumpApiRequests()
end sub

sub ReleaseApiRequest(tag as String, requestId as String)
    if IsMap(m.apiPending) then
        pending = m.apiPending.Lookup(tag)
        if pending <> invalid then
            if pending.task.requestId = requestId then m.apiPending.Delete(tag)
        end if
    end if
    if IsMap(m.apiActive) then
        if m.apiActive.Lookup(tag) = requestId then m.apiActive.Delete(tag)
    end if
    if m.apiTimer <> invalid and IsMap(m.apiPending) then
        if m.apiPending.Count() = 0 then m.apiTimer.control = "stop" else m.apiTimer.control = "start"
    end if
end sub

sub PumpApiRequests()
    now = m.apiClock.TotalMilliseconds()
    best = invalid
    for each tag in m.apiPending.Keys()
        pending = m.apiPending[tag]
        task = pending.task
        if now - pending.queuedAt >= 30000 then
            m.apiPending.Delete(tag)
            task.httpStatus = 0
            task.result = {success:false,error:"queue_timeout"}
        else
            if best = invalid then
                best = pending
            else
                priority = ApiRequestPriority(tag)
                bestPriority = ApiRequestPriority(best.task.tag)
                if priority < bestPriority or (priority = bestPriority and pending.sequence < best.sequence) then best = pending
            end if
        end if
    end for
    if best <> invalid and m.apiActive.Count() < 2 and now >= m.apiNextStartMs then
        task = best.task
        m.apiPending.Delete(task.tag)
        m.apiActive[task.tag] = task.requestId
        m.apiNextStartMs = now + 100
        task.control = "run"
    end if
    if m.apiPending.Count() = 0 then m.apiTimer.control = "stop"
end sub
