sub Main()
    m.checks = 0
    m.registry = {values:{}, Write:sub(key,value)
        m.values[key] = value
    end sub, Flush:sub()
    end sub}
    m.status = {}
    m.title = NormalizeTitle({id:1,title:"Series",is_series:true})
    m.episode = {id:10,season:1,number:1,title:"First"}
    other = {id:11,season:1,number:2,title:"Second"}
    m.history = [HistoryEntry(m.title,other,90,100,false)]
    m.episodeHistory = []
    MarkEpisodeWatched()
    Assert(m.history[0].episodeId = 11 and m.history[0].position = 90,"marking old episode never replaces newer Continue")
    Assert(EpisodeHistoryFind(m.episodeHistory,1,10).completed,"watched marker is persisted independently")
    MarkEpisodeWatched()
    Assert(not EpisodeHistoryFind(m.episodeHistory,1,10).completed,"unwatched reverses marker without network write")
    Assert(m.history[0].position = 90,"unwatched keeps different episode progress")
    m.sleepTickClock = {TotalMilliseconds:function()
        return 1000
    end function,Mark:sub()
    end sub}
    m.sleepClock = {elapsed:1800000,TotalMilliseconds:function()
        return m.elapsed
    end function}
    m.watchPrompt = {visible:false,setFocus:sub(value)
    end sub}
    m.page = "player"
    m.player = {state:"playing",control:""}
    m.watchSeconds = 0
    m.sleepMinutes = 30
    m.stillMinutes = 0
    m.cancelled = []
    m.saved = 0
    OnSleepTick()
    Assert(m.cancelled[0] = "stream","sleep expiry cancels pending/recovery stream fetch")
    Assert(m.page = "title" and m.saved = 1 and m.sleepMinutes = 0,"sleep expiry saves and exits playback once")
    OnSleepTick()
    Assert(m.saved = 1,"expired sleep timer does not fire again")
    m.page = "player"
    m.player.state = "playing"
    m.stillMinutes = 60
    m.watchSeconds = 3600
    OnSleepTick()
    Assert(m.watchPrompt.visible and m.player.control = "pause" and m.pauseAfterSeek,"still-watching pauses even if recovery races")
    Assert(m.saved = 2,"still-watching checkpoint is saved before pause")
    OnSleepTick()
    Assert(m.saved = 2,"prompt does not repeatedly save or pause")
    OnViewerActivity()
    Assert(m.watchSeconds = 0,"remote interaction resets inactivity")
    m.watchPrompt.visible = false
    m.player.state = "paused"
    m.watchSeconds = 10
    OnSleepTick()
    Assert(m.watchSeconds = 0,"intentional pause resets inactivity")
    print "REGRESSION PASS: ";m.checks;" watching controller assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
sub PersistHistory()
    m.registry.Flush()
end sub
sub RenderTitle()
end sub
function NextEpisode() as Dynamic
    return invalid
end function
sub ClosePlayback(save as Boolean)
    if save then SavePlayback()
    m.page = "title"
end sub
sub SavePlayback()
    m.saved = m.saved + 1
end sub

sub CancelRequest(tag as String)
    m.cancelled.Push(tag)
end sub
