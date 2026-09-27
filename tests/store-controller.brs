sub Main()
    m.checks = 0
    m.top = {launchArgs:{contentId:"123:12",mediaType:"episode"}}
    m.pendingStoreLink = invalid
    m.storeLinkSerial = 0
    m.api = {token:""}
    m.page = "home"
    m.cancelled = []
    OnStoreLink()
    Assert(m.page = "account" and m.loginShown,"unauthenticated deep link opens on-device login")
    Assert(m.pendingStoreLink.episodeId = 12,"login retains validated episode target")
    m.api.token = "fixture"
    ResumeStoreLink()
    Assert(m.lastRequest.tag = "store-detail" and m.lastRequest.action = "single/id/123","authenticated link uses existing provider detail contract")
    HandleStoreResult("store-detail",{success:true,result:{id:123,title:"Synthetic series",is_series:true}})
    Assert(m.lastRequest.tag = "store-stream" and m.lastRequest.action = "stream/id/123","validated title requests stream")
    m.history = []
    stream = {list:{"1":[{data:{id:11,season:1,number:1,title:"One"},file:{url:"https://media.example.test/one.m3u8"},subtitle:{}},{data:{id:12,season:1,number:2,title:"Two"},file:{url:"https://media.example.test/two.m3u8"},subtitle:{}}]}}
    HandleStoreResult("store-stream",{success:true,result:stream})
    Assert(m.played.url = "https://media.example.test/two.m3u8" and m.episode.id = 12,"exact episode starts directly without picker")
    Assert(m.pendingStoreLink = invalid and not m.startOver,"consumed link retains normal resume semantics")
    m.top.launchArgs = {contentId:"123:11",mediaType:"series"}
    m.page = "player"
    OnStoreLink()
    Assert(m.savedOnClose,"warm link saves existing playback before replacement")
    HandleStoreResult("store-detail",{success:true,result:{id:123,title:"Synthetic series",is_series:true}})
    m.history = [{id:123,episodeId:11,completed:true}]
    HandleStoreResult("store-stream",{success:true,result:stream})
    Assert(m.episode.id = 12,"completed series bookmark advances into next episode")
    m.top.launchArgs = {contentId:"123:12",mediaType:"season"}
    OnStoreLink()
    HandleStoreResult("store-detail",{success:true,result:{id:123,title:"Synthetic series",is_series:true}})
    HandleStoreResult("store-stream",{success:true,result:stream})
    Assert(m.pickedSeason = 1 and m.selectedEpisodeId = 12,"season links highlight mapped episode")
    m.top.launchArgs = {contentId:"123",mediaType:"movie"}
    OnStoreLink()
    HandleStoreResult("store-detail",{success:true,result:{id:999,title:"Wrong title"}})
    Assert(m.page = "home" and m.pendingStoreLink = invalid,"wrong catalog identity falls back home")
    OnStoreLink()
    HandleStoreResult("store-detail",{success:false})
    Assert(m.page = "home","provider failure returns actionable home")
    m.top.launchArgs = {contentId:"https://other.invalid/path",mediaType:"movie"}
    OnStoreLink()
    Assert(m.pendingStoreLink = invalid and m.page = "home","untrusted URL never becomes content request")
    m.lastRequest = invalid
    HandleStoreResult("store-detail",{success:true,result:{id:123,title:"Late"}})
    Assert(m.lastRequest = invalid,"cancelled link ignores late callback")
    print "REGRESSION PASS: ";m.checks;" store controller assertions"
end sub
sub CancelRequest(tag as String)
    m.cancelled.Push(tag)
end sub
sub ClosePlayback(save as Boolean)
    m.savedOnClose = save
    m.page = "title"
end sub
sub CloseKeyboard()
end sub
sub ShowAccount()
    m.page = "account"
end sub
sub ShowLoginKeyboard(kind as String)
    m.loginShown = true
end sub
sub EnterPage(page as String,title as String)
    m.page = page
    m.status = {}
    m.empty = {}
    m.nav = {setFocus:sub(value)
    end sub}
end sub
sub Request(tag as String,action as String,payload as Object)
    m.lastRequest = {tag:tag,action:action}
end sub
sub ShowHome()
    m.page = "home"
    m.status = {}
end sub
sub SetSyncMedia(data as Dynamic,options as Dynamic)
end sub
sub StartPlayback(file as Dynamic,subtitles as Dynamic)
    m.played = file
end sub
sub ShowEpisodes(season as Integer)
    m.pickedSeason = season
end sub
sub FlushProgressQueue()
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
