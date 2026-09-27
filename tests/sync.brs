sub Main()
    local = HistoryEntry(NormalizeTitle({id:1,title:"Local"}),{id:12,season:1,number:2,title:"Two"},304,2800,false)
    merged = MergeRemoteHistory([local],[{id:1,title:"Old remote",is_series:true,season:1,episode:1,time:30}])
    Assert(merged[0].position = 304 and merged[0].episodeId = 12,"unsent local position and episode survive stale website snapshot")
    remote = MergeRemoteHistory([],[{id:2,title:"Website",is_series:true,season:3,episode:6,time:"120"}])
    Assert(remote[0].position=120 and remote[0].number=6 and remote[0].season=3,"website episode identity and seconds imported")
    Assert(not remote[0].syncDirty,"imported history does not queue a write")
    local.syncDirty = false
    merged = MergeRemoteHistory([local],[{id:1,title:"Remote",is_series:true,season:1,episode:2,time:600}])
    Assert(merged[0].position=600 and merged[0].episodeId=12,"acknowledged local record takes newer website position")
    local.completed=true
    merged = MergeRemoteHistory([local],[{id:1,title:"Remote",time:300}])
    Assert(merged[0].completed,"stale website history cannot undo local completion")
    recent = HistoryEntry(NormalizeTitle({id:3,title:"Recent",is_series:true}),{id:37,season:3,number:7,title:"Seven"},180,1334,false)
    recent.syncDirty = false
    merged = MergeRemoteHistory([recent],[{id:3,title:"Cached",is_series:true,season:3,episode:7,time:90}])
    Assert(merged[0].position=180,"acknowledged recent checkpoint survives provider history cache lag")
    merged = MergeRemoteHistory([recent],[{id:3,title:"Previous",is_series:true,season:3,episode:6,time:1350}])
    Assert(merged[0].number=7 and merged[0].episodeId=37,"cached prior episode cannot undo a recent automatic transition")
    recent.updated = recent.updated - 600
    merged = MergeRemoteHistory([recent],[{id:3,title:"Other device",is_series:true,season:3,episode:6,time:300}])
    Assert(merged[0].number=6 and merged[0].position=300,"older local checkpoint may accept an intentional remote rewind")
    Assert(SafeInt(1790456638)=1790456638,"integer epoch timestamp retains exact precision")
    Assert(SafeInt("1790456638")=1790456638,"string epoch timestamp retains exact precision")
    print "REGRESSION PASS: 10 sync assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    print "PASS: ";label
end sub
