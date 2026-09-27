function ManagedServiceOrigin() as String
    ' Release tooling substitutes the operator's public HTTPS origin in ZIP only.
    return ""
end function

sub InitManagedService()
    m.managedOrigin = ManagedServiceOrigin()
    m.managedEpoch = 0
    m.managedUntil = 0
    m.managedNextAttempt = 0
    m.managedTask = invalid
    m.managedDevice = m.registry.Read("service_device_id")
    if m.managedDevice = "" then
        m.managedDevice = CreateObject("roDeviceInfo").GetRandomUUID()
        m.registry.Write("service_device_id",m.managedDevice)
        m.registry.Flush()
    end if
    if m.managedOrigin <> "" then
        m.helperUrl = m.managedOrigin
        m.helperToken = ""
        timer = m.top.findNode("serviceTimer")
        timer.ObserveField("fire","EnsureManagedSession")
        timer.control = "start"
    end if
end sub

sub EnsureManagedSession()
    if Text(m.managedOrigin) = "" or m.api.token = "" or SafeInt(m.userId) <= 0 then return
    if m.managedTask <> invalid then return
    now = CreateObject("roDateTime").AsSeconds()
    if now < SafeInt(m.managedNextAttempt) then return
    if now < SafeInt(m.managedUntil) - 120 then return
    m.managedEpoch = SafeInt(m.managedEpoch) + 1
    task = CreateObject("roSGNode","SessionTask")
    task.origin = m.managedOrigin
    task.token = m.api.token
    task.deviceId = m.managedDevice
    task.epoch = m.managedEpoch
    task.ObserveField("result","OnManagedSession")
    m.managedTask = task
    m.top.AppendChild(task)
    task.control = "run"
end sub

sub OnManagedSession(event as Object)
    task = event.GetRoSGNode()
    if m.managedTask = invalid then return
    if task.epoch <> m.managedEpoch then return
    task.UnobserveField("result")
    m.top.RemoveChild(task)
    m.managedTask = invalid
    data = task.result
    now = CreateObject("roDateTime").AsSeconds()
    m.managedNextAttempt = now + 60
    if not ValidServiceSession(data) then
        m.helperStatus = "Temporarily unavailable; playback and local progress still work"
        return
    end if
    m.helperToken = data.token
    m.managedUntil = now + SafeInt(data.expiresIn)
    m.helperStatus = "Ready"
    FlushProgressQueue()
    if m.reauthCaption = true then
        m.reauthCaption = false
        if m.page = "player" and m.customCaptionEnabled = true then LoadSidecarCaptions(m.captionCode,m.captionRefreshed)
    end if
end sub

sub RevokeManagedSession()
    if Text(m.managedOrigin) = "" then return
    m.managedEpoch = SafeInt(m.managedEpoch) + 1
    if m.managedTask <> invalid then
        m.managedTask.UnobserveField("result")
        m.managedTask.control = "stop"
        m.top.RemoveChild(m.managedTask)
        m.managedTask = invalid
    end if
    if m.helperToken <> "" then
        task = CreateObject("roSGNode","SessionTask")
        task.origin = m.managedOrigin
        task.token = m.helperToken
        task.revoke = true
        task.ObserveField("result","OnManagedRevoke")
        m.top.AppendChild(task)
        task.control = "run"
    end if
    m.helperToken = ""
    m.managedUntil = 0
    m.managedNextAttempt = 0
end sub

sub OnManagedRevoke(event as Object)
    task = event.GetRoSGNode()
    task.UnobserveField("result")
    m.top.RemoveChild(task)
end sub

sub ClearLocalViewingData()
    m.history = []
    m.episodeHistory = []
    m.watchlist = []
    m.recentSearches = []
    m.searchCache = {}
    m.searchCacheOrder = []
    m.searchItems = []
    m.searchSnapshot = invalid
    m.cloudItems = []
    m.cloudIds = invalid
    m.title = invalid
    m.episode = invalid
    for each key in ["history_v2","episode_history_v1","watchlist","recent_searches","last_resume_id","last_resume_parent_id","last_resume_label"]
        m.registry.Delete(key)
    end for
    for each key in m.registry.GetKeyList()
        if Left(key,15) = "caption_offset_" or Left(key,7) = "resume_" then m.registry.Delete(key)
    end for
    m.registry.Write("history_v2","[]")
    m.registry.Write("episode_history_v1","[]")
    m.registry.Flush()
end sub

sub ConfirmClearLocalData()
    dialog = CreateObject("roSGNode","Dialog")
    dialog.title = "Clear viewing data on this TV?"
    dialog.message = "Removes local progress, recent searches and your TV-only Watchlist. Your account history and account Watchlist are not deleted and may return when refreshed."
    dialog.buttons = ["Cancel","Clear on this TV"]
    dialog.ObserveField("buttonSelected","OnClearLocalData")
    m.top.dialog = dialog
end sub

sub OnClearLocalData(event as Object)
    dialog = event.GetRoSGNode()
    selected = event.GetData()
    dialog.UnobserveField("buttonSelected")
    dialog.close = true
    if selected <> 1 then return
    CancelRequest("remote-history")
    ClearLocalViewingData()
    ShowAccount()
    m.status.text = "Local viewing data cleared; account data was not deleted"
end sub

sub RefreshManagedSession()
    if Text(m.managedOrigin) = "" then return
    m.helperToken = ""
    m.managedUntil = 0
    EnsureManagedSession()
end sub
