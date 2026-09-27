sub ShowHome()
    EnterPage("home", "Home")
    RenderHome(true)
end sub

sub RenderHome(focus as Boolean)
    groups = []
    continuing = ContinueItems(m.history)
    if continuing.Count() > 0 then groups.Push({label:"Continue Watching", items:continuing})
    for each group in m.catalog
        if group.items.Count() > 0 then groups.Push(group)
    end for
    m.status.text = "Find your next watch"
    if groups.Count() = 0 then
        m.status.text = "Loading your library..."
        ShowEmpty("Your movies and series will appear here.")
        m.nav.setFocus(true)
    else
        RenderRails(groups, focus)
    end if
end sub

sub ShowContinue()
    EnterPage("continue", "Continue Watching")
    items = ContinueItems(m.history)
    if items.Count() = 0 then
        ShowEmpty("Nothing to resume yet. Start a movie or episode and it will appear here.")
        m.status.text = "Your progress is saved on this TV"
    else
        m.status.text = "Pick up exactly where you left off"
        RenderRails([{label:"Recently watched",items:items}], true)
    end if
end sub

sub RenderRails(groups as Object, focus as Boolean)
    previous = m.rails.rowItemFocused
    hadFocus = m.rails.hasFocus()
    previousCard = FocusedCard(previous)
    root = CreateObject("roSGNode", "ContentNode")
    m.railItems = []
    for each group in groups
        row = root.CreateChild("ContentNode")
        row.title = group.label
        m.railItems.Push(group.items)
        for each item in group.items
            card = row.CreateChild("ContentNode")
            card.title = item.title
            card.hdPosterUrl = item.poster
            ratio = 0.0
            saved = HistoryFind(m.history, item.id)
            if saved <> invalid and not saved.completed and saved.duration > 0 then
                ratio = saved.position / saved.duration
                if ratio > 1 then ratio = 1
                if ratio < 0 then ratio = 0
            end if
            card.addField("progressRatio", "float", false)
            card.progressRatio = ratio
        end for
    end for
    m.rails.content = root
    m.rails.searchPaging = m.page = "search" or m.page = "cloud-watchlist"
    m.browse.visible = true
    m.empty.visible = false
    m.hint.text = "↑↓ categories • ←→ titles • OK details • Left edge opens menu"
    if m.page = "search" then m.hint.text = "OK details • * search options / pages • Back edit search"
    if not focus and previous.Count() = 2 then
        restore = previous
        if previousCard <> invalid then
            found = false
            for rowIndex = 0 to m.railItems.Count() - 1
                for itemIndex = 0 to m.railItems[rowIndex].Count() - 1
                    if m.railItems[rowIndex][itemIndex].id = previousCard.id then
                        restore = [rowIndex,itemIndex]
                        found = true
                        exit for
                    end if
                end for
                if found then exit for
            end for
        end if
        RestoreRailIndex(restore)
    end if
    if focus or hadFocus then m.rails.setFocus(true)
    OnCardFocused()
end sub

sub RestoreRailIndex(index as Object)
    if index.Count() <> 2 then return
    if index[0] < 0 or index[0] >= m.railItems.Count() then return
    if index[1] < 0 or index[1] >= m.railItems[index[0]].Count() then return
    m.rails.jumpToRowItem = index
end sub

function FocusedCard(index as Object) as Dynamic
    if index.Count() <> 2 then return invalid
    if index[0] < 0 or index[0] >= m.railItems.Count() then return invalid
    items = m.railItems[index[0]]
    if index[1] < 0 or index[1] >= items.Count() then return invalid
    return items[index[1]]
end function

sub OnCardFocused()
    item = FocusedCard(m.rails.rowItemFocused)
    if item = invalid then return
    SetDisplayText(m.previewTitle,item.title,22)
    meta = "Movie"
    if item.isSeries then meta = "Series"
    saved = HistoryFind(m.history, item.id)
    if saved <> invalid and not saved.completed then
        if saved.episodeId > 0 then
            meta = "Last episode"
            if saved.number > 0 then meta = "S" + Text(saved.season) + " · E" + Text(saved.number)
        end if
        if saved.position > 0 then meta = meta + "   Resume at " + ClockText(saved.position) else meta = meta + "   Up next"
    else
        if item.year <> "" then meta = meta + "   " + item.year
        if item.rating <> "" then meta = meta + "   IMDb " + item.rating
    end if
    m.previewMeta.text = meta
end sub

sub OnCardSelected()
    if not m.browse.visible or m.page = "player" then return
    item = FocusedCard(m.rails.rowItemSelected)
    if item = invalid then return
    RememberSearchFocus()
    m.lastBrowse = {page:m.page, index:m.rails.rowItemSelected}
    if m.page = "watchlist" then m.watchFocusId = item.id
    if m.page = "cloud-watchlist" then m.cloudFocusId = item.id
    ShowTitle(item, true)
end sub

sub ReturnToBrowse()
    page = m.lastBrowse.page
    index = m.lastBrowse.index
    if page = "continue" then
        ShowContinue()
    else if page = "watchlist" then
        ShowWatchlist()
        return
    else if page = "cloud-watchlist" then
        m.cloudRestoreIndex = index
        ShowCloudWatchlist()
        return
    else if page = "search" then
        RestoreSearchSnapshot()
    else
        ShowHome()
    end if
    RestoreRailIndex(index)
end sub

sub ShowTitle(item as Object, fetch as Boolean)
    EnterPage("title", "")
    if m.title = invalid then
        m.selectedSeason = -1
        m.selectedEpisodeId = 0
    else if m.title.id <> item.id then
        m.selectedSeason = -1
        m.selectedEpisodeId = 0
    end if
    m.title = item
    m.episode = invalid
    m.detail.visible = true
    RenderTitle()
    m.actions.setFocus(true)
    RefreshCloudMembership()
    if fetch then Request("detail", "single/id/" + Text(item.id), {})
end sub

sub RenderTitle()
    selectionKey = Text(m.title.id)
    if m.episode <> invalid then selectionKey = selectionKey + ":" + Text(m.episode.id)
    selectedAction = ""
    if Text(m.renderedTitleKey) = selectionKey and IsList(m.titleActions) then
        focused = m.actions.itemFocused
        if focused >= 0 and focused < m.titleActions.Count() then selectedAction = m.titleActions[focused]
    end if
    m.renderedTitleKey = selectionKey
    m.detail.visible = true
    m.detailPoster.uri = m.title.poster
    SetDisplayText(m.detailTitle,m.title.title,26)
    m.detailPlot.text = m.title.plot
    meta = "Movie"
    if m.title.isSeries then meta = "Series"
    if m.episode <> invalid then
        meta = "Season " + Text(m.episode.season) + " · Episode " + Text(m.episode.number)
        m.detailPlot.text = m.episode.title
    else
        if m.title.year <> "" then meta = meta + "   " + m.title.year
        if m.title.rating <> "" then meta = meta + "   IMDb " + m.title.rating
    end if
    m.detailMeta.text = meta
    saved = HistoryFind(m.history, m.title.id)
    episodeId = 0
    if m.episode <> invalid then episodeId = m.episode.id
    if m.episode = invalid and m.title.isSeries and saved <> invalid then episodeId = saved.episodeId
    if m.episode <> invalid then saved = EpisodeResumeEntry(m.history,m.episodeHistory,m.title.id,episodeId)
    seconds = ResumeSeconds(saved, episodeId)
    primary = "Play"
    if m.title.isSeries and m.episode = invalid then primary = "Choose an episode"
    if seconds > 0 then
        primary = "Resume · " + ClockText(seconds)
        if m.title.isSeries and m.episode = invalid and saved.number > 0 then primary = "Resume S" + Text(saved.season) + " E" + Text(saved.number) + " · " + ClockText(seconds)
    else if m.title.isSeries and m.episode = invalid and saved <> invalid and saved.episodeId > 0 and not saved.completed then
        primary = "Play next · S" + Text(saved.season) + " E" + Text(saved.number)
    end if
    labels = [primary]
    m.titleActions = ["play"]
    if seconds > 0 then labels.Push("Start over"): m.titleActions.Push("restart")
    if m.title.isSeries then labels.Push("Seasons & episodes"): m.titleActions.Push("seasons")
    if saved <> invalid and not saved.completed then labels.Push("Remove from Continue Watching"): m.titleActions.Push("remove")
    watchLabel = "Add to TV Watchlist"
    if HistoryFind(m.watchlist,m.title.id) <> invalid then watchLabel = "Remove from TV Watchlist"
    labels.Push(watchLabel)
    m.titleActions.Push("watchlist")
    labels.Push(CloudWatchLabel(m.title.id))
    m.titleActions.Push("cloud-watch")
    if m.episode <> invalid then
        watchedLabel = "Mark episode watched"
        if saved <> invalid then
            if saved.episodeId = m.episode.id and saved.completed then watchedLabel = "Mark episode unwatched"
        end if
        labels.Push(watchedLabel): m.titleActions.Push("watched")
    end if
    labels.Push("Back")
    m.titleActions.Push("back")
    m.actions.content = MakeLabels(labels)
    for i = 0 to m.titleActions.Count() - 1
        if m.titleActions[i] = selectedAction then m.actions.jumpToItem = i
    end for
end sub

sub OnAction()
    if m.page <> "title" then return
    index = m.actions.itemSelected
    if index < 0 or index >= m.titleActions.Count() then return
    action = m.titleActions[index]
    if action = "back" then
        if m.episode <> invalid then ShowEpisodes(m.episode.season) else ReturnToBrowse()
    else if action = "watched" then
        MarkEpisodeWatched()
    else if action = "cloud-watch" then
        BeginCloudMutation()
    else if action = "watchlist" then
        m.watchlist = ToggleWatchlist(m.watchlist,m.title)
        m.registry.Write("watchlist",FormatJson(m.watchlist))
        m.registry.Flush()
        RenderTitle()
        m.status.text = "Watchlist updated"
    else if action = "remove" then
        m.history = HistoryRemove(m.history, m.title.id)
        PersistHistory()
        RenderTitle()
        m.status.text = "Removed from Continue Watching"
    else
        RequestTitlePlayback(action)
    end if
end sub

sub RequestTitlePlayback(action as String)
        if m.tasks.DoesExist("stream") then return
        if m.api.token = "" then m.status.text = "Sign in from Account to watch": return
        m.recoveringStream = false
        m.streamIntent = action
        m.startOver = action = "restart"
        if m.episode <> invalid and action <> "seasons" then
            m.streamIntent = "episode"
            m.requestedEpisodeId = m.episode.id
            m.status.text = "Loading episode..."
            Request("stream", "stream/id/" + Text(m.title.id), {})
        else
            m.status.text = "Loading..."
            Request("stream", "stream/id/" + Text(m.title.id), {})
        end if
end sub

sub HandleStream(data as Object)
    if data.list <> invalid then
        m.allEpisodes = FlattenEpisodes(data.list)
        if m.allEpisodes.Count() = 0 then m.status.text = "No playable episode records are available": return
        if m.streamIntent = "seasons" then ShowSeasons(): return
        if m.streamIntent = "episode" then
            index = EpisodeIndex(m.allEpisodes,m.requestedEpisodeId)
            if index < 0 then m.status.text = "That episode is no longer available": return
            m.episode = m.allEpisodes[index]
            SetSyncMedia({id:m.episode.id},m.episode.options)
            StartPlayback(m.episode.file,m.episode.subtitle,0,m.recoveringStream = true)
            return
        end if
        saved = HistoryFind(m.history, m.title.id)
        target = -1
        if saved <> invalid and not saved.completed then
            target = EpisodeIndex(m.allEpisodes,saved.episodeId)
            if target < 0 then
                for i = 0 to m.allEpisodes.Count() - 1
                    ep = m.allEpisodes[i]
                    if ep.season = saved.season and ep.number = saved.number then
                        target = i
                        saved.episodeId = ep.id
                        exit for
                    end if
                end for
            end if
        end if
        if target >= 0 then
            m.episode = m.allEpisodes[target]
            SetSyncMedia({id:m.episode.id},m.episode.options)
            StartPlayback(m.episode.file, m.episode.subtitle,0,m.recoveringStream = true)
        else
            ShowSeasons()
        end if
    else
        m.episode = invalid
        SetSyncMedia(data.data,data.options)
        StartPlayback(data.file, data.subtitle,0,m.recoveringStream = true)
    end if
end sub

sub ShowSeasons()
    EnterPage("seasons", "Seasons")
    m.episode = invalid
    m.status.text = m.title.title
    m.seasons = SeasonNumbers(m.allEpisodes)
    labels = []
    for each season in m.seasons
        episodes = EpisodesInSeason(m.allEpisodes, season)
        labels.Push("Season " + Text(season) + "   ·   " + Text(episodes.Count()) + " episodes")
    end for
    labels.Push("Back to title")
    m.list.content = MakeLabels(labels)
    for i = 0 to m.seasons.Count() - 1
        if m.seasons[i] = SafeInt(m.selectedSeason,-1) then m.list.jumpToItem = i
    end for
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub ShowEpisodes(season as Integer)
    EnterPage("episodes", "Season " + Text(season))
    m.selectedSeason = season
    m.status.text = m.title.title
    m.seasonEpisodes = EpisodesInSeason(m.allEpisodes, season)
    saved = HistoryFind(m.history, m.title.id)
    labels = []
    for each episode in m.seasonEpisodes
        label = "E" + Text(episode.number) + "   " + episode.title
        progress = EpisodeResumeEntry(m.history,m.episodeHistory,m.title.id,episode.id)
        if progress <> invalid then
            if progress.episodeId = episode.id then
                if progress.completed then
                    label = label + "   ·   Watched"
                else if progress.position > 0 then
                    label = label + "   ·   " + ClockText(progress.position)
                end if
            end if
        end if
        labels.Push(label)
    end for
    labels.Push("Back to seasons")
    m.list.content = MakeLabels(labels)
    selected = EpisodeIndex(m.seasonEpisodes,SafeInt(m.selectedEpisodeId))
    if selected >= 0 then m.list.jumpToItem = selected
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub OnList()
    if not m.list.visible then return
    index = m.list.itemSelected
    if m.page = "seasons" then
        if index < m.seasons.Count() then ShowEpisodes(m.seasons[index]) else ShowTitle(m.title, false)
    else if m.page = "episodes" then
        if index < m.seasonEpisodes.Count() then
            episode = m.seasonEpisodes[index]
            m.selectedEpisodeId = episode.id
            EnterPage("title", "")
            m.episode = episode
            RenderTitle()
            m.actions.setFocus(true)
        else
            ShowSeasons()
        end if
    else if m.page = "preferences" then
        OnPreference(index)
    else if m.page = "cloud-watch-options" then
        OnCloudOption(index)
    else if m.page = "watch-options" then
        OnWatchOption(index)
    else if m.page = "search" then
        if not IsList(m.searchErrorActions) then return
        if index < 0 or index >= m.searchErrorActions.Count() then return
        action = m.searchErrorActions[index]
        if action = "retry" then StartSearch(m.searchPage,true)
        if action = "results" then RestoreSearchSnapshot()
        if action = "edit" then ShowSearchKeyboard()
        if action = "home" then ShowHome()
        if action = "account" then ShowAccount()
    else if m.page = "search-options" then
        if index < 0 or index >= m.searchActions.Count() then return
        action = m.searchActions[index]
        if action = "next" then StartSearch(m.searchPage + 1)
        if action = "previous" then StartSearch(m.searchPage - 1)
        if action = "edit" then ShowSearchKeyboard()
        if action = "refresh" then StartSearch(m.searchPage,true)
        if action = "results" then RestoreSearchSnapshot()
        if action = "filter" or action = "sort" then ChangeSearchView(action,index)
    else if m.page = "diagnostics" then
        if index = 0 then Request("catalog","mainV2",{})
        if index = 1 then LoadRemoteHistory()
        if index = 2 then m.helperStatus = "Checking...": RenderDiagnostics(): Request("helper-health","health",{})
        if index = 3 or index = 4 then ShowAccount()
    else if m.page = "recent-searches" then
        if index = 0 then
            m.searchQuery = ""
            ShowSearchKeyboard()
        else if index <= m.recentSearches.Count() then
            m.searchQuery = m.recentSearches[index - 1]
            m.searchPages = 1
            StartSearch(1)
        else
            m.recentSearches = []
            m.registry.Write("recent_searches","[]")
            m.registry.Flush()
            ShowRecentSearches()
        end if
    else if m.page = "account" then
        action = m.listActions[index]
        if action = "auth" then
            if m.api.token <> "" then
                InvalidateSessionRequests()
                m.api.token = ""
                m.syncToken = ""
                m.userId = 0
                m.registry.Delete("session_token")
                m.registry.Flush()
                ShowAccount()
            else
                ShowLoginKeyboard("email")
            end if
        else if action = "autoplay" then
            m.autoplay = not m.autoplay
            value = "off"
            if m.autoplay then value = "on"
            m.registry.Write("autoplay",value)
            m.registry.Flush()
            ShowAccount()
        else if action = "cloud-watchlist" then
            ShowCloudWatchlist()
        else if action = "preferences" then
            ShowPreferences()
        else if action = "verifyLogin" then
            ShowLoginKeyboard("email")
        else if action = "refresh" then
            Request("catalog", "mainV2", {})
            ShowHome()
        else
            ShowDiagnostics()
        end if
    end if
end sub

sub ShowWatchlist()
    EnterPage("watchlist","Watchlist · This TV")
    items = TitleView(m.watchlist,Text(m.watchFilter,"all"),Text(m.watchSort,"added"))
    if items.Count() = 0 then
        message = "Save titles from their detail page to watch later."
        if m.watchlist.Count() > 0 then message = "No titles match this filter. Press * to change it."
        ShowEmpty(message)
    else
        RenderRails([{label:"Saved for later",items:items}],true)
        RestoreRailIndex(TitleFocusIndex(items,SafeInt(m.watchFocusId)))
    end if
    m.status.text = Text(items.Count()) + " of " + Text(m.watchlist.Count()) + " saved · " + m.watchFilter + " · " + m.watchSort
    m.hint.text = "* filters / sort · OK details · Play watches"
end sub

sub ShowRecentSearches()
    EnterPage("recent-searches","Search")
    labels = ["New search"]
    for each query in m.recentSearches
        labels.Push(query)
    end for
    if m.recentSearches.Count() > 0 then labels.Push("Clear recent searches")
    m.list.content = MakeLabels(labels)
    m.list.visible = true
    m.list.setFocus(true)
    m.status.text = "Search the library or repeat a recent search"
end sub
