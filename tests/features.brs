sub Main()
    one = NormalizeTitle({id:1,title:"One"})
    list = ToggleWatchlist([],one)
    Assert(list.Count()=1,"watchlist adds")
    Assert(ToggleWatchlist(list,one).Count()=0,"watchlist removes without duplicates")
    items=[]
    for i=1 to 120
        items = ToggleWatchlist(items,NormalizeTitle({id:i,title:Text(i)}))
    end for
    Assert(items.Count()=100 and items[0].id=120,"watchlist has bounded newest-first storage")
    queries=CleanSearches(["  Love ","love",123,"", "Breaking Bad"])
    Assert(queries.Count()=2 and queries[0]="Love","recent search trims and deduplicates malformed data")
    Assert(RememberSearch(queries,"Breaking Bad")[0]="Breaking Bad","reused query moves to first position")
    options=StreamOptions({source:[{auto:"file:///invalid", "2ch":"https://example.test/stereo.m3u8","6ch":"https://example.test/stereo.m3u8"}],url:"javascript:invalid"})
    Assert(options.Count()=1 and options[0].label="Stereo","source list rejects non-media schemes and deduplicates")
    Assert(ClampCaptionOffset(-11000)=-10000 and ClampCaptionOffset(11000)=10000,"caption adjustment stays within ten-second bounds")
    cues=[{start:1.0,finish:2.0,text:"Timed"}]
    ' Parser uses start/end fields; exercise the actual caption evaluator below.
    cues=ParseCaptions("WEBVTT"+Chr(10)+Chr(10)+"00:00:01.000 --> 00:00:02.000"+Chr(10)+"Timed",false)
    Assert(CaptionAt(cues,1.2 - 0.5)="","positive delay does not render early")
    Assert(CaptionAt(cues,1.6 - 0.5)="Timed","positive delay shifts cue appearance")
    layout=CaptionLayout("Subtitle test: English",40)
    Assert(layout.size=40 and layout.height-8>69,"large subtitle label accommodates merged font ascent/descent")
    layout=CaptionLayout("One"+Chr(10)+"Two"+Chr(10)+"Three"+Chr(10)+"Four",40)
    Assert(layout.height<=224 and layout.size<40,"multiline captions fit the bounded overlay")
    cues = [{start:59.0,finish:61.0,text:"Across minute"},{start:60.0,finish:62.0,text:"Overlap"}]
    index = BuildCaptionIndex(cues)
    Assert(IndexedCaptionAt(index,60.5)=CaptionAt(cues,60.5),"indexed captions preserve overlapping boundary cues")
    Assert(IndexedCaptionAt(index,59.5)="Across minute","indexed captions support backwards seeking")
    Assert(IndexedCaptionAt(index,62.0)="","indexed captions clear at exact cue end")
    cues = [{start:0.0,finish:10000.0,text:"Long"},{start:3.0,finish:4.0,text:"Short"}]
    Assert(IndexedCaptionAt(BuildCaptionIndex(cues),3.5)=CaptionAt(cues,3.5),"pathological long cue has bounded indexing and stable order")
    print "REGRESSION PASS: 15 feature assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    print "PASS: ";label
end sub
