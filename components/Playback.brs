sub StartPlayback(file as Dynamic, subtitles as Dynamic, sourceIndex = 0 as Integer, recovering = false as Boolean)
    CancelScenePreview()
    if not recovering then ResetPlaybackSession()
    m.sourceOptions = StreamOptions(file)
    m.activeFile = file
    m.activeSubtitles = subtitles
    m.sourceIndex = sourceIndex
    url = ""
    if sourceIndex >= 0 and sourceIndex < m.sourceOptions.Count() then url = m.sourceOptions[sourceIndex].url
    if url = "" then m.status.text = "No compatible stream is available for this selection": return
    CancelPageRequests()
    ClearCustomCaptions()
    m.captionCache = {}
    if IsMap(m.incomingCaption) then
        if IsList(m.incomingCaption.cues) and Text(m.incomingCaption.captionCode) <> "" then m.captionCache[m.incomingCaption.captionCode] = m.incomingCaption.cues
    end if
    m.incomingCaption = invalid
    m.generation = m.generation + 1
    m.page = "player"
    m.shell.visible = false
    m.playerScreen.visible = true
    m.trackPicker.visible = false
    m.controls.visible = false
    m.introPrompt.visible = false
    m.playbackStatus.text = "Loading playback..."
    m.subtitleOptions = SubtitleOptions(subtitles)
    print "[30nama][subtitles] sidecars="; m.subtitleOptions.Count() - 2
    m.controlIndex = 0
    m.pauseAfterSeek = recovering and m.recoveryPaused = true
    m.seekPending = false
    m.seekSettling = false
    m.seekNotice.text = ""
    m.pendingAudio = true
    m.lastGoodPosition = 0
    m.advanceClock = CreateObject("roTimespan")
    m.advanceClock.Mark()
    m.healthTimer.control = "start"
    m.playStarted = false
    m.playCompleted = false
    m.pendingSubtitle = true
    m.playerError = false
    m.captionAuthRetries = 0
    m.reauthCaption = false
    m.captionReplayUntil = 0
    m.originalCaptionMode = CreateObject("roDeviceInfo").GetCaptionsMode()
    m.defaultSubtitleTrack = ""
    content = CreateObject("roSGNode", "ContentNode")
    content.title = m.title.title
    content.url = url
    content.streamFormat = "hls"
    if Instr(1,LCase(url),".mp4") > 0 then content.streamFormat = "mp4"
    if Instr(1,LCase(url),".mpd") > 0 then content.streamFormat = "dash"
    content.VideoDisableUI = true
    ' External sidecars use our Unicode renderer; embedded tracks stay native.
    episodeId = 0
    if m.episode <> invalid then episodeId = m.episode.id
    m.captionOffsetKey = "caption_offset_" + Text(m.title.id) + "_" + Text(episodeId)
    m.captionOffset = ClampCaptionOffset(SafeInt(m.registry.Read(m.captionOffsetKey)))
    seconds = ResumeSeconds(EpisodeResumeEntry(m.history,m.episodeHistory,m.title.id,episodeId),episodeId)
    if m.startOver then seconds = 0
    m.expectedResume = seconds
    m.lastGoodPosition = seconds
    if seconds > 0 then content.playStart = seconds
    m.player.notificationInterval = 0.25
    m.player.content = content
    ' Sidecars can load while the decoder buffers; embedded tracks wait for the
    ' native availability event. Never delay picture startup for subtitles.
    preferred = m.registry.Read("subtitle_preference")
    if (preferred = "fa" or preferred = "en") and SidecarUrl(preferred) <> "" then
        LoadSidecarCaptions(preferred)
        m.pendingSubtitle = false
    end if
    m.bufferTimer.control = "start"
    m.player.control = "play"
    m.controlButtons.setFocus(true)
    print "[30nama][play] title="; m.title.id; " episode="; episodeId; " resume="; seconds
end sub

sub OnPlayerState()
    state = m.player.state
    print "[30nama][player] "; state
    if m.page <> "player" then return
    UpdateIntro()
    if state = "playing" then
        m.bufferTimer.control = "stop"
        m.playStarted = true
        QueueStoreRendered()
        m.advanceClock.Mark()
        if not m.startupMeasured then
            m.startupMeasured = true
            m.playbackMetrics.startupMs = m.playbackClock.TotalMilliseconds()
            print "[30nama][performance] first_play_ms="; m.playbackMetrics.startupMs
        end if
        OnAvailableAudio()
        if m.pauseAfterSeek then
            m.seekPauseTimer.control = "start"
            return
        end if
        m.playbackStatus.text = ""
        m.saveTimer.control = "start"
        if m.defaultSubtitleTrack = "" then m.defaultSubtitleTrack = m.player.currentSubtitleTrack
        if m.pendingSubtitle then ApplySavedSubtitle()
        if m.controls.visible then DrawControls(): m.overlayTimer.control = "start"
    else if state = "paused" then
        m.bufferTimer.control = "stop"
        m.seekPauseTimer.control = "stop"
        m.saveTimer.control = "stop"
        SavePlayback()
        ShowControls()
        m.overlayTimer.control = "stop"
        m.playbackStatus.text = "Paused"
    else if state = "buffering" then
            m.bufferTimer.control = "start"
        m.playbackMetrics.bufferEvents = m.playbackMetrics.bufferEvents + 1
        m.playbackStatus.text = "Reconnecting playback..."
        m.saveTimer.control = "stop"
        m.overlayTimer.control = "stop"
    else if state = "finished" then
        if not m.playStarted or m.playCompleted then return
        if m.autoplay = true and NextEpisode() <> invalid then
            BeginNextCountdown()
        else
            CompletePlayback()
            ClosePlayback(false)
            m.status.text = "Finished"
        end if
    else if state = "error" then
        if TryNextSource() then return
        if RecoverPlayback() then return
        m.playerError = true
        SavePlayback()
        ClosePlayback(false)
        m.status.text = "Playback failed. Press Play to fetch a fresh stream and retry."
    end if
end sub

sub OnPosition()
    if m.page <> "player" then return
    position = SafeInt(m.player.position)
    duration = SafeInt(m.player.duration)
    if m.seekSettling = true then
        if Abs(position - SafeInt(m.seekTarget)) <= 3 then
            m.seekSettling = false
            m.seekNotice.text = ""
        else if m.seekClock.TotalMilliseconds() > 15000 then
            m.seekSettling = false
            m.seekNotice.text = "Seek unavailable on this source"
        end if
    end if
    if m.seekPending <> true and m.seekSettling <> true and m.player.state = "playing" then
        if position >= 5 or SafeInt(m.lastGoodPosition) < 5 then
            if position <> SafeInt(m.lastGoodPosition) then m.advanceClock.Mark()
            m.lastGoodPosition = position
        end if
    end if
    UpdateIntro()
    MaybePrefetchNext()
    m.playerTime.text = ClockText(position) + " / " + ClockText(duration)
    ratio = 0.0
    if duration > 0 then ratio = position / duration
    if ratio > 1 then ratio = 1
    if ratio < 0 then ratio = 0
    m.timeline.width = ratio * 1152
    UpdateCustomCaption()
end sub

sub OnSaveTimer()
    SavePlayback()
end sub

sub SavePlayback()
    if m.page <> "player" or not m.playStarted or m.playCompleted then return
    position = CheckpointPosition()
    duration = SafeInt(m.player.duration)
    if duration <= 0 then
        previous = HistoryFind(m.history,m.title.id)
        if previous <> invalid then duration = previous.duration
    end if
    if position < 5 and m.seekPending <> true and m.seekSettling <> true then return
    entry = HistoryEntry(m.title,m.episode,position,duration,false)
    m.history = HistoryUpsert(m.history,entry)
    RecordEpisode(entry)
    PersistHistory()
    SendProgress(position,duration)
end sub

function NextEpisode() as Dynamic
    if m.episode = invalid then return invalid
    index = EpisodeIndex(m.allEpisodes,m.episode.id)
    if index >= 0 and index + 1 < m.allEpisodes.Count() then return m.allEpisodes[index + 1]
    return invalid
end function

sub CompletePlayback()
    RecordEpisode(HistoryEntry(m.title,m.episode,SafeInt(m.player.duration),SafeInt(m.player.duration),true))
    SendProgress(SafeInt(m.player.duration),SafeInt(m.player.duration))
    m.playCompleted = true
    nextItem = NextEpisode()
    if nextItem <> invalid then
        entry = HistoryEntry(m.title,nextItem,0,0,false)
    else
        entry = HistoryEntry(m.title,m.episode,SafeInt(m.player.duration),SafeInt(m.player.duration),true)
    end if
    m.history = HistoryUpsert(m.history,entry)
    PersistHistory()
end sub

sub ClosePlayback(save as Boolean)
    CancelScenePreview()
    m.introPrompt.visible = false
    m.watchPrompt.visible = false
    CancelNextCountdown()
    m.bufferTimer.control = "stop"
    m.healthTimer.control = "stop"
    m.seekCommitTimer.control = "stop"
    m.seekPauseTimer.control = "stop"
    ClearCustomCaptions()
    if save then SavePlayback()
    m.page = "title"
    m.saveTimer.control = "stop"
    m.overlayTimer.control = "stop"
    m.trackPicker.visible = false
    m.controls.visible = false
    m.player.control = "stop"
    m.playerScreen.visible = false
    m.shell.visible = true
    m.status.text = ""
    RenderTitle()
    m.actions.setFocus(true)
    print "[30nama][view] title after playback"
end sub

sub ShowControls()
    if m.scenePreview <> invalid then
        if m.scenePreview.visible then return
    end if
    m.trackList.setFocus(false)
    m.controls.visible = true
    m.playerTitle.text = m.title.title
    m.playerMeta.text = "Movie"
    if m.episode <> invalid then m.playerMeta.text = "S" + Text(m.episode.season) + " · E" + Text(m.episode.number) + "   " + m.episode.title
    DrawControls()
    OnPosition()
    UpdateCustomCaption()
    m.controlButtons.setFocus(true)
    if m.player.state = "playing" then m.overlayTimer.control = "start"
end sub

sub HideControls()
    m.controls.visible = false
    UpdateIntro()
    m.overlayTimer.control = "stop"
    UpdateCustomCaption()
    m.controlButtons.setFocus(true)
end sub

sub OnOverlayTimer()
    if m.page = "player" and m.player.state = "playing" and not m.trackPicker.visible then HideControls()
end sub

sub DrawControls()
    selectedAction = ""
    if IsList(m.controlActions) then
        if m.controlIndex >= 0 and m.controlIndex < m.controlActions.Count() then selectedAction = m.controlActions[m.controlIndex]
    end if
    playLabel = "Pause"
    if m.player.state = "paused" then playLabel = "Play"
    if m.player.state = "buffering" then playLabel = "Loading"
    m.controlActions = ["toggle","back10","forward10","subtitles","audio","restart"]
    labels = [playLabel,"−" + Text(RemoteSeconds("step")) + " sec","+" + Text(RemoteSeconds("step")) + " sec","Subtitles","Audio","Restart"]
    if NextEpisode() <> invalid then m.controlActions.Push("next"): labels.Push("Next")
    if m.sourceOptions.Count() > 1 then m.controlActions.Push("source"): labels.Push("Source")
    m.controlActions.Push("sleep")
    labels.Push("Sleep")
    m.controlActions.Push("scenes")
    labels.Push("Scenes")
    m.controlIntroAvailable = ActiveIntroTarget() >= 0
    if m.controlIntroAvailable then m.controlActions.Push("intro"): labels.Push("Skip intro")
    m.controlActions.Push("close")
    labels.Push("Close")
    if selectedAction <> "" then
        m.controlIndex = 0
        for i = 0 to m.controlActions.Count() - 1
            if m.controlActions[i] = selectedAction then m.controlIndex = i
        end for
    end if
    if m.controlIndex >= labels.Count() then m.controlIndex = labels.Count() - 1
    signature = m.controlActions.Join("|")
    if Text(m.controlSignature) = signature and m.controlButtons.GetChildCount() = labels.Count() then
        for i = 0 to labels.Count() - 1
            group = m.controlButtons.GetChild(i)
            bg = group.GetChild(0)
            label = group.GetChild(1)
            label.text = labels[i]
            bg.color = "0x252c38ff"
            label.color = "0xf4f6faff"
            if i = m.controlIndex then bg.color = "0xe5b46aff": label.color = "0x080b11ff"
        end for
        return
    end if
    m.controlSignature = signature
    while m.controlButtons.GetChildCount() > 0
        m.controlButtons.RemoveChildIndex(0)
    end while
    width = Int((1152 - (labels.Count() - 1) * 10) / labels.Count())
    for i = 0 to labels.Count() - 1
        group = m.controlButtons.CreateChild("Group")
        group.translation = [i * (width + 10),0]
        bg = group.CreateChild("Rectangle")
        bg.width = width
        bg.height = 46
        bg.color = "0x252c38ff"
        label = group.CreateChild("Label")
        label.translation = [4,6]
        label.width = width - 8
        label.height = 34
        label.horizAlign = "center"
        label.vertAlign = "center"
        label.font = m.hint.font
        label.text = labels[i]
        label.color = "0xf4f6faff"
        if i = m.controlIndex then bg.color = "0xe5b46aff": label.color = "0x080b11ff"
    end for
end sub

sub ActivateControl()
    action = m.controlActions[m.controlIndex]
    if action = "toggle" then
        TogglePause()
    else if action = "back10" then
        SeekBy(-RemoteSeconds("step"))
    else if action = "forward10" then
        SeekBy(RemoteSeconds("step"))
    else if action = "subtitles" then
        ShowTracks("subtitles")
    else if action = "audio" then
        ShowTracks("audio")
    else if action = "restart" then
        RestartPlayback()
    else if action = "next" then
        PlayNextEpisode()
    else if action = "source" then
        ShowTracks("source")
    else if action = "sleep" then
        ShowTracks("sleep")
    else if action = "scenes" then
        OpenScenePreview()
    else if action = "intro" then
        SkipIntro()
    else if action = "close" then
        ClosePlayback(true)
    end if
end sub

sub OnBufferTimeout()
    if m.page <> "player" then return
    if m.player.state = "playing" or m.player.state = "paused" then return
    if TryNextSource() then return
    if RecoverPlayback() then return
    ClosePlayback(true)
    m.status.text = "Playback timed out. Your progress is safe. Press Play to retry."
    print "[30nama][player] buffer timeout; returned to title"
end sub

sub OnSeekPauseTimer()
    if m.page = "player" and m.pauseAfterSeek and m.player.state = "playing" then m.player.control = "pause"
end sub

sub SeekBy(delta as Integer)
    if not m.playStarted or m.nextPending = true then return
    if delta < 0 then m.introSkipped = false
    CancelOlderMediaProgress()
    m.pauseAfterSeek = m.pauseAfterSeek or m.player.state = "paused"
    position = m.player.position
    if m.seekPending = true or m.seekSettling = true then position = m.seekTarget
    m.seekTarget = SeekTarget(position,delta,m.player.duration)
    m.seekPending = true
    m.seekSettling = false
    m.seekNotice.text = "Seek to " + ClockText(m.seekTarget) + " / " + ClockText(m.player.duration)
    m.seekCommitTimer.control = "stop"
    m.seekCommitTimer.control = "start"
    m.advanceClock.Mark()
    UpdateIntro()
end sub

sub RestartPlayback()
    m.introSkipped = false
    CancelOlderMediaProgress()
    m.pauseAfterSeek = false
    m.seekPending = false
    m.seekSettling = false
    m.seekCommitTimer.control = "stop"
    m.lastGoodPosition = 0
    m.lastSyncPosition = -1
    entry = HistoryEntry(m.title,m.episode,0,SafeInt(m.player.duration),false)
    m.history = HistoryUpsert(m.history,entry)
    RecordEpisode(entry)
    PersistHistory()
    m.player.seek = 0
    m.expectedResume = 0
    if m.player.state = "paused" then m.player.control = "resume"
end sub

sub TogglePause()
    if m.player.state = "playing" then
        m.player.control = "pause"
    else if m.player.state = "paused" then
        m.pauseAfterSeek = false
        m.player.control = "resume"
    end if
end sub

sub OnAvailableSubtitles()
    if m.page = "player" and m.pendingSubtitle then ApplySavedSubtitle()
end sub

sub ApplySavedSubtitle()
    pref = m.registry.Read("subtitle_preference")
    if pref = "" or pref = "off" then pref = "system"
    if pref = "system" then
        if SidecarUrl("en") <> "" then LoadSidecarCaptions("en")
        m.pendingSubtitle = false
        return
    end if
    if SidecarUrl(pref) <> "" then LoadSidecarCaptions(pref): m.pendingSubtitle = false: return
    options = NativeSubtitleOptions(m.subtitleOptions,m.player.availableSubtitleTracks)
    for each option in options
        if option.code = pref and option.track <> "" then
            m.player.subtitleTrack = option.track
            m.pendingSubtitle = false
            return
        end if
    end for
    ' Track discovery can arrive after "playing". Keep waiting until the native
    ' track list exists; do not silently discard a saved embedded preference.
    if IsList(m.player.availableSubtitleTracks) then
        if m.player.availableSubtitleTracks.Count() > 0 then m.pendingSubtitle = false
    end if
end sub

sub ShowTracks(kind as String)
    m.trackKind = kind
    m.trackOptions = []
    labels = []
    if kind = "sleep" then
        m.trackHeading.text = "Sleep timer · " + SleepLabel()
        m.trackOptions = [{label:"Off",minutes:0},{label:"30 minutes",minutes:30},{label:"60 minutes",minutes:60},{label:"90 minutes",minutes:90},{label:"120 minutes",minutes:120}]
        for each option in m.trackOptions
            labels.Push(option.label)
        end for
    else if kind = "appearance" then
        m.trackHeading.text = "External subtitle appearance"
        m.trackOptions = [{label:"Background: " + m.captionContrast,setting:"contrast"},{label:"Position: " + m.captionPosition,setting:"position"},{label:"Back to subtitles",setting:"back"}]
        for each option in m.trackOptions
            labels.Push(option.label)
        end for
    else if kind = "size" then
        m.trackHeading.text = "Subtitle size"
        m.trackOptions = [{label:"Small",size:26},{label:"Medium",size:32},{label:"Large",size:40}]
        for each option in m.trackOptions
            label = option.label
            if option.size = m.captionSize then label = label + " (current)"
            labels.Push(label)
        end for
    else if kind = "timing" then
        m.trackHeading.text = "Subtitle timing · " + Text(m.captionOffset / 1000.0) + "s"
        m.trackOptions = [{label:"Show 0.5s earlier",delta:-500},{label:"Show 0.5s later",delta:500},{label:"Reset to original timing",reset:true},{label:"Back to subtitles",back:true}]
        for each option in m.trackOptions
            labels.Push(option.label)
        end for
    else if kind = "source" then
        m.trackHeading.text = "Playback source"
        for i = 0 to m.sourceOptions.Count() - 1
            option = m.sourceOptions[i]
            label = option.label
            if i = m.sourceIndex then label = label + " (current)"
            m.trackOptions.Push({label:label,index:i})
            labels.Push(label)
        end for
    else if kind = "subtitles" then
        m.trackHeading.text = "Subtitles"
        m.trackOptions = NativeSubtitleOptions(m.subtitleOptions,m.player.availableSubtitleTracks)
        m.trackOptions.Push({label:"External subtitle timing",code:"timing",track:""})
        m.trackOptions.Push({label:"External subtitle size",code:"size",track:""})
        m.trackOptions.Push({label:"External subtitle appearance",code:"appearance",track:""})
        for each option in m.trackOptions
            labels.Push(option.label)
        end for
    else
        m.trackHeading.text = "Audio"
        m.trackOptions = AudioOptions(m.player.availableAudioTracks)
        for each option in m.trackOptions
            labels.Push(option.label)
        end for
    end if
    m.trackList.content = MakeLabels(labels)
    m.trackPicker.visible = true
    m.introPrompt.visible = false
    m.overlayTimer.control = "stop"
    m.trackList.setFocus(true)
end sub

sub OnTrackSelected()
    if m.page <> "player" or not m.trackPicker.visible then return
    index = m.trackList.itemSelected
    if index < 0 or index >= m.trackOptions.Count() then return
    m.trackSelectedAt = CreateObject("roTimespan")
    m.trackSelectedAt.Mark()
    option = m.trackOptions[index]
    OnViewerActivity()
    if m.trackKind = "sleep" then
        SetSleepTimer(option.minutes)
        m.trackPicker.visible = false
        ShowControls()
        m.playbackStatus.text = "Sleep timer: " + SleepLabel()
        return
    else if m.trackKind = "appearance" then
        if option.setting = "back" then ShowTracks("subtitles"): return
        if option.setting = "contrast" then m.captionContrast = ChoiceNext(m.captionContrast,["standard","solid","soft"])
        if option.setting = "position" then m.captionPosition = ChoiceNext(m.captionPosition,["bottom","raised","top"])
        m.registry.Write("caption_contrast",m.captionContrast)
        m.registry.Write("caption_position",m.captionPosition)
        m.registry.Flush()
        UpdateCustomCaption()
        ShowTracks("appearance")
        m.trackList.jumpToItem = index
        return
    else if m.trackKind = "size" then
        m.captionSize = option.size
        m.registry.Write("caption_size",Text(m.captionSize))
        m.registry.Flush()
        UpdateCustomCaption()
        ShowTracks("subtitles")
        return
    else if m.trackKind = "timing" then
        if Truth(option.back) then ShowTracks("subtitles"): return
        if Truth(option.reset) then m.captionOffset = 0 else m.captionOffset = ClampCaptionOffset(m.captionOffset + SafeInt(option.delta))
        m.registry.Write(m.captionOffsetKey,Text(m.captionOffset))
        m.registry.Flush()
        UpdateCustomCaption()
        ShowTracks("timing")
        return
    else if m.trackKind = "source" then
        m.trackPicker.visible = false
        if option.index <> m.sourceIndex then SwitchSource(option.index)
        return
    else if m.trackKind = "subtitles" then
        if option.code = "appearance" then ShowTracks("appearance"): return
        if option.code = "size" then ShowTracks("size"): return
        if option.code = "timing" then ShowTracks("timing"): return
        ClearCustomCaptions()
        if (option.code = "fa" or option.code = "en") and SidecarUrl(option.code) <> "" then
            CreateObject("roDeviceInfo").SetCaptionsMode("On")
            LoadSidecarCaptions(option.code)
        else if option.code = "off" then
            m.player.globalCaptionMode = "Off"
        else if option.code = "system" then
            ' System mode is owned by Roku settings; never restore a stale snapshot.
            if m.defaultSubtitleTrack <> "" then m.player.subtitleTrack = m.defaultSubtitleTrack
            if SidecarUrl("en") <> "" then LoadSidecarCaptions("en")
        else
            m.player.subtitleTrack = option.track
            m.player.globalCaptionMode = "On"
        end if
        if option.code <> "embedded" then
            preference = option.code
            if preference = "off" then preference = "system"
            m.registry.Write("subtitle_preference",preference)
            m.registry.Flush()
        end if
    else if option.track <> "" then
        m.player.audioTrack = option.track
        m.pendingAudio = false
        m.registry.Write("audio_language",Text(option.language))
        m.registry.Write("audio_description",Text(Truth(option.description)))
        m.registry.Flush()
    end if
    print "[30nama][track] kind="; m.trackKind; " label="; option.label
    m.trackPicker.visible = false
    ShowControls()
end sub

function PlayerKey(key as String) as Boolean
    OnViewerActivity()
    if m.scenePreview <> invalid then
        if m.scenePreview.visible then return ScenePreviewKey(key)
    end if
    if m.watchPrompt <> invalid then
        if m.watchPrompt.visible then
            if key = "OK" or key = "play" then
                m.watchPrompt.visible = false
                m.pauseAfterSeek = false
                m.player.control = "resume"
                HideControls()
            else if key = "back" then
                m.watchPrompt.visible = false
                ClosePlayback(true)
            end if
            return true
        end if
    end if
    if m.nextPending = true then
        if key = "back" then CancelNextCountdown(): ClosePlayback(false): return true
        if key = "OK" or key = "play" then CancelNextCountdown(): PlayNextEpisode(): return true
        return true
    end if
    ' A native LabelList selection can bubble the same OK after its observer.
    if key = "OK" and m.trackSelectedAt <> invalid then
        if m.trackSelectedAt.TotalMilliseconds() < 150 then return true
    end if
    if m.trackPicker.visible then
        if key = "back" then m.trackPicker.visible = false: ShowControls(): return true
        return false
    end if
    if key = "back" then
        if m.controls.visible then HideControls() else ClosePlayback(true)
        return true
    end if
    if key = "OK" then
        if m.introPrompt <> invalid then
            if m.introPrompt.visible and ActiveIntroTarget() >= 0 then SkipIntro(): return true
        end if
        if m.controls.visible then ActivateControl() else ShowControls()
        return true
    end if
    if key = "down" then ShowTracks("subtitles"): return true
    if key = "play" then TogglePause(): return true
    if key = "left" or key = "right" then
        if m.controls.visible then
            if key = "left" then m.controlIndex = m.controlIndex - 1 else m.controlIndex = m.controlIndex + 1
            if m.controlIndex < 0 then m.controlIndex = m.controlActions.Count() - 1
            if m.controlIndex >= m.controlActions.Count() then m.controlIndex = 0
            DrawControls()
            if m.player.state = "playing" then m.overlayTimer.control = "start"
        else
            delta = RemoteSeconds("step")
            if key = "left" then delta = -delta
            SeekBy(delta)
        end if
        return true
    end if
    if key = "fastforward" or key = "rewind" then
        if m.playStarted = true and m.seekPending <> true and m.seekSettling <> true then
            OpenScenePreview()
            if m.scenePreview.visible then return ScenePreviewKey(key)
        end if
        delta = RemoteSeconds("skip")
        if key = "rewind" then delta = -delta
        SeekBy(delta)
        return true
    end if
    if key = "replay" then
        m.captionReplayUntil = m.player.position
        SeekBy(-RemoteSeconds("replay"))
        return true
    end if
    if key = "up" then ShowControls(): return true
    return false
end function

sub PlayNextEpisode()
    nextItem = NextEpisode()
    if nextItem = invalid then return
    prefetch = m.nextPrefetch
    CompletePlayback()
    ClosePlayback(false)
    m.episode = nextItem
    m.startOver = true
    m.streamIntent = "episode"
    m.requestedEpisodeId = nextItem.id
    m.recoveringStream = false
    if IsMap(prefetch) then
        if prefetch.episode.id = nextItem.id and CreateObject("roDateTime").AsSeconds() - prefetch.saved < 90 then
            m.episode = prefetch.episode
            SetSyncMedia({id:m.episode.id},m.episode.options)
            m.incomingCaption = prefetch
            StartPlayback(m.episode.file,m.episode.subtitle)
            return
        end if
    end if
    Request("stream", "stream/id/" + Text(m.title.id), {})
    m.status.text = "Loading next episode..."
end sub

sub SwitchSource(index as Integer)
    paused = m.player.state = "paused" or m.pauseAfterSeek = true
    SavePlayback()
    file = m.activeFile
    subtitles = m.activeSubtitles
    ClosePlayback(false)
    m.startOver = false
    m.recoveryPaused = paused
    StartPlayback(file,subtitles,index,true)
    m.playbackMetrics.recoveries = m.playbackMetrics.recoveries + 1
    print "[30nama][source] selected index="; index
end sub

function TryNextSource() as Boolean
    if not IsList(m.sourceOptions) then return false
    if m.sourceIndex + 1 >= m.sourceOptions.Count() then return false
    SwitchSource(m.sourceIndex + 1)
    m.playbackStatus.text = "Trying source " + Text(m.sourceIndex + 1) + " of " + Text(m.sourceOptions.Count()) + "..."
    return true
end function

sub BeginNextCountdown()
    m.introPrompt.visible = false
    CompletePlayback()
    ClearCustomCaptions()
    m.saveTimer.control = "stop"
    m.bufferTimer.control = "stop"
    m.overlayTimer.control = "stop"
    m.controls.visible = false
    m.trackPicker.visible = false
    m.nextPending = true
    m.nextRemaining = 10
    m.nextCountdown.visible = true
    DrawNextCountdown()
    m.nextCountdown.setFocus(true)
    m.nextTimer.control = "start"
end sub

sub DrawNextCountdown()
    ep = NextEpisode()
    if ep = invalid then CancelNextCountdown(): return
    m.nextCountdownText.text = "Next: S" + Text(ep.season) + " E" + Text(ep.number) + Chr(10) + "Starting in " + Text(m.nextRemaining) + " seconds"
end sub

sub OnNextTimer()
    if m.page <> "player" or not m.nextPending then CancelNextCountdown(): return
    m.nextRemaining = m.nextRemaining - 1
    if m.nextRemaining <= 0 then
        CancelNextCountdown()
        PlayNextEpisode()
    else
        DrawNextCountdown()
    end if
end sub

sub CancelNextCountdown()
    m.nextPending = false
    m.nextTimer.control = "stop"
    m.nextCountdown.visible = false
end sub
