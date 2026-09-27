sub RecordEpisode(entry as Object)
    if SafeInt(entry.episodeId) <= 0 then return
    m.episodeHistory = EpisodeHistoryUpsert(m.episodeHistory,entry)
    budget = 4096
    if m.deviceRegistry <> invalid then
        available = m.deviceRegistry.GetSpaceAvailable() + Len(m.registry.Read("episode_history_v1")) - 2048
        if available < budget then budget = available
    end if
    stored = EpisodeStorage(m.episodeHistory,budget)
    m.episodeHistory = stored.items
    m.registry.Write("episode_history_v1",stored.json)
end sub

sub MarkEpisodeWatched()
    if m.episode = invalid then return
    saved = EpisodeResumeEntry(m.history,m.episodeHistory,m.title.id,m.episode.id)
    watched = false
    duration = 0
    if saved <> invalid then
        if saved.episodeId = m.episode.id then watched = saved.completed: duration = saved.duration
    end if
    entry = HistoryEntry(m.title,m.episode,0,duration,not watched)
    if entry.completed then entry.position = duration
    RecordEpisode(entry)
    current = HistoryFind(m.history,m.title.id)
    ' Never replace a different episode's Continue target during manual marking.
    if current <> invalid then
        if current.episodeId = m.episode.id then
            m.history = HistoryUpsert(m.history,entry)
            if entry.completed and NextEpisode() <> invalid then m.history = HistoryUpsert(m.history,HistoryEntry(m.title,NextEpisode(),0,0,false))
        end if
    end if
    PersistHistory()
    RenderTitle()
    m.status.text = "Marked unwatched on this TV"
    if entry.completed then m.status.text = "Marked watched on this TV"
end sub

sub ShowWatchOptions()
    item = FocusedCard(m.rails.rowItemFocused)
    if m.page = "watchlist" and item <> invalid then m.watchFocusId = item.id
    EnterPage("watch-options","Watchlist options")
    m.list.content = MakeLabels(["Show: " + m.watchFilter,"Sort: " + m.watchSort,"Back to Watchlist","30nama account Watchlist"])
    m.status.text = "Changes apply to your saved titles on this TV"
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub OnWatchOption(index as Integer)
    if index = 3 then ShowCloudWatchlist(): return
    if index = 0 then m.watchFilter = ChoiceNext(m.watchFilter,["all","movies","series"])
    if index = 1 then m.watchSort = ChoiceNext(m.watchSort,["added","title"])
    m.registry.Write("watch_filter",m.watchFilter)
    m.registry.Write("watch_sort",m.watchSort)
    m.registry.Flush()
    if index = 2 then ShowWatchlist(): return
    ShowWatchOptions()
    m.list.jumpToItem = index
end sub

sub ChangeSearchView(action as String,index as Integer)
    if action = "filter" then m.searchFilter = ChoiceNext(m.searchFilter,["all","movies","series"])
    if action = "sort" then m.searchSort = ChoiceNext(m.searchSort,["relevance","title","rating"])
    if IsMap(m.searchSnapshot) then
        items = TitleView(m.searchSnapshot.items,m.searchFilter,m.searchSort)
        m.searchSnapshot.index = TitleFocusIndex(items,SafeInt(m.searchFocusId))
    end if
    ShowSearchOptions()
    m.list.jumpToItem = index
end sub

sub ShowPreferences()
    EnterPage("preferences","Playback preferences")
    m.preferenceActions = ["step","skip","replay","sleep","still","back"]
    labels = ["Left / Right and buttons: " + Text(RemoteSeconds("step")) + " seconds","FF / Rewind: " + Text(RemoteSeconds("skip")) + " seconds","Instant Replay: " + Text(RemoteSeconds("replay")) + " seconds","Sleep timer: " + SleepLabel(),"Still watching check: " + StillLabel(),"Back to Account"]
    m.list.content = MakeLabels(labels)
    m.list.visible = true
    m.list.setFocus(true)
    m.status.text = "OK cycles options · Saved on this TV"
end sub

sub OnPreference(index as Integer)
    if index < 0 or index >= m.preferenceActions.Count() then return
    action = m.preferenceActions[index]
    if action = "back" then ShowAccount(): return
    if action = "sleep" then
        SetSleepTimer(SafeInt(ChoiceNext(Text(m.sleepMinutes),["0","30","60","90","120"])))
        ShowPreferences(): m.list.jumpToItem = index
        return
    end if
    if action = "still" then
        m.stillMinutes = SafeInt(ChoiceNext(Text(m.stillMinutes),["0","60","120","180"]))
        m.registry.Write("still_minutes",Text(m.stillMinutes))
        m.registry.Flush()
        OnViewerActivity()
        ShowPreferences(): m.list.jumpToItem = index
        return
    end if
    choices = ["5","10","15","30"]
    if action = "skip" then choices = ["10","30","60"]
    m["remote_" + action] = SafeInt(ChoiceNext(Text(RemoteSeconds(action)),choices))
    m.registry.Write("remote_" + action,Text(m["remote_" + action]))
    m.registry.Flush()
    ShowPreferences()
    m.list.jumpToItem = index
end sub

sub OnViewerActivity()
    m.watchSeconds = 0
end sub

sub SetSleepTimer(minutes as Integer)
    m.sleepMinutes = minutes
    m.sleepClock = CreateObject("roTimespan")
    m.sleepClock.Mark()
end sub

function SleepLabel() as String
    if SafeInt(m.sleepMinutes) <= 0 then return "Off"
    remaining = m.sleepMinutes * 60 - Int(m.sleepClock.TotalMilliseconds() / 1000)
    if remaining < 0 then remaining = 0
    return Text(Int((remaining + 59) / 60)) + " min left (this session)"
end function

function StillLabel() as String
    if SafeInt(m.stillMinutes) <= 0 then return "Off"
    return Text(m.stillMinutes) + " min without remote input"
end function

sub OnSleepTick()
    delta = m.sleepTickClock.TotalMilliseconds() / 1000.0
    m.sleepTickClock.Mark()
    if m.page = "player" and m.player.state = "playing" and not m.watchPrompt.visible then m.watchSeconds = m.watchSeconds + delta
    if m.page = "player" and m.player.state = "paused" and not m.watchPrompt.visible then m.watchSeconds = 0
    elapsed = 0.0
    if m.sleepClock <> invalid then elapsed = m.sleepClock.TotalMilliseconds() / 1000.0
    reason = SleepReason(m.sleepMinutes,elapsed,m.stillMinutes,m.watchSeconds)
    if reason = "sleep" then
        CancelRequest("stream")
        CancelRequest("next-prefetch")
        CancelRequest("caption-prefetch")
        m.nextPrefetch = invalid
        m.recoveringStream = false
        m.sleepMinutes = 0
        m.watchSeconds = 0
        if m.page = "player" then ClosePlayback(true)
        m.status.text = "Sleep timer ended. Your place is saved."
    else if reason = "still" and m.page = "player" and not m.watchPrompt.visible then
        if m.player.state = "playing" then
            m.pauseAfterSeek = true
            SavePlayback()
            m.player.control = "pause"
            m.watchPrompt.visible = true
            m.watchPrompt.setFocus(true)
        end if
    end if
end sub
