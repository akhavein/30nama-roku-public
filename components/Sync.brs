' Service history integration. Local unsent progress wins over remote snapshots.
sub LoadRemoteHistory()
    if m.api.token = "" then return
    Request("profile","user",{})
    Request("remote-history","stream_watched/sortBy/1/sortBy/",{})
end sub

sub HandleRemoteHistory(result as Dynamic)
    if not IsMap(result) or not Truth(result.success) or not IsList(result.result) then
        m.syncStatus = "Website history unavailable; local progress is safe"
        return
    end if
    active = invalid
    if m.page = "player" and IsMap(m.title) then active = HistoryFind(m.history,m.title.id)
    m.history = MergeRemoteHistory(m.history,result.result)
    if active <> invalid then m.history = HistoryUpsert(m.history,active)
    PersistHistory()
    m.syncStatus = "Website history loaded"
    if m.page = "home" then RenderHome(false)
    if m.page = "continue" then ShowContinue()
end sub

sub SetSyncMedia(data as Dynamic, options as Dynamic)
    m.introMarker = IntroMarker(options)
    m.syncMedia = invalid
    m.lastSyncPosition = -1
    if not IsMap(data) or not IsMap(options) then return
    if SafeInt(data.id) <= 0 or Text(options.key) = "" then return
    m.syncMedia = {fid:Text(data.id),pid:Text(m.title.id),k:Text(options.key)}
end sub

sub SendProgress(position as Integer, duration as Integer)
    if not IsMap(m.syncMedia) or SafeInt(m.userId) <= 0 or m.api.token = "" then return
    checkpoint = Int(position / 30) * 30
    if checkpoint <= 0 or duration < checkpoint then return
    if checkpoint = m.lastSyncPosition then
        entry = HistoryFind(m.history,m.title.id)
        if entry <> invalid then
            sameEpisode = not entry.isSeries or entry.episodeId = SafeInt(m.syncMedia.fid)
            if sameEpisode and Int(entry.position / 30) * 30 = checkpoint then entry.syncDirty = false: PersistHistory()
        end if
        return
    end if
    payload = {fid:m.syncMedia.fid,pid:m.syncMedia.pid,k:m.syncMedia.k,uid:Text(m.userId),t:Text(checkpoint),d:Text(duration)}
    ' Coalesce by media identity while a previous episode/checkpoint is in flight.
    ' The queue is memory-only: signed observer keys never go into the registry.
    if not IsList(m.progressQueue) then m.progressQueue = []
    queue = []
    for each pending in m.progressQueue
        if pending.fid <> payload.fid then queue.Push(pending)
    end for
    queue.Push(payload)
    while queue.Count() > 8
        queue.Shift()
    end while
    m.progressQueue = queue
    FlushProgressQueue()
end sub

sub FlushProgressQueue()
    if m.api.token = "" or m.tasks.DoesExist("progress") then return
    if Text(m.managedOrigin) <> "" and m.helperToken = "" then EnsureManagedSession(): return
    if not IsList(m.progressQueue) then return
    if m.progressQueue.Count() = 0 then return
    payload = m.progressQueue.Shift()
    m.syncStatus = "Saving website progress..."
    print "[30nama][sync] checkpoint="; payload.t
    Request("progress","observer",payload)
end sub

sub HandleProgress(task as Object, ok as Boolean)
    ' A request may already be executing on the server when the viewer seeks.
    ' Let it finish before sending the new checkpoint, but ignore its stale ACK
    ' and never retry it. Cancelling the client cannot cancel a server write.
    if Text(task.requestId) <> "" and Text(task.requestId) = Text(m.obsoleteProgressId) then
        m.obsoleteProgressId = ""
        FlushProgressQueue()
        return
    end if
    if not ok then
        m.syncStatus = "Website sync pending; local progress is safe"
        ' Keep the latest value for this media, not a failed older checkpoint.
        if not IsList(m.progressQueue) then m.progressQueue = []
        newer = false
        for each pending in m.progressQueue
            if pending.fid = task.payload.fid then newer = true
        end for
        if not newer and m.progressQueue.Count() < 8 then m.progressQueue.Push(task.payload)
        m.progressFailures = SafeInt(m.progressFailures) + 1
        if m.progressFailures <= 3 then m.syncRetryTimer.control = "start"
        return
    end if
    if IsMap(m.syncMedia) and m.syncMedia.fid = task.payload.fid then m.lastSyncPosition = SafeInt(task.payload.t)
    entry = HistoryFind(m.history,SafeInt(task.payload.pid))
    if entry <> invalid and not entry.completed then
        sameEpisode = not entry.isSeries or entry.episodeId = SafeInt(task.payload.fid)
        if sameEpisode and Int(entry.position / 30) * 30 = SafeInt(task.payload.t) then
            entry.syncDirty = false
            PersistHistory()
        end if
    end if
    m.progressFailures = 0
    m.syncStatus = "Website progress saved"
    FlushProgressQueue()
end sub

sub OnSyncRetry()
    FlushProgressQueue()
end sub

sub CancelOlderMediaProgress()
    if not IsMap(m.syncMedia) then return
    queue = []
    if IsList(m.progressQueue) then
        for each pending in m.progressQueue
            if pending.fid <> m.syncMedia.fid then queue.Push(pending)
        end for
    end if
    m.progressQueue = queue
    active = m.tasks.Lookup("progress")
    if active <> invalid then
        if active.payload.fid = m.syncMedia.fid then m.obsoleteProgressId = active.requestId
    end if
    m.lastSyncPosition = -1
end sub

sub InvalidateSessionRequests()
    if IsMap(m.easyState) then EasyLoginFailure("Session changed. Get a new code to continue.")
    RevokeManagedSession()
    m.sessionEpoch = SafeInt(m.sessionEpoch) + 1
    m.cloudIds = invalid
    m.cloudClickClock = invalid
    m.cloudMutation = invalid
    m.cloudItems = []
    m.cloudFocusId = 0
    m.cloudPage = 1: m.cloudPages = 1
    if m.cloudVerifyTimer <> invalid then m.cloudVerifyTimer.control = "stop"
    m.storeAuthReported = false
    m.userId = 0
    m.syncToken = ""
    m.syncMedia = invalid
    m.lastSyncPosition = -1
    m.progressFailures = 0
    for each tag in ["profile","remote-history","progress","next-prefetch","stream","detail","search","cloud-list","cloud-membership","cloud-check","cloud-write","cloud-verify"]
        CancelRequest(tag)
    end for
    m.progressQueue = []
    m.obsoleteProgressId = ""
    m.searchCache = {}
    m.searchCacheOrder = []
    if m.syncRetryTimer <> invalid then m.syncRetryTimer.control = "stop"
end sub
