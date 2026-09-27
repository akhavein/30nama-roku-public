' Included only in generated build/qa-app, never the shipping ZIP.
sub OnQaScenario()
    m.autoplay = false
    scenario = m.top.qaScenario
    m.qaScenario = scenario
    if Left(scenario,9) = "autoplay:" then m.autoplay = true: scenario = "stream:" + Mid(scenario,10)
    m.api.token = "fixture"
    if scenario = "store-signedout" then m.api.token = ""
    m.history = []
    m.episodeHistory = []
    m.remote_step = 10: m.remote_skip = 30: m.remote_replay = 10
    m.stillMinutes = 0
    if Left(scenario,8) = "preview:" then
        mode = Mid(scenario,9)
        m.helperUrl = "http://QA_HOST_PLACEHOLDER:8765/" + mode
        m.helperToken = "fixture-preview"
        if mode = "unpaired" then m.helperToken = ""
        if mode = "sleep" then m.sleepMinutes = 0.15: m.sleepClock = CreateObject("roTimespan"): m.sleepClock.Mark()
        scenario = "stream:111"
    end if
    if scenario = "v14-ledger" then
        title = NormalizeTitle({id:201,title:"Episode ledger",is_series:true})
        m.episodeHistory = CleanEpisodeHistory([{id:201,episodeId:11,position:7,duration:12,completed:false},{id:201,episodeId:12,position:6,duration:12,completed:false}])
        m.history = [HistoryEntry(title,{id:12,season:1,number:2,title:"Second"},6,12,false)]
        m.registry.Write("episode_history_v1",FormatJson(m.episodeHistory))
        PersistHistory()
        scenario = "stream:201"
    else if scenario = "v14-ledger-reload" then
        m.episodeHistory = CleanEpisodeHistory(ParseJson(m.registry.Read("episode_history_v1")))
        m.history = CleanHistory(ParseJson(m.registry.Read("history_v2")))
        scenario = "stream:201"
    else if scenario = "v14-sleep" then
        m.sleepMinutes = 0.2
        m.sleepClock = CreateObject("roTimespan"): m.sleepClock.Mark()
        scenario = "stream:111"
    else if scenario = "v14-caption-reset" then
        m.captionContrast = "standard": m.captionPosition = "bottom"
        m.registry.Write("caption_contrast","standard")
        m.registry.Write("caption_position","bottom")
        scenario = "stream:104"
    else if scenario = "v14-remote" then
        for each kind in ["step","skip","replay"]
            m["remote_" + kind] = SafeInt(m.registry.Read("remote_" + kind))
        end for
        scenario = "stream:111"
    else if scenario = "v14-sleep-countdown" then
        m.autoplay = true
        m.sleepMinutes = 0.3
        m.sleepClock = CreateObject("roTimespan"): m.sleepClock.Mark()
        scenario = "stream:201"
    else if scenario = "v14-sleep-loading" then
        m.sleepMinutes = 0.05
        m.sleepClock = CreateObject("roTimespan"): m.sleepClock.Mark()
        scenario = "stream:118"
    else if scenario = "v14-still" then
        m.stillMinutes = 1: m.watchSeconds = 50
        scenario = "stream:111"
    end if
    if scenario = "caption-cycle" then
        m.qaModeCycle = true
        m.qaModeIteration = 0
        scenario = "stream:104"
        m.registry.Write("subtitle_preference","fa")
        m.registry.Flush()
    end if
    if Left(scenario,6) = "cloud:" then
        mode = Mid(scenario,7)
        m.api.base = "http://QA_HOST_PLACEHOLDER:8765/api/case/" + mode
        m.cloudItems = []:m.cloudIds = invalid:m.cloudPage = 1:m.cloudPages = 1
        m.cloudFilter = "all":m.cloudSort = "added"
        if mode = "signedout" then m.api.token = ""
        m.watchlist = NormalizeTitles([{id:888,title:"TV-only sentinel"}])
        ShowCloudWatchlist()
    else if scenario = "v14-preferences" or scenario = "v14-preferences-reload" then
        if scenario = "v14-preferences-reload" then
            for each kind in ["step","skip","replay"]
                m["remote_" + kind] = SafeInt(m.registry.Read("remote_" + kind))
            end for
            m.stillMinutes = SafeInt(m.registry.Read("still_minutes"))
        end if
        ShowPreferences()
    else if scenario = "v14-watch" then
        m.watchlist = NormalizeTitles([{id:101,title:"Zebra Movie"},{id:201,title:"Alpha Series",is_series:true},{id:104,title:"Beta Movie"}])
        m.registry.Write("watchlist",FormatJson(m.watchlist))
        m.watchFilter = "all": m.watchSort = "added"
        ShowWatchlist()
    else if scenario = "account-prefs" then
        m.autoplay = m.registry.Read("autoplay") <> "off"
        ShowAccount()
    else if Left(scenario,5) = "diag:" then
        m.helperUrl = "http://QA_HOST_PLACEHOLDER:8765/" + Mid(scenario,6)
        m.helperToken = ""
        ShowDiagnostics()
    else if scenario = "recent-reset" then
        m.recentSearches = []
        m.searchQuery = "pages"
        StartSearch(1)
    else if scenario = "recent-reload" then
        ShowRecentSearches()
    else if scenario = "watchlist" then
        m.watchlist = []
        m.registry.Write("watchlist","[]")
        ShowTitle(NormalizeTitle({id:101,title:"Saved fixture"}),false)
    else if scenario = "watchlist-reload" then
        ShowWatchlist()
    else if scenario = "search-blank" then
        m.searchQuery = ""
        ShowSearchKeyboard()
        m.keyboard.text = "   "
        OnSearchKeyboard()
    else if scenario = "search-keyboard" then
        m.searchQuery = ""
        ShowSearchKeyboard()
    else if scenario = "search-race" then
        m.searchQuery = "cancel"
        StartSearch(1)
        m.searchQuery = "fresh"
        StartSearch(1)
    else if scenario = "search-recovery" then
        m.searchQuery = "flaky"
        StartSearch(1)
    else if Left(scenario,7) = "search:" then
        m.searchQuery = Mid(scenario,8)
        StartSearch(1)
    else if scenario = "empty-continue" then
        ShowContinue()
    else if scenario = "verify-unauthorized" then
        ShowAccount()
        m.loginEmail = "qa@example.invalid"
        ShowLoginKeyboard("otp")
        m.keyboard.text = "401401"
        OnLoginKeyboard()
    else if Left(scenario,5) = "login" then
        m.api.token = ""
        ShowAccount()
        if scenario <> "login-otp-invalid" and scenario <> "login-success" then ShowLoginKeyboard("email")
        if scenario = "login-empty" then OnLoginKeyboard()
        if scenario = "login-invalid" then m.keyboard.text = "invalid": OnLoginKeyboard()
        if scenario = "login-send" then m.keyboard.text = "qa@example.invalid": OnLoginKeyboard()
        if scenario = "login-otp-invalid" or scenario = "login-success" then
            m.loginEmail = "qa@example.invalid"
            ShowLoginKeyboard("otp")
            m.keyboard.text = "999999"
            if scenario = "login-success" then m.keyboard.text = "123456"
            OnLoginKeyboard()
        end if
    else if Left(scenario,7) = "stream:" then
        id = SafeInt(Mid(scenario,8))
        if id = 109 then m.bufferTimer.duration = 3
        if id = 105 or id = 106 or id = 107 or id = 108 or id = 117 then m.registry.Write("subtitle_preference","fa"): m.registry.Flush()
        ShowTitle(NormalizeTitle({id:id,title:"QA title",is_series:id >= 200}), false)
        m.streamIntent = "seasons"
        if m.qaScenario = "v14-sleep-countdown" then m.streamIntent = "episode": m.requestedEpisodeId = 11
        m.startOver = false
        Request("stream","stream/id/" + Text(id),{})
    end if
    if scenario = "font" then
        label = m.top.CreateChild("Label")
        label.translation = [80,320]
        label.width = 1120
        label.height = 120
        label.horizAlign = "center"
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/components/fonts/Caption-Regular.ttf"
        font.size = 38
        label.font = font
        label.text = ArabicVisual("آزمایش زیرنویس فارسی (2026)")
    end if
    m.qaTimer = CreateObject("roSGNode","Timer")
    m.qaTimer.duration = 1
    m.qaTimer.repeat = true
    m.qaTimer.observeField("fire","QaState")
    m.top.appendChild(m.qaTimer)
    m.qaTimer.control = "start"
end sub
sub QaState()
    if m.qaModeCycle = true and m.player.state = "playing" then
        m.qaModeIteration = m.qaModeIteration + 1
        if m.qaModeIteration <= 18 then
            m.player.suppressCaptions = (m.qaModeIteration mod 2) = 0
            if (m.qaModeIteration mod 3) = 0 then m.player.globalCaptionMode = "On" else m.player.globalCaptionMode = "Off"
        else
            m.qaModeCycle = false
            m.player.suppressCaptions = false
            LoadSidecarCaptions("fa")
        end if
    end if
    state = {scenario:m.qaScenario,page:m.page,status:m.status.text,player:m.player.state,position:SafeInt(m.player.position),tracks:m.trackPicker.visible,empty:m.empty.text,railFocus:m.rails.rowItemFocused,trackFocus:m.trackList.hasFocus(),buttonsFocus:m.controlButtons.hasFocus(),currentCaption:m.player.globalCaptionMode,selectedCaption:m.player.subtitleTrack = m.player.currentSubtitleTrack,control:m.controlIndex,history:m.history,searchPage:m.searchPage,searchPages:m.searchPages,results:m.searchItems.Count(),signedIn:m.api.token <> ""}
    state.cloudknown = IsMap(m.cloudIds)
    state.cloudids = []
    if IsMap(m.cloudIds) then state.cloudids = m.cloudIds.Keys()
    state.cloudpending = IsMap(m.cloudMutation)
    state.cloudpage = m.cloudPage
    state.cloudpages = m.cloudPages
    state.cloudactions = m.cloudActions
    state.titlelabels = []
    if m.actions.content <> invalid then
        for each node in m.actions.content.GetChildren(-1,0)
            state.titlelabels.Push(node.title)
        end for
    end if
    state.scenevisible = m.scenePreview.visible
    state.scenetarget = m.previewTarget
    state.sceneimage = m.previewImage.visible
    state.scenestatus = m.previewStatus.text
    state.sceneserial = m.previewSerial
    state.sceneload = m.previewImage.loadStatus
    state.introprompt = m.introPrompt.visible
    state.introtarget = ActiveIntroTarget()
    state.controls = m.controls.visible
    state.controlactions = m.controlActions
    state.episodehistory = m.episodeHistory
    state.watchfocusid = m.watchFocusId
    state.watchfilter = m.watchFilter
    state.watchsort = m.watchSort
    state.searchfilter = m.searchFilter
    state.searchsort = m.searchSort
    state.sleepminutes = m.sleepMinutes
    state.stillminutes = m.stillMinutes
    state.watchprompt = m.watchPrompt.visible
    state.remotestep = RemoteSeconds("step")
    state.remoteskip = RemoteSeconds("skip")
    state.remotereplay = RemoteSeconds("replay")
    state.captioncontrast = m.captionContrast
    state.captionposition = m.captionPosition
    state.visibleids = []
    if m.browse.visible and m.railItems.Count() > 0 then
        for each item in m.railItems[0]
            state.visibleids.Push(item.id)
        end for
    end if
    state.searchactions = m.searchActions
    state.tracklabels = []
    if IsList(m.trackOptions) then
        for each option in m.trackOptions
            state.tracklabels.Push(option.label)
        end for
    end if
    state.trackindex = m.trackList.itemFocused
    state.railsfocus = m.rails.hasFocus()
    state.navfocus = m.nav.hasFocus()
    state.scenefocus = m.top.hasFocus()
    state.listfocus = m.list.itemFocused
    state.audiooptions = AudioOptions(m.player.availableAudioTracks)
    state.currentaudio = m.player.currentAudioTrack
    state.savedAudioLanguage = m.registry.Read("audio_language")
    state.actionfocus = m.actions.itemFocused
    state.searchstate = m.searchState
    state.searchquery = m.searchQuery
    state.searchEffectiveQuery = m.searchEffectiveQuery
    state.searcherroractions = m.searchErrorActions
    state.seekpending = m.seekPending
    state.seeksettling = m.seekSettling
    state.seektarget = m.seekTarget
    state.seeknotice = m.seekNotice.text
    state.playbackstatus = m.playbackStatus.text
    state.refreshattempts = m.refreshAttempts
    state.pendingaudio = m.pendingAudio
    state.playbackmetrics = m.playbackMetrics
    state.prefetched = IsMap(m.nextPrefetch)
    state.cacheready = IsMap(m.captionIndex)
    state.captioncycles = m.qaModeIteration
    state.autoplay = m.autoplay
    state.run = m.top.qaRun
    state.storepending = IsMap(m.pendingStoreLink)
    state.storereported = m.storeLaunchReported
    if IsMap(m.title) then state.titleid = m.title.id
    state.helperstatus = m.helperStatus
    state.nextpending = m.nextPending
    state.nextremaining = m.nextRemaining
    state.captionvisible = m.captionLayer.visible
    state.captiontranslation = m.captionLayer.translation
    state.captionheight = m.captionText.height
    state.captionsize = m.captionSize
    state.renderedsize = m.captionText.font.size
    state.captionoffset = m.captionOffset
    state.trackkind = m.trackKind
    state.sourceindex = m.sourceIndex
    state.sourcecount = 0
    if IsList(m.sourceOptions) then state.sourcecount = m.sourceOptions.Count()
    state.recents = m.recentSearches
    state.watchcount = m.watchlist.Count()
    state.titleactions = m.titleActions
    state.customCaption = m.customCaptionEnabled
    state.captionText = m.captionText.text
    state.captionNotice = m.captionNotice.text
    state.caption = "none"
    for each option in NativeSubtitleOptions(m.subtitleOptions,m.player.availableSubtitleTracks)
        if option.track <> "" and option.track = m.player.currentSubtitleTrack then state.caption = option.code
    end for
    if m.episode <> invalid then state.episode = m.episode.id
    if m.keyboard <> invalid then state.message = m.keyboard.message: state.keyboardtext = m.keyboard.text
    if m.list.content <> invalid then
        state.items = []
        for each child in m.list.content.GetChildren(-1,0)
            state.items.Push(child.title)
        end for
    end if
    print "[QA] "; FormatJson(state)
end sub
