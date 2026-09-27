sub Main()
    m.checks = 0
    Assert(MarkerSeconds("00:00:00") = 0,"zero is a valid intro start")
    Assert(MarkerSeconds("01:02:03") = 3723,"provider HH:MM:SS parses exactly")
    for each value in [invalid,{},[],23,"", "3:12","00:60:00","00:00:60","-1:00:00","00:00:02x"," 00:00:02","24:00:00"]
        Assert(MarkerSeconds(value) = -1,"malformed timestamp rejected")
    end for
    for each options in [invalid,{}, {intro_start:"00:00:10",intro_end:"00:00:09"},{intro_start:"00:00:10",intro_end:"00:00:10"},{intro_start:"00:00:00",intro_end:"00:20:00"}]
        Assert(IntroMarker(options) = invalid,"missing/reversed/oversized marker rejected")
    end for
    marker = IntroMarker({intro_start:"00:00:10",intro_end:"00:00:30"})
    Assert(IntroTarget(marker,9.99,60) = -1,"does not appear before marker")
    Assert(IntroTarget(marker,10,60) = 30,"exact start included")
    Assert(IntroTarget(marker,29.99,60) = 30,"last fraction inside intro included")
    Assert(IntroTarget(marker,30,60) = -1,"end excluded")
    Assert(IntroTarget(marker,12,0) = -1,"unknown duration suppresses skip")
    Assert(IntroTarget(marker,12,30) = -1,"skip cannot finish episode")
    Assert(IntroTarget(marker,12,20) = -1,"out of duration rejected")
    Assert(IntroTarget(invalid,12,60) = -1,"no marker means no fabricated skip")
    Assert(IntroTarget(marker,"12",60) = -1,"wrong position type rejected")
    m.page = "player": m.playStarted = true: m.player = {state:"playing",position:12.7,duration:60}
    m.introMarker = marker: m.trackPicker = {visible:false}:m.watchPrompt = {visible:false}
    Assert(ActiveIntroTarget() = 30,"active intro available while playing")
    SkipIntro()
    Assert(m.delta = 18,"skip targets exact endpoint with existing seek rounding")
    m.player.position = 29
    Assert(ActiveIntroTarget() = -1,"keyframe landing before endpoint does not re-offer skip")
    m.introSkipped = false
    m.player.state = "paused"
    Assert(ActiveIntroTarget() = 30,"paused intro still available")
    m.seekPending = true
    Assert(ActiveIntroTarget() = -1,"rapid repeated OK cannot seek twice")
    m.seekPending = false:m.seekSettling = true
    Assert(ActiveIntroTarget() = -1,"settling seek suppresses stale prompt")
    m.seekSettling = false:m.player.state = "buffering"
    Assert(ActiveIntroTarget() = -1,"no skip during startup or rebuffer")
    m.player.state = "playing":m.nextPending = true
    Assert(ActiveIntroTarget() = -1,"countdown takes priority")
    m.nextPending = false:m.page = "title"
    Assert(ActiveIntroTarget() = -1,"stale callback outside playback cannot offer skip")
    m.page = "player":m.playStarted = false
    Assert(ActiveIntroTarget() = -1,"no skip before first playing")
    m.playStarted = true:m.controls = {visible:false}:m.introPrompt = {visible:false}
    UpdateIntro()
    Assert(m.introPrompt.visible,"hidden controls allow discoverable prompt")
    m.trackPicker.visible = true:UpdateIntro()
    Assert(not m.introPrompt.visible,"subtitle picker suppresses prompt")
    m.delta = 0:SkipIntro()
    Assert(m.delta = 0,"modal cannot trigger skip")
    m.trackPicker.visible = false:m.watchPrompt.visible = true:UpdateIntro()
    Assert(not m.introPrompt.visible,"still-watching prompt wins")
    m.watchPrompt.visible = false:m.controls.visible = true:UpdateIntro()
    Assert(not m.introPrompt.visible and m.drawn = true,"controls show toolbar action instead of competing prompt")
    print "INTRO REGRESSION PASS ";m.checks
end sub
sub SeekBy(delta as Integer)
    m.delta = delta
end sub
sub DrawControls()
    m.drawn = true
end sub
sub Assert(ok as Boolean,label as String)
    m.checks = m.checks + 1
    if not ok then print "FAIL: ";label:stop
end sub
