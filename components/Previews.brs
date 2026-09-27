' Explicit scene browsing: quick seek/replay remains unchanged.
sub OpenScenePreview()
    if m.page <> "player" or m.playStarted <> true or m.nextPending = true then return
    if m.seekPending = true or m.seekSettling = true then return
    if m.player.state <> "playing" and m.player.state <> "paused" then return
    CancelScenePreview()
    m.previewWasPaused = m.player.state = "paused" or m.pauseAfterSeek = true
    m.previewTarget = PreviewTarget(m.player.position,0,m.player.duration)
    m.scenePreview.visible = true
    m.previewImage.uri = ""
    m.previewImage.visible = false
    HideControls()
    m.trackPicker.visible = false
    m.captionLayer.visible = false
    m.introPrompt.visible = false
    m.player.control = "pause"
    m.controlButtons.setFocus(true)
    RefreshScenePreview()
end sub

sub CancelScenePreview()
    if m.scenePreview = invalid then return
    m.scenePreview.visible = false
    m.previewTimer.control = "stop"
    m.previewSerial = SafeInt(m.previewSerial) + 1
    if m.previewTask <> invalid then
        m.previewTask.UnobserveField("result")
        m.previewTask.control = "stop"
        m.previewTask = invalid
    end if
    m.previewImage.uri = ""
    m.previewImage.visible = false
    if IsList(m.previewFiles) then
        for each path in m.previewFiles
            DeleteFile(path)
        end for
    end if
    m.previewFiles = []
end sub

sub RefreshScenePreview()
    m.previewSerial = SafeInt(m.previewSerial) + 1
    if m.previewTask <> invalid then
        m.previewTask.UnobserveField("result")
        m.previewTask.control = "stop"
        m.previewTask = invalid
    end if
    m.previewImage.visible = false
    m.previewTime.text = ClockText(m.previewTarget) + " / " + ClockText(m.player.duration)
    m.previewStatus.text = "Loading scene..."
    m.previewTimer.control = "stop"
    m.previewTimer.control = "start"
end sub

sub OnPreviewTimer()
    if m.page <> "player" or not m.scenePreview.visible then return
    if m.helperToken = "" or Left(m.helperUrl,8) <> "https://" then
        m.previewStatus.text = "Preview unavailable · you can still seek to this time"
        return
    end if
    task = CreateObject("roSGNode","PreviewTask")
    task.url = m.sourceOptions[m.sourceIndex].url
    task.helperUrl = m.helperUrl
    task.helperToken = m.helperToken
    task.seconds = m.previewTarget
    task.serial = m.previewSerial
    task.ObserveField("result","OnPreviewResult")
    m.previewTask = task
    task.control = "run"
end sub

sub OnPreviewResult(event as Object)
    task = event.GetRoSGNode()
    if m.previewTask = invalid or m.page <> "player" then return
    if not m.scenePreview.visible or task.serial <> m.previewSerial then return
    result = event.GetData()
    m.previewTask.UnobserveField("result")
    m.previewTask = invalid
    m.previewStatus.text = "Preview unavailable · you can still seek to this time"
    if IsMap(result) then
        if result.status = 401 then RefreshManagedSession()
    end if
    if not ValidPreviewResponse(result,m.previewTarget) then return
    bytes = CreateObject("roByteArray")
    bytes.FromBase64String(result.jpeg)
    if bytes.Count() < 128 or bytes.Count() > 100000 then return
    if bytes[0] <> 255 or bytes[1] <> 216 then return
    path = "tmp:/scene-" + m.previewSession + "-" + Text(m.previewSerial) + ".jpg"
    if not bytes.WriteFile(path) then return
    m.previewFiles.Push(path)
    while m.previewFiles.Count() > 3
        DeleteFile(m.previewFiles.Shift())
    end while
    m.previewImage.uri = path
    m.previewImage.visible = true
    m.previewStatus.text = "Scene near " + ClockText(result.seconds)
end sub

function ScenePreviewKey(key as String) as Boolean
    if key = "back" or key = "OK" or key = "play" then
        target = m.previewTarget
        wasPaused = m.previewWasPaused
        CancelScenePreview()
        m.pauseAfterSeek = wasPaused
        if key <> "back" then
            SeekBy(target - SafeInt(m.player.position))
            m.pauseAfterSeek = wasPaused
            OnSeekCommit()
        end if
        if not wasPaused then m.player.control = "resume"
        ShowControls()
        return true
    end if
    delta = 0
    if key = "left" then delta = -RemoteSeconds("step")
    if key = "right" then delta = RemoteSeconds("step")
    if key = "rewind" then delta = -RemoteSeconds("skip")
    if key = "fastforward" then delta = RemoteSeconds("skip")
    if key = "replay" then delta = -RemoteSeconds("replay")
    if delta <> 0 then
        target = PreviewTarget(m.previewTarget,delta,m.player.duration)
        if target <> m.previewTarget then m.previewTarget = target: RefreshScenePreview()
    end if
    return true
end function

sub OnPreviewImageStatus()
    if m.scenePreview.visible and m.previewImage.loadStatus = "failed" then
        m.previewImage.visible = false
        m.previewStatus.text = "Preview unavailable · you can still seek to this time"
    end if
end sub
