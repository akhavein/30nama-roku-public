sub InitStoreIntegration()
    m.pendingStoreLink = invalid
    m.storeLinkSerial = 0
    m.storeLaunchReported = false
    m.storeAuthReported = false
    m.top.ObserveField("launchArgs","OnStoreLink")
    m.storeRenderTimer = m.top.findNode("storeRenderTimer")
    m.storeRenderTimer.ObserveField("fire","OnStoreRendered")
end sub

sub OnStoreLink()
    args = m.top.launchArgs
    if not IsMap(args) then return
    if not args.DoesExist("contentId") and not args.DoesExist("mediaType") then return
    link = ParseStoreLink(args)
    m.storeLinkSerial = m.storeLinkSerial + 1
    CancelRequest("store-detail")
    CancelRequest("store-stream")
    if m.page = "player" then ClosePlayback(true)
    CloseKeyboard()
    m.pendingStoreLink = link
    if link = invalid then StoreLinkFailure(): return
    if m.api.token = "" then
        ShowAccount()
        ShowLoginKeyboard("email")
        return
    end if
    ResumeStoreLink()
end sub

sub ResumeStoreLink()
    if not IsMap(m.pendingStoreLink) or m.api.token = "" then return
    link = m.pendingStoreLink
    EnterPage("store-loading","Opening your selection")
    m.status.text = "Loading..."
    m.empty.text = "Connecting to your library..."
    m.empty.visible = true
    m.nav.setFocus(true)
    Request("store-detail","single/id/" + Text(link.titleId),{})
end sub

sub HandleStoreResult(tag as String,result as Dynamic)
    link = m.pendingStoreLink
    if not IsMap(link) then return
    if not IsMap(result) or not Truth(result.success) or not IsMap(result.result) then StoreLinkFailure(): return
    data = result.result
    if tag = "store-detail" then
        title = NormalizeTitle(data)
        if title = invalid then StoreLinkFailure(): return
        if title.id <> link.titleId then StoreLinkFailure(): return
        if (link.kind = "movie" and title.isSeries) or (link.kind <> "movie" and not title.isSeries) then StoreLinkFailure(): return
        m.title = title
        m.episode = invalid
        m.lastBrowse = {page:"home",index:[0,0]}
        Request("store-stream","stream/id/" + Text(link.titleId),{})
        return
    end if
    m.startOver = false
    m.recoveringStream = false
    if link.kind = "movie" then
        if data.list <> invalid or StreamOptions(data.file).Count() = 0 then StoreLinkFailure(): return
        m.pendingStoreLink = invalid
        SetSyncMedia(data.data,data.options)
        StartPlayback(data.file,data.subtitle)
    else
        m.allEpisodes = FlattenEpisodes(data.list)
        index = StoreEpisodeIndex(link,m.allEpisodes,HistoryFind(m.history,link.titleId))
        if index < 0 or index >= m.allEpisodes.Count() then StoreLinkFailure(): return
        m.episode = m.allEpisodes[index]
        m.pendingStoreLink = invalid
        if link.kind = "season" then
            m.selectedEpisodeId = m.episode.id
            ShowEpisodes(m.episode.season)
            QueueStoreRendered()
            return
        end if
        if StreamOptions(m.episode.file).Count() = 0 then StoreLinkFailure(): return
        SetSyncMedia({id:m.episode.id},m.episode.options)
        StartPlayback(m.episode.file,m.episode.subtitle)
    end if
end sub

sub StoreLinkFailure()
    m.pendingStoreLink = invalid
    ShowHome()
    m.status.text = "That selection isn't available. You can browse or search instead."
    QueueStoreRendered()
end sub

sub QueueStoreRendered()
    if m.storeRenderTimer = invalid then return
    if m.storeLaunchReported = true then return
    m.storeRenderTimer.control = "start"
end sub

sub OnStoreRendered()
    if m.storeLaunchReported = true then return
    if IsMap(m.pendingStoreLink) then return
    if m.page = "store-loading" then return
    if m.page = "player" and m.playStarted <> true then return
    m.top.SignalBeacon("AppLaunchComplete")
    m.storeLaunchReported = true
end sub

sub ReportStoreAuthentication()
    if m.storeAuthReported = true or SafeInt(m.userId) <= 0 or m.api.token = "" then return
    if m.global = invalid then return
    dispatcher = m.global.roku_event_dispatcher
    if dispatcher = invalid then
        dispatcher = CreateObject("roSGNode","Roku_Analytics:AnalyticsNode")
        if dispatcher = invalid then return
        dispatcher.init = {RED:{}}
        m.global.AddFields({roku_event_dispatcher:dispatcher})
    end if
    dispatcher.trackEvent = {RED:{eventName:"Roku_Authenticated"}}
    m.storeAuthReported = true
end sub
