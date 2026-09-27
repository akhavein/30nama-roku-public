' Manual, provider-backed intro skipping. Never infer a marker from duration.
function ActiveIntroTarget() as Integer
    if m.introSkipped = true then return -1
    if m.page <> "player" or m.playStarted <> true or m.nextPending = true then return -1
    if m.seekPending = true or m.seekSettling = true then return -1
    if m.player.state <> "playing" and m.player.state <> "paused" then return -1
    return IntroTarget(m.introMarker,m.player.position,m.player.duration)
end function

sub UpdateIntro()
    if m.introPrompt = invalid then return
    if m.scenePreview <> invalid then
        if m.scenePreview.visible then m.introPrompt.visible = false: return
    end if
    available = ActiveIntroTarget() >= 0
    m.introPrompt.visible = available and not m.controls.visible and not m.trackPicker.visible and not m.watchPrompt.visible
    if m.controls.visible and m.controlIntroAvailable <> available then DrawControls()
end sub

sub SkipIntro()
    target = ActiveIntroTarget()
    if target < 0 or m.trackPicker.visible or m.watchPrompt.visible then return
    SeekBy(target - SafeInt(m.player.position))
    ' HLS may land on a keyframe just before the endpoint. Do not re-offer
    ' the same skip unless the viewer deliberately rewinds or restarts.
    m.introSkipped = true
end sub
