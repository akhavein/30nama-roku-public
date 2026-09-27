sub init()
    m.api = ApiInit()
    m.deviceRegistry = CreateObject("roRegistry")
    m.registry = CreateObject("roRegistrySection", "30nama")
    m.api.token = m.registry.Read("session_token")
    rawHistory = m.registry.Read("history_v2")
    m.history = []
    if rawHistory <> "" then m.history = CleanHistory(ParseJson(rawHistory))
    MigrateHistory()
    m.episodeHistory = []
    rawEpisodes = m.registry.Read("episode_history_v1")
    if rawEpisodes <> "" then m.episodeHistory = CleanEpisodeHistory(ParseJson(rawEpisodes))
    if not m.registry.Exists("episode_history_v1") then
        for each entry in m.history
            RecordEpisode(entry)
        end for
        m.registry.Write("episode_history_v1",EpisodeStorage(m.episodeHistory,4096).json)
        m.registry.Flush()
    end if
    rawWatchlist = m.registry.Read("watchlist")
    m.watchlist = []
    if rawWatchlist <> "" then m.watchlist = NormalizeTitles(ParseJson(rawWatchlist))
    m.watchFilter = m.registry.Read("watch_filter")
    if m.watchFilter <> "movies" and m.watchFilter <> "series" then m.watchFilter = "all"
    m.watchSort = m.registry.Read("watch_sort")
    if m.watchSort <> "title" then m.watchSort = "added"
    rawSearches = m.registry.Read("recent_searches")
    m.recentSearches = []
    if rawSearches <> "" then m.recentSearches = CleanSearches(ParseJson(rawSearches))
    m.helperUrl = m.registry.Read("helper_url")
    ' Public builds have no default helper; pair your own HTTPS service.
    m.helperToken = m.registry.Read("helper_token")
    m.captionPosition = m.registry.Read("caption_position")
    if m.captionPosition <> "raised" and m.captionPosition <> "top" then m.captionPosition = "bottom"
    m.captionContrast = m.registry.Read("caption_contrast")
    if m.captionContrast <> "soft" and m.captionContrast <> "solid" then m.captionContrast = "standard"
    m.captionSize = SafeInt(m.registry.Read("caption_size"),32)
    if m.captionSize <> 26 and m.captionSize <> 32 and m.captionSize <> 40 then m.captionSize = 32
    m.sessionEpoch = 0
    m.cloudItems = []
    m.cloudPage = 1
    m.cloudPages = 1
    m.cloudFilter = "all"
    m.cloudSort = "added"
    m.progressQueue = []
    m.userId = 0
    m.syncStatus = "Local progress ready"
    for each kind in ["step","skip","replay"]
        m["remote_" + kind] = SafeInt(m.registry.Read("remote_" + kind))
    end for
    m.autoplay = m.registry.Read("autoplay") <> "off"
    for each id in ["shell", "nav", "heading", "status", "browse", "previewTitle", "previewMeta", "rails", "detail", "detailPoster", "detailTitle", "detailMeta", "detailPlot", "actions", "list", "empty", "hint", "playerScreen", "player", "playbackStatus", "controls", "playerTitle", "playerMeta", "playerTime", "timeline", "controlButtons", "trackPicker", "trackHeading", "trackList", "saveTimer", "overlayTimer", "captionLayer", "captionText", "captionNotice", "seekPauseTimer", "captionBackground", "bufferTimer", "nextCountdown", "nextCountdownText", "nextTimer", "healthTimer", "seekCommitTimer", "seekNotice", "syncRetryTimer", "searchQueryLabel", "sleepTimer", "watchPrompt", "introPrompt", "cloudVerifyTimer", "scenePreview", "previewImage", "previewTime", "previewStatus", "previewTimer"]
        m[id] = m.top.findNode(id)
    end for
    for each pair in [{node:m.list,size:23},{node:m.actions,size:18}]
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/components/fonts/Caption-Regular.ttf"
        font.size = pair.size
        pair.node.font = font
        pair.node.focusedFont = font
    end for
    m.previewImage.observeField("loadStatus","OnPreviewImageStatus")
    m.previewFiles = []
    m.previewSerial = 0
    m.previewSession = CreateObject("roDeviceInfo").GetRandomUUID()
    m.previewTimer.observeField("fire","OnPreviewTimer")
    m.sleepMinutes = 0
    m.watchSeconds = 0
    m.stillMinutes = SafeInt(m.registry.Read("still_minutes"))
    if m.stillMinutes <> 60 and m.stillMinutes <> 120 and m.stillMinutes <> 180 then m.stillMinutes = 0
    m.sleepTickClock = CreateObject("roTimespan")
    m.sleepTickClock.Mark()
    m.cloudVerifyTimer.observeField("fire","OnCloudVerifyTimer")
    m.sleepTimer.observeField("fire","OnSleepTick")
    m.sleepTimer.control = "start"
    m.page = "home"
    m.generation = 0
    m.tasks = {}
    m.requestCounter = 0
    m.keyboardCounter = 0
    m.catalog = []
    m.railItems = []
    m.allEpisodes = []
    m.episode = invalid
    m.title = invalid
    m.lastBrowse = {page:"home", index:[0,0]}
    m.searchFilter = "all"
    m.searchSort = "relevance"
    m.searchQuery = ""
    m.searchPage = 1
    m.searchPages = 1
    m.searchItems = []
    m.searchState = "idle"
    m.searchCache = {}
    m.searchCacheOrder = []
    m.customCaptionEnabled = false
    m.captionCues = []
    m.subtitleOptions = []
    m.controlIndex = 0
    m.nav.content = MakeLabels(["Home", "Continue", "Search", "Account", "Watchlist"])
    m.nav.observeField("itemSelected", "OnNav")
    m.rails.observeField("rowItemSelected", "OnCardSelected")
    m.rails.observeField("rowItemFocused", "OnCardFocused")
    m.rails.observeField("shortcut", "OnBrowseShortcut")
    m.actions.observeField("itemSelected", "OnAction")
    m.list.observeField("itemSelected", "OnList")
    m.trackList.observeField("itemSelected", "OnTrackSelected")
    m.player.observeField("state", "OnPlayerState")
    m.player.observeField("position", "OnPosition")
    m.player.observeField("availableAudioTracks", "OnAvailableAudio")
    if m.player.hasField("seamlessAudioTrackSelection") then m.player.seamlessAudioTrackSelection = true
    m.syncRetryTimer.observeField("fire","OnSyncRetry")
    m.healthTimer.observeField("fire", "OnPlaybackHealth")
    m.seekCommitTimer.observeField("fire", "OnSeekCommit")
    m.player.observeField("availableSubtitleTracks", "OnAvailableSubtitles")
    m.nextPending = false
    m.nextTimer.observeField("fire","OnNextTimer")
    m.bufferTimer.observeField("fire", "OnBufferTimeout")
    m.seekPauseTimer.observeField("fire", "OnSeekPauseTimer")
    m.saveTimer.observeField("fire", "OnSaveTimer")
    m.overlayTimer.observeField("fire", "OnOverlayTimer")
    m.stats = {requests:0, failures:0}
    ShowHome()
    Request("catalog", "mainV2", {})
    LoadRemoteHistory()
end sub

sub OnBrowseShortcut()
    if m.page = "player" then return
    key = m.rails.shortcut
    if m.page = "cloud-watchlist" then
        if key = "fastforward" then ShowCloudWatchlist(m.cloudPage + 1): return
        if key = "rewind" then ShowCloudWatchlist(m.cloudPage - 1): return
    end if
    if m.page = "search" then
        if key = "fastforward" and m.searchPage < m.searchPages then StartSearch(m.searchPage + 1): return
        if key = "rewind" and m.searchPage > 1 then StartSearch(m.searchPage - 1): return
    end if
    if not m.browse.visible then return
    if key = "play" then
        item = FocusedCard(m.rails.rowItemFocused)
        if item <> invalid then
            if m.page = "watchlist" then m.watchFocusId = item.id
            if m.page = "cloud-watchlist" then m.cloudFocusId = item.id
            m.lastBrowse = {page:m.page,index:m.rails.rowItemFocused}
            RememberSearchFocus()
            ShowTitle(item,false)
            RequestTitlePlayback("play")
        end if
    end if
end sub

function MakeLabels(labels as Object) as Object
    root = CreateObject("roSGNode", "ContentNode")
    for each label in labels
        item = root.CreateChild("ContentNode")
        item.title = DisplayText(label)
    end for
    return root
end function

sub EnterPage(page as String, heading as String)
    CancelPageRequests()
    m.generation = m.generation + 1
    m.page = page
    m.heading.text = heading
    m.searchQueryLabel.visible = false
    m.status.translation = [280,96]
    m.status.width = 920
    m.status.text = ""
    m.hint.text = "OK selects • Back returns"
    m.browse.visible = false
    m.detail.visible = false
    m.list.visible = false
    m.empty.visible = false
    m.shell.visible = true
    m.playerScreen.visible = false
    print "[30nama][view] "; page
end sub

sub ShowEmpty(message as String)
    m.empty.text = message
    m.empty.visible = true
    m.nav.setFocus(true)
end sub

sub CancelPageRequests()
    for each tag in m.tasks.Keys()
        if tag <> "catalog" and tag <> "progress" and tag <> "profile" and tag <> "remote-history" and not CloudGlobalTag(tag) then CancelRequest(tag)
    end for
end sub

sub CancelRequest(tag as String)
    task = m.tasks.Lookup(tag)
    if task = invalid then return
    task.unobserveField("result")
    task.control = "stop"
    m.top.removeChild(task)
    m.tasks.Delete(tag)
end sub

sub Request(tag as String, action as String, payload as Object)
    if m.tasks.DoesExist(tag) then return
    m.requestCounter = m.requestCounter + 1
    task = CreateObject("roSGNode", "ApiTask")
    task.helperUrl = m.helperUrl
    task.helperToken = m.helperToken
    task.base = m.api.base
    task.apiKey = m.api.apiKey
    task.version = m.api.version
    task.platform = m.api.platform
    task.language = m.api.language
    task.sessionEpoch = SafeInt(m.sessionEpoch)
    task.token = m.api.token
    if tag = "progress" and Text(m.syncToken) <> "" then task.token = m.syncToken
    task.action = action
    task.tag = tag
    task.generation = m.generation
    task.payload = payload
    task.requestId = Text(m.requestCounter)
    task.observeField("result", "OnApiResult")
    m.tasks[tag] = task
    m.top.appendChild(task)
    task.control = "run"
end sub

sub OnApiResult(event as Object)
    task = event.GetRoSGNode()
    tag = task.tag
    activeTask = m.tasks.Lookup(tag)
    if activeTask = invalid then return
    if activeTask.requestId <> task.requestId then return
    result = task.result
    validPage = tag = "catalog" or tag = "progress" or tag = "profile" or tag = "remote-history" or CloudGlobalTag(tag) or task.generation = m.generation
    m.tasks.Delete(tag)
    m.top.removeChild(task)
    if not validPage then return
    if task.sessionEpoch <> invalid and task.sessionEpoch <> SafeInt(m.sessionEpoch) then return
    m.stats.requests = m.stats.requests + 1
    ok = IsMap(result) and Truth(result.success)
    if not ok then m.stats.failures = m.stats.failures + 1
    if task.httpStatus = 401 and tag <> "helper-health" and tag <> "progress" and tag <> "login" then
        InvalidateSessionRequests()
        m.api.token = ""
        m.syncToken = ""
        m.userId = 0
        m.registry.Delete("session_token")
        m.registry.Flush()
    end if
    if Left(tag,6) = "cloud-" then
        HandleCloudResult(tag,result,task.httpStatus)
    else if tag = "helper-health" then
        m.helperStatus = "Unavailable"
        if ok then m.helperStatus = "Ready"
        if task.httpStatus = 401 then m.helperStatus = "Pairing key needs repair"
    else if tag = "profile" then
        if ok and IsMap(result.result) then
            m.userId = SafeInt(result.result.userid)
            m.syncToken = Text(result.result.usertoken)
        end if
    else if tag = "remote-history" then
        HandleRemoteHistory(result)
    else if tag = "progress" then
        HandleProgress(task,ok)
    else if tag = "catalog" then
        if ok and IsMap(result.result) then
            data = result.result
            m.catalog = [{label:"Featured", items:SectionPosts(data.hero_section)}, {label:"Suggested", items:SectionPosts(data.suggested)}, {label:"Top 10", items:SectionPosts(data.top10)}]
            if m.page = "home" then RenderHome(false)
        else if m.page = "home" then
            m.status.text = "Couldn't load the catalog. Open Account to refresh."
        end if
    else if tag = "detail" then
        if ok and IsMap(result.result) then
            info = NormalizeTitle(result.result)
            if info <> invalid then
                if info.poster = "" then info.poster = m.title.poster
                if info.plot = "" then info.plot = m.title.plot
                m.title = info
                RenderTitle()
            end if
        else
            m.status.text = "Details unavailable. You can still try playback."
        end if
    else if tag = "search" then
        m.searchHttpStatus = task.httpStatus
        HandleSearchResult(result)
    else if tag = "stream" then
        if ok and IsMap(result.result) then HandleStream(result.result) else StreamFailure(task.httpStatus)
    else if tag = "next-prefetch" then
        HandleNextPrefetch(result)
    else if tag = "subtitle-refresh" then
        RefreshCaptionMetadata(result)
    else if tag = "login" then
        HandleLogin(result, task.action)
    end if
    if m.page = "diagnostics" then RenderDiagnostics()
end sub

sub StreamFailure(status as Integer)
    if status = 401 or m.api.token = "" then
        m.status.text = "Your session has expired. Sign in from Account."
    else
        m.status.text = "Playback unavailable. Check your connection or subscription, then try again."
    end if
    m.actions.setFocus(true)
end sub

sub OnNav()
    if m.page = "player" then return
    index = m.nav.itemSelected
    if index = 0 then ShowHome()
    if index = 1 then ShowContinue()
    if index = 2 then ShowRecentSearches()
    if index = 3 then ShowAccount()
    if index = 4 then ShowWatchlist()
end sub

sub ShowAccount()
    EnterPage("account", "Account")
    auth = "Sign in"
    m.status.text = "Sign in to watch with your 30nama account"
    if m.api.token <> "" then auth = "Sign out": m.status.text = "Signed in on this TV"
    m.listActions = ["auth", "refresh", "diagnostics", "autoplay", "verifyLogin", "preferences", "cloud-watchlist"]
    autoLabel = "Autoplay next episode: Off"
    if m.autoplay then autoLabel = "Autoplay next episode: On"
    m.list.content = MakeLabels([auth, "Refresh catalog", "Connection diagnostics", autoLabel, "Verify sign-in with a fresh code", "Playback preferences", "30nama account Watchlist"])
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub ShowLoginKeyboard(kind as String)
    m.loginKind = kind
    if m.keyboard <> invalid then CloseKeyboard()
    m.keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
    m.keyboard.title = "Sign in to 30nama"
    m.keyboard.buttons = ["Continue", "Cancel"]
    if kind = "email" then
        m.keyboard.message = ["Enter your account email address"]
        m.keyboard.keyboardDomain = "email"
    else
        m.keyboard.message = ["Enter the one-time code sent to your email"]
        m.keyboard.keyboardDomain = "numeric"
    end if
    ObserveKeyboard()
    m.keyboard.observeField("buttonSelected", "OnLoginKeyboard")
    m.top.dialog = m.keyboard
end sub

sub OnLoginKeyboard()
    if m.keyboard = invalid then return
    if m.keyboard.buttonSelected = 1 then CloseKeyboard(): ShowAccount(): return
    value = m.keyboard.text.Trim()
    if value = "" then KeyboardMessage("Please enter a value before continuing"): return
    if m.tasks.DoesExist("login") then return
    if m.loginKind = "email" then
        if Instr(1,value,"@") = 0 then KeyboardMessage("Enter a valid email address"): return
        m.loginEmail = value
        Request("login", "send_otp", {userlogin:value, "g-recaptcha-response":""})
    else
        Request("login", "verify_otp", {userlogin:m.loginEmail, code:value})
    end if
    KeyboardMessage("Please wait...")
end sub

sub HandleLogin(result as Dynamic, action as String)
    if m.keyboard = invalid then return
    if IsMap(result) and Truth(result.success) then
        if action = "send_otp" then ShowLoginKeyboard("otp"): return
        token = ""
        if IsMap(result.result) then
            for each key in ["user_session", "token", "session_key", "usertoken"]
                candidate = Text(result.result.Lookup(key))
                if candidate <> "" then token = candidate
            end for
        end if
        if token <> "" then
            InvalidateSessionRequests()
            m.api.token = token
            m.registry.Write("session_token", token)
            m.registry.Flush()
            CloseKeyboard()
            ShowAccount()
            m.status.text = "Signed in successfully"
            LoadRemoteHistory()
            return
        end if
    end if
    KeyboardMessage("Sign-in failed. Check the email/code and try again, or Cancel.")
end sub

sub KeyboardMessage(message as String)
    if m.keyboard = invalid then return
    m.keyboard.message = [message]
    ' Native dialog content rebuilds can drop focus after a message update.
    m.keyboard.setFocus(true)
end sub

sub ObserveKeyboard()
    m.keyboardCounter = m.keyboardCounter + 1
    m.keyboard.addField("dialogId","integer",false)
    m.keyboard.dialogId = m.keyboardCounter
    m.keyboard.observeField("wasClosed","OnKeyboardClosed")
end sub

sub OnKeyboardClosed(event as Object)
    if m.keyboard = invalid then return
    closed = event.GetRoSGNode()
    if closed.dialogId <> m.keyboard.dialogId then return
    CloseKeyboard()
    if m.page = "search" then CancelSearchEdit() else ShowAccount()
end sub

sub CloseKeyboard()
    CancelRequest("login")
    if m.keyboard <> invalid then
        m.keyboard.unobserveField("wasClosed")
        m.keyboard.unobserveField("buttonSelected")
        m.keyboard.close = true
    end if
    m.top.dialog = invalid
    m.keyboard = invalid
end sub

sub MigrateHistory()
    if m.registry.Exists("history_v2") then return
    id = SafeInt(m.registry.Read("last_resume_id"))
    parent = SafeInt(m.registry.Read("last_resume_parent_id"))
    if id > 0 then
        titleId = id
        if parent > 0 then titleId = parent
        entry = NormalizeTitle({id:titleId, title:m.registry.Read("last_resume_label"), is_series:parent > 0})
        entry.position = SafeInt(m.registry.Read("resume_" + Text(id)))
        entry.duration = 0
        entry.completed = false
        entry.updated = 0
        if parent > 0 then entry.episodeId = id
        m.history = HistoryUpsert(m.history, entry)
    end if
    PersistHistory()
end sub

sub PersistHistory()
    m.registry.Write("history_v2", FormatJson(m.history))
    m.registry.Flush()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    OnViewerActivity()
    if m.page = "player" then return PlayerKey(key)
    if m.keyboard <> invalid then
        if key = "back" then
            CloseKeyboard()
            if m.page = "search" then CancelSearchEdit() else ShowAccount()
            return true
        end if
        return false
    end if
    if key = "options" then
        if m.page = "home" then Request("catalog", "mainV2", {}): m.status.text = "Refreshing...": return true
        if m.page = "search" then ShowSearchOptions(): return true
        if m.page = "watchlist" then ShowWatchOptions(): return true
        if m.page = "cloud-watchlist" then ShowCloudOptions(): return true
    end if
    if key = "left" and m.rails.hasFocus() then
        focused = m.rails.rowItemFocused
        if focused.Count() < 2 or focused[1] = 0 then m.nav.setFocus(true): return true
    end if
    if key = "left" and not m.nav.hasFocus() and not m.rails.hasFocus() then m.nav.setFocus(true): return true
    if key = "play" and m.rails.hasFocus() then
        item = FocusedCard(m.rails.rowItemFocused)
        if item <> invalid then
            if m.page = "watchlist" then m.watchFocusId = item.id
            if m.page = "cloud-watchlist" then m.cloudFocusId = item.id
            m.lastBrowse = {page:m.page,index:m.rails.rowItemFocused}
            RememberSearchFocus()
            ShowTitle(item,false)
            RequestTitlePlayback("play")
        end if
        return true
    end if
    if key = "right" and m.nav.hasFocus() then
        FocusContent()
        return true
    end if
    if key = "back" then
        if m.page = "title" then
            if m.episode <> invalid then ShowEpisodes(m.episode.season) else ReturnToBrowse()
        else if m.page = "episodes" then
            ShowSeasons()
        else if m.page = "seasons" then
            ShowTitle(m.title, false)
        else if m.page = "preferences" then
            ShowAccount()
        else if m.page = "cloud-watch-options" then
            ShowCloudWatchlist()
        else if m.page = "cloud-watchlist" then
            ShowWatchlist()
        else if m.page = "watch-options" then
            ShowWatchlist()
        else if m.page = "search-options" then
            RestoreSearchSnapshot()
        else if m.page = "search" then
            ShowSearchKeyboard()
        else if m.page = "home" then
            if not m.nav.hasFocus() then m.nav.setFocus(true) else return false
        else
            ShowHome()
        end if
        return true
    end if
    if m.page = "cloud-watchlist" then
        if key = "fastforward" then ShowCloudWatchlist(m.cloudPage + 1): return true
        if key = "rewind" then ShowCloudWatchlist(m.cloudPage - 1): return true
    end if
    if m.page = "search" and m.keyboard = invalid then
        if key = "fastforward" and m.searchPage < m.searchPages then StartSearch(m.searchPage + 1): return true
        if key = "rewind" and m.searchPage > 1 then StartSearch(m.searchPage - 1): return true
    end if
    return false
end function

sub FocusContent()
    if m.browse.visible and m.railItems.Count() > 0 then
        m.rails.setFocus(true)
    else if m.detail.visible then
        m.actions.setFocus(true)
    else if m.list.visible then
        m.list.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub
