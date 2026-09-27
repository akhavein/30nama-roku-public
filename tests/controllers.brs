sub Main()
    m.checks = 0
    m.registry = {values:{}, Read:function(key)
        return m.values.Lookup(key)
    end function, Write:sub(key,value)
        m.values[key] = value
    end sub, Delete:sub(key)
        m.values.Delete(key)
    end sub, Flush:sub()
    end sub}
    m.top = {removed:0, removeChild:sub(node)
        m.removed = m.removed + 1
    end sub}
    m.tasks = {}
    m.requestCounter = 10
    task = {requestId:"active",tag:"stream",generation:5,httpStatus:200,result:{success:true},unobserveField:sub(name)
    end sub}
    m.tasks.stream = task
    Request("stream","stream/id/123",{})
    Assert(m.requestCounter = 10, "repeated Play does not spawn another request")
    stale = {requestId:"old",tag:"stream",generation:4,httpStatus:401,result:{success:false}}
    event = {node:stale,GetRoSGNode:function()
        return m.node
    end function}
    m.generation = 5
    m.api = {token:"fixture"}
    m.stats = {requests:0,failures:0}
    OnApiResult(event)
    Assert(m.tasks.stream.requestId = "active", "old callback cannot remove new request")
    Assert(m.top.removed = 0, "old callback leaves active node attached")
    task.generation = 4
    event.node = task
    OnApiResult(event)
    Assert(not m.tasks.DoesExist("stream"), "navigated-away request cleaned up")
    Assert(m.stats.requests = 0, "stale callback cannot mutate active screen state")
    Assert(m.api.token = "fixture", "stale auth response cannot clear current session")
    m.sessionEpoch = 2
    oldAccount = {requestId:"old-account",tag:"profile",generation:5,sessionEpoch:1,httpStatus:401,result:{success:false}}
    m.tasks.profile = oldAccount
    event.node = oldAccount
    OnApiResult(event)
    Assert(m.api.token = "fixture" and m.stats.requests = 0,"old-account response cannot invalidate a replacement login")
    m.userId = 123
    m.syncToken = "old-observer-token"
    task = {requestId:"401",tag:"fixture",generation:5,httpStatus:401,result:{success:false}}
    m.tasks.fixture = task
    event.node = task
    m.registry.Write("session_token","fixture")
    OnApiResult(event)
    Assert(m.api.token = "", "active 401 clears session memory")
    Assert(m.registry.Read("session_token") = invalid, "active 401 clears session registry")
    Assert(m.userId = 0 and m.syncToken = "","session invalidation clears observer identity as well as login")
    Assert(m.stats.failures = 1, "active failure counted once")
    OnApiResult(event)
    Assert(m.stats.failures = 1, "duplicate result ignored")
    task = {requestId:"bad-success",tag:"fixture",generation:5,httpStatus:200,result:{success:{unexpected:true}}}
    m.tasks.fixture = task
    event.node = task
    OnApiResult(event)
    Assert(m.stats.failures = 2, "malformed success flag fails without runtime type error")
    m.tasks.catalog = {control:"run",unobserveField:sub(name)
    end sub}
    m.tasks.detail = {control:"run",unobserveField:sub(name)
    end sub}
    CancelPageRequests()
    Assert(m.tasks.DoesExist("catalog") and not m.tasks.DoesExist("detail"), "Back cancels page request but retains catalog")
    m.title = NormalizeTitle({id:99,title:"Series",is_series:true})
    m.allEpisodes = [{id:1,season:1,number:1,title:"One"},{id:2,season:1,number:2,title:"Two"},{id:3,season:2,number:1,title:"Three"}]
    m.episode = m.allEpisodes[0]
    m.page = "player"
    m.player = {position:120,duration:1000,state:"playing"}
    m.playStarted = false
    m.playCompleted = false
    m.history = []
    SavePlayback()
    Assert(m.history.Count() = 0, "buffering does not overwrite resume")
    m.playStarted = true
    SavePlayback()
    Assert(m.history[0].position = 120 and m.history[0].episodeId = 1, "playing checkpoint persisted")
    m.player.position = 3
    SavePlayback()
    Assert(m.history[0].position = 120, "early position does not erase resume")
    m.player.position = 150
    m.player.state = "paused"
    m.seekCommitTimer = {}
    SavePlayback()
    Assert(m.history[0].position = 150, "pause checkpoint persisted")
    Assert(NextEpisode().id = 2, "next episode in same season")
    m.episode = m.allEpisodes[1]
    Assert(NextEpisode().id = 3, "next episode crosses season boundary")
    CompletePlayback()
    Assert(m.history[0].episodeId = 3 and m.history[0].position = 0 and not m.history[0].completed, "completion advances continue target")
    SavePlayback()
    Assert(m.history[0].episodeId = 3 and m.history[0].position = 0, "late save cannot undo completion")
    m.episode = m.allEpisodes[2]
    CompletePlayback()
    Assert(m.history[0].completed and ContinueItems(m.history).Count() = 0, "series finale leaves Continue Watching")
    m.episode = invalid
    Assert(NextEpisode() = invalid, "movie has no next episode")
    m.title = NormalizeTitle({id:22,title:"Movie"})
    m.playCompleted = false
    m.player.state = "paused"
    RestartPlayback()
    Assert(m.player.seek = 0 and m.player.control = "resume", "restart while paused seeks and resumes")
    Assert(m.history[0].position = 0, "restart checkpoint replaces old progress")
    m.player.state = "playing"
    TogglePause()
    Assert(m.player.control = "pause", "Play remote pauses playing content")
    m.player.state = "paused"
    m.pauseAfterSeek = true
    TogglePause()
    Assert(m.player.control = "resume" and not m.pauseAfterSeek, "Play remote resumes paused content")
    m.player.state = "buffering"
    m.player.control = "unchanged"
    TogglePause()
    Assert(m.player.control = "unchanged", "Play during buffering does not issue invalid resume")
    m.trackSelectedAt = {elapsed:25,TotalMilliseconds:function()
        return m.elapsed
    end function}
    m.trackPicker = {visible:false}
    m.controls = {visible:true}
    m.activations = 0
    PlayerKey("OK")
    Assert(m.activations = 0, "native track-selection OK cannot reopen picker")
    m.trackSelectedAt.elapsed = 220
    PlayerKey("OK")
    Assert(m.activations = 1, "next physical OK remains responsive")
    m.keyboard = {dialogId:2,unobserveField:sub(name)
    end sub}
    m.top.dialog = m.keyboard
    m.page = "search"
    event.node = {dialogId:1}
    OnKeyboardClosed(event)
    Assert(m.keyboard.dialogId = 2, "old keyboard dismissal cannot close new dialog")
    event.node = {dialogId:2}
    OnKeyboardClosed(event)
    Assert(m.keyboard = invalid and m.top.dialog = invalid, "native Back clears keyboard reference")
    Assert(m.page = "home", "native search keyboard Back restores Home")
    m.keyboard = {focused:false,setFocus:sub(value)
        m.focused = value
    end sub}
    KeyboardMessage("Try again")
    Assert(m.keyboard.message[0] = "Try again", "keyboard error message updates")
    Assert(m.keyboard.focused, "keyboard message rebuild restores focus for Back/retry")
    m.player = {state:"paused",position:5,duration:100}
    m.page = "player"
    m.seekNotice = {}
    m.advanceClock = {Mark:sub()
    end sub}
    SeekBy(-10)
    OnSeekCommit()
    Assert(m.pauseAfterSeek and m.player.seek = 0, "seek preserves pause intent and clamps lower bound")
    m.player.state = "buffering"
    SeekBy(30)
    Assert(m.pauseAfterSeek, "rapid seek during buffering preserves paused intent")
    Assert(m.seekTarget = 30, "rapid seek accumulates from previous intent, not stale decoder position")
    SeekBy(30)
    Assert(m.seekTarget = 60, "third rapid seek adds to pending target")
    Assert(CheckpointPosition() = 60, "closing during debounce saves the requested position")
    m.pauseAfterSeek = false
    m.seekPending = false
    m.seekSettling = false
    m.player.state = "playing"
    SeekBy(30)
    OnSeekCommit()
    Assert(not m.pauseAfterSeek and m.player.seek = 35, "playing seek does not request pause")
    m.seekSettling = false
    m.player.position = 0
    m.lastGoodPosition = 180
    Assert(CheckpointPosition() = 180,"decoder zero during error preserves the last valid position")
    m.page = "search"
    m.browse = {visible:false}
    m.rails = {shortcut:"fastforward"}
    m.searchPage = 1: m.searchPages = 3
    m.requestedSearchPage = 0
    OnBrowseShortcut()
    Assert(m.requestedSearchPage = 2,"hidden search rail still forwards pagination shortcut")
    m.rails.shortcut = "play"
    m.requestedSearchPage = 0
    OnBrowseShortcut()
    Assert(m.requestedSearchPage = 0,"empty filtered view cannot play a hidden stale title")
    print "REGRESSION PASS: ";m.checks;" controller assertions"
end sub
sub Assert(condition as Boolean, label as String)
    if not condition then print "FAIL: ";label: stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub

sub ActivateControl()
    m.activations = m.activations + 1
end sub

sub ShowHome()
    m.page = "home"
end sub
sub ShowAccount()
    m.page = "account"
end sub

sub SendProgress(position as Integer,duration as Integer)
end sub

sub StartSearch(page as Integer)
    m.requestedSearchPage = page
end sub
