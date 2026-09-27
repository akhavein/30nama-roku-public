sub Main()
    m.checks = 0
    Assert(Text(invalid) = "", "missing text")
    Assert(SafeInt("bad") = 0, "invalid number")
    Assert(Truth(1) and Truth(true) and Truth("true") and not Truth("false"), "API boolean variants")
    Assert(NormalizeTitle({title:"No id"}) = invalid, "reject missing title ID")
    Assert(NormalizeTitle("bad") = invalid, "reject scalar title")
    title = NormalizeTitle({id:42,title:"Movie",image:{poster:{medium:"https://example.invalid/poster"}},english_plot:"Plot"})
    Assert(title.poster = "https://example.invalid/poster", "poster fallback")
    Assert(title.plot = "Plot", "English plot")
    Assert(NormalizeTitle({id:1,title:"Series",is_series:1}).isSeries, "numeric series flag")
    Assert(NormalizeTitle({id:1,title:"Series",is_series:"true"}).isSeries, "string series flag")
    Assert(NormalizeTitles([invalid,{},title,title]).Count() = 1, "deduplicate and reject malformed catalog")
    Assert(SectionPosts(invalid).Count() = 0, "missing catalog")
    Assert(SectionPosts({posts:[title]}).Count() = 1, "section envelope")
    Assert(SectionPosts([title]).Count() = 1, "bare section array")
    Assert(FlattenEpisodes(invalid).Count() = 0, "missing episodes")
    Assert(FlattenEpisodes({}).Count() = 0, "empty episodes")
    Assert(FlattenEpisodes([]).Count() = 0, "wrong episode envelope")
    seasons = {
        "10": [{data:{id:1001,season:10,number:1}}],
        "2": [{data:{id:203,season:2,number:3}}, {data:{id:201,season:2,number:1}}],
        "1": [invalid,{}, {data:{id:102,season:1,number:2}}, {data:{id:101,season:1,number:1}}, {data:{id:101,season:1,number:1}}],
        "bad":"bad"
    }
    episodes = FlattenEpisodes(seasons)
    Assert(episodes.Count() = 5, "malformed and duplicate episodes skipped")
    expected = [101,102,201,203,1001]
    for i = 0 to expected.Count() - 1
        Assert(episodes[i].id = expected[i], "numeric episode order " + Text(i))
    end for
    Assert(SeasonNumbers(episodes).Count() = 3, "unique season picker")
    Assert(EpisodesInSeason(episodes,2).Count() = 2, "season filter")
    Assert(EpisodesInSeason(episodes,99).Count() = 0, "missing season")
    Assert(EpisodeIndex(episodes,1001) = 4, "resume episode lookup")
    Assert(EpisodeIndex(episodes,7) = -1, "removed episode lookup")
    Assert(StreamUrl(invalid) = "", "no stream")
    Assert(StreamUrl({source:[{}, {auto:"https://example.invalid/a.m3u8"}]}).Instr("a.m3u8") > 0, "skip empty stream source")
    Assert(StreamUrl({source:[{"2ch":"https://example.invalid/b.m3u8"}]}).Instr("b.m3u8") > 0, "stereo stream fallback")
    Assert(StreamUrl({url:"javascript:invalid"}) = "", "reject nonmedia scheme")
    Assert(SubtitleOptions(invalid).Count() = 2, "system and off without sidecars")
    Assert(SubtitleOptions({en:"https://example.invalid/en.vtt",fa:"https://example.invalid/fa.vtt"}).Count() = 4, "both subtitle languages")
    Assert(SubtitleOptions({en:[],fa:""}).Count() = 2, "malformed subtitle URLs")
    Assert(MediaUrl("link://example.invalid/en.srt") = "https://example.invalid/en.srt", "SDK subtitle protocol placeholder")
    Assert(MediaUrl("linkStream://example.invalid/video.m3u8") = "https://example.invalid/video.m3u8", "SDK stream protocol placeholder")
    Assert(SubtitleOptions({en:"link://example.invalid/en.srt"}).Count() = 3, "real API subtitle scheme")
    Assert(EpisodeLabel({title:"قسمت دوم"},2) = "Episode 2", "safe English episode label")
    Assert(ClockText(-1) = "0:00", "negative clock")
    Assert(ClockText(65) = "1:05", "minute clock")
    Assert(ClockText(3661) = "1:01:01", "hour clock")
    Assert(SeekTarget(4,-10,100) = 0, "rewind lower bound")
    Assert(SeekTarget(96,10,100) = 99, "seek upper bound")
    Assert(SeekTarget(50,10,0) = 60, "unknown duration seek")
    Assert(CleanHistory(invalid).Count() = 0, "missing history")
    Assert(CleanHistory({bad:"data"}).Count() = 0, "corrupt history envelope")
    entry = HistoryEntry(title,invalid,150,500,false)
    history = HistoryUpsert([],entry)
    Assert(history.Count() = 1, "save movie")
    Assert(ResumeSeconds(history[0],0) = 150, "resume movie exact position")
    Assert(ResumeSeconds(history[0],88) = 0, "different episode never inherits position")
    entry.position = 180
    history = HistoryUpsert(history,entry)
    Assert(history.Count() = 1 and history[0].position = 180, "update without duplicate")
    series = NormalizeTitle({id:99,title:"Series",is_series:true})
    entry = HistoryEntry(series,episodes[2],300,900,false)
    history = HistoryUpsert(history,entry)
    Assert(history.Count() = 2, "multiple saved titles")
    Assert(history[0].episodeId = 201 and history[0].season = 2 and history[0].number = 1, "exact episode identity")
    Assert(ResumeSeconds(history[0],201) = 300, "exact episode position")
    Assert(HistoryFind(history,42).position = 180, "other movie retained")
    restarted = HistoryEntry(series,episodes[2],0,900,false)
    history = HistoryUpsert(history,restarted)
    Assert(ResumeSeconds(history[0],201) = 0, "restart clears checkpoint")
    nextEpisode = HistoryEntry(series,episodes[3],0,0,false)
    history = HistoryUpsert(history,nextEpisode)
    Assert(history[0].episodeId = 203 and ContinueItems(history).Count() = 2, "next episode is resumable target")
    completed = HistoryEntry(title,invalid,500,500,true)
    history = HistoryUpsert(history,completed)
    Assert(ContinueItems(history).Count() = 1, "completed movie hidden")
    Assert(ResumeSeconds(history[0],0) = 0, "completed movie starts fresh")
    restored = CleanHistory(ParseJson(FormatJson(history)))
    Assert(restored.Count() = 2 and restored[1].episodeId = 203, "persist and reload exact episode")
    Assert(HistoryRemove(restored,99).Count() = 1, "remove selected continue entry")
    entry = HistoryEntry(title,invalid,-9,-10,false)
    cleaned = CleanHistory([entry])
    Assert(cleaned[0].position = 0 and cleaned[0].duration = 0, "corrupt negative positions sanitized")
    entry = HistoryEntry(title,invalid,499,500,false)
    Assert(ResumeSeconds(entry,0) = 499, "unfinished final seconds do not restart entire title")
    many = []
    for i = 1 to 30
        many = HistoryUpsert(many,HistoryEntry(NormalizeTitle({id:i,title:"T"}),invalid,i,100,false))
    end for
    Assert(many.Count() = 20 and many[0].id = 30 and many[19].id = 11, "history bounded and recent-first")
    dirty = {id:72,title:"Safe",position:10,duration:50,url:"https://secret.invalid",token:"do-not-save",file:{url:"private"}}
    clean = CleanHistory([dirty])[0]
    Assert(not clean.DoesExist("url") and not clean.DoesExist("token") and not clean.DoesExist("file"), "history strips credentials and signed URLs")
    native = [{Language:"eng",Description:"English",TrackName:"srt/0"},{Language:"per",Description:"Persian",TrackName:"srt/1"}]
    options = NativeSubtitleOptions(SubtitleOptions({en:"link://example.invalid/en.srt",fa:"link://example.invalid/fa.srt"}),native)
    Assert(options.Count() = 4, "no duplicate sidecar/native subtitles")
    Assert(options[2].track = "srt/0" and options[3].track = "srt/1", "select Roku native subtitle identifiers")
    audio = AudioOptions([{Track:"a",Name:"audio",Language:"eng"},{Track:"b",Name:"audio",Language:"fas"},{Track:"a",Name:"duplicate"},invalid,{}])
    Assert(audio.Count() = 2, "audio filters invalid and duplicate track IDs")
    Assert(audio[0].label = "1 · English" and audio[1].label = "2 · Persian", "audio labels distinguish anonymous tracks")
    Assert(audio[1].track = "b", "audio preserves native selection ID")
    Assert(AudioOptions(invalid)[0].track = "", "no audio alternatives remains safe")
    print "REGRESSION PASS: "; m.checks; " assertions"
end sub
sub Assert(condition as Boolean, label as String)
    if not condition then print "FAIL: "; label: stop
    m.checks = m.checks + 1
    print "PASS: "; label
end sub
