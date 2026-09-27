sub Main()
    m.checks = 0
    Assert(PreviewTarget(10,-30,60) = 0,"preview clamps before start")
    Assert(PreviewTarget(55,30,60) = 59,"preview cannot seek past end")
    Assert(PreviewTarget(12.9,10,60) = 22,"preview timestamp follows seek rounding")
    for each value in [invalid,{},[],{success:false},{success:{}},{success:[]},{success:"true"},{success:true,seconds:"5",jpeg:"abcdefgh"},{success:true,seconds:6,jpeg:"abcdefgh"},{success:true,seconds:5,jpeg:[]},{success:true,seconds:5,jpeg:""}]
        Assert(not ValidPreviewResponse(value,5),"malformed or stale preview rejected")
    end for
    Assert(ValidPreviewResponse({success:true,seconds:5,jpeg:"abcdefgh"},5),"matching bounded preview accepted")
    Fixture("playing")
    OpenScenePreview()
    Assert(m.scenePreview.visible and m.player.control = "pause","opening preview pauses real playback")
    Assert(not m.previewWasPaused and m.previewTarget = 20,"playing intent and initial position captured")
    Assert(not m.captionLayer.visible and not m.introPrompt.visible,"preview suppresses competing overlays")
    ScenePreviewKey("right")
    Assert(m.previewTarget = 30 and m.seekCalls = 0,"browsing changes target not playback position")
    ScenePreviewKey("fastforward")
    Assert(m.previewTarget = 59,"large preview jumps remain bounded")
    ScenePreviewKey("back")
    Assert(not m.scenePreview.visible and m.player.control = "resume" and m.seekCalls = 0,"cancel restores playing without seeking")
    Fixture("paused")
    OpenScenePreview():ScenePreviewKey("left"):ScenePreviewKey("OK")
    Assert(m.seekCalls = 1 and m.delta = -10 and m.committed,"OK commits exactly one requested seek")
    Assert(m.pauseAfterSeek and m.player.control <> "resume","paused intent survives confirmation")
    Fixture("playing")
    OpenScenePreview():m.player.state = "paused":ScenePreviewKey("right"):ScenePreviewKey("play")
    Assert(not m.pauseAfterSeek and m.player.control = "resume","original playing intent survives paused scrubber")
    Fixture("paused"):OpenScenePreview():ScenePreviewKey("back")
    Assert(m.seekCalls = 0 and m.player.control <> "resume","cancel keeps original pause")
    Fixture("buffering"):OpenScenePreview()
    Assert(not m.scenePreview.visible,"startup/rebuffer cannot open preview")
    Fixture("playing"):m.seekPending = true:OpenScenePreview()
    Assert(not m.scenePreview.visible,"in-flight seek cannot open preview")
    Fixture("playing"):OpenScenePreview():serial = m.previewSerial
    m.previewTask = {serial:serial,unobserveField:sub(field)
    end sub}
    task = m.previewTask:CancelScenePreview()
    Assert(task.control = "stop" and m.previewTask = invalid and m.previewSerial > serial,"close cancels request and invalidates late result")
    print "PREVIEW REGRESSION PASS ";m.checks
end sub
sub Fixture(state as String)
    m.page = "player":m.playStarted = true:m.nextPending = false:m.seekPending = false:m.seekSettling = false:m.pauseAfterSeek = false
    m.player = {state:state,position:20,duration:60,control:""}
    m.scenePreview = {visible:false}:m.previewImage = {}:m.previewTime = {}:m.previewStatus = {}:m.previewTimer = {}
    m.controls = {}:m.trackPicker = {}:m.captionLayer = {visible:true}:m.introPrompt = {visible:true}
    m.controlButtons = {setFocus:sub(f)
    end sub}
    m.previewFiles = []:m.previewTask = invalid:m.seekCalls = 0:m.committed = false
end sub
sub HideControls()
    m.controls.visible = false
end sub
sub ShowControls()
    m.controls.visible = true
end sub
sub SeekBy(delta as Integer)
    m.seekCalls++:m.delta = delta:m.pauseAfterSeek = m.player.state = "paused"
end sub
sub OnSeekCommit()
    m.committed = true
end sub
sub Assert(ok as Boolean,label as String)
    m.checks++
    if not ok then print "FAIL: ";label:stop
end sub
