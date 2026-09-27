sub Main()
    m.checks = 0
    movie = ParseStoreLink({contentId:"123",mediaType:"movie"})
    Assert(movie.titleId = 123 and movie.episodeId = 0,"movie routes by title")
    ep = ParseStoreLink({CONTENTID:"123:456",MEDIATYPE:"EPISODE"})
    Assert(ep.episodeId = 456 and ep.kind = "episode","case insensitive keys and types")
    for each args in [{},{contentId:"x",mediaType:"movie"},{contentId:"0",mediaType:"movie"},{contentId:"-1",mediaType:"movie"},{contentId:"1/stream",mediaType:"movie"},{contentId:"9999999999",mediaType:"movie"},{contentId:"1",mediaType:"episode"},{contentId:"1:2:3",mediaType:"episode"},{contentId:"1:0",mediaType:"series"},{contentId:"1:2",mediaType:"movie"},{contentId:"1",mediaType:"liveFeed"},{contentId:{url:"bad"},mediaType:"movie"}]
        Assert(ParseStoreLink(args) = invalid,"malformed or unsupported deep link rejected")
    end for
    episodes = [{id:10,season:0},{id:11,season:1},{id:12,season:1}]
    link = {kind:"series",episodeId:11}
    Assert(StoreEpisodeIndex(link,episodes,invalid) = 1,"unwatched series begins first regular episode")
    Assert(StoreEpisodeIndex(link,episodes,{episodeId:12,completed:false}) = 2,"series resumes prior episode")
    Assert(StoreEpisodeIndex(link,episodes,{episodeId:11,completed:true}) = 2,"series advances completed episode")
    Assert(StoreEpisodeIndex({kind:"episode",episodeId:12},episodes,invalid) = 2,"exact episode bypasses chooser")
    Assert(StoreEpisodeIndex({kind:"series",episodeId:999},episodes,invalid) = -1,"removed ID fails rather than playing arbitrary content")
    Assert(StoreCaptionVisible("On",90,0),"system On shows sidecar")
    Assert(not StoreCaptionVisible("Off",90,100),"system Off overrides replay")
    Assert(StoreCaptionVisible("Instant replay",90,100),"replay captions inside window")
    Assert(not StoreCaptionVisible("Instant replay",100,100),"replay captions end at original position")
    Assert(not StoreCaptionVisible("Unknown",90,100),"unknown mode fails closed")
    m.remote_replay = 30
    Assert(RemoteSeconds("replay") = 10,"old out-of-range replay migrates to valid default")
    m.remote_replay = 25
    Assert(RemoteSeconds("replay") = 25,"25-second replay supported")
    token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    Assert(ValidServiceSession({success:true,token:token,expiresIn:900}),"valid bounded service session accepted")
    for each data in [invalid,{},{success:"true",token:token,expiresIn:900},{success:{},token:token,expiresIn:900},{success:true,token:"short",expiresIn:900},{success:true,token:token,expiresIn:901},{success:true,token:token,expiresIn:"900"},{success:true,token:token,expiresIn:0}]
        Assert(not ValidServiceSession(data),"invalid service reply cannot become helper credential")
    end for
    Assert(SystemCaptionColor("Yellow","75%","0xffffffff") = "0xffff00bf","system caption color and opacity respected")
    Assert(SystemCaptionColor("Default","Default","0x000000b0") = "0x000000b0","unspecified system style preserves readable app default")
    Assert(SystemCaptionColor("Blue","Off","0x000000b0") = "0x0000ff00","system background Off is transparent")
    print "REGRESSION PASS: ";m.checks;" store model assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
