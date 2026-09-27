sub Main()
    m.checks = 0
    a = {id:1,episodeId:10,position:45,duration:100,completed:false,updated:10}
    b = {id:1,episodeId:11,position:20,duration:100,completed:false,updated:20}
    items = EpisodeHistoryUpsert([],a)
    items = EpisodeHistoryUpsert(items,b)
    Assert(EpisodeHistoryFind(items,1,10).position = 45,"another episode retains independent resume")
    Assert(EpisodeHistoryFind(items,2,10) = invalid,"same episode ID on different series is isolated")
    a.completed = true
    items = EpisodeHistoryUpsert(items,a)
    Assert(ResumeSeconds(EpisodeHistoryFind(items,1,10),10) = 0,"watched episodes replay from zero")
    Assert(EpisodeHistoryFind(items,1,11).position = 20,"manual watched marker preserves other episode")
    dirty = CleanEpisodeHistory([invalid,{id:0,episodeId:1},a,a,{id:2,episodeId:3,position:-1,duration:-5}])
    Assert(dirty.Count() = 2 and dirty[1].position = 0,"ledger sanitizes malformed duplicate and negative data")
    Assert(ResumeSeconds(EpisodeResumeEntry([b],items,1,10),10) = 0,"different continue target cannot overwrite episode marker")
    fresh = {id:1,episodeId:11,position:60,duration:100,completed:false,updated:30}
    Assert(EpisodeResumeEntry([fresh],items,1,11).position = 60,"newer cloud checkpoint supersedes episode ledger")
    items = []
    for i = 1 to 350
        items.Push({id:2,episodeId:i})
    end for
    items = EpisodeHistoryUpsert(items,{id:2,episodeId:351})
    Assert(items.Count() = 120 and items[0].episodeId = 351,"ledger eviction is bounded and newest-first")
    titles = NormalizeTitles([{id:1,title:"Zulu",rating:"7.8"},{id:2,title:"alpha",is_series:true,rating:"9.1"},{id:3,title:"Beta",rating:"bad"}])
    Assert(TitleView(titles,"movies","title")[0].id = 3,"watchlist movie filter and case-insensitive title order")
    Assert(TitleView(titles,"series","added").Count() = 1,"series filter excludes movies")
    Assert(TitleView(titles,"all","added")[0].id = 1 and titles[0].id = 1,"sorting never mutates insertion order")
    Assert(TitleFocusIndex(TitleView(titles,"all","title"),1)[1] = 2,"focus follows title identity after sorting")
    Assert(TitleFocusIndex([],1)[1] = 0,"empty filter has safe focus fallback")
    Assert(ChoiceNext("series",["all","movies","series"]) = "all","filter cycles back to all")
    Assert(TitleView(titles,"all","rating")[0].id = 2,"numeric ratings sort high first with malformed rating last")
    Assert(TitleView([],"movies","title").Count() = 0,"empty provider page remains empty after filtering")
    Assert(TitleView([titles[0]],"series","title").Count() = 0,"filter has no synthetic or substituted results")
    Assert(TitleView(titles,"all","relevance")[0].id = 1,"provider/exact-match ranking retained by default")
    Assert(RemoteSeconds("step") = 10 and RemoteSeconds("skip") = 30,"missing settings preserve familiar remote defaults")
    m.remote_skip = 60
    m.remote_step = 5
    m.remote_replay = 15
    Assert(RemoteSeconds("skip") = 60 and RemoteSeconds("step") = 5 and RemoteSeconds("replay") = 15,"remote intervals are independent")
    m.remote_skip = -10
    Assert(RemoteSeconds("skip") = 30,"corrupt intervals cannot produce negative seeks")
    for each position in ["bottom","raised","top"]
        y = CaptionPlacement(224,position,true)
        Assert(y >= 130 and y + 224 <= 416,"large captions stay above controls: " + position)
    end for
    Assert(CaptionPlacement(100,"raised",false) < CaptionPlacement(100,"bottom",false),"raised position clears lower-third film text")
    Assert(CaptionPlacement(100,"top",false) = 130,"top captions stay below playback notices")
    Assert(CaptionContrast("bad") = "0x000000b0" and CaptionContrast("solid") = "0x000000ff","contrast fallback and solid background are readable")
    Assert(SleepReason(30,1799,120,100) = "","sleep deadline does not trigger early")
    Assert(SleepReason(30,1800,120,7200) = "sleep","sleep deadline takes priority over still-watching prompt")
    Assert(SleepReason(0,99999,120,7200) = "still","still-watching threshold works without sleep timer")
    Assert(SleepReason(0,99999,0,99999) = "","disabled sleep controls never interrupt playback")
    packed = EpisodeStorage(items,4096)
    Assert(Len(packed.json) <= 4096,"episode storage respects byte budget, not only item count")
    unpacked = CleanEpisodeHistory(ParseJson(packed.json))
    Assert(unpacked.Count() = packed.items.Count() and unpacked[0].episodeId = 351,"compact ledger round-trips all retained entries")
    Assert(EpisodeStorage(items,80).items.Count() < items.Count() and Len(EpisodeStorage(items,80).json) <= 80,"low registry space trims oldest ledger entries")
    local = [{id:1,episodeId:10,position:100,duration:1000,completed:false,updated:CreateObject("roDateTime").AsSeconds()}]
    remote = [{id:1,episodeId:10,position:180,duration:1000,completed:false,updated:0,syncDirty:false}]
    Assert(EpisodeResumeEntry(remote,local,1,10).position = 180,"untimestamped forward cloud progress is not shadowed by ledger")
    remote[0].position = 60
    Assert(EpisodeResumeEntry(remote,local,1,10).position = 100,"recent ledger checkpoint resists stale cloud rollback")
    local[0].updated = local[0].updated - 301
    Assert(EpisodeResumeEntry(remote,local,1,10).position = 60,"settled cross-device rewind can supersede old ledger")
    local[0].completed = true
    Assert(EpisodeResumeEntry(remote,local,1,10).completed,"cloud snapshot cannot undo local watched marker")
    print "REGRESSION PASS: ";m.checks;" watching assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
